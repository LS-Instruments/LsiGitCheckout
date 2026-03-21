# Developer Guide

This guide covers setting up a development environment for contributing to LsiGitCheckout.

## Prerequisites

### PowerShell 7.6 LTS

LsiGitCheckout requires PowerShell 7.6 LTS or later. PowerShell 7.x installs side-by-side with Windows PowerShell 5.1 — it will not replace or interfere with the built-in version.

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

LsiGitCheckout uses PuTTY on Windows because OpenSSH has known issues with submodule SSH inheritance (see [CLAUDE.md](../CLAUDE.md) for details).

1. Install PuTTY suite from [putty.org](https://www.putty.org/) — ensure `plink.exe` and `pageant.exe` are on PATH
2. Convert OpenSSH keys to `.ppk` format using PuTTYgen
3. Start Pageant and add your key
4. Create `git_credentials.json` mapping hostnames to `.ppk` key paths:

   ```json
   { "github.com": "C:\\Users\\username\\.ssh\\github_key.ppk" }
   ```

**macOS/Linux — OpenSSH:**

OpenSSH is bundled with the OS. LsiGitCheckout uses `GIT_SSH_COMMAND` to specify keys per-host.

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
1. Open the workspace file — this will prompt you to install the recommended PowerShell extension: `code LsiGitCheckout.code-workspace`
1. If not prompted automatically, install the **PowerShell** extension (`ms-vscode.powershell`) from the Extensions sidebar.

> **Important:** Always open the project via the `.code-workspace` file, not the folder directly. The workspace file contains terminal profiles, debug configurations, and extension recommendations.

### What the Workspace Configures

The `LsiGitCheckout.code-workspace` file provides:

- **Terminal profiles**: defaults to `pwsh` on all platforms (PowerShell 7.x, not Windows PowerShell 5.1)
- **File associations**: `.ps1`, `.psm1`, `.psd1` mapped to PowerShell language mode
- **Editor settings**: 4-space indentation for PowerShell files
- **Launch configurations**: pre-configured debug profiles for tests and script execution (see [Debugging](#debugging))
- **Extension recommendations**: prompts to install the PowerShell extension

## Project Structure

```text
LsiGitCheckout.ps1       # Entry point (~260 lines) — params, module import, main flow
LsiGitCheckout.psm1      # Module (~2700 lines) — all function definitions
LsiGitCheckout.psd1      # Module manifest — metadata, exported functions
tests/
  LsiGitCheckout.Unit.Tests.ps1         # 65 unit tests (no network required)
  LsiGitCheckout.Integration.Tests.ps1  # 18 integration tests (needs network)
  semver-basic/dependencies.json        # Test configs in subdirectories
  agnostic-recursive/dependencies.json  # (16 subdirectories total)
  api-incompatibility-*/dependencies.json
```

The entry point script imports the module, calls `Initialize-LsiGitCheckout` to set module state from CLI parameters, then runs the main logic. All functions live in the `.psm1` file using `$script:` scoped variables for shared state.

## Running Tests

### Unit Tests

Fast tests covering pure and near-pure functions. No network or git operations required.

```powershell
pwsh -Command "Invoke-Pester ./tests/LsiGitCheckout.Unit.Tests.ps1 -Output Detailed"
```

Covers: `Parse-VersionPattern`, `Test-SemVerCompatibility`, `Get-CompatibleVersionsForPattern`, `Select-VersionFromIntersection`, `Get-SemVersionIntersection`, `Format-SemVersion`, `Get-TagIntersection`, `Get-HostnameFromUrl`, `Validate-DependencyConfiguration`, `Get-AbsoluteBasePath`, `Export-CheckoutResults`.

### Integration Tests

Runs `LsiGitCheckout.ps1` against 18 test cases (16 configs with recursive mode, plus a non-recursive SemVer regression test) with actual git clones. Validates exit codes, structured JSON output (schema, metadata, summary), and **the exact tag checked out for each repository**. Requires network access to GitHub.

Each test starts from a clean state — cloned test repositories are removed between runs. Tests use `-OutputFile` to generate JSON results and validate the output against expected per-repo tags.

```powershell
pwsh -Command "Invoke-Pester ./tests/LsiGitCheckout.Integration.Tests.ps1 -Output Detailed"
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
| **Run Script (DryRun - SemVer)** | Runs `LsiGitCheckout.ps1 -DryRun` against `tests/semver-basic/dependencies.json` |
| **Run Script (Custom Config)** | Prompts for a config file path, then runs with `-DryRun` |

Select a profile and press **F5** to launch. Breakpoints set in `.psm1` or `.ps1` files will be hit.

## Debugging

### VS Code Breakpoints

1. Open the workspace: `code LsiGitCheckout.code-workspace`
2. Set breakpoints by clicking the gutter in any `.ps1` or `.psm1` file
3. Select a launch profile from the Run and Debug sidebar
4. Press **F5** — the debugger will stop at breakpoints
5. Use the **Debug Console** to inspect variables and module state (e.g., `$script:RepositoryDictionary`)

All launch profiles use `createTemporaryIntegratedConsole` to ensure a clean PowerShell session for each run, avoiding stale module state between debug sessions.

### Command-Line Debugging

**Debug logging:** The `-EnableDebug` flag writes a timestamped log file:

```powershell
pwsh -File ./LsiGitCheckout.ps1 -InputFile tests/semver-basic/dependencies.json -EnableDebug
# Creates: debug_log_YYYYMMDDHHMM.txt
```

**Error context:** The `-EnableErrorContext` flag adds stack traces and line numbers to error output:

```powershell
pwsh -File ./LsiGitCheckout.ps1 -InputFile tests/semver-basic/dependencies.json -EnableErrorContext
```

**Structured JSON output:** The `-OutputFile` flag writes machine-readable results:

```powershell
pwsh -File ./LsiGitCheckout.ps1 -InputFile tests/semver-basic/dependencies.json -OutputFile result.json
```

**Interactive breakpoints** (terminal-based, no VS Code required):

```powershell
pwsh
Set-PSBreakpoint -Script ./LsiGitCheckout.psm1 -Command Process-DependencyFile
./LsiGitCheckout.ps1 -InputFile tests/semver-basic/dependencies.json
```

## Manual Testing

Run any of the test configurations individually:

```powershell
# SemVer mode
pwsh -File ./LsiGitCheckout.ps1 -InputFile tests/semver-basic/dependencies.json

# SemVer floating versions
pwsh -File ./LsiGitCheckout.ps1 -InputFile tests/semver-floating-versions/dependencies.json

# Agnostic mode with recursive dependencies
pwsh -File ./LsiGitCheckout.ps1 -InputFile tests/agnostic-recursive/dependencies.json

# Expected failure — SemVer API incompatibility (exit code 1)
pwsh -File ./LsiGitCheckout.ps1 -InputFile tests/api-incompatibility-semver/dependencies.json

# Expected failure — Agnostic Strict mode (exit code 1)
pwsh -File ./LsiGitCheckout.ps1 -InputFile tests/api-incompatibility-agnostic/dependencies.json -ApiCompatibility Strict
```

See [testing_infrastructure.md](testing_infrastructure.md) for the full test architecture, per-test descriptions, external repo dependencies, and constraints.

## Coding Conventions

See [CLAUDE.md](../CLAUDE.md) for the full coding conventions. Key points:

- **PowerShell 7.6 LTS** — use `??` null-coalescing, `-AsHashtable` for JSON, etc.
- **Function names**: `Verb-Noun` PascalCase (e.g., `Test-GitInstalled`, `Parse-VersionPattern`)
- **Logging**: always use `Write-Log` with appropriate level, never raw `Write-Host`
- **Error handling**: wrap operations in `Invoke-WithErrorContext -Context "description" -ScriptBlock { ... }`
- **Module state**: use `$script:` prefix for shared variables, initialize via `Initialize-LsiGitCheckout`
- **CHANGELOG**: update `CHANGELOG.md` following [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format
