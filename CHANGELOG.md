# Changelog

All notable changes to LsiGitCheckout will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [6.0.0] - 2025-01-24

### Breaking Changes
- **BREAKING**: Removed `-DisableTagSorting` parameter - tag temporal sorting is now always enabled
- **BREAKING**: Eliminated all legacy manual ordering code paths for API Compatible Tags
- **BREAKING**: API Compatible Tags can now be listed in any order - automatic chronological sorting is always applied

### Added
- Always-on intelligent tag temporal sorting using actual git tag dates
- Enhanced performance with optimized tag sorting algorithms that run only when needed
- Simplified codebase with single, consistent code paths for tag handling
- Improved user experience with no configuration required for optimal tag ordering

### Changed
- **Major Simplification**: Removed 195+ lines of conditional logic and legacy fallback code (26% reduction)
- API compatibility resolution now always uses chronological tag intelligence
- Tag selection algorithms simplified to single code paths for both Strict and Permissive modes
- Documentation streamlined to reflect always-enabled temporal sorting
- Startup logging simplified with clear indication that tag sorting is always active

### Removed
- `-DisableTagSorting` parameter and all associated functionality
- `$script:EnableTagSorting` variable and conditional logic
- Legacy manual ordering requirements and validation
- Complex fallback algorithms for manual tag ordering compatibility
- Conditional warnings for incompatible manually-ordered tag lists
- All code branches that handled disabled tag sorting

### Performance
- **Optimized algorithms**: Tag date fetching only occurs when needed for conflict resolution
- **Reduced complexity**: Single execution path eliminates branching overhead
- **Cleaner memory usage**: Removed unused variables and conditional state tracking
- **Faster conflict resolution**: Always uses optimal chronological intelligence

### Migration Notes
- **Zero configuration changes**: All existing JSON files work without modification
- **Improved behavior**: Users automatically get optimal tag ordering without any parameter changes
- **Enhanced reliability**: Eliminates the possibility of manual ordering errors
- **Better developer experience**: API Compatible Tags can be listed in any order

### Benefits
- **Cleaner codebase**: 26% reduction in code complexity
- **Better maintainability**: Single code path for all tag operations
- **Enhanced user experience**: Always uses intelligent behavior by default
- **Consistent performance**: Optimized algorithms used in all scenarios
- **Simplified documentation**: Easier to understand and use

## [5.0.0] - 2025-01-17

### Breaking Changes
- **BREAKING**: Renamed `-Recursive` parameter to `-DisableRecursion` for cleaner API design
- **BREAKING**: Renamed `-EnableTagSorting` parameter to `-DisableTagSorting` for consistent naming conventions
- **BREAKING**: Recursive mode and tag temporal sorting are now enabled by default (no parameters needed for optimal behavior)

### Added
- Clean parameter API following PowerShell switch parameter best practices
- Intuitive default behavior requiring zero configuration for most use cases
- Consistent naming conventions for all disable flags

### Changed
- Switch parameters now use proper naming conventions (disable flags instead of enable flags with defaults)
- Default behavior provides intelligent recursive processing and tag sorting out-of-the-box
- Enhanced user experience with no required parameters for optimal functionality

### Migration
- **Old**: `.\LsiGitCheckout.ps1 -Recursive -EnableTagSorting` → **New**: `.\LsiGitCheckout.ps1` (default)
- **Old**: `.\LsiGitCheckout.ps1 -Recursive:$false -EnableTagSorting:$false` → **New**: `.\LsiGitCheckout.ps1 -DisableRecursion -DisableTagSorting`
- All JSON configuration files work without modification
- Functionality remains identical with improved parameter usability

## [4.2.0] - 2025-01-17

### Added
- **Default Intelligent Behavior**: Made `-Recursive` and `-EnableTagSorting` enabled by default for optimal out-of-the-box experience
- **Performance-Optimized Tag Temporal Sorting**: Intelligent tag selection algorithm that prioritizes existing/new "Tag" values when resolving repository conflicts
- `Get-GitTagDates` function for efficient tag date fetching using `git for-each-ref`
- `Sort-TagsByDate` function for chronological tag sorting with comprehensive debug logging
- Enhanced `Get-TagUnion` function with temporal sorting support when tag dates are available
- Priority-based tag selection: prefers specified "Tag" values over other compatible tags when both are compatible
- Fallback to chronologically most recent tag when neither existing nor new "Tag" is compatible
- Comprehensive verbose and debug logging for tag temporal sorting operations
- Tag date verification and temporal order display in verbose mode
- Tag date caching in repository dictionary for performance optimization
- Enhanced repository conflict detection logging with clear status indicators

