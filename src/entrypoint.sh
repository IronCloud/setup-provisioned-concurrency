#!/bin/bash

handle_error() {
  echo "::error::Error on line $1"
  exit 1
}

trap 'handle_error $LINENO' ERR

set -euo pipefail

# --- Input validation ---

if [[ -z "${INPUT_FUNCTION_NAME:-}" ]]; then
  echo "::error::Input 'function-name' is required"
  exit 1
fi

if ! [[ "${INPUT_PROVISIONED_CONCURRENCY}" =~ ^[1-9][0-9]*$ ]]; then
  echo "::error::Input 'provisioned-concurrency' must be a positive integer, got: '${INPUT_PROVISIONED_CONCURRENCY}'"
  exit 1
fi

if ! [[ "${INPUT_WAIT_TIMEOUT}" =~ ^[0-9]+$ ]] || [[ "${INPUT_WAIT_TIMEOUT}" -lt 1 ]]; then
  echo "::error::Input 'wait-timeout' must be a positive integer, got: '${INPUT_WAIT_TIMEOUT}'"
  exit 1
fi

if ! [[ "${INPUT_VERSIONS_TO_KEEP}" =~ ^[0-9]+$ ]]; then
  echo "::error::Input 'versions-to-keep' must be a non-negative integer, got: '${INPUT_VERSIONS_TO_KEEP}'"
  exit 1
fi

# --- AWS CLI check ---

if ! command -v aws &> /dev/null; then
  echo "::error::AWS CLI is not installed. GitHub-hosted runners include it by default."
  exit 1
fi

echo "AWS CLI is available."

# --- Publish new version ---

echo "Publishing a new version for Lambda function: ${INPUT_FUNCTION_NAME}..."
NEW_VERSION=$(aws lambda publish-version \
  --function-name "${INPUT_FUNCTION_NAME}" \
  --query "Version" \
  --output text)
echo "Successfully published new version: ${NEW_VERSION}"

# --- Set outputs ---

echo "new-version=${NEW_VERSION}" >> "${GITHUB_OUTPUT}"
echo "provisioned-concurrency=${INPUT_PROVISIONED_CONCURRENCY}" >> "${GITHUB_OUTPUT}"

# Backward compat: also write to GITHUB_ENV
echo "NEW_VERSION=${NEW_VERSION}" >> "${GITHUB_ENV}"
echo "PROVISIONED_CONCURRENCY=${INPUT_PROVISIONED_CONCURRENCY}" >> "${GITHUB_ENV}"

# --- Set provisioned concurrency (with rollback on failure) ---

echo "Setting up provisioned concurrency for version: ${NEW_VERSION}..."
if ! aws lambda put-provisioned-concurrency-config \
  --function-name "${INPUT_FUNCTION_NAME}" \
  --qualifier "${NEW_VERSION}" \
  --provisioned-concurrent-executions "${INPUT_PROVISIONED_CONCURRENCY}"; then

  echo "::error::Failed to set provisioned concurrency. Rolling back version ${NEW_VERSION}..."
  aws lambda delete-function \
    --function-name "${INPUT_FUNCTION_NAME}" \
    --qualifier "${NEW_VERSION}" || true
  exit 1
fi
echo "Successfully set up provisioned concurrency for version: ${NEW_VERSION}"

# --- Readiness polling ---

if [[ "${INPUT_WAIT_FOR_READY}" == "true" ]]; then
  echo "Waiting for provisioned concurrency to become Ready (timeout: ${INPUT_WAIT_TIMEOUT}s)..."
  SECONDS=0
  while true; do
    STATUS=$(aws lambda get-provisioned-concurrency-config \
      --function-name "${INPUT_FUNCTION_NAME}" \
      --qualifier "${NEW_VERSION}" \
      --query "Status" \
      --output text 2>/dev/null || echo "UNKNOWN")

    if [[ "${STATUS}" == "READY" ]]; then
      echo "Provisioned concurrency is Ready."
      break
    elif [[ "${STATUS}" == "FAILED" ]]; then
      echo "::error::Provisioned concurrency status is FAILED for version ${NEW_VERSION}."
      exit 1
    fi

    if [[ ${SECONDS} -ge ${INPUT_WAIT_TIMEOUT} ]]; then
      echo "::error::Timed out after ${INPUT_WAIT_TIMEOUT}s waiting for provisioned concurrency (status: ${STATUS})."
      exit 1
    fi

    echo "  Status: ${STATUS} (${SECONDS}s elapsed)..."
    sleep 10
  done
fi

# --- Cleanup old versions ---

if [[ "${INPUT_CLEANUP}" == "true" ]]; then
  echo "Cleaning up old versions..."

  # Get all versions (excluding $LATEST and the new version), sorted descending
  ALL_VERSIONS=$(aws lambda list-versions-by-function \
    --function-name "${INPUT_FUNCTION_NAME}" \
    --no-paginate \
    --query "Versions[?Version!='\$LATEST' && Version!='${NEW_VERSION}'].Version" \
    --output text)

  if [[ -z "${ALL_VERSIONS}" ]]; then
    echo "No older versions found. Skipping cleanup."
  else
    # Sort versions descending numerically
    SORTED_VERSIONS=$(echo "${ALL_VERSIONS}" | tr '\t' '\n' | sort -rn)

    # Get alias-protected versions
    ALIAS_VERSIONS=$(aws lambda list-aliases \
      --function-name "${INPUT_FUNCTION_NAME}" \
      --no-paginate \
      --query "Aliases[].FunctionVersion" \
      --output text 2>/dev/null || echo "")

    SKIP_COUNT=0
    for OLD_VERSION in ${SORTED_VERSIONS}; do
      # Skip versions we want to keep (most recent N)
      if [[ ${SKIP_COUNT} -lt ${INPUT_VERSIONS_TO_KEEP} ]]; then
        echo "Keeping version ${OLD_VERSION} (versions-to-keep: ${INPUT_VERSIONS_TO_KEEP})"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        continue
      fi

      # Skip alias-protected versions
      if echo "${ALIAS_VERSIONS}" | tr '\t' '\n' | grep -qx "${OLD_VERSION}" 2>/dev/null; then
        echo "::warning::Skipping version ${OLD_VERSION} — referenced by an alias"
        continue
      fi

      echo "Deleting provisioned concurrency for version: ${OLD_VERSION}..."
      aws lambda delete-provisioned-concurrency-config \
        --function-name "${INPUT_FUNCTION_NAME}" \
        --qualifier "${OLD_VERSION}" 2>/dev/null || true

      echo "Deleting version: ${OLD_VERSION}..."
      aws lambda delete-function \
        --function-name "${INPUT_FUNCTION_NAME}" \
        --qualifier "${OLD_VERSION}" || true

      sleep 0.5
    done
  fi
fi

# --- Step summary ---

cat >> "${GITHUB_STEP_SUMMARY}" <<EOF
### Provisioned Concurrency Setup

| Detail | Value |
|--------|-------|
| Function | \`${INPUT_FUNCTION_NAME}\` |
| New Version | \`${NEW_VERSION}\` |
| Provisioned Concurrency | \`${INPUT_PROVISIONED_CONCURRENCY}\` |
| Wait for Ready | \`${INPUT_WAIT_FOR_READY}\` |
| Cleanup | \`${INPUT_CLEANUP}\` |
| Versions to Keep | \`${INPUT_VERSIONS_TO_KEEP}\` |
EOF

echo "Done."
