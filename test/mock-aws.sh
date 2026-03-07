#!/bin/bash
# Mock AWS CLI for testing. Simulates Lambda API responses.
# Place this directory first in PATH to override the real aws command.

set -euo pipefail

MOCK_VERSION="${MOCK_AWS_VERSION:-42}"
MOCK_OLD_VERSIONS="${MOCK_AWS_OLD_VERSIONS:-}"
MOCK_ALIAS_VERSIONS="${MOCK_AWS_ALIAS_VERSIONS:-}"
MOCK_READY_AFTER="${MOCK_AWS_READY_AFTER:-0}"
MOCK_STATE_DIR="${MOCK_AWS_STATE_DIR:-/tmp/mock-aws}"

mkdir -p "${MOCK_STATE_DIR}"

SUBCOMMAND="${1:-} ${2:-}"
shift 2 || true

case "${SUBCOMMAND}" in
  "lambda publish-version")
    echo "${MOCK_VERSION}"
    ;;

  "lambda put-provisioned-concurrency-config")
    echo '{"Status": "IN_PROGRESS"}'
    ;;

  "lambda get-provisioned-concurrency-config")
    POLL_COUNT=0
    if [[ -f "${MOCK_STATE_DIR}/poll-count" ]]; then
      POLL_COUNT=$(cat "${MOCK_STATE_DIR}/poll-count")
    fi
    POLL_COUNT=$((POLL_COUNT + 1))
    echo "${POLL_COUNT}" > "${MOCK_STATE_DIR}/poll-count"

    if [[ ${POLL_COUNT} -ge ${MOCK_READY_AFTER} ]]; then
      echo "READY"
    else
      echo "IN_PROGRESS"
    fi
    ;;

  "lambda list-versions-by-function")
    echo "${MOCK_OLD_VERSIONS}"
    ;;

  "lambda list-aliases")
    echo "${MOCK_ALIAS_VERSIONS}"
    ;;

  "lambda delete-provisioned-concurrency-config")
    echo "mock: deleted provisioned concurrency" >&2
    ;;

  "lambda delete-function")
    echo "mock: deleted function version" >&2
    ;;

  *)
    echo "mock-aws: unhandled command: ${SUBCOMMAND}" >&2
    exit 1
    ;;
esac
