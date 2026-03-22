# Agnostic Mode

> [← Back to README](../README.md)

A tag-based resolution using exact tags and explicit API Compatible Tags lists for managing shared dependencies. This mode provides maximum control and flexibility for projects that don't follow strict semantic versioning.

**Key Features for Shared Dependencies:**
- Explicit compatibility definitions via "API Compatible Tags"
- Always-on intelligent tag temporal sorting
- Support for Strict and Permissive compatibility modes
- Fine-grained control over version relationships

**Basic Configuration Example:**
```json
{
  "Repository URL": "https://github.com/org/library.git",
  "Base Path": "libs/library",
  "Tag": "v2.1.0",
  "API Compatible Tags": ["v2.0.0", "v2.0.1", "v2.0.5"],
  "API Compatibility": "Strict"
}
```

## API Compatibility Modes in Agnostic Mode

API compatibility modes control how version conflicts are resolved when multiple projects depend on the same repository. These modes apply to Agnostic mode repositories.

### Strict Mode

In Strict mode, the script uses the **intersection** of compatible tags when resolving version conflicts. This ensures maximum compatibility but may result in older versions being selected.

**Use Strict mode when:**
- Working with production systems
- API stability is critical
- Breaking changes must be avoided
- Conservative version management is preferred

### Permissive Mode

In Permissive mode, the script uses the **union** of compatible tags, allowing more flexibility in version selection. This typically results in newer versions being selected.

**Use Permissive mode when:**
- Working in development environments
- Rapid iteration is important
- Teams can quickly adapt to API changes
- Latest features are prioritized

### Mode Interaction Rules

When the same repository is encountered multiple times with different compatibility modes and/or tag requirements:

**Strict Mode Algorithm:**
- **Intersection**: Calculates the intersection of all compatible tag sets
- **Tag Selection**: Uses intelligent temporal sorting to prioritize existing/new "Tag" values if they're in the intersection, otherwise selects the chronologically most recent tag from the intersection

**Permissive Mode Algorithm:**
- **Union**: Calculates the union of all compatible tag sets
- **Tag Selection**: Uses intelligent temporal sorting to prioritize existing/new "Tag" values if they're in the union, otherwise selects the chronologically most recent tag from the union

**Mode Combination Rules:**
1. **Strict + Strict**: Uses intersection algorithm (conservative)
2. **Strict + Permissive**: Keeps the Strict repository unchanged
3. **Permissive + Permissive**: Uses union algorithm (flexible)
4. **Permissive + Strict**: Adopts Strict mode and its version requirements

### Configuration Examples

#### Repository-Level Configuration

```json
[
  {
    "Repository URL": "https://github.com/myorg/stable-lib.git",
    "Base Path": "libs/stable",
    "Tag": "v2.0.0",
    "API Compatible Tags": ["v1.8.0", "v1.9.0"],
    "API Compatibility": "Strict"
  },
  {
    "Repository URL": "https://github.com/myorg/dev-lib.git",
    "Base Path": "libs/dev",
    "Tag": "v3.0.0-beta",
    "API Compatible Tags": ["v2.0.0", "v2.1.0", "v2.2.0"],
    "API Compatibility": "Permissive"
  }
]
```

#### Script-Level Default

```powershell
# Set default to Strict for production environments
.\LsiGitCheckout.ps1 -ApiCompatibility Strict

# Use Permissive for development (default behavior)
.\LsiGitCheckout.ps1

# Disable recursive mode if only processing single dependency file
.\LsiGitCheckout.ps1 -DisableRecursion
```

## Version Management Rules

When updating dependencies, simply add or remove versions from the API Compatible Tags array:

1. **Adding a new compatible version** (e.g., v1.0.3 → v1.0.4):
   - Add the new version to "API Compatible Tags" or update "Tag"
   - Order doesn't matter - automatic sorting handles chronology

   ```json
   {
     "Tag": "v1.0.4",
     "API Compatible Tags": ["v1.0.0", "v1.0.1", "v1.0.2", "v1.0.3"]
   }
   ```

2. **Bumping to an incompatible version** (e.g., v1.0.3 → v2.0.0):
   - Update "Tag" to the new version
   - Clear or update "API Compatible Tags" for the new API version

   ```json
   {
     "Tag": "v2.0.0",
     "API Compatible Tags": []
   }
   ```

## Checkout Tag Selection Algorithm in Agnostic Mode

The script features an intelligent automatic tag selection algorithm using actual git tag dates, providing optimal version selection without any manual configuration required.

### Overview

The script automatically:
1. **Fetches tag dates** from each repository after checkout using `git for-each-ref`
2. **Sorts tags chronologically** during processing using actual git tag creation dates
3. **Prioritizes specified tags** - intelligently uses your specified "Tag" values when processing repositories
4. **Optimizes performance** - only fetches tag dates when needed

### Key Benefits

- **Accurate chronology**: Uses actual git tag dates instead of assumed ordering
- **Intelligent tag selection**: Prioritizes your specified "Tag" values in dependency files
- **Minimal performance impact**: Efficient tag date fetching only when needed
- **Simplified maintenance**: Works automatically without manual configuration
- **Optimal behavior**: No configuration required for best performance
- **Zero maintenance overhead**: No need to maintain temporal order in configuration files

### Performance Optimization

- **On-demand processing**: Tag dates are only fetched when needed
- **Efficient git operations**: Uses `git for-each-ref` instead of multiple `git log` calls
- **Smart caching**: Tag dates are cached in memory during processing
- **Minimal server impact**: Only one tag date fetch per repository during checkout

This intelligent sorting ensures that when you specify tags in your dependency files, the script handles them optimally while maintaining performance and accuracy.

## Mixed Mode Support

You can use both SemVer and Agnostic modes in the same dependency tree. Each repository's mode is determined by its configuration and cannot change once established.

**Example Mixed Configuration:**
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
    "Version": "2.3.*"
  },
  {
    "Repository URL": "https://github.com/org/lib-utils.git",
    "Base Path": "libs/utils",
    "Tag": "v1.5.0",
    "API Compatible Tags": ["v1.4.0", "v1.4.1"]
  }
]
```

This flexibility allows you to:
- Use SemVer mode for well-versioned libraries that follow semantic versioning
- Use Agnostic mode for legacy components or repositories with custom tagging schemes
- Choose the appropriate mode for each repository based on its versioning practices
- Maintain different levels of control across your dependency tree
