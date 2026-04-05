# CLAUDE.md — RepoHerd

## Project Overview

PowerShell-based dependency management tool that checks out multiple Git repositories to specified versions. Module architecture: `RepoHerd.psm1` (functions + `Invoke-RepoHerd` entry point) + `RepoHerd.ps1` (thin wrapper for script-based usage). Version 9.1.0, published on PowerShell Gallery, by LS Instruments AG.

## Running the Tool

```powershell
# Via PowerShell Gallery (recommended)
Install-Module RepoHerd
Invoke-RepoHerd                                    # defaults to dependencies.json in CWD
Invoke-RepoHerd -InputFile "path/to/deps.json"     # custom config
Invoke-RepoHerd -DryRun                             # preview without executing
Invoke-RepoHerd -EnableDebug -EnableErrorContext     # full debug output
Invoke-RepoHerd -OutputFile result.json             # structured JSON output

# Via script (manual download / cloned repo)
.\RepoHerd.ps1                                     # defaults to dependencies.json in script dir
.\RepoHerd.ps1 -InputFile "path/to/deps.json"
```

Key parameters: `-InputFile`, `-CredentialsFile`, `-DryRun`, `-EnableDebug`, `-DisableRecursion`, `-MaxDepth` (default 5), `-ApiCompatibility` (Strict|Permissive), `-DisablePostCheckoutScripts`, `-EnableErrorContext`, `-OutputFile` (structured JSON results)

## Testing

### Automated Tests (Pester 5.x)

```powershell
# Install Pester if needed
Install-Module Pester -Force -MinimumVersion 5.0

# Unit tests — fast, no network required
Invoke-Pester ./tests/RepoHerd.Unit.Tests.ps1 -Output Detailed

# Integration tests — requires network access to GitHub test repos
Invoke-Pester ./tests/RepoHerd.Integration.Tests.ps1 -Output Detailed
```

### Manual Testing

Test configs in `tests/` are organized in subdirectories, each containing a `dependencies.json`:

```powershell
.\RepoHerd.ps1 -InputFile tests/semver-basic/dependencies.json
.\RepoHerd.ps1 -InputFile tests/agnostic-recursive/dependencies.json
.\RepoHerd.ps1 -InputFile tests/api-incompatibility-agnostic/dependencies.json -ApiCompatibility Strict
```

There are 17 test cases across 16 test configs covering SemVer, Agnostic, API incompatibility (Permissive + Strict), custom paths, post-checkout scripts, and recursive dependencies. See `docs/testing_infrastructure.md` for the full test architecture.

**Important**: Integration tests depend on 5 external GitHub test repos. Modifying those repos will break the tests. See `docs/testing_infrastructure.md` for details.

## Architecture

- **Module**: `RepoHerd.psm1` — all function definitions (~36 functions) including `Invoke-RepoHerd` (main entry point)
- **Script wrapper**: `RepoHerd.ps1` — thin wrapper that imports the module and delegates to `Invoke-RepoHerd` (defaults to script directory for paths)
- **Manifest**: `RepoHerd.psd1` — module metadata, exported functions
- **Two dependency resolution modes**: SemVer (recommended, automatic version resolution) and Agnostic (explicit tag-based)
- **Configuration**: JSON files — `dependencies.json` for repos, `git_credentials.json` for SSH keys
- **Recursive processing**: walks dependency trees with conflict detection, max depth configurable
- **SSH**: Cross-platform — PuTTY/Pageant on Windows (`.ppk`), OpenSSH on macOS/Linux
- **Post-checkout scripts**: optional PowerShell scripts run after successful checkouts
- **Structured output**: `-OutputFile` writes JSON (schema 1.0.0) with per-repo results, post-checkout script tracking, and `requestedBy` parent chain

## Design Decisions

