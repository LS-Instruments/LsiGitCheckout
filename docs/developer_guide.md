# Developer Guide

This guide covers setting up a development environment for contributing to RepoHerd.

## Prerequisites

### PowerShell 7.6 LTS

RepoHerd requires PowerShell 7.6 LTS or later. PowerShell 7.x installs side-by-side with Windows PowerShell 5.1 — it will not replace or interfere with the built-in version.

**Windows:**

```powershell
winget install Microsoft.PowerShell
```

Or download the MSI installer from [PowerShell GitHub Releases](https://github.com/PowerShell/PowerShell/releases).

**macOS:**

```bash
brew install --cask powershell
```

**Linux (Ubuntu/Debian):**

```bash
# Register Microsoft package repository
wget -q https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb

# Install PowerShell
sudo apt-get update
sudo apt-get install -y powershell
```

For other Linux distributions, see the [official installation docs](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux).

**Verify installation:**

```bash
pwsh --version
# Expected: PowerShell 7.6.x
```

### Git

Git 2.x or later must be installed and available on PATH.

**Windows:**

```cmd
winget install Git.Git
```

Or download from [git-scm.com](https://git-scm.com/download/win). Git for Windows bundles Git Credential Manager for HTTPS authentication.

**macOS:**

```bash
# Via Xcode CLI tools (may already be installed)
xcode-select --install

# Or via Homebrew
brew install git
```

**Linux (Ubuntu/Debian):**

```bash
sudo apt-get install git
```

**Verify:**

```bash
git --version
```

### Git Credential Manager (for HTTPS repos)

Git Credential Manager (GCM) handles HTTPS authentication (OAuth browser flows for GitHub, Azure DevOps, etc.). On Windows it is bundled with Git for Windows. On macOS/Linux it must be installed separately.

**macOS:**

```bash
brew install git-credential-manager
git-credential-manager configure
```

**Linux:**

Download the latest `.deb` or `.rpm` from the [GCM releases page](https://github.com/git-credential-manager/git-credential-manager/releases), then:

```bash
sudo dpkg -i gcm-linux_amd64.deb   # Debian/Ubuntu
git-credential-manager configure
```

Alternatively, use a Personal Access Token (PAT) as the password when git prompts for HTTPS credentials.

### SSH Setup (for SSH repos)

SSH is only needed if your repositories use SSH URLs (`git@host:...` or `ssh://...`).

**Windows — PuTTY/plink:**

RepoHerd uses PuTTY on Windows because OpenSSH has known issues with submodule SSH inheritance (see [CLAUDE.md](../CLAUDE.md) for details).

1. Install PuTTY suite from [putty.org](https://www.putty.org/) — ensure `plink.exe` and `pageant.exe` are on PATH
2. Convert OpenSSH keys to `.ppk` format using PuTTYgen
3. Start Pageant and add your key
4. Create `git_credentials.json` mapping hostnames to `.ppk` key paths:

   ```json
   { "github.com": "C:\\Users\\username\\.ssh\\github_key.ppk" }
   ```

**macOS/Linux — OpenSSH:**

OpenSSH is bundled with the OS. RepoHerd uses `GIT_SSH_COMMAND` to specify keys per-host.

1. Generate or use existing OpenSSH keys (`~/.ssh/id_ed25519`, etc.)
2. Set permissions: `chmod 600 ~/.ssh/id_ed25519`
3. For passphrase-protected keys, load into ssh-agent before running:

   ```bash
   eval "$(ssh-agent -s)"
   ssh-add ~/.ssh/id_ed25519
   ```

4. Create `git_credentials.json` mapping hostnames to key paths:

   ```json
   { "github.com": "/home/username/.ssh/id_ed25519" }
   ```

5. If converting from PuTTY `.ppk` keys, use PuTTYgen on Windows (**Conversions → Export OpenSSH key (force new file format)**) or:

   ```bash
   # Requires: brew install putty (macOS) or apt install putty-tools (Linux)
   puttygen key.ppk -O private-openssh -o key_openssh
   chmod 600 key_openssh
   ```

### GitHub CLI (`gh`)

The GitHub CLI is used to create and manage issues directly from the command line.

**macOS:**

```bash
brew install gh
```

**Windows:**

```cmd
winget install GitHub.cli
```

**Linux (Ubuntu/Debian):**

```bash
sudo apt-get install gh
```

**Authenticate after install:**

```bash
gh auth login
```

Choose **GitHub.com**, **HTTPS**, and **Login with a web browser**. This opens a browser for OAuth — once approved, `gh` stores the token securely.

**Verify:**

```bash
gh auth status
```

### Pester 5.x (Test Framework)

Install the Pester module inside PowerShell 7:

```powershell
pwsh -Command "Install-Module Pester -Force -MinimumVersion 5.0 -Scope CurrentUser"
```

Verify:

```powershell
pwsh -Command "Get-Module Pester -ListAvailable"
```

## Editor Setup

### VS Code with PowerShell Extension

1. Install [Visual Studio Code](https://code.visualstudio.com/).
1. Open the workspace file — this will prompt you to install the recommended PowerShell extension: `code RepoHerd.code-workspace`
1. If not prompted automatically, install the **PowerShell** extension (`ms-vscode.powershell`) from the Extensions sidebar.

> **Important:** Always open the project via the `.code-workspace` file, not the folder directly. The workspace file contains terminal profiles, debug configurations, and extension recommendations.

### What the Workspace Configures

The `RepoHerd.code-workspace` file provides:

- **Terminal profiles**: defaults to `pwsh` on all platforms (PowerShell 7.x, not Windows PowerShell 5.1)
- **File associations**: `.ps1`, `.psm1`, `.psd1` mapped to PowerShell language mode
- **Editor settings**: 4-space indentation for PowerShell files
- **Launch configurations**: pre-configured debug profiles for tests and script execution (see [Debugging](#debugging))
- **Extension recommendations**: prompts to install the PowerShell extension

## Project Structure

```text
RepoHerd.ps1       # Script wrapper (~70 lines), delegates to Invoke-RepoHerd
RepoHerd.psm1      # Module (~2750 lines) — all functions including Invoke-RepoHerd
RepoHerd.psd1      # Module manifest — metadata, exported functions
tests/
  RepoHerd.Unit.Tests.ps1         # 65 unit tests (no network required)
  RepoHerd.Integration.Tests.ps1  # 18 integration tests (needs network)
  semver-basic/dependencies.json        # Test configs in subdirectories
  agnostic-recursive/dependencies.json  # (16 subdirectories total)
  api-incompatibility-*/dependencies.json
```

The script wrapper imports the module and delegates to `Invoke-RepoHerd`, which is the main entry point. All functions live in the `.psm1` file using `$script:` scoped variables for shared state.

## Running Tests

### Unit Tests

Fast tests covering pure and near-pure functions. No network or git operations required.

```powershell
pwsh -Command "Invoke-Pester ./tests/RepoHerd.Unit.Tests.ps1 -Output Detailed"
```

Covers: `ConvertTo-VersionPattern`, `Test-SemVerCompatibility`, `Get-CompatibleVersionsForPattern`, `Select-VersionFromIntersection`, `Get-SemVersionIntersection`, `Format-SemVersion`, `Get-TagIntersection`, `Get-HostnameFromUrl`, `Test-DependencyConfiguration`, `Get-AbsoluteBasePath`, `Export-CheckoutResults`.

### Integration Tests

Runs `RepoHerd.ps1` against 18 test cases (16 configs with recursive mode, plus a non-recursive SemVer regression test) with actual git clones. Validates exit codes, structured JSON output (schema, metadata, summary), and **the exact tag checked out for each repository**. Requires network access to GitHub.

Each test starts from a clean state — cloned test repositories are removed between runs. Tests use `-OutputFile` to generate JSON results and validate the output against expected per-repo tags.

```powershell
pwsh -Command "Invoke-Pester ./tests/RepoHerd.Integration.Tests.ps1 -Output Detailed"
```

> **Note:** Integration tests take ~3 minutes because they perform actual git clones. No `-DryRun` is used so the full recursive checkout flow is exercised.

> **Important:** Integration tests depend on 5 external GitHub test repos. Do not modify those repos without updating the test expectations. See [testing_infrastructure.md](testing_infrastructure.md) for full details.

### All Tests

```powershell
pwsh -Command "Invoke-Pester ./tests/ -Output Detailed"
```

### Running from VS Code

The workspace includes pre-configured launch profiles accessible from the **Run and Debug** sidebar (Ctrl+Shift+D / Cmd+Shift+D):

| Profile | Description |
|---------|-------------|
| **Run Unit Tests** | Runs unit tests with debugger attached |
| **Run Integration Tests** | Runs integration tests with debugger attached |
| **Run All Tests** | Runs both unit and integration tests |
| **Run Script (DryRun - SemVer)** | Runs `RepoHerd.ps1 -DryRun` against `tests/semver-basic/dependencies.json` |
| **Run Script (Custom Config)** | Prompts for a config file path, then runs with `-DryRun` |

Select a profile and press **F5** to launch. Breakpoints set in `.psm1` or `.ps1` files will be hit.

## Debugging

### VS Code Breakpoints

1. Open the workspace: `code RepoHerd.code-workspace`
2. Set breakpoints by clicking the gutter in any `.ps1` or `.psm1` file
3. Select a launch profile from the Run and Debug sidebar
4. Press **F5** — the debugger will stop at breakpoints
5. Use the **Debug Console** to inspect variables and module state (e.g., `$script:RepositoryDictionary`)

All launch profiles use `createTemporaryIntegratedConsole` to ensure a clean PowerShell session for each run, avoiding stale module state between debug sessions.

### Command-Line Debugging

**Debug logging:** The `-EnableDebug` flag writes a timestamped log file:

```powershell
pwsh -File ./RepoHerd.ps1 -InputFile tests/semver-basic/dependencies.json -EnableDebug
# Creates: debug_log_YYYYMMDDHHMM.txt
```

**Error context:** The `-EnableErrorContext` flag adds stack traces and line numbers to error output:

```powershell
pwsh -File ./RepoHerd.ps1 -InputFile tests/semver-basic/dependencies.json -EnableErrorContext
```

**Structured JSON output:** The `-OutputFile` flag writes machine-readable results:

```powershell
pwsh -File ./RepoHerd.ps1 -InputFile tests/semver-basic/dependencies.json -OutputFile result.json
```

**Interactive breakpoints** (terminal-based, no VS Code required):

```powershell
pwsh
Set-PSBreakpoint -Script ./RepoHerd.psm1 -Command Invoke-DependencyFile
./RepoHerd.ps1 -InputFile tests/semver-basic/dependencies.json
```

## Manual Testing

Run any of the test configurations individually:

```powershell
# SemVer mode
pwsh -File ./RepoHerd.ps1 -InputFile tests/semver-basic/dependencies.json

# SemVer floating versions
pwsh -File ./RepoHerd.ps1 -InputFile tests/semver-floating-versions/dependencies.json

# Agnostic mode with recursive dependencies
pwsh -File ./RepoHerd.ps1 -InputFile tests/agnostic-recursive/dependencies.json

# Expected failure — SemVer API incompatibility (exit code 1)
pwsh -File ./RepoHerd.ps1 -InputFile tests/api-incompatibility-semver/dependencies.json

# Expected failure — Agnostic Strict mode (exit code 1)
pwsh -File ./RepoHerd.ps1 -InputFile tests/api-incompatibility-agnostic/dependencies.json -ApiCompatibility Strict
```

See [testing_infrastructure.md](testing_infrastructure.md) for the full test architecture, per-test descriptions, external repo dependencies, and constraints.

## Coding Conventions

See [CLAUDE.md](../CLAUDE.md) for the full coding conventions. Key points:

- **PowerShell 7.6 LTS** — use `??` null-coalescing, `-AsHashtable` for JSON, etc.
- **Function names**: `Verb-Noun` PascalCase using approved PowerShell verbs (e.g., `Test-GitInstalled`, `ConvertTo-VersionPattern`)
- **Logging**: always use `Write-Log` with appropriate level, never raw `Write-Host`
- **Error handling**: wrap operations in `Invoke-WithErrorContext -Context "description" -ScriptBlock { ... }`
- **Module state**: use `$script:` prefix for shared variables, initialize via `Initialize-RepoHerd`
- **CHANGELOG**: update `CHANGELOG.md` following [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format

## Release Process

### Overview

Releases are published to both GitHub (tagged release) and PowerShell Gallery. The process is driven by the user confirming a version number to Claude Code, which then handles version bumps, tagging, and the GitHub release. The final `Publish-Module` command is run manually by the user because it requires the API key.

### PowerShell Gallery setup

- A PowerShell Gallery account at [powershellgallery.com](https://www.powershellgallery.com/)
- An API key: go to Account > API Keys > Create. Store it securely; you'll paste it once during publishing.

### Step-by-step

1. **Confirm the version number** with the user. Follow SemVer:
   - Patch (x.y.Z): bug fixes, no API changes
   - Minor (x.Y.0): new features, backwards-compatible
   - Major (X.0.0): breaking changes

2. **Update version in all locations:**
   - `RepoHerd.psd1` — `ModuleVersion` and `ReleaseNotes`
   - `RepoHerd.psm1` — `$script:Version` and header comment
   - `RepoHerd.ps1` — `.NOTES` version
   - `tests/RepoHerd.Unit.Tests.ps1` — version assertion
   - `tests/RepoHerd.Integration.Tests.ps1` — version assertion
   - `CHANGELOG.md` — new entry at the top
   - `CLAUDE.md` — version in Project Overview

3. **Run all tests** (unit + integration) to confirm everything passes.

4. **Commit and push** the version bump.

5. **Create a GitHub release** using `gh release create vX.Y.Z`.

6. **Validate the manifest:**

   ```powershell
   Test-ModuleManifest ./RepoHerd.psd1
   ```

7. **Publish to PowerShell Gallery** (run by the user):

   ```powershell
   Publish-Module -Path . -NuGetApiKey "YOUR_API_KEY"
   ```

8. **Verify the upload:**

   ```powershell
   Find-Module RepoHerd
   ```

9. **Test the installed module end-to-end:**

   ```powershell
   Update-Module RepoHerd -Force
   Import-Module RepoHerd -Force
   cd tests/semver-basic
   Invoke-RepoHerd
   ```

   Confirm the version in the output matches the release.

### Important notes

- `Publish-Module` is irreversible: you cannot overwrite a version, only publish a new one. Double-check the version before publishing.
- The Gallery web UI can take a few minutes to update the "current version" label, but `Find-Module` and `Install-Module` pick up the new version immediately.
- Always test the full `Install-Module` -> `Invoke-RepoHerd` round-trip before announcing.
