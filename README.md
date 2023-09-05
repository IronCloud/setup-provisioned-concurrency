# Setup Provisioned Concurrency GitHub Action

This GitHub Action sets up and cleans up provisioned concurrency for a specified AWS Lambda function. It automatically publishes a new version of the Lambda function, sets up provisioned concurrency for that version, and deletes older versions along with their provisioned concurrency configurations.

## Prerequisites

- The AWS Lambda function must already exist.
- AWS credentials must be configured before running this action. 
- We recommend using [`aws-actions/configure-aws-credentials`](https://github.com/aws-actions/configure-aws-credentials) for this.

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
        "lambda:ListVersionsByFunction",
        "lambda:DeleteProvisionedConcurrencyConfig",
        "lambda:DeleteFunction"
      ],
      "Resource": "arn:aws:lambda:REGION:ACCOUNT_ID:function:FUNCTION_NAME"
    }
  ]
}

```

Replace `REGION`, `ACCOUNT_ID`, and `FUNCTION_NAME` with your AWS region, account ID, and the name of your Lambda function, respectively.

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

    steps:
    - name: Checkout code
      uses: actions/checkout@v3

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v3
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-west-2

    - name: Deploy Chalice App
      run: |
        cd my-app/
        chalice deploy        

    - name: Setup Provisioned Concurrency
      uses: IronCloud/setup-provisioned-concurrency@v2
      with:
        function-name: 'your-lambda-function-name'
        provisioned-concurrency: 5
```

Replace `your-github-username` with your GitHub username and `your-lambda-function-name` with the name of your Lambda function.

## Inputs

| Input                    | Description                                         | Required |
|--------------------------|-----------------------------------------------------|----------|
| `function-name`          | The name of the AWS Lambda function.                | Yes      |
| `provisioned-concurrency`| The number of provisioned concurrency to set up.    | Yes      |

## Outputs

- `new-version`: The new version of the Lambda function that was published.
- `provisioned-concurrency`: The number of provisioned concurrency that was set up.

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License

[MIT](LICENSE)
