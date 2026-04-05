# RepoHerd

A cross-platform Git dependency management tool that automates cloning, checking out, and version-pinning of multiple repositories from a single JSON configuration. Designed for multi-repo projects where teams need reproducible builds without the complexity of git submodules or monorepo tooling.

RepoHerd resolves recursive dependencies across repository trees, supports both Semantic Versioning (SemVer) and tag-based version pinning, and handles SSH authentication (PuTTY on Windows, OpenSSH on macOS/Linux), Git LFS, and post-checkout script execution.

## Table of Contents

- [Features](#features)
- [Supported Platforms](#supported-platforms)
- [Platform Setup](#platform-setup)
- [Installation](#installation)
- [Basic Usage (Non-Recursive)](#basic-usage-non-recursive)
- [Advanced Usage (Recursive Mode)](#advanced-usage-recursive-mode)
- [Dependency Resolution Modes](#dependency-resolution-modes)
- [SemVer Mode](docs/semver_mode.md)
- [Agnostic Mode](docs/agnostic_mode.md)
- [Choosing Between Dependency Resolution Modes](docs/choosing_modes.md)
- [Custom Dependency Files](docs/custom_dependency_files.md)
- [Post-Checkout Scripts](docs/post_checkout_scripts.md)
- [Security Best Practices](docs/security_best_practices.md)
- [SSH Setup](docs/ssh_setup.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Version Migration Guide](docs/version_migration.md)
- [Advanced Topics](docs/advanced_topics.md)
- [License](#license)
- [Contributing](#contributing)

## Features

- **Clone and Checkout**: Automatically clone and checkout multiple Git repositories to pinned versions from a single JSON configuration
- **Version Pinning**: Pin repositories to exact tags or SemVer ranges for reproducible builds across your team
- **Recursive Dependency Resolution**: Discover and resolve nested repository dependencies with API compatibility checking — an alternative to git submodules for multi-repo projects
- **Dependency Resolution Modes**: Choose between SemVer (Semantic Versioning with floating versions) and Agnostic (explicit tag-based) resolution
- **Floating Versions**: SemVer floating version patterns (x.y.\*, x.\*) for automatic latest compatible version selection
- **Cross-Platform SSH**: PuTTY/Pageant on Windows, OpenSSH on macOS/Linux — automated git authentication per host
- **Secure Credentials Management**: SSH keys stored separately from repository configuration
- **Submodule Support**: Handles Git submodules with automatic per-host SSH key lookup
- **Git LFS Support**: Optional Git LFS content management with skip functionality
- **Smart Reset**: Automatically resets repositories to clean state before checkout
- **Structured JSON Output**: Machine-readable results with per-repo status, dependency chains, and error details for CI/CD integration
- **Dry Run Mode**: Preview clone and checkout operations without making changes
- **Flexible Compatibility Modes**: Choose between Strict and Permissive API compatibility modes for Agnostic mode
- **Custom Dependency Files**: Support for different project structures and naming conventions with proper isolation
- **Post-Checkout Scripts**: Execute PowerShell scripts after successful repository checkouts for integration with external dependency management systems

## Supported Platforms

| Component | Windows 10/11, Server 2016+ | macOS | Linux |
|-----------|----------------------------|-------|-------|
| PowerShell | 7.6 LTS (side-by-side with 5.1) | 7.6 LTS | 7.6 LTS |
| Git | Git for Windows 2.x+ | Xcode CLI tools or standalone | Distribution package |
| SSH transport | PuTTY/plink + Pageant (`.ppk` keys) | OpenSSH (bundled) | OpenSSH (bundled) |
| HTTPS auth | Git Credential Manager (bundled with Git for Windows) | Git Credential Manager | Git Credential Manager or PAT |
| Git LFS | Optional | Optional | Optional |

## Platform Setup

### Windows

1. **Install PowerShell 7.6 LTS** (installs as `pwsh.exe` alongside Windows PowerShell 5.1 — existing scripts are unaffected):

   ```cmd
   winget install Microsoft.PowerShell
   ```

2. **Install Git for Windows** (includes Git Credential Manager for HTTPS authentication):

   Download from [git-scm.com](https://git-scm.com/download/win) or:

   ```cmd
   winget install Git.Git
   ```

3. **Set execution policy** (one-time, allows running local scripts):

   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

4. **SSH setup** (only if accessing repositories via SSH URLs):

   RepoHerd uses PuTTY/plink on Windows. See [SSH Setup](docs/ssh_setup.md).

### macOS

1. **Install PowerShell 7.6 LTS**:

   ```bash
   # Via Homebrew (recommended)
   brew install powershell

   # Or via .NET global tool
   dotnet tool install --global PowerShell
   ```

2. **Install Git** (may already be installed via Xcode CLI tools):

   ```bash
   # Check if installed
   git --version

   # Install Xcode CLI tools if needed
   xcode-select --install
   ```

3. **Install Git Credential Manager** (for HTTPS authentication to GitHub, Azure DevOps, etc.):

   ```bash
   brew install git-credential-manager
   git-credential-manager configure
   ```

4. **SSH setup** (only if accessing repositories via SSH URLs):

   macOS includes OpenSSH. See [SSH Setup](docs/ssh_setup.md).

### Linux

1. **Install PowerShell 7.6 LTS**:

   ```bash
   # Ubuntu/Debian
   sudo apt-get update
   sudo apt-get install -y powershell

   # RHEL/CentOS/Fedora
   sudo dnf install powershell

   # Or via .NET global tool
   dotnet tool install --global PowerShell
   ```

   See [Microsoft's Linux installation guide](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux) for all distributions.

2. **Install Git**:

   ```bash
   # Ubuntu/Debian
   sudo apt-get install git

   # RHEL/CentOS/Fedora
   sudo dnf install git
   ```

3. **Install Git Credential Manager** (for HTTPS authentication):

   ```bash
   # Download latest .deb or .rpm from:
   # https://github.com/git-credential-manager/git-credential-manager/releases
   sudo dpkg -i gcm-linux_amd64.deb   # Debian/Ubuntu
   git-credential-manager configure
   ```

   Alternatively, use a Personal Access Token (PAT) for HTTPS repos.

4. **SSH setup** (only if accessing repositories via SSH URLs):

   Linux includes OpenSSH. See [SSH Setup](docs/ssh_setup.md).

## Installation

### From PowerShell Gallery (recommended)

```powershell
Install-Module -Name RepoHerd
```

Then run from any directory containing a `dependencies.json`:

```powershell
Invoke-RepoHerd
Invoke-RepoHerd -InputFile "path/to/deps.json"
Invoke-RepoHerd -DryRun
```

### Manual download

1. Download `RepoHerd.ps1`, `RepoHerd.psm1`, and `RepoHerd.psd1` to the same directory
2. Create `dependencies.json` with your repository configuration
3. Create `git_credentials.json` with your SSH key mappings (if using SSH repositories)
4. Run with `pwsh`:

   ```bash
   pwsh ./RepoHerd.ps1 -InputFile dependencies.json
   ```

## Basic Usage (Non-Recursive)

### Overview

In non-recursive mode, the script processes only the repositories listed in your main dependencies file. It does not look for or process any nested dependencies.

### Command Line Usage

```powershell
# If installed from PowerShell Gallery, use Invoke-RepoHerd:
Invoke-RepoHerd
Invoke-RepoHerd -InputFile "C:\configs\myrepos.json" -CredentialsFile "C:\configs\my_credentials.json"
Invoke-RepoHerd -EnableDebug
Invoke-RepoHerd -DryRun

# If using the script directly:
.\RepoHerd.ps1
.\RepoHerd.ps1 -InputFile "C:\configs\myrepos.json" -CredentialsFile "C:\configs\my_credentials.json"
.\RepoHerd.ps1 -EnableDebug
.\RepoHerd.ps1 -DryRun

# Verbose output
.\RepoHerd.ps1 -Verbose

# Set default API compatibility mode (applies only to Agnostic mode repositories)
.\RepoHerd.ps1 -ApiCompatibility Strict

# Disable recursive mode (non-recursive mode)
.\RepoHerd.ps1 -DisableRecursion

# Disable post-checkout script execution
.\RepoHerd.ps1 -DisablePostCheckoutScripts

# Enable detailed error context for debugging
.\RepoHerd.ps1 -EnableErrorContext

# Export structured JSON results for CI/CD pipelines
.\RepoHerd.ps1 -OutputFile result.json
```

### Parameters

- `-InputFile`: Path to repository configuration file (default: dependencies.json)
- `-CredentialsFile`: Path to SSH credentials file (default: git_credentials.json)
- `-DryRun`: Preview operations without making changes
- `-EnableDebug`: Create detailed debug log file
- `-Verbose`: Show verbose output messages
- `-ApiCompatibility`: Default API compatibility mode for Agnostic mode repositories ('Strict' or 'Permissive', default: 'Permissive')
- `-DisableRecursion`: Disable recursive dependency processing (default: recursive mode enabled)
- `-DisablePostCheckoutScripts`: Disable post-checkout script execution (default: post-checkout scripts enabled)
- `-EnableErrorContext`: Enable detailed error context with stack traces (default: simple errors only)
- `-OutputFile`: Write structured JSON results to the specified file path (for CI/CD integration)

### Structured JSON Output

When `-OutputFile` is specified, a JSON file is written with the results of the checkout operation. The output is guaranteed to be written even on failure, making it safe for CI/CD pipelines. Schema version: **1.0.0**.

```powershell
.\RepoHerd.ps1 -InputFile deps.json -OutputFile result.json
```

**Output structure:**

| Field | Type | Description |
|-------|------|-------------|
| `schemaVersion` | string | JSON schema version (`"1.0.0"`) |
| `metadata` | object | Execution context: `toolVersion`, `timestamp`, `dryRun`, `recursiveMode`, `maxDepth`, `apiCompatibility`, `inputFile`, `powershellVersion` |
| `summary` | object | `success` (bool), `successCount`, `failureCount`, `totalRepositories`, `postCheckoutScripts` (enabled/executions/failures) |
| `repositories[]` | array | Per-repository results (see below) |
| `processedDependencyFiles[]` | array | Absolute paths of all dependency files processed |
| `rootPostCheckoutScripts[]` | array | Post-checkout script tracking for depth-0 (root-level) scripts |
| `errors[]` | array | Error messages collected during execution |

**Repository entry fields:**

| Field | Type | Description |
|-------|------|-------------|
| `url` | string | Repository URL |
| `path` | string | Absolute checkout path |
| `dependencyResolution` | string | `"SemVer"` or `"Agnostic"` |
| `status` | string | `"success"`, `"failed"`, or `"skipped"` |
| `alreadyCheckedOut` | bool | Whether the repo was already at the correct version |
| `requestedBy` | string[] | Parent repo URLs or `"root-dependency-file"` |
| `tag` | string | Git tag checked out |
| `requestedVersion` | string? | SemVer version pattern requested (SemVer only) |
| `selectedVersion` | string? | SemVer version selected (SemVer only) |
| `postCheckoutScript` | object? | Script tracking: `configured`, `scriptPath`, `found`, `executed`, `status`, `reason` (null if no script configured) |

**Post-checkout script status values:** `"executed"`, `"failed"`, `"skipped"`, `"timeout"`

### Understanding Dependency Resolution Modes

RepoHerd provides two approaches for determining which git tag to checkout for each repository. Both modes examine the available git tags in each repository to make their selection decisions.

#### SemVer Mode (Recommended)

Uses **Semantic Versioning 2.0.0 rules** with the `Version` field in your dependency file to automatically determine compatible tags.

**How it works:**
1. You specify a `"Version"` field in your dependency file for each repository
2. Script fetches all git tags from the repository
3. Parses tags using a version regex pattern to extract semantic versions
4. Finds all tags compatible with your version requirement
5. Selects the appropriate version based on your pattern type

**Version Field Patterns in Dependency File:**
- **Lowest Applicable (`x.y.z`)**: Selects minimum version that satisfies compatibility
  - Example: `"Version": "2.1.0"` in dependency file → Selects 2.1.0, 2.1.1, or 2.2.0 but not 3.0.0
- **Floating Patch (`x.y.*`)**: Automatically selects latest patch within major.minor
  - Example: `"Version": "2.1.*"` in dependency file → Selects latest 2.1.x (e.g., 2.1.5 if available)
- **Floating Minor (`x.*`)**: Automatically selects latest minor.patch within major
  - Example: `"Version": "2.*"` in dependency file → Selects latest 2.x.x (e.g., 2.5.3 if available)

**Key Benefits:**
- Zero maintenance for compatible updates
- Automatic selection of bug fixes and compatible features
- Clear boundaries preventing breaking changes

#### Agnostic Mode

Uses **explicit tag specification** with the `Tag` field in your dependency file to checkout exact versions.

**How it works:**
1. You specify a `"Tag"` field in your dependency file for each repository
2. Script checks if the specified tag exists in the repository
3. Checks out exactly the requested tag
4. No automatic version resolution or compatibility checking

**Tag Field Usage in Dependency File:**
- **Exact Tag (`Tag`)**: Specifies the precise git tag to checkout
  - Example: `"Tag": "v2.1.0"` in dependency file → Checks out exactly tag v2.1.0

**Key Benefits:**
- Maximum control over exact versions
- Works with any tagging scheme
- Explicit, predictable behavior

### Configuration Files

#### dependencies.json

The dependencies.json file contains the specification of the repositories that are your dependencies. This file lists all the repositories you want to checkout and configure, without any credential information:

**SemVer Mode Configuration (Recommended):**
```json
{
  "Post-Checkout Script File Name": "setup-dependencies.ps1",
  "Post-Checkout Script File Path": "scripts/build",
  "Repositories": [
    {
      "Repository URL": "https://github.com/user/repo.git",
      "Base Path": "repos/my-repo",
      "Dependency Resolution": "SemVer",
      "Version": "2.1.*",
      "Version Regex": "^v(\\d+)\\.(\\d+)\\.(\\d+)$",
      "Skip LFS": false
    }
  ]
}
```

**Agnostic Mode Configuration:**
```json
{
  "Repositories": [
    {
      "Repository URL": "https://github.com/user/repo.git",
      "Base Path": "repos/my-repo",
      "Tag": "v2.1.0",
      "Skip LFS": false
    }
  ]
}
```

**Simple Array Format (Legacy Support):**
```json
[
  {
    "Repository URL": "https://github.com/user/repo.git",
    "Base Path": "repos/my-repo",
    "Dependency Resolution": "SemVer",
    "Version": "2.*"
  }
]
```

#### Configuration Fields

**Common Fields:**
- **Repository URL** (required): Git repository URL (HTTPS or SSH)
- **Base Path** (required): Local directory checkout path (relative or absolute)
- **Dependency Resolution** (optional): "SemVer" (recommended) or "Agnostic" (default)
- **Skip LFS** (optional): Skip Git LFS downloads for this repository
- **Dependency File Path** (optional): Custom subdirectory for dependency file
- **Dependency File Name** (optional): Custom name for dependency file

**SemVer Mode Fields:**
- **Version** (required): Semantic version requirement (e.g., "2.1.0", "2.1.*", "2.*")
- **Version Regex** (optional): Custom regex pattern for version extraction from tags (default: `^v?(\\d+)\\.(\\d+)\\.(\\d+)$`)

**Agnostic Mode Fields:**
- **Tag** (required): Git tag to checkout (e.g., "v2.1.0")

**Post-Checkout Script Fields:**
- **Post-Checkout Script File Name** (optional): PowerShell script to execute after checkout
- **Post-Checkout Script File Path** (optional): Subdirectory where script is located

#### git_credentials.json

Maps hostnames to SSH key file paths. The key format depends on your platform:

**Windows** (PuTTY `.ppk` format):

```json
{
  "github.com": "C:\\Users\\username\\.ssh\\github_key.ppk",
  "gitlab.com": "C:\\Users\\username\\.ssh\\gitlab_key.ppk",
  "ssh://git.internal.corp": "C:\\keys\\internal_key.ppk"
}
```

**macOS/Linux** (OpenSSH format):

```json
{
  "github.com": "/home/username/.ssh/id_ed25519",
  "gitlab.com": "/home/username/.ssh/gitlab_rsa",
  "ssh://git.internal.corp": "/home/username/.ssh/internal_key"
}
```

### Examples

#### Example 1: SemVer Mode with Floating Versions

```json
[
  {
    "Repository URL": "https://github.com/microsoft/terminal.git",
    "Base Path": "repos/windows-terminal",
    "Dependency Resolution": "SemVer",
    "Version": "1.19.*"
  },
  {
    "Repository URL": "https://github.com/PowerShell/PowerShell.git",
    "Base Path": "repos/powershell",
    "Dependency Resolution": "SemVer",
    "Version": "7.*",
    "Skip LFS": true
  }
]
```

#### Example 2: Agnostic Mode with Explicit Tags

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

#### Example 3: Mixed Mode Usage

```json
[
  {
    "Repository URL": "https://github.com/org/modern-lib.git",
    "Base Path": "libs/modern",
    "Dependency Resolution": "SemVer",
    "Version": "3.*"
  },
  {
    "Repository URL": "https://github.com/org/legacy-lib.git",
    "Base Path": "libs/legacy",
    "Tag": "release-2024-01"
  }
]
```

## Advanced Usage (Recursive Mode)

### Overview

**When Recursive Mode is enabled (Default)** the script automatically discovers and processes nested dependencies. After checking out each repository, it looks for a dependency file (dependencies.json if not specified differently upon script execution) within the root folder of that repository and processes it recursively, with intelligent handling of shared dependencies.

### Controlling Recursive Mode

```powershell
# Default behavior (recursive mode enabled with intelligent tag sorting)
.\RepoHerd.ps1

# Disable recursive mode for simple single-file processing
.\RepoHerd.ps1 -DisableRecursion

# Customize recursive behavior
.\RepoHerd.ps1 -MaxDepth 10

# Use strict compatibility mode for Agnostic mode repositories
.\RepoHerd.ps1 -ApiCompatibility Strict

# Disable post-checkout scripts
.\RepoHerd.ps1 -DisablePostCheckoutScripts
```

### Recursion and Discovering Common Dependencies

When recursive mode processes nested dependencies, a common scenario emerges: **the same repository is required by multiple projects with potentially different version requirements**. This creates the fundamental challenge that the script's dependency resolution system is designed to solve.

#### The Challenge: Conflicting Dependency Requirements

Consider this scenario:

1. **ProjectA** requires `LibraryX` at version `v2.1.0` (or `2.1.*` in SemVer mode)
2. **ProjectB** also requires `LibraryX` but at version `v2.0.5` (or `2.0.*` in SemVer mode)
3. Both projects expect to work with `LibraryX`, but they're requesting different versions

When the script encounters `LibraryX` for the second time, it faces a critical decision: **which version should be checked out to satisfy both callers?**

#### Practical Example

```
Main Project Dependencies:
├── ProjectA (requires LibraryX v2.1.0 or 2.1.*)
└── ProjectB (requires LibraryX v2.0.5 or 2.0.*)
```

When processing recursively:
1. **Round 1**: Processes main dependencies → clones ProjectA and ProjectB
2. **Round 2**:
   - Processes ProjectA's dependencies → clones LibraryX at appropriate version
   - Processes ProjectB's dependencies → **discovers LibraryX already exists!**

At this point, the script must determine:
- Are the versions compatible?
- If compatible, which version should be used?
- How do we ensure both ProjectA and ProjectB continue to work?

## Dependency Resolution Modes

RepoHerd provides two powerful approaches to solve the dependency resolution problem:

1. **SemVer Mode**: Automatically resolves compatible versions based on Semantic Versioning 2.0.0 rules with floating version support
2. **Agnostic Mode**: Uses explicit "API Compatible Tags" lists with intelligent intersection/union algorithms

Both modes use sophisticated conflict resolution algorithms that consider the compatibility requirements of all callers and select the optimal version that satisfies everyone's needs.

The two dependency resolution modes can be mixed within the same dependency tree.

For detailed documentation on each mode, see:
- **[SemVer Mode](docs/semver_mode.md)** -- Automatic version resolution using Semantic Versioning 2.0.0 rules with floating version patterns for zero-maintenance dependency updates.
- **[Agnostic Mode](docs/agnostic_mode.md)** -- Tag-based resolution using explicit API Compatible Tags lists for maximum control over version compatibility.
- **[Choosing Between Modes](docs/choosing_modes.md)** -- Guidance on when to use each mode, with best practices for mixed-mode dependency trees.

## Custom Dependency Files

Per-repository custom dependency file paths and names provide flexibility for different project structures and naming conventions. For details, see [Custom Dependency Files](docs/custom_dependency_files.md).

## Post-Checkout Scripts

Post-checkout scripts are PowerShell scripts that execute automatically after a repository is successfully checked out, enabling integration with external dependency management systems. For details, see [Post-Checkout Scripts](docs/post_checkout_scripts.md).

## Security Best Practices

Guidelines for protecting credentials, SSH keys, and managing post-checkout script security. For details, see [Security Best Practices](docs/security_best_practices.md).

## SSH Setup

Platform-specific SSH configuration for Windows (PuTTY/Pageant) and macOS/Linux (OpenSSH). For details, see [SSH Setup](docs/ssh_setup.md).

## Troubleshooting

Common issues and solutions, debug mode instructions, and enhanced error context. For details, see [Troubleshooting](docs/troubleshooting.md).

## Version Migration Guide

Step-by-step instructions for upgrading between RepoHerd versions (6.2.x to 7.0.0, 7.0.0 to 7.1.0). For details, see [Version Migration Guide](docs/version_migration.md).

## Advanced Topics

Links to in-depth guides on migrating dependency trees to RepoHerd and tool comparisons. For details, see [Advanced Topics](docs/advanced_topics.md).

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Authors

Originally developed by LS Instruments AG for managing complex multi-repository projects.

Co-authored with Claude (Anthropic) through collaborative development.