- **API compatibility in Agnostic mode**: In **Permissive** mode (default), version/tag conflicts during recursive checkout are resolved silently by picking the best available tag. In **Strict** mode, any tag mismatch is an error. This is controlled by `-ApiCompatibility` (CLI) or `"API Compatibility"` (per-repo JSON field).
- **SemVer major version conflicts**: SemVer mode always rejects cross-major version incompatibilities regardless of the API compatibility setting, since different major versions imply breaking API changes by SemVer convention.
- **SSH transport is platform-specific**: On Windows, PuTTY/plink with `.ppk` keys and Pageant is used. On macOS/Linux, OpenSSH is used via `GIT_SSH_COMMAND="ssh -i <key> -o IdentitiesOnly=yes"`, which specifies keys per-host without requiring `~/.ssh/config` changes or a running `ssh-agent`. **Why PuTTY on Windows**: We attempted OpenSSH on Windows but hit a specific failure: when a parent repository is cloned via HTTPS and has submodules accessed via SSH, the `git submodule update` process on Windows did not reliably inherit `GIT_SSH_COMMAND`/`GIT_SSH` environment variables, causing SSH submodule fetches to fail silently or hang. PuTTY/plink with Pageant (which manages keys via a system-tray agent process rather than environment variables) was the only reliable workaround. This issue was not reproduced on macOS/Linux, where environment variable inheritance across git subprocess forks works correctly.

## Coding Conventions

- **PowerShell 7.6 LTS** required (`#Requires -Version 7.6`)
- **Function names**: PascalCase Verb-Noun using approved PowerShell verbs (e.g., `Test-GitInstalled`, `ConvertTo-VersionPattern`, `Get-SemVersionIntersection`)
- **Documentation**: comment-based help blocks (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`) on all functions
- **Logging**: use `Write-Log` with levels: Info, Warning, Error, Debug, Verbose
- **Error handling**: wrap operations in `Invoke-WithErrorContext -Context "description" -ScriptBlock { ... }`
- **Module state**: `$script:` prefix for module-scoped variables (e.g., `$script:RepositoryDictionary`, `$script:DryRun`)
- **Initialization**: `Initialize-RepoHerd` sets module state; called internally by `Invoke-RepoHerd`
- **Publishing**: before any `Publish-Module`, always test the full `Install-Module` -> `Invoke-RepoHerd` round-trip
- **CHANGELOG**: follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format with SemVer versioning

## Project Structure

```
RepoHerd.ps1       # Script wrapper (~70 lines), delegates to Invoke-RepoHerd
RepoHerd.psm1      # Module with all functions including Invoke-RepoHerd (~2750 lines)
RepoHerd.psd1      # Module manifest
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
  RepoHerd.Unit.Tests.ps1         # 65 unit tests (no network)
  RepoHerd.Integration.Tests.ps1  # 18 integration tests (needs network)
  semver-basic/dependencies.json        # Test configs in subdirectories
  agnostic-recursive/dependencies.json  # (16 subdirectories total)
  api-incompatibility-*/dependencies.json
tasks/
  BACKLOG.md               # Planned features, enhancements, bugs
  DONE.md                  # All completed GitHub issues with summaries
```

## Key Domain Concepts

- **SemVer mode**: uses `"Dependency Resolution": "SemVer"` and `"Version": "x.y.z"` fields. Supports floating versions (`"2.1.*"`, `"2.*"`)
- **Agnostic mode**: uses `"Tag"` and `"API Compatible Tags"` fields for explicit version control
- **Repository Dictionary** (`$script:RepositoryDictionary`): central tracking structure for all repositories being processed across the dependency tree
- **Immutable config**: once a repo's resolution mode is set, it cannot change during processing

## Task & Issue Workflow

Features, bugs, and enhancements are tracked in `tasks/BACKLOG.md` (planned) and `tasks/DONE.md` (completed), mirroring GitHub issues.

**When the user requests a new feature or reports a bug:**

1. Draft a properly formatted issue description (title + body in GitHub markdown)
2. Ask the user for confirmation before creating
3. Create the issue on GitHub using `gh issue create`
4. Update `tasks/BACKLOG.md` with the issue number and description
5. When implemented, move the entry from `BACKLOG.md` to `DONE.md` with a summary

**When committing a fix or feature**, reference the GitHub issue in the commit message (`Fixes #N` or `Refs #N`)
