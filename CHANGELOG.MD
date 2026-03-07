# Changelog

## [v3.0.0] - 2026-03-07

### Added
- Readiness polling: waits for provisioned concurrency to reach `Ready` status before proceeding (configurable via `wait-for-ready` and `wait-timeout` inputs).
- Alias protection: cleanup skips any version referenced by a Lambda alias.
- `versions-to-keep` input to retain a configurable number of old versions during cleanup.
- `cleanup` input to optionally disable old version cleanup.
- Input validation with clear error messages for all inputs.
- Rollback on failure: deletes the orphaned version if `put-provisioned-concurrency-config` fails.
- Rate limiting (`sleep 0.5`) between version deletions to avoid API throttling.
- Step summary written to `GITHUB_STEP_SUMMARY`.
- Output verification step in test workflow.

### Changed
- Outputs now use `GITHUB_OUTPUT` with proper `value:` mappings in `action.yml` (fixes broken outputs).
- All variables are quoted throughout the script (fixes shellcheck SC2086).
- AWS CLI is now required (hard error instead of `pip install awscli`).
- Cleanup uses `--no-paginate` to handle functions with many versions.
- CI workflow dependencies pinned to latest: `actions/checkout@v6.0.2`, `aws-actions/configure-aws-credentials@v6.0.0` (SHA-pinned).
- CI cleanup step now runs with `if: always()`.
- IAM permissions in README updated: added `lambda:ListAliases` and `lambda:GetProvisionedConcurrencyConfig`, fixed Resource ARN to include `:*`.
- Usage example updated with OIDC authentication and concurrency group recommendation.

### Fixed
- Broken action outputs: outputs were not accessible to downstream steps.
- Blind version deletion: versions referenced by aliases are now skipped.
- No pagination on `list-versions-by-function` could silently skip versions.
- Unquoted variables throughout the script.
- CI cleanup step was skipped on action failure.

## [v2.0.0] - 2023-09-05

### Added

- The action now also cleans up older versions of the Lambda function and their provisioned concurrency configurations.

### Changed
- Updated IAM permissions in the README to include lambda:DeleteProvisionedConcurrencyConfig and lambda:DeleteFunction.

### Fixed
- The action now correctly handles cases where there are no older versions or provisioned concurrency configurations.

## [v1.0.0] - 2023-08-31

### Added
- Initial release of the Setup Provisioned Concurrency GitHub Action.
- Publishes a new version of a specified AWS Lambda function.
- Sets up provisioned concurrency for the new version.
