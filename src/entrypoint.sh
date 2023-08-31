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

echo "echo \"::set-output name=new-version::$NEW_VERSION\"" > set_outputs.sh

echo "Setting up provisioned concurrency for version: $NEW_VERSION..."
aws lambda put-provisioned-concurrency-config \
  --function-name $INPUT_FUNCTION_NAME \
  --qualifier $NEW_VERSION \
  --provisioned-concurrent-executions $INPUT_PROVISIONED_CONCURRENCY
echo "Successfully set up provisioned concurrency for version: $NEW_VERSION"

echo "echo \"::set-output name=provisioned-concurrency::$INPUT_PROVISIONED_CONCURRENCY\"" >> set_outputs.sh
