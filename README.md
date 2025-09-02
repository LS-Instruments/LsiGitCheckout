# LsiGitCheckout

A PowerShell script for managing multiple Git repositories with support for tags, SSH authentication via PuTTY, Git LFS, and submodules. Features advanced recursive dependency resolution with API compatibility checking, Semantic Versioning (SemVer) support with floating versions, flexible compatibility modes, intelligent automatic tag temporal sorting, custom dependency file configurations, and post-checkout PowerShell script execution for integration with external dependency management systems.

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Basic Usage (Non-Recursive)](#basic-usage-non-recursive)
- [Advanced Usage (Recursive Mode)](#advanced-usage-recursive-mode)
- [Dependency Resolution Modes](#dependency-resolution-modes)
- [API Compatibility Modes](#api-compatibility-modes)
- [Checkout Tag Selection Algorithm](#checkout-tag-selection-algorithm)
- [Custom Dependency Files](#custom-dependency-files)
- [Post-Checkout Scripts](#post-checkout-scripts)
- [Security Best Practices](#security-best-practices)
- [SSH Setup with PuTTY](#ssh-setup-with-putty)
- [Troubleshooting](#troubleshooting)
- [Migration Guide](#migration-guide)
- [Advanced Topics](#advanced-topics)
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
- **Dependency Resolution Modes**: Choose between Agnostic (tag-based) and SemVer (Semantic Versioning) resolution
- **Floating Versions**: Support for SemVer floating version patterns (x.y.*, x.*) for automatic latest version selection
- **Flexible Compatibility Modes**: Choose between Strict and Permissive API compatibility modes
- **Intelligent Tag Temporal Sorting**: Always-on automatic chronological tag ordering using actual git tag dates with optimized performance
- **Custom Dependency Files**: Per-repository custom dependency file paths and names with proper isolation
- **Post-Checkout Scripts**: Execute PowerShell scripts after successful repository checkouts for integration with external dependency management systems, including support for root-level execution

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

# Enable detailed error context for debugging
.\LsiGitCheckout.ps1 -EnableErrorContext
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
- `-EnableErrorContext`: Enable detailed error context with stack traces (default: simple errors only)

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

**Simple Array Format (without Post-Checkout Scripts):**
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
- **Base Path** (required): Local directory checkout path (relative or absolute)
- **Tag** (required for Agnostic mode): Git tag to checkout
- **API Compatible Tags** (optional, Agnostic mode): List of API-compatible tags (can be in any order - automatic chronological sorting)
- **API Compatibility** (optional): "Strict" or "Permissive" (defaults to script parameter when absent)
- **Dependency Resolution** (optional): "Agnostic" (default) or "SemVer" - see [Dependency Resolution Modes](#dependency-resolution-modes)
- **Version** (required for SemVer mode): Semantic version requirement (e.g., "2.1.0", "2.1.*", "2.*")
- **Version Regex** (optional, SemVer mode): Custom regex pattern for version extraction from tags
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

**When Recursive Mode is enabled (Default)** the script automatically discovers and processes nested dependencies. After checking out each repository, it looks for a dependency file (dependencies.json if not specified differently upon script execution) within the root folder of that repository and processes it recursively, with intelligent handling of shared dependencies.

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

When recursive mode processes nested dependencies, a common scenario emerges: **the same repository is required by multiple projects with potentially different version requirements**. This creates the fundamental challenge that the script's dependency resolution system is designed to solve.

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

#### The Solution: Multiple Resolution Modes

LsiGitCheckout provides two powerful approaches to solve this challenge:

1. **Agnostic Mode**: Uses explicit "API Compatible Tags" lists with intelligent intersection/union algorithms
2. **SemVer Mode**: Automatically resolves compatible versions based on Semantic Versioning 2.0.0 rules with floating version support

Both modes use sophisticated conflict resolution algorithms that consider the compatibility requirements of all callers and select the optimal version that satisfies everyone's needs.

### Choosing Between Dependency Resolution Modes

Each mode offers distinct advantages and is suited for different scenarios:

#### SemVer Mode Advantages
- **Zero maintenance overhead**: Compatible updates require no configuration changes
- **Automatic conflict detection**: Clear error messages when version requirements conflict
- **Immediate availability**: Entire dependency tree benefits from compatible updates as soon as they're released
- **Simplified configuration**: Only need to specify minimum version requirements or floating patterns
- **Floating versions**: Automatically select latest compatible versions using patterns like `2.1.*` or `2.*`
- **Industry standard**: Follows well-understood Semantic Versioning 2.0.0 rules

#### Agnostic Mode Advantages  
- **Maximum control**: Fine-grained control over version compatibility relationships
- **Flexible versioning**: Works with any tagging scheme, not just semantic versioning
- **Complex compatibility**: Handle intricate compatibility relationships that don't fit SemVer rules
- **Legacy support**: Ideal for migrating projects with inconsistent versioning practices

#### When to Choose SemVer Mode
- Your repositories follow semantic versioning consistently
- You want to minimize configuration maintenance overhead
- Your team understands and follows SemVer 2.0.0 principles
- You prefer automatic compatibility resolution with clear, predictable rules
- You want to leverage floating versions for automatic latest version selection
- You're starting a new project or can enforce semantic versioning discipline

#### When to Choose Agnostic Mode
- You need fine-grained control over version compatibility
- Your repositories don't follow strict semantic versioning
- You have complex compatibility relationships that don't fit SemVer rules
- You're migrating legacy systems with inconsistent versioning approaches  
- You require maximum flexibility in defining version relationships

**Mixed Mode Support**: You can use both modes in the same dependency tree, choosing the appropriate mode for each repository based on its versioning practices and requirements.

## Dependency Resolution Modes

LsiGitCheckout supports two dependency resolution modes that can be mixed within the same dependency tree:

### Agnostic Mode (Default)

The traditional tag-based resolution using exact tags and explicit API Compatible Tags lists. This mode provides maximum control and flexibility for projects that don't follow strict semantic versioning.

**Key Features:**
- Explicit compatibility definitions via "API Compatible Tags"
- Always-on intelligent tag temporal sorting
- Support for Strict and Permissive compatibility modes
- Fine-grained control over version relationships

**Configuration Example:**
```json
{
  "Repository URL": "https://github.com/org/library.git",
  "Base Path": "libs/library",
  "Tag": "v2.1.0",
  "API Compatible Tags": ["v2.0.0", "v2.0.1", "v2.0.5"],
  "API Compatibility": "Strict"
}
```

### SemVer Mode

Automatic version resolution based on Semantic Versioning 2.0.0 rules. This mode eliminates the need to maintain explicit compatibility lists by leveraging semantic versioning conventions and supports floating version patterns for automatic latest version selection.

**Key Features:**
- Automatic compatibility resolution using SemVer rules
- Floating version patterns for automatic latest version selection
- Support for custom version tag patterns
- Intelligent conflict detection and reporting
- Mixed specification mode: floating patterns select highest compatible versions

**Configuration Examples:**

#### Lowest Applicable Version (traditional)
```json
{
  "Repository URL": "https://github.com/org/library.git",
  "Base Path": "libs/library",
  "Dependency Resolution": "SemVer",
  "Version": "2.1.0",
  "Version Regex": "^v(\\d+)\\.(\\d+)\\.(\\d+)$"
}
```

#### Floating Patch Version (new in v7.1.0)
```json
{
  "Repository URL": "https://github.com/org/library.git",
  "Base Path": "libs/library", 
  "Dependency Resolution": "SemVer",
  "Version": "2.1.*"
}
```

#### Floating Minor Version (new in v7.1.0)
```json
{
  "Repository URL": "https://github.com/org/library.git",
  "Base Path": "libs/library",
  "Dependency Resolution": "SemVer",
  "Version": "2.*"
}
```

### SemVer Mode Details

#### Version Specification Patterns

SemVer mode supports three version specification patterns:

1. **Lowest Applicable Version (`x.y.z`)**: Select minimum version that satisfies compatibility requirements
   - Example: `"Version": "2.1.0"` → Compatible: 2.1.0, 2.1.1, 2.2.0 → Selects: 2.1.0

2. **Floating Patch Version (`x.y.*`)**: Select latest patch version within specified major.minor
   - Example: `"Version": "2.1.*"` → Compatible: 2.1.0, 2.1.1, 2.1.5 → Selects: 2.1.5

3. **Floating Minor Version (`x.*`)**: Select latest minor.patch version within specified major
   - Example: `"Version": "2.*"` → Compatible: 2.1.0, 2.3.2, 2.5.0 → Selects: 2.5.0

#### Mixed Specification Mode

When multiple repositories declare the same dependency with different specification patterns:

- **If ANY dependency uses floating patterns** → select **highest** compatible version
- **If ALL dependencies use lowest-applicable** → select **lowest** compatible version

**Example Mixed Mode Scenario:**
```
Repository A: "Version": "3.0.0" (lowest-applicable)  
Repository B: "Version": "3.*" (floating minor)
Result: System selects highest 3.x.x version that satisfies both requirements
```

#### Version Compatibility Rules

SemVer mode follows standard Semantic Versioning 2.0.0 rules:

1. **For versions >= 1.0.0**:
   - Compatible versions must have the same MAJOR version
   - MINOR and PATCH must be >= the requested version
   - Example: Request `2.1.0` → Compatible: `2.1.0`, `2.1.1`, `2.2.0`, NOT `3.0.0`

2. **For 0.x.y versions**:
   - MINOR version acts as the major version (breaking changes)
   - Compatible versions must have the same MINOR version
   - PATCH must be >= the requested version
   - Example: Request `0.2.1` → Compatible: `0.2.1`, `0.2.5`, NOT `0.3.0`

#### Custom Version Tag Formats

If your repositories use non-standard version tag formats, you can specify a custom regex:

```json
{
  "Version Regex": "^release-(\\d+)\\.(\\d+)\\.(\\d+)$"
}
```

**Requirements:**
- Must have exactly 3 capture groups in order: major, minor, patch
- The pattern is immutable once a repository is discovered
- All tags not matching the pattern are ignored

#### Conflict Resolution

If multiple repositories depend on the same library with incompatible version requirements, the script will report a detailed conflict error showing:
- All repositories requesting the conflicting dependency
- Their individual version requirements and pattern types
- The compatible versions for each requirement

**Example conflict:**
```
SemVer conflict for repository 'https://github.com/org/shared-lib.git':
No version satisfies all requirements:
- https://github.com/org/app-a.git requests: 2.1.0 (type: LowestApplicable, compatible: v2.1.0, v2.1.1, v2.2.0)
- https://github.com/org/app-b.git requests: 3.* (type: FloatingMinor, compatible: v3.0.0, v3.1.0, v3.2.0)
```

### Mixed Mode Support

You can use both Agnostic and SemVer modes in the same dependency tree. Each repository's mode is determined by its configuration and cannot change once established.

**Example Mixed Configuration:**
```json
[
  {
    "Repository URL": "https://github.com/org/app.git",
    "Base Path": "app",
    "Dependency Resolution": "SemVer",
    "Version": "1.0.0"
  },
  {
    "Repository URL": "https://github.com/org/lib-core.git", 
    "Base Path": "libs/core",
    "Dependency Resolution": "SemVer",
    "Version": "2.3.*"
  },
  {
    "Repository URL": "https://github.com/org/lib-utils.git",
    "Base Path": "libs/utils", 
    "Tag": "v1.5.0",
    "API Compatible Tags": ["v1.4.0", "v1.4.1"]
  }
]
```

### Best Practices

1. **Choose SemVer mode** when your repositories follow semantic versioning consistently
2. **Use floating versions** (`x.y.*`, `x.*`) when you want automatic latest version selection
3. **Use lowest-applicable versions** (`x.y.z`) when you need stability and predictable versions
4. **Use Agnostic mode** when you need fine-grained control over compatibility or don't follow strict semver
5. **Mix modes appropriately** - use SemVer for well-versioned libraries and Agnostic for experimental or legacy components
6. **Test your dependency tree** with `-DryRun` before actual checkouts
7. **Use consistent version tag formats** across your organization when using SemVer mode

## API Compatibility Modes

API compatibility modes control how version conflicts are resolved when multiple projects depend on the same repository. These modes apply to Agnostic mode repositories.

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

## Checkout Tag Selection Algorithm

The script features an intelligent automatic tag selection algorithm using actual git tag dates, providing optimal version selection without any manual configuration required.

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

### Tag Selection Algorithm

When multiple repositories reference the same dependency with different tags, the algorithm prioritizes in this order:

1. **Both existing and new "Tag" are compatible**: Choose the chronologically most recent "Tag"
2. **Only existing "Tag" is compatible**: Use the existing "Tag" 
3. **Only new "Tag" is compatible**: Use the new "Tag"
4. **Neither "Tag" is compatible**: Use the chronologically most recent tag from the compatible set (intersection/union)

### Performance Optimization

- **On-demand processing**: Tag dates are only fetched when needed for conflict resolution
- **Efficient git operations**: Uses `git for-each-ref` instead of multiple `git log` calls
- **Smart caching**: Tag dates are cached in memory during recursive processing
- **Minimal server impact**: Only one tag date fetch per repository during initial checkout

## Custom Dependency Files

Per-repository custom dependency file paths and names provide flexibility for different project structures and naming conventions while maintaining proper dependency isolation.

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

## Post-Checkout Scripts

### Overview

Post-checkout scripts are PowerShell scripts (.ps1) that execute automatically after a repository is successfully checked out to a specific tag. These scripts run only when an actual checkout occurs - they are skipped when repositories are already up-to-date with the correct tag. Post-checkout scripts enable integration with external dependency management systems and custom setup procedures.

**Key Characteristics:**
- **Execution Trigger**: Only after successful repository checkouts (clone or tag change)
- **Working Directory**: Scripts execute with the repository root as the working directory
- **Environment Variables**: Scripts receive context about the checkout operation
- **Timeout Protection**: Scripts are terminated if they exceed 5 minutes execution time
- **Error Handling**: Script failures are logged but don't prevent repository checkout success
- **Security**: Scripts run with `-ExecutionPolicy Bypass` for maximum compatibility
- **Root-Level Support**: Scripts can execute at depth 0 (root level) for global setup tasks

### Configuration

Post-checkout scripts are configured at the dependency file level and can execute at any depth:

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

#### Package Manager Integration

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

6. **SemVer version conflicts**
   - Verify version requirements are compatible
   - Check that version tags follow your specified regex pattern
   - Review conflict details in error messages for resolution guidance
   - Consider using floating versions (x.y.*, x.*) for more flexible version selection

7. **Floating version pattern errors**
   - Ensure floating patterns use correct syntax: `x.y.*` or `x.*` 
   - Verify repository tags match the specified Version Regex pattern
   - Check that compatible versions exist for floating patterns
   - Review debug logs for pattern parsing and version selection details

8. **Tag temporal sorting issues**  
   - Verify git tags exist in repositories
   - Check debug logs for tag date fetching errors
   - Ensure repositories are accessible for tag date queries
   - Review verbose output for tag selection decisions

9. **Custom dependency file not found**
   - Verify the custom path and filename are correct
   - Check that the dependency file exists in the specified location
   - Remember that paths are relative to repository root
   - Use debug logging to see resolved paths

10. **Repository path conflicts**
    - Ensure the same repository isn't referenced with different relative paths
    - Check that custom dependency file paths don't create conflicting layouts
    - Verify relative paths resolve correctly from repository roots

11. **Post-checkout script issues**
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
- SemVer version parsing and conflict resolution
- Version pattern recognition (LowestApplicable, FloatingPatch, FloatingMinor)
- Mixed specification mode selection logic
- Custom dependency file path resolution
- Repository root path usage for relative path resolution
- Post-checkout script discovery and execution details
- Detailed Git command execution

### Enhanced Error Context

For advanced debugging, enable detailed error context:

```powershell
.\LsiGitCheckout.ps1 -EnableDebug -EnableErrorContext
```

This provides:
- Full stack traces for all errors
- Line numbers and function names where errors occurred
- Detailed error context for complex dependency resolution scenarios
- Enhanced troubleshooting information for SemVer conflicts
- Floating version pattern parsing and resolution diagnostics

## Migration Guide

### From Version 7.0.0 to 7.1.0

Version 7.1.0 introduces Floating Versions support for SemVer mode:

#### New Features Available
- **Floating Patch Versions (`x.y.*`)**: Automatically select latest patch versions
- **Floating Minor Versions (`x.*`)**: Automatically select latest minor.patch versions  
- **Mixed Specification Mode**: Intelligent selection between lowest-applicable and highest-compatible based on pattern types
- **Enhanced logging**: Shows version pattern types and selection reasoning

#### Migration Steps
1. **Immediate**: All existing v7.0.0 configurations work without changes
2. **Optional**: Convert appropriate SemVer specifications to floating patterns for automatic latest version selection
3. **Enhanced workflows**: Leverage floating versions for dependency currency while maintaining stability where needed

#### Floating Version Examples

**Before (Lowest Applicable):**
```json
{
  "Repository URL": "https://github.com/org/library.git",
  "Dependency Resolution": "SemVer",
  "Version": "2.1.0"
}
```

**After (Floating Patch - optional):**
```json
{
  "Repository URL": "https://github.com/org/library.git",
  "Dependency Resolution": "SemVer",
  "Version": "2.1.*"
}
```

**After (Floating Minor - optional):**
```json
{
  "Repository URL": "https://github.com/org/library.git",
  "Dependency Resolution": "SemVer",
  "Version": "2.*"
}
```

#### Benefits of Floating Versions
- **Automatic updates**: Get latest patches/minors without manual configuration changes
- **Flexible dependency management**: Mix fixed and floating patterns as appropriate
- **Reduced maintenance**: Less frequent dependency file updates required
- **Better currency**: Stay up-to-date with compatible improvements

#### Non-Breaking Changes
- **Zero configuration changes required**: All existing dependency files work without modification
- **Backward compatibility**: Traditional `x.y.z` patterns remain the default
- **Gradual adoption**: Convert to floating patterns as appropriate for your stability requirements

### From Version 6.2.x to 7.0.0

Version 7.0.0 introduces Semantic Versioning (SemVer) support alongside the existing Agnostic mode:

#### New Features Available
- **SemVer Mode**: Automatic version resolution based on Semantic Versioning 2.0.0 rules
- **Mixed Mode Support**: Use both Agnostic and SemVer repositories in the same dependency tree
- **Enhanced Version Parsing**: One-time tag parsing with caching for performance
- **Improved Conflict Reporting**: Detailed conflict messages with full context

#### Migration Steps
1. **Immediate**: All existing v6.2.x configurations work without changes in Agnostic mode
2. **Optional**: Convert appropriate repositories to SemVer mode for automatic compatibility resolution
3. **Enhanced workflows**: Leverage SemVer for well-versioned libraries while keeping Agnostic mode for complex scenarios

#### SemVer Configuration Example

**Before (Agnostic mode):**
```json
{
  "Repository URL": "https://github.com/org/library.git",
  "Base Path": "libs/library",
  "Tag": "v2.1.0",
  "API Compatible Tags": ["v2.0.0", "v2.0.1", "v2.0.5"]
}
```

**After (SemVer mode - optional):**
```json
{
  "Repository URL": "https://github.com/org/library.git",
  "Base Path": "libs/library", 
  "Dependency Resolution": "SemVer",
  "Version": "2.1.0"
}
```

#### Benefits of Migration
- **Reduced maintenance**: No need to manually maintain API Compatible Tags for SemVer repositories
- **Automatic resolution**: SemVer rules automatically determine compatible versions
- **Clear conflict reporting**: Detailed error messages when version requirements conflict
- **Mixed approach**: Use SemVer where appropriate while keeping Agnostic mode for complex cases

#### Non-Breaking Changes
- **Zero configuration changes required**: All existing dependency files work without modification
- **Backward compatibility**: Agnostic mode remains the default and fully supported
- **Gradual adoption**: Convert repositories to SemVer mode as appropriate for your workflow

### Previous Version Migration Guides

For migration guides from earlier versions, see the [CHANGELOG.md](CHANGELOG.md) file which contains detailed migration instructions for all version transitions.

## Advanced Topics

For detailed information on advanced scenarios and tool comparisons, see these additional guides:

### [Migration and Dependency Management Guide](docs/migration_guide.md)

Comprehensive guide covering:
- **[Migrating Existing Dependency Trees to LsiGitCheckout (Agnostic Mode)](docs/migration_guide.md#migrating-existing-dependency-trees-to-lsigitcheckout-agnostic-mode)**: Step-by-step migration using explicit API Compatible Tags
- **[Migrating Existing Dependency Trees to LsiGitCheckout (SemVer Mode)](docs/migration_guide.md#migrating-existing-dependency-trees-to-lsigitcheckout-semver-mode)**: Step-by-step migration using Semantic Versioning rules
- **[Handling Shared Dependencies Version Changes (Agnostic Mode)](docs/migration_guide.md#handling-shared-dependencies-version-changes-agnostic-mode)**: Managing version updates with explicit compatibility tags
- **[Handling Shared Dependencies Version Changes (SemVer Mode)](docs/migration_guide.md#handling-shared-dependencies-version-changes-semver-mode)**: Managing version updates with automatic SemVer compatibility

### [Tool Comparison Guide](docs/comparison_guide.md)

Detailed comparisons with other tools:
- **[LsiGitCheckout vs Google's Repo Tool](docs/comparison_guide.md#lsigitcheckout-vs-googles-repo-tool)**: Feature comparison and use case guidance
- **[LsiGitCheckout vs Traditional Package Managers](docs/comparison_guide.md#lsigitcheckout-vs-traditional-package-managers)**: Understanding when to use each approach

These guides provide in-depth coverage of complex scenarios and help you make informed decisions about tool selection and migration strategies.

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Authors

Originally developed by LS Instruments AG for managing complex multi-repository projects.

Co-authored with Claude (Anthropic) through collaborative development.