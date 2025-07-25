# LsiGitCheckout

A PowerShell script for managing multiple Git repositories with support for tags, SSH authentication via PuTTY, Git LFS, and submodules. Features advanced recursive dependency resolution with API compatibility checking, flexible compatibility modes, intelligent automatic tag temporal sorting, custom dependency file configurations, and post-checkout PowerShell script execution for integration with external dependency management systems.

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Basic Usage (Non-Recursive)](#basic-usage-non-recursive)
- [Advanced Usage (Recursive Mode)](#advanced-usage-recursive-mode)
- [API Compatibility Modes](#api-compatibility-modes)
- [Intelligent Tag Temporal Sorting](#intelligent-tag-temporal-sorting)
- [Custom Dependency Files](#custom-dependency-files)
- [Post-Checkout Scripts](#post-checkout-scripts)
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
- **Custom Dependency Files**: Per-repository custom dependency file paths and names with proper isolation
- **Post-Checkout Scripts**: Execute PowerShell scripts after successful repository checkouts for integration with external dependency management systems

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

# Disable post-checkout script execution
.\LsiGitCheckout.ps1 -DisablePostCheckoutScripts
```

### Parameters

- `-InputFile`: Path to repository configuration file (default: dependencies.json)
- `-CredentialsFile`: Path to SSH credentials file (default: git_credentials.json)
- `-DryRun`: Preview operations without making changes
- `-EnableDebug`: Create detailed debug log file
- `-Verbose`: Show verbose output messages
- `-ApiCompatibility`: Default API compatibility mode ('Strict' or 'Permissive', default: 'Permissive')
- `-DisableRecursion`: Disable recursive dependency processing (default: recursive mode enabled)
- `-DisablePostCheckoutScripts`: Disable post-checkout script execution (default: post-checkout scripts enabled)

### Configuration Files

#### dependencies.json

Contains repository configurations without any credential information:

**New Object Format (with Post-Checkout Scripts):**
```json
{
  "Post-Checkout Script File Name": "setup-dependencies.ps1",
  "Post-Checkout Script File Path": "scripts/build",
  "Repositories": [
    {
      "Repository URL": "https://github.com/user/repo.git",
      "Base Path": "repos/my-repo",
      "Tag": "v1.0.0",
      "API Compatible Tags": ["v0.9.0", "v0.9.1", "v0.9.2"],
      "API Compatibility": "Strict",
      "Skip LFS": false,
      "Dependency File Path": "config/deps",
      "Dependency File Name": "project-deps.json"
    }
  ]
}
```

**Legacy Array Format (Backward Compatible):**
```json
[
  {
    "Repository URL": "https://github.com/user/repo.git",
    "Base Path": "repos/my-repo",
    "Tag": "v1.0.0",
    "API Compatible Tags": ["v0.9.0", "v0.9.1", "v0.9.2"],
    "API Compatibility": "Strict",
    "Skip LFS": false,
    "Dependency File Path": "config/deps",
    "Dependency File Name": "project-deps.json"
  }
]
```

**Configuration Options:**
- **Post-Checkout Script File Name** (optional): PowerShell script to execute after successful repository checkout
- **Post-Checkout Script File Path** (optional): Subdirectory within repository where post-checkout script is located (default: repository root)
- **Repositories** (required in object format): Array of repository configurations
- **Repository URL** (required): Git repository URL (HTTPS or SSH)
- **Base Path** (required): Local directory path (relative or absolute)
- **Tag** (required): Git tag to checkout
- **API Compatible Tags** (optional): List of API-compatible tags (can be in any order - automatic chronological sorting)
- **API Compatibility** (optional): "Strict" or "Permissive" (defaults to script parameter when absent)
- **Skip LFS** (optional): Skip Git LFS downloads for this repository and all submodules
- **Dependency File Path** (optional): Custom subdirectory within repository for dependency file
- **Dependency File Name** (optional): Custom name for dependency file

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

#### Example 2: Private Repository with SSH and Post-Checkout Scripts

dependencies.json:
```json
{
  "Post-Checkout Script File Name": "install-dependencies.ps1",
  "Repositories": [
    {
      "Repository URL": "git@github.com:mycompany/private-repo.git",
      "Base Path": "C:\\Projects\\private-repo",
      "Tag": "release-2024.1",
      "API Compatibility": "Strict",
      "Dependency File Path": "build/config",
      "Dependency File Name": "external-requirements.json"
    }
  ]
}
```

git_credentials.json:
```json
{
  "github.com": "C:\\Users\\john\\.ssh\\github_company.ppk"
}
```

## Advanced Usage (Recursive Mode)

### Overview

**When Recursive Mode is enabled (Default)** the script automatically discovers and processes nested dependencies. After checking out each repository, it looks for a dependency file within that repository and processes it recursively, with intelligent handling of shared dependencies.

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

# Disable post-checkout scripts
.\LsiGitCheckout.ps1 -DisablePostCheckoutScripts
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

## Custom Dependency Files

Version 6.1.0 introduces support for per-repository custom dependency file paths and names, providing flexibility for different project structures and naming conventions while maintaining proper dependency isolation.

### Overview

By default, the script looks for dependency files with the same name as the input file (e.g., `dependencies.json`) in the root directory of each checked-out repository. With custom dependency file support, each repository can specify:

- **Custom File Name**: Use different naming conventions (e.g., `project-modules.json`, `requirements.json`)
- **Custom File Path**: Place dependency files in subdirectories (e.g., `config/deps`, `build/dependencies`)

### Configuration Fields

#### Dependency File Path
- **Purpose**: Specifies a subdirectory within the repository where the dependency file is located
- **Type**: String (relative path from repository root)
- **Default**: Repository root directory
- **Examples**: `"config"`, `"build/deps"`, `"scripts/deployment"`

#### Dependency File Name  
- **Purpose**: Specifies a custom name for the dependency file
- **Type**: String (filename with extension)
- **Default**: Same as the input file name (e.g., `dependencies.json`)
- **Examples**: `"project-modules.json"`, `"external-deps.json"`, `"requirements.json"`

### Dependency Isolation

**Critical Behavior**: Custom dependency file settings are **NOT propagated** to nested repositories. Each repository's custom settings apply only to that repository. Nested repositories discovered during recursive processing always use the default dependency file name from the root invocation.

This isolation prevents:
- Unintended dependency file lookups in nested repositories
- Coupling between parent and child repository configurations
- Complexity in deeply nested dependency hierarchies

### Path Resolution

**Important**: Relative paths in dependency files are always resolved relative to the **repository root**, not the dependency file location.

**Example:**
```
Repository: test-repo/
Custom dependency file: test-repo/build/config/deps.json
Relative path in deps.json: ../libs/library
Resolves to: test-repo/libs/library (relative to repository root)
```

### Configuration Examples

#### Basic Custom File Name
```json
{
  "Repository URL": "https://github.com/myorg/project.git",
  "Base Path": "repos/project",
  "Tag": "v1.0.0",
  "Dependency File Name": "project-modules.json"
}
```
**Result**: Looks for `project-modules.json` in the repository root

#### Custom Subdirectory
```json
{
  "Repository URL": "https://github.com/myorg/project.git",
  "Base Path": "repos/project",
  "Tag": "v1.0.0",
  "Dependency File Path": "config/deps"
}
```
**Result**: Looks for `dependencies.json` in the `config/deps` subdirectory

#### Both Custom Path and Name
```json
{
  "Repository URL": "https://github.com/myorg/project.git",
  "Base Path": "repos/project",
  "Tag": "v1.0.0",
  "Dependency File Path": "build/config",
  "Dependency File Name": "external-dependencies.json"
}
```
**Result**: Looks for `external-dependencies.json` in the `build/config` subdirectory

### Real-World Usage Scenarios

#### 1. Organization with Multiple Conventions
```json
[
  {
    "_comment": "Legacy project using old naming convention",
    "Repository URL": "https://github.com/myorg/legacy-app.git",
    "Base Path": "apps/legacy",
    "Tag": "v2.0.0",
    "Dependency File Name": "modules.json"
  },
  {
    "_comment": "New project using standard convention",
    "Repository URL": "https://github.com/myorg/new-app.git", 
    "Base Path": "apps/new",
    "Tag": "v1.0.0"
  }
]
```

#### 2. Microservices with Centralized Configuration
```json
[
  {
    "_comment": "Service with dependencies in config directory",
    "Repository URL": "https://github.com/myorg/auth-service.git",
    "Base Path": "services/auth",
    "Tag": "v1.5.0",
    "Dependency File Path": "config",
    "Dependency File Name": "service-deps.json"
  },
  {
    "_comment": "Service with build-time dependencies",
    "Repository URL": "https://github.com/myorg/api-gateway.git",
    "Base Path": "services/gateway", 
    "Tag": "v2.0.0",
    "Dependency File Path": "build/dependencies"
  }
]
```

### Isolation Example

Consider this scenario:
1. **Root dependencies.json** contains a repository with custom settings
2. **That repository** has its own dependency file with different custom settings
3. **Nested repositories** within that repository

```
Root: dependencies.json
├── ProjectA (custom: config/project-deps.json)
│   └── config/project-deps.json
│       ├── LibraryX (will use dependencies.json in root, NOT config/project-deps.json)
│       └── LibraryY (will use dependencies.json in root, NOT config/project-deps.json)
```

**Key Point**: `LibraryX` and `LibraryY` will look for `dependencies.json` (the original input file name) in their repository roots, regardless of ProjectA's custom settings.

### Command Line Usage

Custom dependency file settings work with all existing command line options:

```powershell
# Standard usage - custom settings are read from the JSON file
.\LsiGitCheckout.ps1

# With custom input file - nested repos use "custom-deps.json" as default
.\LsiGitCheckout.ps1 -InputFile "custom-deps.json"

# Debugging custom dependency file resolution
.\LsiGitCheckout.ps1 -EnableDebug -Verbose

# Dry run to see what dependency files would be processed
.\LsiGitCheckout.ps1 -DryRun
```

### Verbose Output

When using `-Verbose`, the script shows custom dependency file configurations:

```
[2025-01-24 10:30:15] [Info] Processing repository: https://github.com/myorg/project.git
[2025-01-24 10:30:15] [Verbose] Custom Dependency File Path: config/deps
[2025-01-24 10:30:15] [Verbose] Custom Dependency File Name: project-modules.json
[2025-01-24 10:30:16] [Debug] Resolved dependency file path: C:\repos\project\config\deps\project-modules.json
```

### Benefits

- **Flexibility**: Support different project structures and naming conventions
- **Backward Compatibility**: No changes required for existing repositories  
- **Isolation**: Custom settings don't affect nested dependencies
- **Migration Friendly**: Gradual adoption without breaking existing workflows
- **Organization Support**: Handle legacy and new projects with different conventions
- **Correct Path Resolution**: Relative paths always resolve from repository roots

## Post-Checkout Scripts

Version 6.2.0 introduces support for executing PowerShell scripts after successful repository checkouts. This feature enables integration with external dependency management systems and custom setup procedures.

### Overview

Post-checkout scripts are PowerShell scripts (.ps1) that execute automatically after a repository is successfully checked out to a specific tag. These scripts run only when an actual checkout occurs - they are skipped when repositories are already up-to-date with the correct tag.

**Key Characteristics:**
- **Execution Trigger**: Only after successful repository checkouts (clone or tag change)
- **Working Directory**: Scripts execute with the repository root as the working directory
- **Environment Variables**: Scripts receive context about the checkout operation
- **Timeout Protection**: Scripts are terminated if they exceed 5 minutes execution time
- **Error Handling**: Script failures are logged but don't prevent repository checkout success
- **Security**: Scripts run with `-ExecutionPolicy Bypass` for maximum compatibility

### Configuration

Post-checkout scripts are configured at the dependency file level and execute for the repository that contains the dependency file:

#### New Object Format

```json
{
  "Post-Checkout Script File Name": "setup-environment.ps1",
  "Post-Checkout Script File Path": "scripts/build",
  "Repositories": [
    {
      "Repository URL": "https://github.com/myorg/project.git",
      "Base Path": "repos/project",
      "Tag": "v1.0.0"
    }
  ]
}
```

#### Configuration Fields

- **Post-Checkout Script File Name** (optional): Name of the PowerShell script to execute
- **Post-Checkout Script File Path** (optional): Subdirectory within each repository where the script is located (default: repository root)

### Script Execution Context

When a post-checkout script executes, it receives the following environment variables:

- **`$env:LSIGIT_REPOSITORY_URL`**: The repository URL that was checked out
- **`$env:LSIGIT_REPOSITORY_PATH`**: Absolute path to the repository on disk
- **`$env:LSIGIT_TAG`**: The git tag that was checked out
- **`$env:LSIGIT_SCRIPT_VERSION`**: Version of LsiGitCheckout executing the script

### Execution Rules

1. **Trigger Conditions**: Scripts execute for the repository containing the dependency file when:
   - The repository containing the dependency file was successfully checked out
   - The dependency file specifies a post-checkout script configuration
   - Only executed during recursive processing (depth > 0) when processing nested dependency files

2. **Repository Context**: The script executes for the repository that **contains** the dependency file, not for the individual repositories listed in the dependency file

3. **Skip Conditions**: Scripts are skipped when:
   - Post-checkout scripts are disabled via `-DisablePostCheckoutScripts` parameter
   - Script file is not found or is not a .ps1 file
   - Processing the root-level dependency file (depth 0)

4. **Error Handling**: Script failures:
   - Are logged as warnings
   - Don't affect dependency processing success status
   - Increment the script failure counter in the summary

### Command Line Control

```powershell
# Default behavior (post-checkout scripts enabled)
.\LsiGitCheckout.ps1

# Disable post-checkout script execution
.\LsiGitCheckout.ps1 -DisablePostCheckoutScripts

# Debug script execution with detailed logging
.\LsiGitCheckout.ps1 -EnableDebug -Verbose

# Dry run shows what scripts would be executed
.\LsiGitCheckout.ps1 -DryRun
```

### Example Use Cases

#### 1. Package Manager Integration

```powershell
# setup-dependencies.ps1
Write-Host "Setting up dependencies for $env:LSIGIT_REPOSITORY_URL at tag $env:LSIGIT_TAG"

# Install npm dependencies if package.json exists
if (Test-Path "package.json") {
    Write-Host "Installing npm dependencies..."
    npm install
}

# Install NuGet packages if packages.config exists
if (Test-Path "packages.config") {
    Write-Host "Restoring NuGet packages..."
    nuget restore
}

# Install Python requirements if requirements.txt exists
if (Test-Path "requirements.txt") {
    Write-Host "Installing Python requirements..."
    pip install -r requirements.txt
}

Write-Host "Dependency setup completed for $env:LSIGIT_REPOSITORY_PATH"
```

#### 2. Build Environment Setup

```powershell
# configure-build.ps1
Write-Host "Configuring build environment for $env:LSIGIT_TAG"

# Set up environment-specific configuration
$configFile = "config/environment.json"
if (Test-Path $configFile) {
    $config = Get-Content $configFile | ConvertFrom-Json
    $env:BUILD_VERSION = $env:LSIGIT_TAG
    $env:BUILD_PATH = $env:LSIGIT_REPOSITORY_PATH
    
    Write-Host "Build environment configured:"
    Write-Host "  Version: $env:BUILD_VERSION"
    Write-Host "  Path: $env:BUILD_PATH"
}

# Generate build metadata
$metadata = @{
    CheckoutTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Tag = $env:LSIGIT_TAG
    Repository = $env:LSIGIT_REPOSITORY_URL
    ScriptVersion = $env:LSIGIT_SCRIPT_VERSION
}

$metadata | ConvertTo-Json | Out-File "build-metadata.json"
Write-Host "Build metadata saved to build-metadata.json"
```

#### 3. License and Security Scanning

```powershell
# security-scan.ps1
Write-Host "Running security scan for $env:LSIGIT_REPOSITORY_URL"

# Scan for known vulnerabilities in dependencies
if (Test-Path "package.json") {
    Write-Host "Scanning npm dependencies..."
    npm audit --audit-level=moderate
}

# Check for license compatibility
if (Test-Path "LICENSE") {
    $license = Get-Content "LICENSE" -First 5
    Write-Host "License information found: $($license -join ' ')"
}

# Log security scan completion
Write-Host "Security scan completed for tag $env:LSIGIT_TAG"
```

### Logging and Debugging

Post-checkout script execution is extensively logged:

**Standard Output:**
```
[2025-01-24 15:30:20] [Info] Executing post-checkout script after successful checkout
[2025-01-24 15:30:22] [Info] Successfully executed post-checkout script: C:\repos\project\scripts\setup.ps1
```

**Debug Output:**
```
[2025-01-24 15:30:19] [Debug] Looking for post-checkout script at: C:\repos\project\scripts\setup.ps1
[2025-01-24 15:30:19] [Debug] Using custom post-checkout script path: scripts
[2025-01-24 15:30:20] [Debug] Starting post-checkout script execution at: 2025-01-24 15:30:20
[2025-01-24 15:30:22] [Debug] Post-checkout script completed in 2.3 seconds with exit code: 0
```

**Error Logging:**
```
[2025-01-24 15:30:25] [Warning] Post-checkout script errors: npm: command not found
[2025-01-24 15:30:25] [Error] Failed to execute post-checkout script 'setup.ps1': Script failed with exit code: 1
```

### Security Considerations

1. **Script Source Control**: Post-checkout scripts are stored in the repositories themselves, ensuring version control and auditability

2. **Execution Isolation**: Each script runs in its own PowerShell process with the repository as the working directory

3. **Timeout Protection**: Scripts are automatically terminated after 5 minutes to prevent hanging processes

4. **Environment Cleanup**: Environment variables are cleaned up after script execution

5. **Optional Execution**: Scripts can be disabled entirely via command line parameter

6. **No Network Dependencies**: Scripts should be self-contained within the repository for reliability

### Summary Statistics

Post-checkout script execution statistics are included in the execution summary:

```
========================================
LsiGitCheckout Execution Summary
========================================
Script Version: 6.2.0
Successful: 3
Failed: 0
Recursive Mode: Enabled
Max Depth: 5
Default API Compatibility: Permissive
Total Unique Repositories: 3
Tag Temporal Sorting: Always Enabled
Post-Checkout Scripts: Enabled
Script Executions: 2
Script Failures: 0
========================================
```

### Backward Compatibility

- **Legacy Array Format**: Fully supported - existing dependency files continue to work without changes
- **No Scripts**: Repositories without post-checkout scripts work exactly as before
- **Gradual Adoption**: Post-checkout scripts can be added incrementally to dependency files

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

4. **Post-Checkout Script Security**
   - Review post-checkout scripts before execution
   - Ensure scripts are version controlled within repositories
   - Use `-DisablePostCheckoutScripts` in untrusted environments
   - Monitor script execution logs for security events

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

7. **Custom dependency file not found**
   - Verify the custom path and filename are correct
   - Check that the dependency file exists in the specified location
   - Remember that paths are relative to repository root
   - Use debug logging to see resolved paths

8. **Repository path conflicts**
   - Ensure the same repository isn't referenced with different relative paths
   - Check that custom dependency file paths don't create conflicting layouts
   - Verify relative paths resolve correctly from repository roots

9. **Post-checkout script issues**
   - Verify script file exists at the specified location
   - Ensure script has .ps1 extension
   - Check script execution permissions
   - Review debug logs for script execution details
   - Use `-DisablePostCheckoutScripts` to bypass script execution
   - Verify script doesn't exceed 5-minute timeout

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
- Custom dependency file path resolution
- Repository root path usage for relative path resolution
- Post-checkout script discovery and execution details
- Detailed Git command execution

## Migration Guide

### From Version 6.1.x to 6.2.0

Version 6.2.0 introduces post-checkout script support with complete backward compatibility:

1. **Non-breaking changes**: All v6.1.x configurations work in v6.2.0
2. **New optional fields**: "Post-Checkout Script File Name" and "Post-Checkout Script File Path"
3. **New object format**: Enhanced JSON structure while maintaining legacy array compatibility
4. **Enhanced integration**: Support for external dependency management systems

**New Features Available:**
- Post-checkout PowerShell script execution after successful repository checkouts
- Environment variables providing checkout context to scripts
- Timeout protection and comprehensive error handling
- Script execution statistics in summary reports

**Migration Steps:**
1. **Immediate**: All existing repositories continue to work without changes
2. **Optional**: Convert to new object format to add post-checkout scripts
3. **Gradual**: Add post-checkout scripts to repositories as needed

**Format Migration Examples:**

**Legacy Array Format:**
```json
[
  {
    "Repository URL": "https://github.com/user/repo.git",
    "Base Path": "repos/repo",
    "Tag": "v1.0.0"
  }
]
```

**New Object Format:**
```json
{
  "Post-Checkout Script File Name": "setup.ps1",
  "Repositories": [
    {
      "Repository URL": "https://github.com/user/repo.git",
      "Base Path": "repos/repo",
      "Tag": "v1.0.0"
    }
  ]
}
```

### From Version 6.0.x to 6.1.0

Version 6.1.0 introduces custom dependency file support with complete backward compatibility:

1. **Non-breaking changes**: All v6.0.x configurations work in v6.1.0
2. **New optional fields**: "Dependency File Path" and "Dependency File Name"
3. **Enhanced path resolution**: Relative paths now properly resolve from repository roots
4. **Dependency isolation**: Custom settings don't propagate to nested repositories

**New Features Available:**
- Per-repository custom dependency file paths and names
- Flexible support for different project structures
- Proper isolation of custom settings
- Enhanced logging for custom configurations

**Migration Steps:**
1. **Immediate**: All existing repositories continue to work without changes
2. **Optional**: Add custom dependency file settings to repositories as needed
3. **Gradual**: Migrate to different naming conventions at your own pace

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
- Using different dependency file conventions across projects
- Supporting custom project structures and naming conventions
- **Integrating with multiple dependency management systems via post-checkout scripts**

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
12. **Custom Dependency Files**: Support for different project structures and naming conventions
13. **Dependency Isolation**: Proper separation of concerns in nested dependencies
14. ****Multi-System Integration**: Post-checkout scripts enable seamless integration with npm, NuGet, pip, and other package managers**

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
   - Supporting diverse project structures and conventions
   - **Integrating multiple package management systems**

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
   - Handling mixed dependency file conventions
   - **Orchestrating complex build processes with multiple tools**

### Hybrid Approach: Best of Both Worlds

Many successful projects combine both approaches:
- Use npm/NuGet for stable, third-party libraries
- Use LsiGitCheckout for internal dependencies and actively developed components
- **Use post-checkout scripts to automatically install package manager dependencies**
- Maintain clear boundaries between packaged and source dependencies
- Apply different compatibility modes based on environment (Strict for production, Permissive for development)
- Leverage always-on intelligent tag sorting for simplified dependency management
- Support different dependency file conventions across teams and projects

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
- Organizations with diverse project structures and naming conventions
- Multi-team environments requiring dependency isolation
- **Polyglot projects requiring integration of multiple package managers**
- **Automated build systems that need to install packages after source checkout**

### Post-Checkout Script Integration Examples

**JavaScript/Node.js Integration:**
```powershell
# Install npm dependencies after Git checkout
if (Test-Path "package.json") {
    npm install
}
```

**.NET Integration:**
```powershell
# Restore NuGet packages after Git checkout
if (Test-Path "*.csproj") {
    dotnet restore
}
```

**Python Integration:**
```powershell
# Install pip requirements after Git checkout
if (Test-Path "requirements.txt") {
    pip install -r requirements.txt
}
```

**Multi-Language Project:**
```powershell
# Handle multiple package managers in one script
if (Test-Path "package.json") { npm install }
if (Test-Path "requirements.txt") { pip install -r requirements.txt }
if (Test-Path "*.csproj") { dotnet restore }
if (Test-Path "Gemfile") { bundle install }
```

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Authors

Originally developed by LS Instruments AG for managing complex multi-repository projects.

Co-authored with Claude (Anthropic) through collaborative development.