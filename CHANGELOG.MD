# Changelog

## [v2.0.0] - 2023-09-05

### Added

- The action now also cleans up older versions of the Lambda function and their provisioned concurrency configurations.

### Changed
- Updated IAM permissions in the README to include `lambda:DeleteProvisionedConcurrencyConfig` and `lambda:DeleteFunction`.

### Fixed
- The action now correctly handles cases where there are no older versions or provisioned concurrency configurations.

## [v1.0.0] - 2023-08-31

### Added
- Initial release of the Setup Provisioned Concurrency GitHub Action.
- Publishes a new version of a specified AWS Lambda function.
- Sets up provisioned concurrency for the new version.