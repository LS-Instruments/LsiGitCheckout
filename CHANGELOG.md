# Changelog

All notable changes to LsiGitCheckout will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.0] - 2025-01-14

### Changed
- **BREAKING**: Moved SSH key configuration from dependencies.json to separate git_credentials.json file
- SSH keys are now mapped by hostname instead of per-repository
- Improved security by separating credentials from repository configuration

### Added
- New `-CredentialsFile` parameter to specify custom SSH credentials file
- Automatic hostname extraction from repository URLs
- Support for hostnames with and without `ssh://` prefix in credentials file

### Removed
- "SSH Key Path" field from Repository configuration in dependencies.json
- "SSH Key Path" field from Submodule Config in dependencies.json

### Migration Guide
1. Create a new `git_credentials.json` file with hostname-to-key mappings
2. Remove all "SSH Key Path" fields from your dependencies.json
3. The script will automatically look up SSH keys based on repository hostnames

## [2.1.2] - 2025-01-10

### Removed
- Removed dead code: Get-SshKeyPassword function (not used with PuTTY/Pageant)

### Fixed
- Script structure syntax errors

## [2.1.0] - 2025-01-10

### Changed
- **BREAKING**: Removed OpenSSH support - now PuTTY/plink only
- Simplified SSH key handling to only support PuTTY format (.ppk)
- Removed -SshClient parameter

### Removed
- All OpenSSH-related code branches
- SSH client mode selection

## [2.0.0] - 2025-01-09

### Changed
- **BREAKING**: Removed per-submodule Skip LFS configuration
- Skip LFS now applies to the entire repository including all submodules
- Significantly simplified code by removing complex LFS override logic

### Fixed
- Submodule LFS inheritance issues
- Debug message accuracy

## [1.5.0] - 2025-01-09

### Added
- SSH key support for individual submodules during update
- Submodules can now use different SSH keys as configured
- Improved error handling for SSH submodule authentication

### Changed
- Merged "Submodule SSH Keys" into "Submodule Config" for cleaner JSON format

## [1.4.0] - 2025-01-09

### Added
- "Skip LFS" configuration option for repositories
- "Submodule Config" section with per-submodule LFS control
- LFS pulls can now be skipped on a per-repository or per-submodule basis

## [1.3.0] - 2025-01-08

### Added
- Support for PuTTY/plink SSH client
- -SshClient parameter to choose between OpenSSH and PuTTY
- Automatic detection of key format (OpenSSH vs PuTTY)
- Integration with Pageant for PuTTY keys

## [1.2.0] - 2025-01-08

### Added
- Support for repository paths with spaces
- Proper quoting for all path operations

### Fixed
- Clone operations failing when repository path contains spaces
- Git commands not properly handling quoted paths

## [1.1.0] - 2025-01-08

### Added
- Git LFS support with automatic detection
- Submodule SSH key configuration
- Dry run mode (-DryRun parameter)
- Debug logging (-EnableDebugLog parameter)

### Changed
- Improved error handling and user feedback
- Enhanced logging system with multiple levels

## [1.0.0] - 2025-01-07

### Added
- Initial release
- Multiple repository management from JSON configuration
- Tag-based checkout
- SSH key support for repositories
- Automatic repository reset
- Submodule initialization and update
- Comprehensive error handling
- Summary report generation