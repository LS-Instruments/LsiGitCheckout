# LsiGitCheckout — Completed Issues

All implemented features and fixes, ordered by issue number.

---

### #1 — Separate SSH credentials from repository configuration (v3.0.0)

Introduced a separate `git_credentials.json` file that maps hostnames to SSH key paths, allowing `dependencies.json` to be safely committed to version control.

- Maps hostnames to SSH key paths; supports plain hostnames and `ssh://` prefixed hostnames
- Automatic hostname extraction from `git@`, `ssh://`, and `https://` URL formats
- New `-CredentialsFile` parameter (defaults to `git_credentials.json`)
- Submodules are auto-discovered — removed `"Submodule Config"` section
- **Breaking**: Removed `"SSH Key Path"` from repo configs, removed `"Submodule Config"` section, renamed `-Debug` to `-EnableDebug`

---

### #2 — Recursive dependency discovery with API compatibility checking (v4.0.0)

Recursive dependency discovery that automatically processes nested repository dependencies while ensuring API compatibility across shared dependencies.

- After checkout, looks for `dependencies.json` in each repo root and processes recursively
- Configurable max depth with `-MaxDepth` (default 5), circular dependency prevention
- New `"API Compatible Tags"` field with temporal ordering convention (oldest to newest)
- Intelligent version resolution: calculates tag intersection, selects most recent compatible version
- Conflict detection: path conflicts (same repo at different locations), API incompatibility (no common compatible versions)

---

### #3 — Flexible API compatibility modes for recursive dependency resolution (v4.1.0)

Added `"API Compatibility"` per-repo JSON field and `-ApiCompatibility` CLI parameter with two modes:

- **Strict**: uses intersection of compatible tags (conservative, ensures compatibility)
- **Permissive** (default): uses union of compatible tags (flexible, allows newer versions)
- Mode interaction rules: Strict + Strict → intersection; Strict + Permissive → keep Strict unchanged; Permissive + Permissive → union; Permissive + Strict → adopt Strict
- Repository dictionary tracks and updates API Compatibility mode per repository

---

### #4 — Tag temporal sorting (v4.2.0)

Automatic tag temporal sorting using `git for-each-ref --sort=creatordate` to sort tags chronologically by actual creation date.

- New `-EnableTagSorting` parameter (disabled by default for backward compatibility)
- Fetches tag dates once per repository after initial checkout, cached in repository dictionary
- Enhanced tag selection algorithm: prioritizes existing/new "Tag" values when resolving conflicts, falls back to chronologically most recent from compatible set
- Eliminates manual temporal ordering maintenance burden

---

### #5 — Per-repository dependency file configuration (v5.0.0)

Per-repository configuration options to customize dependency file location and naming during recursive processing.

- New `"Dependency File Path"` field: relative path within the repository where the dependency file is located (default: repo root)
- New `"Dependency File Name"` field: custom filename for the dependency file (default: same as input filename)
- Both fields can be used independently or together
- Example: `"Dependency File Path": "config", "Dependency File Name": "deps.json"` → looks for `<repo>/config/deps.json`

---

### #6 — Remove `-DisableTagSorting` and always enable intelligent tag sorting (v6.0.0)

Removed the `-DisableTagSorting` parameter — intelligent tag temporal sorting is now always enabled.

- ~195 lines of conditional logic removed (26% code reduction)
- API Compatible Tags can now be listed in any order — automatic chronological sorting
- Simplified `Sort-TagsByDate`, `Get-TagUnion`, and `Update-RepositoryDictionary` to single code paths
- **Breaking**: `-DisableTagSorting` parameter removed

---

### #7 — Post-checkout script execution support (v6.1.0)

Execute PowerShell scripts after successful repository checkouts for integration with external dependency management systems.

- New JSON fields: `"Post-Checkout Script File Name"` and `"Post-Checkout Script File Path"`
- Scripts execute only when actual checkouts occur (new clone or tag change), not when already at correct tag
- Working directory set to repository root; environment variables provided: `LSIGIT_REPOSITORY_URL`, `LSIGIT_REPOSITORY_PATH`, `LSIGIT_TAG`, `LSIGIT_SCRIPT_VERSION`
- 5-minute timeout protection; failures logged as warnings without affecting checkout success
- New `-DisablePostCheckoutScripts` parameter to disable execution

---

### #8 — Migration guide and tool comparison documentation

Added comprehensive documentation for adopting LsiGitCheckout in existing projects.

- `docs/migration_guide.md`: bottom-up migration strategy with step-by-step example using 6 repositories, directory structure visualization, semantic versioning compliance guidance
- `docs/comparison_guide.md`: LsiGitCheckout vs Google's Repo Tool, covering architecture differences, use cases, and decision criteria

---

### #9 — Enable post-checkout scripts at root level (depth 0)

Post-checkout scripts can now execute at depth 0 (root level) when configured in the input dependency file.

- Path construction at depth 0: `<input_file_directory>/<Post-Checkout Script File Path>/<Post-Checkout Script File Name>`
- Working directory: input dependency file directory
- Root-level script executes BEFORE processing any repositories
- Use cases: global environment setup, system validation, workspace preparation, pre-flight checks

---

### #10 — Documentation: handling shared dependencies version changes

Added documentation section explaining version update management in complex dependency trees.

