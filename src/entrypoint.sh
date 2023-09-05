#!/bin/bash

handle_error() {
  echo "Error on line $1"
  exit 1
}

trap 'handle_error $LINENO' ERR

set -e

if ! command -v aws &> /dev/null; then
  echo "AWS CLI could not be found, installing..."
  pip install awscli
else
  echo "AWS CLI is already installed."
fi

echo "Publishing a new version for Lambda function: $INPUT_FUNCTION_NAME..."
NEW_VERSION=$(aws lambda publish-version --function-name $INPUT_FUNCTION_NAME --query "Version" --output text)
echo "Successfully published new version: $NEW_VERSION"

echo "NEW_VERSION=$NEW_VERSION" >> $GITHUB_ENV

echo "Setting up provisioned concurrency for version: $NEW_VERSION..."
aws lambda put-provisioned-concurrency-config \
  --function-name $INPUT_FUNCTION_NAME \
  --qualifier $NEW_VERSION \
  --provisioned-concurrent-executions $INPUT_PROVISIONED_CONCURRENCY
echo "Successfully set up provisioned concurrency for version: $NEW_VERSION"

echo "PROVISIONED_CONCURRENCY=$INPUT_PROVISIONED_CONCURRENCY" >> $GITHUB_ENV

# Clean up
OLDER_VERSIONS=$(aws lambda list-versions-by-function \
  --function-name $INPUT_FUNCTION_NAME \
  --query "Versions[?Version!='\$LATEST' && Version!='${NEW_VERSION}'].Version" \
  --output text)

if [ -z "$OLDER_VERSIONS" ]; then
  echo "No older versions found. Skipping deletion."
else
  for OLD_VERSION in $OLDER_VERSIONS; do
    echo "Deleting provisioned concurrency for version: $OLD_VERSION..."
    aws lambda delete-provisioned-concurrency-config \
      --function-name $INPUT_FUNCTION_NAME \
      --qualifier $OLD_VERSION || echo "No provisioned concurrency to delete for version: $OLD_VERSION"

    echo "Deleting version: $OLD_VERSION..."
    aws lambda delete-function \
      --function-name $INPUT_FUNCTION_NAME \
      --qualifier $OLD_VERSION || echo "Failed to delete version: $OLD_VERSION"
  done
fi
