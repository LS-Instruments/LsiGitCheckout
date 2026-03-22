# Version Migration Guide

> [← Back to README](../README.md)

This guide covers migration steps between LsiGitCheckout versions. For migrating existing dependency trees *to* LsiGitCheckout, see the [Migration and Dependency Management Guide](migration_guide.md).

## From Version 7.0.0 to 7.1.0

Version 7.1.0 introduces Floating Versions support for SemVer mode:

### New Features Available
- **Floating Patch Versions (`x.y.*`)**: Automatically select latest patch versions
- **Floating Minor Versions (`x.*`)**: Automatically select latest minor.patch versions
- **Mixed Specification Mode**: Intelligent selection between lowest-applicable and highest-compatible based on pattern types
- **Enhanced logging**: Shows version pattern types and selection reasoning

### Migration Steps
1. **Immediate**: All existing v7.0.0 configurations work without changes
2. **Optional**: Convert appropriate SemVer specifications to floating patterns for automatic latest version selection
3. **Enhanced workflows**: Leverage floating versions for dependency currency while maintaining stability where needed

### Floating Version Examples

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

### Benefits of Floating Versions
- **Automatic updates**: Get latest patches/minors without manual configuration changes
- **Flexible dependency management**: Mix fixed and floating patterns as appropriate
- **Reduced maintenance**: Less frequent dependency file updates required
- **Better currency**: Stay up-to-date with compatible improvements

### Non-Breaking Changes
- **Zero configuration changes required**: All existing dependency files work without modification
- **Backward compatibility**: Traditional `x.y.z` patterns remain the default
- **Gradual adoption**: Convert to floating patterns as appropriate for your stability requirements

## From Version 6.2.x to 7.0.0

Version 7.0.0 introduces Semantic Versioning (SemVer) support alongside the existing Agnostic mode:

### New Features Available
- **SemVer Mode**: Automatic version resolution based on Semantic Versioning 2.0.0 rules
- **Mixed Mode Support**: Use both SemVer and Agnostic repositories in the same dependency tree
- **Enhanced Version Parsing**: One-time tag parsing with caching for performance
- **Improved Conflict Reporting**: Detailed conflict messages with full context

### Migration Steps
1. **Immediate**: All existing v6.2.x configurations work without changes in Agnostic mode
2. **Optional**: Convert appropriate repositories to SemVer mode for automatic compatibility resolution
3. **Enhanced workflows**: Leverage SemVer for well-versioned libraries while keeping Agnostic mode for complex scenarios

### SemVer Configuration Example

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

### Benefits of Migration
- **Reduced maintenance**: No need to manually maintain API Compatible Tags for SemVer repositories
- **Automatic resolution**: SemVer rules automatically determine compatible versions
- **Clear conflict reporting**: Detailed error messages when version requirements conflict
- **Mixed approach**: Use SemVer where appropriate while keeping Agnostic mode for complex cases

### Non-Breaking Changes
- **Zero configuration changes required**: All existing dependency files work without modification
- **Backward compatibility**: Agnostic mode remains the default and fully supported
- **Gradual adoption**: Convert repositories to SemVer mode as appropriate for your workflow

## Previous Version Migration Guides

For migration guides from earlier versions, see the [CHANGELOG.md](../CHANGELOG.md) file which contains detailed migration instructions for all version transitions.
