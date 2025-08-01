# Additional README Sections for SemVer Mode

## Dependency Resolution Modes

LsiGitCheckout supports two dependency resolution modes:

### Agnostic Mode (Default)
The traditional tag-based resolution using exact tags and API Compatible Tags lists.

### SemVer Mode
Automatic version resolution based on Semantic Versioning 2.0.0 rules.

## SemVer Mode

### Overview
SemVer mode enables automatic dependency resolution based on Semantic Versioning rules. Instead of maintaining explicit lists of compatible tags, you specify a version requirement, and the script automatically finds the best compatible version.

### Configuration
To use SemVer mode for a repository, add these fields to your dependency configuration:

```json
{
  "Repository URL": "https://github.com/org/library.git",
  "Base Path": "libs/library",
  "Dependency Resolution": "SemVer",
  "Version": "2.1.0",
  "Version Regex": "^v(\\d+)\\.(\\d+)\\.(\\d+)$"  // Optional, defaults shown
}
```

### Fields
- **Dependency Resolution**: Set to `"SemVer"` to enable SemVer mode
- **Version**: The minimum version requirement in `MAJOR.MINOR.PATCH` format
- **Version Regex** (Optional): Custom regex pattern for parsing version tags
  - Default: `"^v?(\\d+)\\.(\\d+)\\.(\\d+)$"` (matches `v1.2.3` or `1.2.3`)
  - Must have at least 3 capture groups for major, minor, and patch

### Version Compatibility Rules

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

### Version Selection
When multiple compatible versions exist, the script selects the **lowest compatible version** to ensure stability and predictable behavior.

### Conflict Resolution
If multiple repositories depend on the same library with incompatible version requirements, the script will report a detailed conflict error showing:
- All repositories requesting the conflicting dependency
- Their individual version requirements
- The compatible versions for each requirement

Example conflict:
```
SemVer conflict for repository 'https://github.com/org/shared-lib.git':
No version satisfies all requirements:
- https://github.com/org/app-a.git requests: 2.1.0 (compatible: v2.1.0, v2.1.1, v2.2.0)
- https://github.com/org/app-b.git requests: 3.0.0 (compatible: v3.0.0, v3.1.0)
```

### Mixed Mode Support
You can use both Agnostic and SemVer modes in the same dependency tree. Each repository's mode is determined by its configuration and cannot change once established.

### Custom Version Tag Formats
If your repositories use non-standard version tag formats, you can specify a custom regex:

```json
{
  "Version Regex": "^release-(\\d+)\\.(\\d+)\\.(\\d+)$"  // Matches: release-1.2.3
}
```

Requirements:
- Must have exactly 3 capture groups in order: major, minor, patch
- The pattern is immutable once a repository is discovered
- All tags not matching the pattern are ignored

### Best Practices

1. **Version Tags**: Use consistent version tag formats across your organization
2. **Version Requirements**: Specify the minimum version that includes required features/fixes
3. **Major Version Bumps**: Be cautious with major version requirements as they may cause conflicts
4. **Testing**: Test your dependency tree with `-DryRun` before actual checkouts

### Example: Complex Dependency Tree

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
    "Version": "2.3.0"
  },
  {
    "Repository URL": "https://github.com/org/lib-utils.git",
    "Base Path": "libs/utils",
    "Tag": "v1.5.0"  // Can mix Agnostic mode
  }
]
```

In this example, `app` and `lib-core` use SemVer resolution, while `lib-utils` uses traditional tag-based (Agnostic) resolution.