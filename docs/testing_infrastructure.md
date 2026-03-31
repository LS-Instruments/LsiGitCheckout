# Testing Infrastructure

This document describes how the RepoHerd automated test suite is designed, how it depends on external GitHub repositories, and what constraints must be respected when maintaining it.

## Overview

The test suite consists of two layers:

- **Unit tests** (`tests/RepoHerd.Unit.Tests.ps1`) — 60 tests covering pure functions. No network, no git operations. Fast (~2 seconds).
- **Integration tests** (`tests/RepoHerd.Integration.Tests.ps1`) — 17 tests that perform actual git clones with full recursive dependency resolution. Require network access to GitHub. Slower (~3 minutes).

Both require [Pester 5.x](https://pester.dev/) (PowerShell test framework):

```powershell
Install-Module Pester -Force -MinimumVersion 5.0 -Scope CurrentUser
```

## Integration Test Architecture

### Real checkouts, not mocks

Integration tests execute `RepoHerd.ps1` as a child process (`pwsh -NonInteractive`) against real GitHub repositories. No mocking, no DryRun. Each test:

1. **Cleans up** cloned repos from previous runs (`BeforeEach`)
2. **Executes** the script with a test config and `-OutputFile` for structured JSON output
3. **Validates** exit code, JSON schema, metadata, summary counters, and **the exact tag checked out for each repository**

### Test config structure

Each test has its own subdirectory containing a `dependencies.json` file:

```
tests/
  semver-basic/dependencies.json
  semver-floating-versions/dependencies.json
  agnostic-recursive/dependencies.json
  api-incompatibility-semver/dependencies.json
  ...
```

The file **must** be named `dependencies.json` because the recursive dependency lookup propagates the root config's filename to all depth levels. A file named `dependencies_semver.json` would cause the recursive lookup to search for `dependencies_semver.json` inside cloned repos — which doesn't exist, silently breaking depth-1+ recursion.

### Structured JSON output

Tests pass `-OutputFile` to generate a JSON result file (schema v1.0.0) that is parsed and validated. This makes the output format part of the test contract. The JSON includes:

- Execution metadata (tool version, recursion settings, API compatibility mode)
- Per-repository results (URL, tag, status, requestedBy, postCheckoutScript tracking)
- Summary counters (success/failure counts, total repos)
- Error messages

### Per-repository tag validation

Every test specifies an `ExpectedTags` hashtable with the exact tag each repository should be checked out at after full recursive resolution. For example:

```powershell
ExpectedTags = @{ RootA = 'v3.0.0'; RootB = 'v3.0.0'; TestA = 'v3.0.0'; TestB = 'v3.0.0'; TestC = 'v3.0.0' }
```

This validates the semantic correctness of the dependency resolution — not just "did it succeed" but "did it select the right version for each repo across the full dependency tree."

The expected tags were traced manually using the dependency data cataloged in [test_repositories_reference.md](test_repositories_reference.md).

## External Test Repositories

### Repository inventory

The integration tests depend on **5 GitHub repositories** in the [LS-Instruments](https://github.com/LS-Instruments) organization:

| Repository | Role | Visibility |
|------------|------|------------|
| LsiCheckOutTestRootA | Root entry point | Public |
| LsiCheckOutTestRootB | Root entry point | Private |
| LsiCheckOutTestA | Intermediate dependency | Private |
| LsiCheckOutTestB | Intermediate dependency | Private |
| LsiCheckOutTestC | Leaf dependency (no children) | Private |

### Dependency graph

```
RootA ──► TestA ──► TestB ──► TestC
     └──► TestB ──► TestC

RootB ──► TestC
```

TestC is the convergence point — it is requested by multiple paths in the tree, which is what enables conflict detection testing.

### How the repos are used

Each repo contains multiple git tags. Each tag may or may not include a `dependencies.json` file that references other repos in the set. The test configs reference specific tags of RootA and RootB, which triggers a recursive checkout that discovers TestA, TestB, and TestC at deeper levels.

The full catalog of tags, their `dependencies.json` content, and version patterns is documented in [test_repositories_reference.md](test_repositories_reference.md).

## Critical constraint: do not alter the test repositories

**Modifying the test repositories on GitHub will break the integration tests.**

The tests validate the exact tag checked out for each repo. These expected values are derived from the specific `dependencies.json` content at each tag in the test repos. If you:

- **Add, remove, or rename tags** — the SemVer resolution may select different versions
- **Change `dependencies.json` content at any tag** — the recursive dependency tree changes, altering which repos are discovered and what versions are requested
- **Change `API Compatible Tags` arrays** — the Agnostic mode conflict resolution changes
- **Delete a repository** — tests that reference it will fail to clone

If test repo changes are necessary, you must:

1. Update [test_repositories_reference.md](test_repositories_reference.md) with the new tag/dependency data
2. Re-trace the expected dependency resolution for all affected test cases
3. Update the `ExpectedTags` hashtables in the integration test matrix
4. Verify all tests pass

### What is safe to change

- Adding new tags that don't interfere with existing version resolution (e.g., adding `v5.0.0` to TestC won't affect tests requesting `v3.0.0`)
- Adding new test repos for new test scenarios
- Creating new test configs (new subdirectories) that reference existing tags

## Test categories

### SemVer mode (8 tests)

| Test | What it validates |
|------|-------------------|
| semver-basic | All repos at exact LowestApplicable versions |
| semver-floating-versions | FloatingPatch (`3.0.*`) resolves to highest patch (v3.0.2) |
| semver-floating-versions-2 | FloatingMinor (`3.*`) resolves to highest minor (v3.1.0) |
| semver-custom-dep-path-1 | Custom dependency file path on RootB (nested deps not found) |
| semver-custom-dep-path-2 | Custom dependency file name on RootB (nested deps not found) |
| semver-post-checkout-scripts | Post-checkout script configured, disabled via CLI |
| semver-post-checkout-scripts-2 | Same with different RootB tag |
| semver-post-checkout-depth-0 | Root-level post-checkout script tracking |

### Agnostic mode (6 tests)

| Test | What it validates |
|------|-------------------|
| agnostic-recursive | Full recursive checkout through all depth levels |
| agnostic-custom-dep-path | Custom dependency path/name on RootB |
| agnostic-partial-api-overlap | API compatible tags partially overlap between requesters |
| agnostic-post-checkout-scripts | Post-checkout script configured, disabled via CLI |
| agnostic-post-checkout-scripts-2 | Same with different RootB tag |
| agnostic-post-checkout-depth-0 | Root-level post-checkout script tracking |

### API incompatibility (3 tests)

| Test | What it validates |
|------|-------------------|
| Agnostic + Permissive | Conflict resolved silently (TestC re-checked-out from v2.0.0 to v1.0.3) |
| Agnostic + Strict | Conflict rejected (TestC stays at v2.0.0, exit code 1) |
| SemVer | Major version conflict (TestC v4.0.0 vs v3.0.0, empty intersection, exit code 1) |

## Running tests

```powershell
# Unit tests only (fast, no network)
Invoke-Pester ./tests/RepoHerd.Unit.Tests.ps1 -Output Detailed

# Integration tests only (requires network)
Invoke-Pester ./tests/RepoHerd.Integration.Tests.ps1 -Output Detailed

# All tests
Invoke-Pester ./tests/ -Output Detailed
```
