# SemVer Mode

> [← Back to README](../README.md)

Automatic version resolution based on Semantic Versioning 2.0.0 rules for managing shared dependencies across multiple repositories. This mode eliminates the need to maintain explicit compatibility lists by leveraging semantic versioning conventions and supports floating version patterns for automatic latest version selection.

**Key Features for Shared Dependencies:**
- Automatic compatibility resolution using SemVer rules
- Floating version patterns for automatic latest version selection
- Support for custom version tag patterns
- Intelligent conflict detection and reporting
- Mixed specification mode: floating patterns select highest compatible versions

## Advanced SemVer Configuration

### Lowest Applicable Version
```json
{
  "Repository URL": "https://github.com/org/library.git",
  "Base Path": "libs/library",
  "Dependency Resolution": "SemVer",
  "Version": "2.1.0",
  "Version Regex": "^v(\\d+)\\.(\\d+)\\.(\\d+)$"
}
```

### Floating Patch Version
```json
{
  "Repository URL": "https://github.com/org/library.git",
  "Base Path": "libs/library",
  "Dependency Resolution": "SemVer",
  "Version": "2.1.*"
}
```

### Floating Minor Version
```json
{
  "Repository URL": "https://github.com/org/library.git",
  "Base Path": "libs/library",
  "Dependency Resolution": "SemVer",
  "Version": "2.*"
}
```

## SemVer Shared Dependency Resolution

### Version Specification Patterns

SemVer mode supports three version specification patterns for handling shared dependencies:

1. **Lowest Applicable Version (`x.y.z`)**: Select minimum version that satisfies compatibility requirements
   - Example: `"Version": "2.1.0"` → Compatible: 2.1.0, 2.1.1, 2.2.0 → Selects: 2.1.0

2. **Floating Patch Version (`x.y.*`)**: Select latest patch version within specified major.minor
   - Example: `"Version": "2.1.*"` → Compatible: 2.1.0, 2.1.1, 2.1.5 → Selects: 2.1.5

3. **Floating Minor Version (`x.*`)**: Select latest minor.patch version within specified major
   - Example: `"Version": "2.*"` → Compatible: 2.1.0, 2.3.2, 2.5.0 → Selects: 2.5.0

### Mixed Specification Mode

When multiple repositories declare the same dependency with different specification patterns:

- **If ANY dependency uses floating patterns** → select **highest** compatible version
- **If ALL dependencies use lowest-applicable** → select **lowest** compatible version

**Example Mixed Mode Scenario:**
```
Repository A: "Version": "3.0.0" (lowest-applicable)
Repository B: "Version": "3.*" (floating minor)
Result: System selects highest 3.x.x version that satisfies both requirements
```

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

## Custom Version Tag Formats

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

## Conflict Resolution

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
