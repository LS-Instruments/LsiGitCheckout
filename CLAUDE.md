# CLAUDE.md — LsiGitCheckout

## Project Overview

PowerShell-based dependency management tool that checks out multiple Git repositories to specified versions. Module architecture: `LsiGitCheckout.psm1` (functions) + `LsiGitCheckout.ps1` (entry point). Version 8.1.0, by LS Instruments AG.

## Running the Tool

```powershell
.\LsiGitCheckout.ps1                                    # defaults to dependencies.json
.\LsiGitCheckout.ps1 -InputFile "path/to/deps.json"     # custom config
.\LsiGitCheckout.ps1 -DryRun                             # preview without executing
.\LsiGitCheckout.ps1 -EnableDebug -EnableErrorContext     # full debug output
.\LsiGitCheckout.ps1 -OutputFile result.json             # structured JSON output
```

Key parameters: `-InputFile`, `-CredentialsFile`, `-DryRun`, `-EnableDebug`, `-DisableRecursion`, `-MaxDepth` (default 5), `-ApiCompatibility` (Strict|Permissive), `-DisablePostCheckoutScripts`, `-EnableErrorContext`, `-OutputFile` (structured JSON results)

## Testing

### Automated Tests (Pester 5.x)

```powershell
# Install Pester if needed
Install-Module Pester -Force -MinimumVersion 5.0

# Unit tests — fast, no network required
Invoke-Pester ./tests/LsiGitCheckout.Unit.Tests.ps1 -Output Detailed

# Integration tests — requires network access to GitHub test repos
Invoke-Pester ./tests/LsiGitCheckout.Integration.Tests.ps1 -Output Detailed
```

### Manual Testing

Test configs in `tests/` are organized in subdirectories, each containing a `dependencies.json`:

```powershell
.\LsiGitCheckout.ps1 -InputFile tests/semver-basic/dependencies.json
.\LsiGitCheckout.ps1 -InputFile tests/agnostic-recursive/dependencies.json
.\LsiGitCheckout.ps1 -InputFile tests/api-incompatibility-agnostic/dependencies.json -ApiCompatibility Strict
```

There are 17 test cases across 16 test configs covering SemVer, Agnostic, API incompatibility (Permissive + Strict), custom paths, post-checkout scripts, and recursive dependencies. See `docs/testing_infrastructure.md` for the full test architecture.

**Important**: Integration tests depend on 5 external GitHub test repos. Modifying those repos will break the tests. See `docs/testing_infrastructure.md` for details.

## Architecture

- **Module**: `LsiGitCheckout.psm1` — all function definitions (~35 functions)
- **Entry point**: `LsiGitCheckout.ps1` — param block, module import, initialization, main execution
- **Manifest**: `LsiGitCheckout.psd1` — module metadata, exported functions
- **Two dependency resolution modes**: SemVer (recommended, automatic version resolution) and Agnostic (explicit tag-based)
- **Configuration**: JSON files — `dependencies.json` for repos, `git_credentials.json` for SSH keys
- **Recursive processing**: walks dependency trees with conflict detection, max depth configurable
- **SSH**: PuTTY/Pageant integration for authentication (`.ppk` key format)
- **Post-checkout scripts**: optional PowerShell scripts run after successful checkouts
- **Structured output**: `-OutputFile` writes JSON (schema 1.0.0) with per-repo results, post-checkout script tracking, and `requestedBy` parent chain

## Design Decisions

- **API compatibility in Agnostic mode**: In **Permissive** mode (default), version/tag conflicts during recursive checkout are resolved silently by picking the best available tag. In **Strict** mode, any tag mismatch is an error. This is controlled by `-ApiCompatibility` (CLI) or `"API Compatibility"` (per-repo JSON field).
- **SemVer major version conflicts**: SemVer mode always rejects cross-major version incompatibilities regardless of the API compatibility setting, since different major versions imply breaking API changes by SemVer convention.
- **PuTTY/Pageant on Windows (not OpenSSH)**: We attempted to use OpenSSH on Windows but encountered persistent issues — possibly related to Git submodule operations not properly inheriting SSH settings (exact root cause not confirmed in commit history). PuTTY with `.ppk` keys and Pageant was the only reliable solution on Windows. On Mac/Linux, OpenSSH (as bundled with Git) should work natively and is a future TODO.

## Coding Conventions

- **PowerShell 7.6 LTS** required (`#Requires -Version 7.6`)
- **Function names**: PascalCase Verb-Noun (e.g., `Test-GitInstalled`, `Parse-VersionPattern`, `Get-SemVersionIntersection`)
- **Documentation**: comment-based help blocks (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`) on all functions
- **Logging**: use `Write-Log` with levels: Info, Warning, Error, Debug, Verbose
- **Error handling**: wrap operations in `Invoke-WithErrorContext -Context "description" -ScriptBlock { ... }`
- **Module state**: `$script:` prefix for module-scoped variables (e.g., `$script:RepositoryDictionary`, `$script:DryRun`)
- **Initialization**: call `Initialize-LsiGitCheckout` to set module state from entry point parameters
- **CHANGELOG**: follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format with SemVer versioning

## Project Structure

```
LsiGitCheckout.ps1       # Entry point script (~230 lines)
LsiGitCheckout.psm1      # Module with all functions (~2520 lines)
LsiGitCheckout.psd1      # Module manifest
CHANGELOG.md             # Version history
README.md                # Comprehensive user documentation
docs/
  developer_guide.md            # Developer setup, testing, debugging
  comparison_guide.md            # vs Google Repo Tool
  migration_guide.md             # Migration strategies
  test_repositories_reference.md # Test repo tags and dependency data
  testing_infrastructure.md      # Test architecture, constraints, and categories
examples/                # 7 example dependency JSON configs
tests/                   # Pester test files + 16 test config subdirectories
  LsiGitCheckout.Unit.Tests.ps1         # 60 unit tests (no network)
  LsiGitCheckout.Integration.Tests.ps1  # 17 integration tests (needs network)
  semver-basic/dependencies.json        # Test configs in subdirectories
  agnostic-recursive/dependencies.json  # (16 subdirectories total)
  api-incompatibility-*/dependencies.json
```

## Key Domain Concepts

- **SemVer mode**: uses `"Dependency Resolution": "SemVer"` and `"Version": "x.y.z"` fields. Supports floating versions (`"2.1.*"`, `"2.*"`)
- **Agnostic mode**: uses `"Tag"` and `"API Compatible Tags"` fields for explicit version control
- **Repository Dictionary** (`$script:RepositoryDictionary`): central tracking structure for all repositories being processed across the dependency tree
- **Immutable config**: once a repo's resolution mode is set, it cannot change during processing