### Changed
- **BREAKING (Default Behavior)**: `-Recursive` now defaults to `$true` (enabled by default)
- **BREAKING (Default Behavior)**: `-EnableTagSorting` now defaults to `$true` (enabled by default)
- Enhanced repository dictionary structure to include `TagDates` field for storing tag date mappings
- Improved tag selection logic in all API compatibility scenarios (Strict-Strict, Strict-Permissive, Permissive-Permissive, Permissive-Strict)
- Updated summary report to display tag temporal sorting status and statistics
- Enhanced union algorithm to use temporal sorting when enabled, falling back to original logic when disabled
- Optimized tag sorting to only run when needed during API compatibility resolution
- Improved repository conflict logging to clearly indicate when repositories already exist in dictionary
- Enhanced error handling for tag date parsing and git command failures

### Fixed
- PowerShell string interpolation issues with datetime formatting in log messages
- Improved tag sorting object creation using `[PSCustomObject]` for reliable `Sort-Object` operations
- Enhanced temporal verification logging with proper variable delimiting

### Performance
- **Optimized on-demand processing**: Tag dates fetched only when conflicts require resolution during recursive processing
- Efficient `git for-each-ref` command usage instead of individual `git log` calls per tag
- Tag date caching eliminates redundant git operations during recursive processing
- Reduced unnecessary tag date fetching and sorting operations

### Backward Compatibility
- **Behavior Change**: Default behavior now includes recursive processing and intelligent tag sorting
- **Legacy Support**: Use `-Recursive:$false -EnableTagSorting:$false` to restore v4.1.x behavior
- **Non-breaking**: All existing configurations work without modification
- Manual temporal ordering requirements preserved when tag sorting is explicitly disabled

### Migration Notes
- **Zero configuration upgrade**: Most users get optimal behavior without any parameter changes
- **Enhanced user experience**: New users get intelligent behavior by default
- **Optional legacy mode**: Previous behavior available via explicit parameter flags
- **Performance benefits**: Automatic optimization for complex dependency graphs

## [4.1.1] - 2025-01-16

### Fixed
- Temporal ordering preserved in union operations for Permissive mode
- Union algorithm now maintains the chronological order of tags when constraints are met

### Added
- Warning when tag lists don't start with the same tag (falls back to unordered union)
- Warning when tag lists have same length but different content (falls back to unordered union)
- Debug logging for edge cases in union operations

## [4.1.0] - 2025-01-16

### Added
- "API Compatibility" field in dependencies.json with "Strict" and "Permissive" modes
- `-ApiCompatibility` parameter to set default compatibility mode (defaults to "Permissive")
- Enhanced tag selection algorithm based on compatibility mode:
  - **Strict mode**: Uses intersection of compatible tags (existing behavior)
  - **Permissive mode**: Uses union of compatible tags for more flexible version management
- Compatibility mode inheritance rules:
  - Strict + Strict = Use intersection algorithm
  - Strict + Permissive = Keep existing Strict repository unchanged
  - Permissive + Permissive = Use union algorithm
  - Permissive + Strict = Adopt Strict mode and its tags

### Changed
- Tag selection in Permissive mode now selects the most recent tag from the union of all compatible versions
- Repository dictionary now tracks API Compatibility mode for each repository
- Summary report now displays the default API Compatibility mode

### Fixed
- Improved handling of tag ordering in union operations

## [4.0.2] - 2025-01-15

### Fixed
- Git checkout error capture now properly displays stderr messages for missing tags
- Improved error reporting clarity when tags don't exist in repositories

### Changed
- Switched from `Invoke-Expression` to `&` operator for more reliable error capture

## [4.0.1] - 2025-01-15

### Added
- Cleanup of failed clones to prevent repositories in undefined states
- CheckoutFailed tracking to skip dependency processing for failed repositories

### Fixed
- Error handling for missing tags now provides detailed error messages
- Repositories that fail to checkout no longer have their dependencies processed

### Changed
- Enhanced error message capture and display for all git operations

## [4.0.0] - 2025-01-15

### Added
- Recursive dependency discovery and processing with `-Recursive` flag
- API compatibility checking for shared dependencies
- "API Compatible Tags" field for version compatibility management
- Automatic version selection (most recent compatible version)
- Path conflict detection for duplicate repositories
- `-MaxDepth` parameter to control recursion depth (default: 5)
- JSON dependency file content logging in debug mode
- Dynamic tag checkout when newer compatible version is found

### Changed
- Improved path normalization to resolve relative paths correctly
- Enhanced debug logging for better troubleshooting
- Repository dictionary tracks all discovered repositories

### Fixed
- PowerShell HashSet compatibility issues across different versions
- Path resolution for nested relative paths with ".." segments

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