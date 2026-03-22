# Custom Dependency Files

> [← Back to README](../README.md)

Per-repository custom dependency file paths and names provide flexibility for different project structures and naming conventions while maintaining proper dependency isolation.

## Overview

By default, the script looks for dependency files with the same name as the input file (e.g., `dependencies.json`) in the root directory of each checked-out repository. With custom dependency file support, each repository can specify:

- **Custom File Name**: Use different naming conventions (e.g., `project-modules.json`, `requirements.json`)
- **Custom File Path**: Place dependency files in subdirectories (e.g., `config/deps`, `build/dependencies`)

## Configuration Fields

### Dependency File Path
- **Purpose**: Specifies a subdirectory within the repository where the dependency file is located
- **Type**: String (relative path from repository root)
- **Default**: Repository root directory
- **Examples**: `"config"`, `"build/deps"`, `"scripts/deployment"`

### Dependency File Name
- **Purpose**: Specifies a custom name for the dependency file
- **Type**: String (filename with extension)
- **Default**: Same as the input file name (e.g., `dependencies.json`)
- **Examples**: `"project-modules.json"`, `"external-deps.json"`, `"requirements.json"`

## Dependency Isolation

**Critical Behavior**: Custom dependency file settings are **NOT propagated** to nested repositories. Each repository's custom settings apply only to that repository. Nested repositories discovered during recursive processing always use the default dependency file name from the root invocation.

This isolation prevents:
- Unintended dependency file lookups in nested repositories
- Coupling between parent and child repository configurations
- Complexity in deeply nested dependency hierarchies

## Path Resolution

**Important**: Relative paths in dependency files are always resolved relative to the **repository root**, not the dependency file location.

**Example:**
```
Repository: test-repo/
Custom dependency file: test-repo/build/config/deps.json
Relative path in deps.json: ../libs/library
Resolves to: test-repo/libs/library (relative to repository root)
```

## Configuration Examples

### Basic Custom File Name
```json
{
  "Repository URL": "https://github.com/myorg/project.git",
  "Base Path": "repos/project",
  "Dependency Resolution": "SemVer",
  "Version": "1.*",
  "Dependency File Name": "project-modules.json"
}
```
**Result**: Looks for `project-modules.json` in the repository root

### Custom Subdirectory
```json
{
  "Repository URL": "https://github.com/myorg/project.git",
  "Base Path": "repos/project",
  "Tag": "v1.0.0",
  "Dependency File Path": "config/deps"
}
```
**Result**: Looks for `dependencies.json` in the `config/deps` subdirectory

### Both Custom Path and Name
```json
{
  "Repository URL": "https://github.com/myorg/project.git",
  "Base Path": "repos/project",
  "Dependency Resolution": "SemVer",
  "Version": "1.0.*",
  "Dependency File Path": "build/config",
  "Dependency File Name": "external-dependencies.json"
}
```
**Result**: Looks for `external-dependencies.json` in the `build/config` subdirectory