- Two scenarios covered: API-compatible updates (bug fixes) and breaking changes with enhanced capabilities
- Step-by-step JSON change examples for each scenario
- Semantic versioning best practices: when to use major vs minor version bumps
- Uses migration example as starting point for continuity

---

### #11 — Semantic Versioning (SemVer) support for dependency resolution (v7.0.0)

New `"Dependency Resolution": "SemVer"` mode with `"Version": "x.y.z"` field for automatic version compatibility resolution.

- Automatically resolves compatible versions based on SemVer 2.0.0 rules: same major version, >= minor.patch
- Optional `"Version Regex"` field for custom tag parsing (default: `^v?(\d+)\.(\d+)\.(\d+)$`)
- Detects and rejects cross-major version conflicts regardless of API compatibility setting
- Reduces configuration maintenance — no need for explicit `"API Compatible Tags"` arrays

---

### #12 — Reorganize documentation and add SemVer mode coverage

Restructured documentation to reduce README complexity and add comprehensive SemVer mode coverage.

- Moved migration content to `docs/migration_guide.md`, comparison content to `docs/comparison_guide.md`
- Added SemVer mode documentation with identical dependency tree scenarios as Agnostic mode
- Mode selection guidance: advantages/disadvantages, when to use SemVer vs Agnostic, mixed mode support
- Clear sectioning distinguishing Agnostic vs SemVer content throughout

---

### #13 — Floating versions support for SemVer dependencies (v7.1.0)

Extended SemVer resolution with floating version patterns similar to NuGet package management.

- `x.y.*` — latest patch version within major.minor (e.g., `"3.0.*"` gets highest 3.0.z)
- `x.*` — latest minor.patch version within major (e.g., `"3.*"` gets highest 3.y.z)
- `x.y.z` — existing lowest applicable behavior (unchanged)
- Mixed mode resolution: if any dependency uses floating patterns → select highest compatible version; if all use lowest-applicable → select lowest (existing behavior)

---

### #14 — Floating versions documentation

Added comprehensive documentation for the floating versions functionality introduced in v7.1.0.

- Floating version syntax explanation and examples in main README
- Mixed-mode behavior documentation (highest version selection when floating patterns present)
- Migration scenarios demonstrating advantages over Agnostic mode
- Strategy tables and best practices for choosing between patch-level and minor-level floating patterns

---

### #15 — Module architecture, automated testing & structured JSON output (v8.0.0)

**Breaking change:** Requires PowerShell 7.6 LTS (installs side-by-side with Windows PowerShell 5.1).

- **Module refactor**: Split monolithic `LsiGitCheckout.ps1` (2750 lines) into `LsiGitCheckout.psm1` + `LsiGitCheckout.psd1` with slim entry point script. `Initialize-LsiGitCheckout` for module state initialization. PS 7.6 syntax: `??` null-coalescing operator, `pwsh` for post-checkout scripts.
- **Automated testing**: 65 unit tests (Pester 5.x, no network, <1s) + 18 integration tests (~96s) against live GitHub test repos with per-repository tag validation. All test configs moved to named subdirectories (`tests/<name>/dependencies.json`).
- **Structured JSON output**: New `-OutputFile` parameter writes machine-readable results (schema 1.0.0) with execution metadata, per-repo status, summary counters, `requestedBy` parent chain, post-checkout script tracking.
- **Cross-platform SSH**: PuTTY/plink on Windows (`.ppk`), OpenSSH via `GIT_SSH_COMMAND` on macOS/Linux. Same credential file format, different key types. Validated with HTTPS parent + SSH submodule on custom port scenario on both platforms.
- **Bug fixes**: `Show-ErrorDialog` pipeline leakage, non-interactive GUI dialogs for CI environments, SemVer parsing guard in DryRun mode.
- **Documentation**: `CLAUDE.md`, developer guide, testing infrastructure guide, test repositories reference, platform setup instructions (Windows, macOS, Linux).

---

### #16 — SemVer version resolution fails when using -DisableRecursion (v8.0.0)

**Bug**: `Update-RepositoryDictionary`, `Parse-RepositoryVersions`, and `SelectedTag` lookup in `Invoke-GitCheckout` were all gated behind `if ($script:RecursiveMode)`. When `-DisableRecursion` sets `RecursiveMode = false`, the entire SemVer resolution pipeline was skipped, producing an empty tag passed to `git checkout`.

**Fix**: Removed `$script:RecursiveMode` gates from version resolution conditions. `RecursiveMode` now only controls whether nested dependency files are followed, not whether version resolution runs for the current level. Regression test added.

---

### #17 — Rename functions to use approved PowerShell verbs (v8.0.1)

Eliminated `Import-Module` warning by renaming all functions with non-approved verbs:

| Old name | New name |
| --- | --- |
| `Parse-VersionPattern` | `ConvertTo-VersionPattern` |
| `Parse-RepositoryVersions` | `Get-RepositoryVersions` |
| `Validate-DependencyConfiguration` | `Test-DependencyConfiguration` |
| `Sort-TagsByDate` | `Resolve-TagsByDate` |
| `Process-DependencyFile` | `Invoke-DependencyFile` |
| `Process-RecursiveDependencies` | `Invoke-RecursiveDependencies` |

Updated all call sites, exports in `.psd1`, unit tests, and integration tests. Removed `-DisableNameChecking` workaround.
