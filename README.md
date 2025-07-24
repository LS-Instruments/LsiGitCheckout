# LsiGitCheckout

A PowerShell script for managing multiple Git repositories with support for tags, SSH authentication via PuTTY, Git LFS, and submodules. Features advanced recursive dependency resolution with API compatibility checking, flexible compatibility modes, and intelligent automatic tag temporal sorting.

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Basic Usage (Non-Recursive)](#basic-usage-non-recursive)
- [Advanced Usage (Recursive Mode)](#advanced-usage-recursive-mode)
- [API Compatibility Modes](#api-compatibility-modes)
- [Intelligent Tag Temporal Sorting](#intelligent-tag-temporal-sorting)
- [Security Best Practices](#security-best-practices)
- [SSH Setup with PuTTY](#ssh-setup-with-putty)
- [Troubleshooting](#troubleshooting)
- [Migration Guide](#migration-guide)
- [LsiGitCheckout vs Traditional Package Managers](#lsigitcheckout-vs-traditional-package-managers)
- [License](#license)
- [Contributing](#contributing)

## Features

- **Batch Operations**: Clone or update multiple Git repositories from a single JSON configuration file
- **Tag Support**: Automatically checkout specific tags for each repository
- **PuTTY/Pageant Integration**: SSH authentication using PuTTY format keys (.ppk)
- **Secure Credentials Management**: SSH keys stored separately from repository configuration
- **Submodule Support**: Handles Git submodules with automatic SSH key lookup
- **Git LFS Support**: Optional Git LFS content management with skip functionality
- **Smart Reset**: Automatically resets repositories to clean state before checkout
- **Error Handling**: Comprehensive logging and user-friendly error dialogs
- **Dry Run Mode**: Preview operations without making changes
- **Recursive Dependencies**: Discover and process nested repository dependencies with API compatibility checking
- **Flexible Compatibility Modes**: Choose between Strict and Permissive API compatibility modes
- **Intelligent Tag Temporal Sorting**: Always-on automatic chronological tag ordering using actual git tag dates with optimized performance

## Requirements

- **Operating System**: Windows 10/11 or Windows Server 2016+
- **PowerShell**: Version 5.1 or higher
- **Git**: Git for Windows (https://git-scm.com/download/win)
- **PuTTY Suite**: For SSH authentication (https://www.putty.org/)
  - plink.exe must be in PATH
  - pageant.exe for SSH key management
- **Git LFS**: Optional, for Large File Storage support (https://git-lfs.github.com/)

## Installation

1. Download `LsiGitCheckout.ps1` to your desired location
2. Create `dependencies.json` with your repository configuration
3. Create `git_credentials.json` with your SSH key mappings (if using SSH)
4. Ensure execution policy allows running scripts:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

## Basic Usage (Non-Recursive)

### Overview

In non-recursive mode, the script processes only the repositories listed in your main dependencies file. It does not look for or process any nested dependencies.

### Command Line Usage

```powershell
# Use default settings (recursive mode and intelligent tag sorting enabled by default)
.\LsiGitCheckout.ps1

# Specify custom JSON files
.\LsiGitCheckout.ps1 -InputFile "C:\configs\myrepos.json" -CredentialsFile "C:\configs\my_credentials.json"

# Enable debug logging
.\LsiGitCheckout.ps1 -EnableDebug

# Dry run mode (preview without changes)
.\LsiGitCheckout.ps1 -DryRun

# Verbose output
.\LsiGitCheckout.ps1 -Verbose

# Set default API compatibility mode
.\LsiGitCheckout.ps1 -ApiCompatibility Strict

# Disable recursive mode (non-recursive mode)
.\LsiGitCheckout.ps1 -DisableRecursion
```

### Parameters

- `-InputFile`: Path to repository configuration file (default: dependencies.json)
- `-CredentialsFile`: Path to SSH credentials file (default: git_credentials.json)
- `-DryRun`: Preview operations without making changes
- `-EnableDebug`: Create detailed debug log file
- `-Verbose`: Show verbose output messages
- `-ApiCompatibility`: Default API compatibility mode ('Strict' or 'Permissive', default: 'Permissive')
- `-DisableRecursion`: Disable recursive dependency processing (default: recursive mode enabled)

### Configuration Files

#### dependencies.json

Contains repository configurations without any credential information:

```json
[
  {
    "Repository URL": "https://github.com/user/repo.git",
    "Base Path": "repos/my-repo",
    "Tag": "v1.0.0",
    "API Compatible Tags": ["v0.9.0", "v0.9.1", "v0.9.2"],
    "API Compatibility": "Strict",
    "Skip LFS": false
  }
]
```

**Configuration Options:**
- **Repository URL** (required): Git repository URL (HTTPS or SSH)
- **Base Path** (required): Local directory path (relative or absolute)
- **Tag** (required): Git tag to checkout
- **API Compatible Tags** (optional): List of API-compatible tags (can be in any order - automatic chronological sorting)
- **API Compatibility** (optional): "Strict" or "Permissive" (defaults to script parameter when absent)
- **Skip LFS** (optional): Skip Git LFS downloads for this repository and all submodules

#### git_credentials.json

Maps hostnames to SSH key files:

```json
{
  "github.com": "C:\\Users\\username\\.ssh\\github_key.ppk",
  "gitlab.com": "C:\\Users\\username\\.ssh\\gitlab_key.ppk",
  "bitbucket.org": "C:\\Users\\username\\.ssh\\bitbucket_key.ppk",
  "ssh://git.internal.corp": "C:\\keys\\internal_key.ppk"
}
```

### Examples

#### Example 1: Public Repositories

```json
[
  {
    "Repository URL": "https://github.com/microsoft/terminal.git",
    "Base Path": "repos/windows-terminal",
    "Tag": "v1.19.10573.0"
  },
  {
    "Repository URL": "https://github.com/PowerShell/PowerShell.git",
    "Base Path": "repos/powershell",
    "Tag": "v7.4.1",
    "Skip LFS": true
  }
]
```

#### Example 2: Private Repository with SSH

dependencies.json:
```json
[
  {
    "Repository URL": "git@github.com:mycompany/private-repo.git",
    "Base Path": "C:\\Projects\\private-repo",
    "Tag": "release-2024.1",
    "API Compatibility": "Strict"
  }
]
```

git_credentials.json:
```json
{
  "github.com": "C:\\Users\\john\\.ssh\\github_company.ppk"
}
```

## Advanced Usage (Recursive Mode)

### Overview

**When Recursive Mode is enabled (Default)** the script automatically discovers and processes nested dependencies. After checking out each repository, it looks for a dependency file with the same name as the input file within that repository and processes it recursively, with intelligent handling of shared dependencies.

### Controlling Recursive Mode

```powershell
# Default behavior (recursive mode enabled with intelligent tag sorting)
.\LsiGitCheckout.ps1

# Disable recursive mode for simple single-file processing
.\LsiGitCheckout.ps1 -DisableRecursion

# Customize recursive behavior
.\LsiGitCheckout.ps1 -MaxDepth 10

# Use strict compatibility mode
.\LsiGitCheckout.ps1 -ApiCompatibility Strict
```

### Recursion and Discovering Common Dependencies

When recursive mode processes nested dependencies, a common scenario emerges: **the same repository is required by multiple projects with potentially different version requirements**. This creates the fundamental challenge that the script's API compatibility system is designed to solve.

#### The Challenge: Conflicting Dependency Requirements

Consider this scenario:

1. **ProjectA** requires `LibraryX` at version `v2.1.0`
2. **ProjectB** also requires `LibraryX` but at version `v2.0.5`
3. Both projects expect to work with `LibraryX`, but they're requesting different versions

When the script encounters `LibraryX` for the second time, it faces a critical decision: **which version should be checked out to satisfy both callers?**

#### Practical Example

```
Main Project Dependencies:
├── ProjectA (requires LibraryX v2.1.0)
└── ProjectB (requires LibraryX v2.0.5)
```

When processing recursively:
1. **Round 1**: Processes main dependencies → clones ProjectA and ProjectB
2. **Round 2**: 
   - Processes ProjectA's dependencies → clones LibraryX at v2.1.0
   - Processes ProjectB's dependencies → **discovers LibraryX already exists!**

At this point, the script must determine:
- Are v2.1.0 and v2.0.5 API-compatible?
- If compatible, which version should be used?
- How do we ensure both ProjectA and ProjectB continue to work?

#### The API Compatibility Problem

The core issue is that **the first caller (ProjectA) might be using APIs that are incompatible with those expected by the newly discovered caller (ProjectB)**. Simply keeping the first version could break ProjectB, while switching to the second version could break ProjectA.

#### Solution: API Compatible Tags

To solve this, the script introduces the concept of **"API Compatible Tags"**. Together with the main **"Tag"**, these define the complete set of versions that a caller declares as compatible with their usage:

```json
{
  "Repository URL": "https://github.com/company/LibraryX.git",
  "Base Path": "libs/library-x",
  "Tag": "v2.1.0",
  "API Compatible Tags": ["v2.0.0", "v2.0.1", "v2.0.2", "v2.0.3", "v2.0.4", "v2.0.5"]
}
```

This declaration means: *"I'm using LibraryX v2.1.0, but I know my code works with any version from v2.0.0 through v2.0.5"*.

#### The API Compatibility Algorithm

When a repository conflict is detected, the script executes a compatibility algorithm that:

1. **Assesses Compatibility**: Checks if the union of ("Tag" + "API Compatible Tags") from the first caller overlaps with the same set from the new caller. If there's no overlap, the dependencies are incompatible and the script reports an error.

2. **Chooses the Optimal Version**: If the callers are compatible, the script determines which version to checkout based on the "API Compatibility" modes declared by both callers (Strict vs Permissive) and uses intelligent tag temporal sorting based on actual git tag dates.

3. **Updates Repository State**: Once the algorithm completes, it stores the resolved "API Compatibility" mode, "Tag", and "API Compatible Tags" that will apply to the checked-out repository. These resolved values will be used if the same repository becomes a dependency of future callers during continued recursive processing.

The specific rules for version selection and state resolution depend on the compatibility modes declared by the callers, which are detailed in the following sections.

### API Compatibility - Critical Concepts

The **"API Compatible Tags"** field is the foundation of the recursive dependency resolution system described above. This field, combined with the "Tag", enables intelligent version resolution when multiple projects depend on the same repository with different version requirements.

#### Simplified Tag Management (v6.0.0+)

**API Compatible Tags can be listed in any order** - the script automatically uses actual git tag dates for chronological sorting:

```json
{
  "Tag": "v1.0.4",
  "API Compatible Tags": ["v1.0.1", "v1.0.0", "v1.0.3", "v1.0.2"]
}
```

The script will automatically sort these chronologically based on git tag creation dates, eliminating the need for manual temporal ordering.

#### Version Management Rules

When updating dependencies, simply add or remove versions from the API Compatible Tags array:

1. **Adding a new compatible version** (e.g., v1.0.3 → v1.0.4):
   - Add the new version to "API Compatible Tags" or update "Tag"
   - Order doesn't matter - automatic sorting handles chronology
   
   ```json
   {
     "Tag": "v1.0.4",
     "API Compatible Tags": ["v1.0.0", "v1.0.1", "v1.0.2", "v1.0.3"]
   }
   ```

2. **Bumping to an incompatible version** (e.g., v1.0.3 → v2.0.0):
   - Update "Tag" to the new version
   - Clear or update "API Compatible Tags" for the new API version
   
   ```json
   {
     "Tag": "v2.0.0",
     "API Compatible Tags": []
   }
   ```

#### Why This Convention Matters

When multiple projects depend on the same repository with different version requirements, the script:
1. Calculates the intersection of all compatible versions (in Strict mode) or union (in Permissive mode)
2. Uses intelligent tag temporal sorting based on actual git tag dates
3. Automatically checks out the optimal version if different from the current one

This ensures all dependent projects get the best version that satisfies everyone's requirements.

## API Compatibility Modes

Version 4.1.0 introduces flexible API compatibility modes that control how version conflicts are resolved when multiple projects depend on the same repository.

### Strict Mode

In Strict mode, the script uses the **intersection** of compatible tags when resolving version conflicts. This ensures maximum compatibility but may result in older versions being selected.

**Use Strict mode when:**
- Working with production systems
- API stability is critical
- Breaking changes must be avoided
- Conservative version management is preferred

### Permissive Mode

In Permissive mode, the script uses the **union** of compatible tags, allowing more flexibility in version selection. This typically results in newer versions being selected.

**Use Permissive mode when:**
- Working in development environments
- Rapid iteration is important
- Teams can quickly adapt to API changes
- Latest features are prioritized

### Mode Interaction Rules

When the same repository is encountered multiple times with different compatibility modes and/or tag requirements:

**Strict Mode Algorithm:**
- **Intersection**: Calculates the intersection of all compatible tag sets
- **Tag Selection**: Uses intelligent temporal sorting to prioritize existing/new "Tag" values if they're in the intersection, otherwise selects the chronologically most recent tag from the intersection

**Permissive Mode Algorithm:**
- **Union**: Calculates the union of all compatible tag sets  
- **Tag Selection**: Uses intelligent temporal sorting to prioritize existing/new "Tag" values if they're in the union, otherwise selects the chronologically most recent tag from the union

**Mode Combination Rules:**
1. **Strict + Strict**: Uses intersection algorithm (conservative)
2. **Strict + Permissive**: Keeps the Strict repository unchanged
3. **Permissive + Permissive**: Uses union algorithm (flexible)  
4. **Permissive + Strict**: Adopts Strict mode and its version requirements

### Configuration Examples

#### Repository-Level Configuration

```json
[
  {
    "Repository URL": "https://github.com/myorg/stable-lib.git",
    "Base Path": "libs/stable",
    "Tag": "v2.0.0",
    "API Compatible Tags": ["v1.8.0", "v1.9.0"],
    "API Compatibility": "Strict"
  },
  {
    "Repository URL": "https://github.com/myorg/dev-lib.git",
    "Base Path": "libs/dev",
    "Tag": "v3.0.0-beta",
    "API Compatible Tags": ["v2.0.0", "v2.1.0", "v2.2.0"],
    "API Compatibility": "Permissive"
  }
]
```

#### Script-Level Default

```powershell
# Set default to Strict for production environments
.\LsiGitCheckout.ps1 -ApiCompatibility Strict

# Use Permissive for development (default behavior)
.\LsiGitCheckout.ps1

# Disable recursive mode if only processing single dependency file
.\LsiGitCheckout.ps1 -DisableRecursion
```

## Intelligent Tag Temporal Sorting

The script features intelligent automatic tag temporal sorting using actual git tag dates, providing optimal version selection without any manual configuration required.

### Overview

The script automatically:
1. **Fetches tag dates** from each repository after checkout using `git for-each-ref`
2. **Sorts tags chronologically** during API compatibility resolution using actual git tag creation dates
3. **Prioritizes Tag values** - intelligently prefers existing/new "Tag" values over other compatible tags when resolving conflicts
4. **Optimizes performance** - only fetches tag dates and sorts when needed during conflict resolution

### Key Benefits

- **Accurate chronology**: Uses actual git tag dates instead of assumed ordering
- **Intelligent tag selection**: Prioritizes specified "Tag" values when they're compatible
- **Minimal performance impact**: Efficient tag date fetching only when conflicts require resolution
- **Simplified maintenance**: Add tags to "API Compatible Tags" in any order
- **Optimal behavior**: No configuration required for best performance
- **Zero maintenance overhead**: No need to maintain temporal order in configuration files

### Usage

Control verbosity and debugging:

```powershell
# Default behavior
.\LsiGitCheckout.ps1

# With verbose output to see tag dates and sorting decisions
.\LsiGitCheckout.ps1 -Verbose

# With debug logging for detailed tag processing
.\LsiGitCheckout.ps1 -EnableDebug
```

### Intelligent Tag Selection Algorithm

When multiple repositories reference the same dependency with different tags, the algorithm prioritizes in this order:

1. **Both existing and new "Tag" are compatible**: Choose the chronologically most recent "Tag"
2. **Only existing "Tag" is compatible**: Use the existing "Tag" 
3. **Only new "Tag" is compatible**: Use the new "Tag"
4. **Neither "Tag" is compatible**: Use the chronologically most recent tag from the compatible set (intersection/union)

### Example with Intelligent Tag Temporal Sorting

**Flexible Ordering:**
```json
{
  "Repository URL": "https://github.com/myorg/lib.git",
  "Base Path": "libs/mylib", 
  "Tag": "v1.0.4",
  "API Compatible Tags": ["v1.0.2", "v1.0.0", "v1.0.3", "v1.0.1"]
}
```

The script automatically sorts these tags by their actual git creation dates during conflict resolution, providing intelligent tag selection based on chronological order and compatibility requirements.

### Performance Optimization

- **On-demand processing**: Tag dates are only fetched when needed for conflict resolution
- **Efficient git operations**: Uses `git for-each-ref` instead of multiple `git log` calls
- **Smart caching**: Tag dates are cached in memory during recursive processing
- **Minimal server impact**: Only one tag date fetch per repository during initial checkout

### Real-World Example with Test Repositories

Using the LS-Instruments test repositories to demonstrate recursive dependencies:

#### Initial Setup

Main dependencies.json:
```json
[
  {
    "Repository URL": "https://github.com/LS-Instruments/LsiCheckOutTestRootA.git",
    "Base Path": "test-root-a",
    "Tag": "v1.0.0"
  },
  {
    "Repository URL": "https://github.com/LS-Instruments/LsiCheckOutTestRootB.git",
    "Base Path": "test-root-b",
    "Tag": "v1.0.0"
  }
]
```

#### Nested Dependencies

LsiCheckOutTestRootA/dependencies.json:
```json
[
  {
    "Repository URL": "https://github.com/LS-Instruments/LsiCheckOutTestA.git",
    "Base Path": "../libs/test-a",
    "Tag": "v1.0.3",
    "API Compatible Tags": ["v1.0.1", "v1.0.0", "v1.0.2"],
    "API Compatibility": "Strict"
  },
  {
    "Repository URL": "https://github.com/LS-Instruments/LsiCheckOutTestB.git",
    "Base Path": "../libs/test-b",
    "Tag": "v1.0.3",
    "API Compatible Tags": ["v1.0.2", "v1.0.0", "v1.0.1"],
    "API Compatibility": "Permissive"
  }
]
```

Note: API Compatible Tags are listed in mixed order - the script automatically sorts them chronologically based on actual git tag dates.

#### Processing Flow

1. **Round 1**: Clones RootA and RootB
2. **Round 2**: 
   - Processes RootA's dependencies → clones TestA and TestB
   - Processes RootB's dependencies → clones TestC
3. **Round 3**: 
   - Processes TestA's dependencies
   - Finds TestB already exists at same path
   - Applies compatibility rules based on mode settings and chronological tag intelligence
4. **Round 4**: 
   - Processes TestB's dependencies
   - Continues applying compatibility rules with automatic tag sorting

**Important**: The script uses the same filename for all recursive processing. If you run `.\LsiGitCheckout.ps1 -InputFile "mydeps.json"`, it will look for "mydeps.json" in each checked-out repository, not "dependencies.json".

### API Compatibility Checking

When the same repository is referenced multiple times:

1. **Path Check**: Ensures all references resolve to the same absolute path
2. **API Compatibility**: 
   - **Strict mode**: Calculates intersection of all compatible versions
   - **Permissive mode**: Calculates union of all compatible versions
3. **Version Selection**: Uses chronological tag selection algorithm with intelligent prioritization

#### Example: Version Conflict Resolution

If TestA requires TestC compatible with [v1.0.0, v1.0.1, v1.0.2, v1.0.3] but TestB requires TestC compatible with [v1.0.2, v1.0.3, v1.0.4]:

**Strict Mode (both repositories):**
- **Algorithm**: Intersection of compatible tag sets
- **Result**: [v1.0.2, v1.0.3]
- **Tag Selection**: TestA or TestB "Tag" if in intersection, otherwise chronologically most recent

**Permissive Mode (both repositories):**
- **Algorithm**: Union of compatible tag sets
- **Result**: [v1.0.0, v1.0.1, v1.0.2, v1.0.3, v1.0.4]
- **Tag Selection**: TestA or TestB "Tag" if in union, otherwise chronologically most recent

**Mixed Mode (TestA Strict, TestB Permissive):**
- **Algorithm**: TestA is Strict, so its requirements are preserved
- **Result**: Uses TestA's compatible versions

### Error Scenarios

#### Path Conflict
```
Repository path conflict for 'https://github.com/LS-Instruments/LsiCheckOutTestC.git':
Existing path: C:\project\libs\test-c
New path: C:\project\modules\test-c
```

#### API Incompatibility
```
API incompatibility for repository 'https://github.com/LS-Instruments/LsiCheckOutTestC.git':
Existing tags: v2.0.0
New tags: v1.0.0, v1.0.1, v1.0.2, v1.0.3
No common API-compatible tags found.
```

## Security Best Practices

1. **Never commit `git_credentials.json` to version control**
   - Add it to your `.gitignore` file
   - Use `git_credentials.example.json` as a template

2. **Protect your SSH key files**
   - Store keys in a secure location
   - Use appropriate file permissions
   - Use passphrases on your keys

3. **Use separate keys for different services**
   - Don't reuse the same SSH key across multiple services
   - Use deployment-specific keys with limited permissions

## SSH Setup with PuTTY

1. **Convert OpenSSH keys to PuTTY format**:
   - Open PuTTYgen
   - Load your OpenSSH private key
   - Save private key as .ppk file

2. **Configure Pageant**:
   - Start Pageant (will appear in system tray)
   - Right-click Pageant icon → Add Key
   - Browse to your .ppk file
   - Enter passphrase when prompted

3. **Test SSH connection**:
   ```cmd
   plink -i "C:\path\to\key.ppk" git@github.com
   ```

## Troubleshooting

### Common Issues

1. **"Plink.exe not found"**
   - Install PuTTY suite
   - Add PuTTY installation directory to PATH

2. **"SSH key is not in PuTTY format"**
   - Use PuTTYgen to convert OpenSSH keys to .ppk format

3. **"No SSH key configured for repository"**
   - Check that hostname is correctly specified in git_credentials.json
   - Verify the hostname matches the repository URL

4. **Git LFS errors**
   - Install Git LFS: `git lfs install`
   - Or set `"Skip LFS": true` in configuration

5. **API Incompatibility errors in recursive mode**
   - Review the "API Compatible Tags" for conflicting repositories
   - Check if versions truly are API compatible
   - Consider if compatibility modes need adjustment
   - Tags can be listed in any order - automatic chronological sorting handles temporal ordering

6. **Tag temporal sorting issues**  
   - Verify git tags exist in repositories
   - Check debug logs for tag date fetching errors
   - Ensure repositories are accessible for tag date queries
   - Review verbose output for tag selection decisions

### Debug Mode

Enable detailed logging to troubleshoot issues:

```powershell
.\LsiGitCheckout.ps1 -EnableDebug -Verbose
```

Check the generated debug log file for:
- JSON content of all processed dependency files
- Hostname extraction from URLs
- SSH key lookup attempts
- API compatibility calculations
- Compatibility mode interactions
- Tag date fetching operations and chronological sorting
- Detailed Git command execution

## Migration Guide

### From Version 5.x to 6.0.0

Version 6.0.0 introduces a major simplification by removing the `-DisableTagSorting` parameter and always enabling intelligent tag temporal sorting:

1. **BREAKING**: Removed `-DisableTagSorting` parameter - tag temporal sorting is now always enabled
2. **Simplified codebase**: 26% reduction in code complexity (195+ lines removed)
3. **Enhanced user experience**: Always uses optimal tag ordering without configuration
4. **Zero configuration changes**: All existing JSON files work without modification
5. **Improved reliability**: Eliminates manual ordering errors and complexity
6. **Enhanced logging**: Improved visibility into recursive dependency processing with consistent depth tracking

**Migration from v5.x:**
```powershell
# Old v5.x syntax
.\LsiGitCheckout.ps1 -DisableTagSorting  # No longer supported

# New v6.0 behavior (always enabled)
.\LsiGitCheckout.ps1  # Intelligent tag sorting always active
```

**Benefits of v6.0:**
- **Always optimal behavior**: No configuration required for intelligent tag sorting
- **Simplified maintenance**: API Compatible Tags can be in any order
- **Better performance**: Optimized algorithms always used
- **Cleaner codebase**: Single code path for all tag operations
- **Enhanced reliability**: Eliminates possibility of manual ordering errors
- **Improved troubleshooting**: Enhanced logging with clear depth boundaries and statistics

**Enhanced Logging in v6.0:**
- Consistent Info-level start/end messages for all dependency processing depths
- Detailed completion statistics showing repositories examined and dependency files found
- Fixed depth numbering (now correctly shows 0 → 1 → 2 → 3 progression)
- Clear final completion message when recursive processing ends
- Better visibility into the recursive dependency discovery process

**API Compatible Tags Simplification:**
```json
// v5.x: Manual ordering required with -DisableTagSorting
{
  "API Compatible Tags": ["v1.0.0", "v1.0.1", "v1.0.2", "v1.0.3"]
}

// v6.0: Any order works - automatic chronological sorting
{
  "API Compatible Tags": ["v1.0.2", "v1.0.0", "v1.0.3", "v1.0.1"]
}
```

### From Version 4.x to 5.0.0

Version 5.0 introduces a cleaner API with breaking changes to parameter naming. Functionality remains the same with improved usability:

1. **BREAKING**: Changed `-Recursive` to `-DisableRecursion` (recursive mode enabled by default)
2. **BREAKING**: Changed `-EnableTagSorting` to `-DisableTagSorting` (tag sorting enabled by default)
3. **Cleaner API**: Switch parameters follow proper naming conventions
4. **Same functionality**: All features work identically with better parameter names
5. **Zero configuration**: Optimal behavior out-of-the-box without any parameters

**Migration from v4.x:**
```powershell
# Old v4.x syntax
.\LsiGitCheckout.ps1 -Recursive -EnableTagSorting

# New v5.0 syntax (default behavior)
.\LsiGitCheckout.ps1

# Old v4.x legacy mode
.\LsiGitCheckout.ps1 -Recursive:$false -EnableTagSorting:$false

# New v5.0 legacy mode
.\LsiGitCheckout.ps1 -DisableRecursion -DisableTagSorting
```

### From Version 4.0.x to 4.1.x

Version 4.1 adds API compatibility modes. Existing configurations continue to work:

1. **Non-breaking changes**: All v4.0.x configurations work in v4.1.x
2. **New optional field**: "API Compatibility" for mode control
3. **New parameter**: `-ApiCompatibility` for default mode
4. **Default behavior**: Permissive mode (more flexible than v4.0.x)

To maintain v4.0.x behavior exactly:
```powershell
.\LsiGitCheckout.ps1 -ApiCompatibility Strict
```

### From Version 3.x to 4.x

Version 4.0 adds recursive dependency support. Existing configurations continue to work:

1. **Non-breaking changes**: All v3.x configurations work in v4.x
2. **New optional field**: "API Compatible Tags" for recursive mode
3. **New parameters**: Recursive mode enabled by default

To use recursive features:
1. Add "API Compatible Tags" to your repository configurations
2. Place dependencies.json files in your repositories
3. Run the script (recursive mode is enabled by default)

### From Version 2.x to 3.x/4.x

1. Create `git_credentials.json` with your SSH key mappings
2. Remove all "SSH Key Path" fields from dependencies.json
3. Remove all "Submodule Config" sections
4. Update any scripts to use `-EnableDebug` instead of `-Debug`

## LsiGitCheckout vs Traditional Package Managers

### Understanding the Fundamental Difference

Traditional package managers (npm, NuGet, Maven, pip) work with **packaged artifacts** - pre-built, versioned bundles of code that are published to registries. LsiGitCheckout takes a radically different approach by working directly with **source repositories** at specific git tags.

This fundamental difference leads to distinct advantages and trade-offs that make each approach suitable for different scenarios.

### When to Use Each Approach

#### Use Traditional Package Managers When:
- Managing standard third-party library dependencies
- Working with well-maintained public packages
- Needing automatic transitive dependency resolution
- Prioritizing minimal configuration overhead
- Following established ecosystem conventions
- Building simple applications with straightforward dependencies

#### Use LsiGitCheckout When:
- Managing source-level dependencies across teams
- Working with private repositories or mixed public/private code
- Requiring precise control over versions and compatibility
- Frequently debugging or modifying dependencies
- Building reproducible research or compliance-critical systems
- Orchestrating complex multi-repository projects
- Needing immediate patches without waiting for upstream releases
- Requiring flexible compatibility modes for different environments
- Managing complex temporal dependencies with automatic intelligent sorting
- Eliminating manual tag ordering complexity

### Key Advantages of LsiGitCheckout

1. **Source-Level Transparency**: Complete visibility into all dependency code
2. **Debugging Power**: Step through dependency code, set breakpoints anywhere
3. **Immediate Patches**: Modify dependencies locally for quick fixes
4. **No Publication Required**: Use code directly from git repositories
5. **Mixed Repository Support**: Seamlessly handle public and private code
6. **Virtual Monorepo**: Work as if in a monorepo while maintaining separate repos
7. **Temporal Versioning**: Explicit control over version selection with API compatibility
8. **Flexible Compatibility**: Choose between Strict and Permissive modes per repository
9. **Complete Audit Trail**: Full git history for security reviews
10. **Intelligent Tag Sorting**: Always-on automatic chronological ordering with performance optimization
11. **Simplified Maintenance**: No manual tag ordering required

### Key Advantages of Traditional Package Managers

1. **Ease of Use**: Simple commands like `npm install` handle everything
2. **Automatic Dependency Resolution**: Transitive dependencies resolved automatically
3. **Optimized Storage**: Shared packages stored once and reused
4. **Fast Installation**: Downloading pre-built packages is quick
5. **Mature Ecosystem**: Extensive tooling, security scanning, license checking
6. **Registry Features**: Search, statistics, vulnerability databases

### Target Users and Organizations

#### Primary Target Users for LsiGitCheckout:

1. **Enterprise Development Teams**
   - Managing proprietary code alongside open-source
   - Requiring strict security and compliance controls
   - Complex interdependencies between internal projects
   - Need for flexible compatibility policies

2. **Research Organizations**
   - Ensuring long-term reproducibility
   - Archiving exact states of all dependencies
   - Frequently modifying dependency code

3. **Regulated Industries (Financial, Healthcare)**
   - Regulatory requirements for source code access
   - Complete audit trails needed
   - Cannot rely solely on external registries

4. **DevOps and Platform Teams**
   - Building deployment pipelines for multi-repository projects
   - Applying organization-specific patches
   - Managing architectural transitions
   - Supporting both stable and experimental environments

### Hybrid Approach: Best of Both Worlds

Many successful projects combine both approaches:
- Use npm/NuGet for stable, third-party libraries
- Use LsiGitCheckout for internal dependencies and actively developed components
- Maintain clear boundaries between packaged and source dependencies
- Apply different compatibility modes based on environment (Strict for production, Permissive for development)
- Leverage always-on intelligent tag sorting for simplified dependency management

This leverages the convenience of package managers for commodity dependencies while maintaining control over critical internal code.

### Example Scenarios

**Perfect for Package Managers:**
- Building a React web app with standard npm packages
- Creating a .NET application using common NuGet libraries
- Developing a Python project with well-known pip packages

**Perfect for LsiGitCheckout:**
- Financial trading system with proprietary components
- Medical device software requiring FDA compliance
- Large enterprise with shared internal libraries
- Research requiring reproducible computational environments
- Gradual open-sourcing of internal components
- Mixed development/production environments with different stability requirements
- Complex dependency graphs requiring intelligent temporal sorting without manual ordering
- Teams needing flexible tag ordering without temporal maintenance overhead

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Authors

Originally developed by LS Instruments AG for managing complex multi-repository projects.

Co-authored with Claude (Anthropic) through collaborative development.