# Setup Provisioned Concurrency GitHub Action

This GitHub Action sets up and cleans up provisioned concurrency for a specified AWS Lambda function. It automatically publishes a new version of the Lambda function, sets up provisioned concurrency for that version, waits for it to become ready, and safely deletes older versions along with their provisioned concurrency configurations.

## Prerequisites

- The AWS Lambda function must already exist.
- AWS credentials must be configured before running this action.
- We recommend using [`aws-actions/configure-aws-credentials`](https://github.com/aws-actions/configure-aws-credentials) with OIDC for keyless authentication. Static access keys also work but are less secure.

## IAM Permissions

The AWS credentials used must have the following IAM permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "lambda:PublishVersion",
        "lambda:PutProvisionedConcurrencyConfig",
        "lambda:GetProvisionedConcurrencyConfig",
        "lambda:ListVersionsByFunction",
        "lambda:ListAliases",
        "lambda:DeleteProvisionedConcurrencyConfig",
        "lambda:DeleteFunction"
      ],
      "Resource": "arn:aws:lambda:REGION:ACCOUNT_ID:function:FUNCTION_NAME:*"
    }
  ]
}
```

Replace `REGION`, `ACCOUNT_ID`, and `FUNCTION_NAME` with your AWS region, account ID, and the name of your Lambda function, respectively. The `:*` suffix is required because versioned operations (publish, delete, qualifier-based calls) target versioned ARNs.

## Usage

Here's a sample workflow to demonstrate how to use this action:

```yaml
name: Setup Provisioned Concurrency

on:
  push:
    branches:
      - main

jobs:
  setup:
    runs-on: ubuntu-latest
    # Prevent concurrent runs to avoid race conditions during cleanup
    concurrency:
      group: provisioned-concurrency-${{ github.ref }}
      cancel-in-progress: false

    steps:
    - name: Checkout code
      uses: actions/checkout@v6

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v6
      with:
        role-to-assume: arn:aws:iam::123456789012:role/my-github-actions-role
        aws-region: us-west-2

    - name: Deploy Lambda
      run: |
        cd my-app/
        # your deployment command here

    - name: Setup Provisioned Concurrency
      id: provisioned
      uses: IronCloud/setup-provisioned-concurrency@v3
      with:
        function-name: 'your-lambda-function-name'
        provisioned-concurrency: 5
        wait-for-ready: 'true'
        wait-timeout: '300'
        cleanup: 'true'
        versions-to-keep: '1'

    - name: Use outputs
      run: |
        echo "Published version: ${{ steps.provisioned.outputs.new-version }}"
        echo "Concurrency set: ${{ steps.provisioned.outputs.provisioned-concurrency }}"
```

## Inputs

| Input                    | Description                                               | Required | Default |
|--------------------------|-----------------------------------------------------------|----------|---------|
| `function-name`          | The name of the AWS Lambda function.                      | Yes      |         |
| `provisioned-concurrency`| The number of provisioned concurrency to set up.          | Yes      |         |
| `wait-for-ready`         | Wait for provisioned concurrency to reach Ready status.   | No       | `true`  |
| `wait-timeout`           | Seconds to wait for provisioned concurrency to be ready.  | No       | `300`   |
| `cleanup`                | Whether to clean up old versions after setup.             | No       | `true`  |
| `versions-to-keep`       | Number of old versions to retain (0 = delete all old).    | No       | `0`     |

## Outputs

| Output                    | Description                                            |
|---------------------------|--------------------------------------------------------|
| `new-version`             | The new version of the Lambda function that was published. |
| `provisioned-concurrency` | The number of provisioned concurrency that was set up. |

## Concurrency

To prevent race conditions when multiple workflows run simultaneously, use a [concurrency group](https://docs.github.com/en/actions/using-jobs/using-concurrency) as shown in the usage example above.

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License

[MIT](LICENSE)
