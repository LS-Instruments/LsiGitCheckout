# Migration and Dependency Management Guide

This guide covers advanced scenarios for migrating existing projects to LsiGitCheckout and managing shared dependencies over time. Both Agnostic mode (explicit API Compatible Tags) and SemVer mode (automatic semantic versioning) approaches are covered.

## Table of Contents

- [Migrating Existing Dependency Trees to LsiGitCheckout (Agnostic Mode)](#migrating-existing-dependency-trees-to-lsigitcheckout-agnostic-mode)
- [Migrating Existing Dependency Trees to LsiGitCheckout (SemVer Mode)](#migrating-existing-dependency-trees-to-lsigitcheckout-semver-mode)
- [Handling Shared Dependencies Version Changes (Agnostic Mode)](#handling-shared-dependencies-version-changes-agnostic-mode)
- [Handling Shared Dependencies Version Changes (SemVer Mode)](#handling-shared-dependencies-version-changes-semver-mode)

## Migrating Existing Dependency Trees to LsiGitCheckout (Agnostic Mode)

If you already have a complex project with multiple Git repositories forming a dependency tree, you can migrate to LsiGitCheckout by working systematically from the bottom up. This approach ensures that each level of your dependency tree is properly configured before moving to the next level.

### Migration Strategy: Bottom-Up Approach

The key principle is to **start from the penultimate level** (one level above the leaf dependencies) and work your way up to the root project. This ensures that when you configure a repository's dependencies, all the referenced repositories already have their `dependencies.json` files in place.

#### Basic Concept

1. **Identify Dependency Levels**: Map out your dependency tree to understand which repositories depend on which others
2. **Prepare Leaf Dependencies**: Ensure leaf repositories (those with no dependencies) have appropriate tags to be referenced, but don't add `dependencies.json` files to them
3. **Start at Penultimate Level**: Begin with repositories that depend directly on leaf nodes
4. **Add Dependencies Files**: For each level, add `dependencies.json` files referencing the previously configured level
5. **Tag Appropriately**: Create tags that make each level available to the level above
6. **Work Upward**: Repeat until you reach your root project

#### The Migration Process

```
Level 3 (Root):     ProjectMain
                       │
Level 2:           SubProjectA ──── SubProjectB
                       │               │
Level 1:           LibraryCore ──── UtilityLib ──── CommonLib
                       │
Level 0 (Leaf):    BaseFoundation
```

**Migration Order**: Ensure Level 0 has tags, then start with Level 1, then Level 2, finally Level 3.

### Practical Example

Let's walk through migrating a simple project with the following dependency tree. This migration process assumes you are starting from a state where all repositories are already checked out locally at the tags shown below and organized in the directory structure that will be referenced by the dependencies.json files we'll create.

#### Current Dependency Tree and Tags

```
Level 3 (Root):             MyApplication (v0.9.2)
                                 │
                   ┌─────────────┴─────────────┐
                   │                           │
Level 2:     UserInterface (v4.1.3)    BusinessLogic (v4.5.1)
                   │                           │
                   │                    ┌──────┴──────┐
                   │                    │             │
Level 1:     CommonControls (v3.0.8) ────────┐   DataAccess (v2.2.5)
                   │                         │        │
                   └─────────────────────────┼────────┘
                                             │
Level 0 (Leaf):                     DatabaseUtils (v1.2.0)
                                          (leaf)
```

#### Current Directory Structure (Before Migration)

The migration process assumes you start with all repositories already checked out in the target directory structure:

```
MyApplication/                         # MyApplication (v0.9.2) - currently checked out
├── shared/                            # Shared dependencies location
│   ├── database-utils/                # DatabaseUtils (v1.2.0) - currently checked out
│   │   └── ...                        # DatabaseUtils source code
│   └── common-controls/               # CommonControls (v3.0.8) - currently checked out
│       └── ...                        # CommonControls source code
├── modules/                           # Project modules location
│   ├── user-interface/                # UserInterface (v4.1.3) - currently checked out
│   │   └── ...                        # UserInterface source code
│   └── business-logic/                # BusinessLogic (v4.5.1) - currently checked out
│       ├── libs/                      # BusinessLogic's dependencies location
│       │   └── data-access/           # DataAccess (v2.2.5) - currently checked out
│       │       └── ...                # DataAccess source code
│       └── ...                        # BusinessLogic source code
└── ...                                # MyApplication source code
```

**Key Points About the Starting State:**
- All repositories are already cloned and checked out at their respective tags
- **No `dependencies.json` files exist yet** in any repository
- The dependencies.json files we'll create will reflect this existing directory structure
- Shared dependencies (DatabaseUtils, CommonControls) are already in the `shared/` directory
- Project-specific dependencies are already organized under their parent projects

#### Migration Target: New Tags

The migration process will create new tags for each repository (except leaf dependencies):

- **MyApplication**: existing `v0.9.2` → needs new tag `v1.0.0` (major release with LsiGitCheckout)
- **UserInterface**: existing `v4.1.3` → needs new tag `v4.2.0` (minor release with dependencies)  
- **BusinessLogic**: existing `v4.5.1` → needs new tag `v4.6.0` (minor release, not v5.0.0!)
- **DataAccess**: existing `v2.2.5` → needs new tag `v2.3.0` (minor release with dependencies)
- **CommonControls**: existing `v3.0.8` → needs new tag `v3.1.0` (minor release with dependencies)
- **DatabaseUtils**: existing `v1.2.0` → **no new tag needed** (leaf dependency)

#### Step 1: Prepare Leaf Dependencies (DatabaseUtils)

DatabaseUtils already has tag `v1.2.0` which will be referenced by other repositories. Since it's a leaf dependency, we do **not** add a `dependencies.json` file and do **not** create a new tag.

```powershell
Set-Location DatabaseUtils
git tag --list  # Verify v1.2.0 exists
# No changes needed for leaf dependencies
```

#### Step 2: Configure Penultimate Level Dependencies (Level 1)

Now we start adding `dependencies.json` files, beginning with repositories that depend directly on leaf nodes.

**Important Note About API Compatible Tags During Migration:**
During the migration process, we set "API Compatible Tags" to empty arrays. This is because any older tags (like the existing v2.2.5, v3.0.8, etc.) correspond to commits that lack `dependencies.json` files. Including these older tags would risk LsiGitCheckout checking out versions without dependency configuration, breaking the recursive dependency resolution.

**In normal future use**, you should populate "API Compatible Tags" with versions that:
- Are truly API-compatible with your current tag
- **Also contain the `dependencies.json` file** with proper LsiGitCheckout configuration

##### Configure DataAccess

**Current tag**: `v2.2.5` → **New tag**: `v2.3.0` (minor version bump for adding dependencies)

```powershell
Set-Location DataAccess
```

Create `dependencies.json`:
```json
[
  {
    "Repository URL": "https://github.com/yourorg/DatabaseUtils.git",
    "Base Path": "../shared/database-utils",
    "Tag": "v1.2.0",
    "API Compatible Tags": []
  }
]
```

Commit and tag:
```powershell
git add dependencies.json
git commit -m "Add LsiGitCheckout dependencies configuration"
git tag v2.3.0  # Minor version bump, compatible with v2.2.5
git push origin v2.3.0
```

##### Configure CommonControls

**Current tag**: `v3.0.8` → **New tag**: `v3.1.0` (minor version bump for adding dependencies)

```powershell
Set-Location ..\CommonControls
```

Create `dependencies.json`:
```json
[
  {
    "Repository URL": "https://github.com/yourorg/DatabaseUtils.git",
    "Base Path": "../shared/database-utils",
    "Tag": "v1.2.0",
    "API Compatible Tags": []
  }
]
```

Commit and tag:
```powershell
git add dependencies.json
git commit -m "Add LsiGitCheckout dependencies configuration"
git tag v3.1.0  # Minor version bump, compatible with v3.0.8
git push origin v3.1.0
```

#### Step 3: Configure Level 2 Dependencies

##### Configure UserInterface

**Current tag**: `v4.1.3` → **New tag**: `v4.2.0` (minor version bump for adding dependencies)

```powershell
Set-Location ..\UserInterface
```

Create `dependencies.json`:
```json
[
  {
    "Repository URL": "https://github.com/yourorg/CommonControls.git",
    "Base Path": "../shared/common-controls",
    "Tag": "v3.1.0",
    "API Compatible Tags": []
  }
]
```

Commit and tag:
```powershell
git add dependencies.json
git commit -m "Add LsiGitCheckout dependencies configuration"
git tag v4.2.0  # Minor version bump, compatible with v4.1.3
git push origin v4.2.0
```

##### Configure BusinessLogic

**Current tag**: `v4.5.1` → **New tag**: `v4.6.0` (minor version bump, **not** v5.0.0 which would break semver!)

```powershell
Set-Location ..\BusinessLogic
```

Create `dependencies.json`:
```json
[
  {
    "Repository URL": "https://github.com/yourorg/DataAccess.git",
    "Base Path": "libs/data-access",
    "Tag": "v2.3.0",
    "API Compatible Tags": []
  },
  {
    "Repository URL": "https://github.com/yourorg/CommonControls.git",
    "Base Path": "../shared/common-controls",
    "Tag": "v3.1.0",
    "API Compatible Tags": []
  }
]
```

Commit and tag:
```powershell
git add dependencies.json
git commit -m "Add LsiGitCheckout dependencies configuration"
git tag v4.6.0  # Minor version bump - API compatible with v4.5.1
git push origin v4.6.0
```

#### Step 4: Configure Root Project (MyApplication)

**Current tag**: `v0.9.2` → **New tag**: `v1.0.0` (major version bump for significant migration to LsiGitCheckout)

```powershell
Set-Location ..\MyApplication
```

Create `dependencies.json`:
```json
[
  {
    "Repository URL": "https://github.com/yourorg/UserInterface.git",
    "Base Path": "modules/user-interface",
    "Tag": "v4.2.0",
    "API Compatible Tags": []
  },
  {
    "Repository URL": "https://github.com/yourorg/BusinessLogic.git", 
    "Base Path": "modules/business-logic",
    "Tag": "v4.6.0",
    "API Compatible Tags": []
  }
]
```

Commit and tag:
```powershell
git add dependencies.json
git commit -m "Add LsiGitCheckout dependencies configuration - Major migration to dependency management"
git tag v1.0.0  # Major version for significant architectural change
git push origin v1.0.0
```

### Updated Dependency Tree After Migration

Here's the dependency tree showing both **old tags** (existing) and **new tags** (with LsiGitCheckout):

```
                    MyApplication
                   v0.9.2 → v1.0.0
                         │
           ┌─────────────┴─────────────┐
           │                           │
     UserInterface              BusinessLogic
    v4.1.3 → v4.2.0            v4.5.1 → v4.6.0
           │                           │
           │                     ┌─────┴──────┐
           │                     │            │
     CommonControls              │        DataAccess
    v3.0.8 → v3.1.0 ─────────────┐      v2.2.5 → v2.3.0
           │                     │            │
           └─────────────────────┼────────────┘
                                 │
                         DatabaseUtils
                           v1.2.0
                         (unchanged)
```

### Step 5: Test Your Migration

Now test that the migration worked correctly:

```powershell
# Navigate to a clean workspace
Set-Location C:\workspace\test-migration
New-Item -ItemType Directory -Name "test-migration" -Force
Set-Location test-migration

# Clone and run LsiGitCheckout on your root project
git clone https://github.com/yourorg/MyApplication.git
Set-Location MyApplication
git checkout v1.0.0  # Use the new tag with LsiGitCheckout support

# Run LsiGitCheckout (assumes script is in PATH or current directory)
.\LsiGitCheckout.ps1

# Verify all dependencies were cloned recursively with correct versions
Get-ChildItem modules\      # Should show user-interface and business-logic
Get-ChildItem shared\       # Should show database-utils and common-controls (shared dependencies)
Get-ChildItem modules\business-logic\libs\    # Should show only data-access

# Verify the correct tags were checked out
Set-Location modules\user-interface
git describe --tags  # Should show v4.2.0
Set-Location ..\business-logic  
git describe --tags  # Should show v4.6.0 (not v5.0.0!)
Set-Location libs\data-access
git describe --tags  # Should show v2.3.0
Set-Location ..\..\..\shared\common-controls
git describe --tags  # Should show v3.1.0 (single shared location)
Set-Location ..\database-utils
git describe --tags  # Should show v1.2.0 (single shared location)
```

### Key Migration Tips

#### Determining API Compatible Tags

When filling out the "API Compatible Tags" field **after migration**, consider:

1. **Breaking Changes**: Only include versions that are truly API-compatible
2. **LsiGitCheckout Compatibility**: **Only include tags that also contain `dependencies.json` files**
3. **Testing History**: Look at which versions have been tested together
4. **Git History**: Use `git log --oneline` to review what changed between versions
5. **Semantic Versioning**: If you follow semver, patch and minor versions are typically compatible

**Migration-Specific Note**: During the initial migration, we use empty "API Compatible Tags" arrays because older tags lack `dependencies.json` files. As you continue development and create new compatible versions, you can populate these arrays with tags that both:
- Are API-compatible with your current version
- Contain proper LsiGitCheckout configuration

Example for future updates:
```powershell
Set-Location SomeLibrary
git log --oneline v2.3.0..v2.4.0
# Review commits to identify breaking changes
# If no breaking changes AND both tags have dependencies.json: 
# include v2.3.0 in API Compatible Tags for v2.4.0
```

#### Handling Multiple Dependencies

When a repository depends on multiple others that might conflict:
- **Use consistent versions** across the dependency tree where possible
- **Test compatibility** combinations before committing
- **Document assumptions** in commit messages about why specific versions are compatible

#### Validation

After completing migration:
1. **Test recursive cloning** from a clean workspace
2. **Verify build compatibility** with the fetched dependencies  
3. **Check dependency resolution** - LsiGitCheckout should handle any conflicts gracefully
4. **Document the migration** for your team

### Next Steps

Once your dependency tree is migrated:
- Explore [recursive mode and dependency resolution modes](../README.md#advanced-usage-recursive-mode) for configuration options
- Review [API compatibility modes](../README.md#api-compatibility-modes) to optimize conflict resolution  
- Set up [SSH authentication](../README.md#ssh-setup-with-putty) if using private repositories
- Configure your build system to use the LsiGitCheckout-managed dependencies
- Consider adding [post-checkout scripts](../README.md#post-checkout-scripts) for automated dependency installation

The bottom-up migration approach ensures that your entire dependency tree becomes manageable through LsiGitCheckout while maintaining the ability to resolve version conflicts intelligently as your project evolves.

## Migrating Existing Dependency Trees to LsiGitCheckout (SemVer Mode)

The migration process for SemVer mode follows the same bottom-up approach as Agnostic mode, but leverages Semantic Versioning 2.0.0 rules for automatic compatibility resolution instead of explicit API Compatible Tags lists.

### SemVer Migration Strategy: Bottom-Up Approach

The key principle remains the same: **start from the penultimate level** and work your way up to the root project. However, with SemVer mode, you don't need to maintain explicit API Compatible Tags - the script automatically determines compatibility based on semantic versioning rules.

#### Basic SemVer Concept

1. **Identify Dependency Levels**: Map out your dependency tree (same as Agnostic mode)
2. **Prepare Leaf Dependencies**: Ensure leaf repositories have appropriate semantic version tags
3. **Start at Penultimate Level**: Begin with repositories that depend directly on leaf nodes
4. **Add SemVer Dependencies Files**: For each level, add `dependencies.json` files with SemVer configuration
5. **Tag with Semantic Versions**: Create semantic version tags for each level
6. **Work Upward**: Repeat until you reach your root project

#### The SemVer Migration Process

```
Level 3 (Root):     ProjectMain
                       │
Level 2:           SubProjectA ──── SubProjectB
                       │               │
Level 1:           LibraryCore ──── UtilityLib ──── CommonLib
                       │
Level 0 (Leaf):    BaseFoundation
```

**Migration Order**: Same as Agnostic mode - ensure Level 0 has semantic version tags, then start with Level 1.

### Practical SemVer Example

Let's walk through migrating the same dependency tree using SemVer mode. This assumes the same starting state as the Agnostic example.

#### Current Dependency Tree and Semantic Versions

```
Level 3 (Root):             MyApplication (v0.9.2)
                                 │
                   ┌─────────────┴─────────────┐
                   │                           │
Level 2:     UserInterface (v4.1.3)    BusinessLogic (v4.5.1)
                   │                           │
                   │                    ┌──────┴──────┐
                   │                    │             │
Level 1:     CommonControls (v3.0.8) ────────┐   DataAccess (v2.2.5)
                   │                         │        │
                   └─────────────────────────┼────────┘
                                             │
Level 0 (Leaf):                     DatabaseUtils (v1.2.0)
                                          (leaf)
```

#### Current Directory Structure (Same as Agnostic)

The directory structure remains identical to the Agnostic mode example.

#### SemVer Migration Target: New Semantic Versions

The migration process will create new semantic version tags for each repository (except leaf dependencies):

- **MyApplication**: existing `v0.9.2` → needs new tag `v1.0.0` (major release with LsiGitCheckout)
- **UserInterface**: existing `v4.1.3` → needs new tag `v4.2.0` (minor release with dependencies)  
- **BusinessLogic**: existing `v4.5.1` → needs new tag `v4.6.0` (minor release)
- **DataAccess**: existing `v2.2.5` → needs new tag `v2.3.0` (minor release with dependencies)
- **CommonControls**: existing `v3.0.8` → needs new tag `v3.1.0` (minor release with dependencies)
- **DatabaseUtils**: existing `v1.2.0` → **no new tag needed** (leaf dependency)

#### Step 1: Prepare Leaf Dependencies (DatabaseUtils)

DatabaseUtils already has semantic version tag `v1.2.0` which will be referenced by other repositories. Since it's a leaf dependency, we do **not** add a `dependencies.json` file.

```powershell
Set-Location DatabaseUtils
git tag --list  # Verify v1.2.0 exists and follows semantic versioning
# No changes needed for leaf dependencies
```

#### Step 2: Configure Penultimate Level Dependencies (Level 1) - SemVer Mode

Now we start adding `dependencies.json` files with SemVer configuration, beginning with repositories that depend directly on leaf nodes.

**Important Note About SemVer Migration:**
During SemVer migration, we specify exact version requirements using the "Version" field. The script will automatically find compatible versions based on SemVer rules, eliminating the need for explicit API Compatible Tags.

##### Configure DataAccess (SemVer Mode)

**Current tag**: `v2.2.5` → **New tag**: `v2.3.0` (minor version bump for adding dependencies)

```powershell
Set-Location DataAccess
```

Create `dependencies.json` with SemVer configuration:
```json
[
  {
    "Repository URL": "https://github.com/yourorg/DatabaseUtils.git",
    "Base Path": "../shared/database-utils",
    "Dependency Resolution": "SemVer",
    "Version": "1.2.0"
  }
]
```

Commit and tag:
```powershell
git add dependencies.json
git commit -m "Add LsiGitCheckout SemVer dependencies configuration"
git tag v2.3.0  # Minor version bump, compatible with v2.2.5
git push origin v2.3.0
```

##### Configure CommonControls (SemVer Mode)

**Current tag**: `v3.0.8` → **New tag**: `v3.1.0` (minor version bump for adding dependencies)

```powershell
Set-Location ..\CommonControls
```

Create `dependencies.json` with SemVer configuration:
```json
[
  {
    "Repository URL": "https://github.com/yourorg/DatabaseUtils.git",
    "Base Path": "../shared/database-utils",
    "Dependency Resolution": "SemVer",
    "Version": "1.2.0"
  }
]
```

Commit and tag:
```powershell
git add dependencies.json
git commit -m "Add LsiGitCheckout SemVer dependencies configuration"
git tag v3.1.0  # Minor version bump, compatible with v3.0.8
git push origin v3.1.0
```

#### Step 3: Configure Level 2 Dependencies (SemVer Mode)

##### Configure UserInterface (SemVer Mode)

**Current tag**: `v4.1.3` → **New tag**: `v4.2.0` (minor version bump for adding dependencies)

```powershell
Set-Location ..\UserInterface
```

Create `dependencies.json` with SemVer configuration:
```json
[
  {
    "Repository URL": "https://github.com/yourorg/CommonControls.git",
    "Base Path": "../shared/common-controls",
    "Dependency Resolution": "SemVer",
    "Version": "3.1.0"
  }
]
```

Commit and tag:
```powershell
git add dependencies.json
git commit -m "Add LsiGitCheckout SemVer dependencies configuration"
git tag v4.2.0  # Minor version bump, compatible with v4.1.3
git push origin v4.2.0
```

##### Configure BusinessLogic (SemVer Mode)

**Current tag**: `v4.5.1` → **New tag**: `v4.6.0` (minor version bump)

```powershell
Set-Location ..\BusinessLogic
```

Create `dependencies.json` with SemVer configuration:
```json
[
  {
    "Repository URL": "https://github.com/yourorg/DataAccess.git",
    "Base Path": "libs/data-access",
    "Dependency Resolution": "SemVer",
    "Version": "2.3.0"
  },
  {
    "Repository URL": "https://github.com/yourorg/CommonControls.git",
    "Base Path": "../shared/common-controls",
    "Dependency Resolution": "SemVer",
    "Version": "3.1.0"
  }
]
```

Commit and tag:
```powershell
git add dependencies.json
git commit -m "Add LsiGitCheckout SemVer dependencies configuration"
git tag v4.6.0  # Minor version bump - API compatible with v4.5.1
git push origin v4.6.0
```

#### Step 4: Configure Root Project (MyApplication) - SemVer Mode

**Current tag**: `v0.9.2` → **New tag**: `v1.0.0` (major version bump for significant migration to LsiGitCheckout)

```powershell
Set-Location ..\MyApplication
```

Create `dependencies.json` with SemVer configuration:
```json
[
  {
    "Repository URL": "https://github.com/yourorg/UserInterface.git",
    "Base Path": "modules/user-interface",
    "Dependency Resolution": "SemVer",
    "Version": "4.2.0"
  },
  {
    "Repository URL": "https://github.com/yourorg/BusinessLogic.git", 
    "Base Path": "modules/business-logic",
    "Dependency Resolution": "SemVer",
    "Version": "4.6.0"
  }
]
```

Commit and tag:
```powershell
git add dependencies.json
git commit -m "Add LsiGitCheckout SemVer dependencies configuration - Major migration to semantic dependency management"
git tag v1.0.0  # Major version for significant architectural change
git push origin v1.0.0
```

### Updated SemVer Dependency Tree After Migration

Here's the dependency tree showing both **old tags** (existing) and **new SemVer tags** (with LsiGitCheckout SemVer support):

```
                    MyApplication
                   v0.9.2 → v1.0.0
                         │
           ┌─────────────┴─────────────┐
           │                           │
     UserInterface              BusinessLogic
    v4.1.3 → v4.2.0            v4.5.1 → v4.6.0
           │                           │
           │                     ┌─────┴──────┐
           │                     │            │
     CommonControls              │        DataAccess
    v3.0.8 → v3.1.0 ─────────────┐      v2.2.5 → v2.3.0
           │                     │            │
           └─────────────────────┼────────────┘
                                 │
                         DatabaseUtils
                           v1.2.0
                         (unchanged)
```

### Step 5: Test Your SemVer Migration

Test that the SemVer migration worked correctly:

```powershell
# Navigate to a clean workspace
Set-Location C:\workspace\test-semver-migration
New-Item -ItemType Directory -Name "test-semver-migration" -Force
Set-Location test-semver-migration

# Clone and run LsiGitCheckout on your root project
git clone https://github.com/yourorg/MyApplication.git
Set-Location MyApplication
git checkout v1.0.0  # Use the new tag with LsiGitCheckout SemVer support

# Run LsiGitCheckout (assumes script is in PATH or current directory)
.\LsiGitCheckout.ps1

# Verify all dependencies were cloned recursively with correct versions
Get-ChildItem modules\      # Should show user-interface and business-logic
Get-ChildItem shared\       # Should show database-utils and common-controls (shared dependencies)
Get-ChildItem modules\business-logic\libs\    # Should show only data-access

# Verify the correct tags were checked out (same as Agnostic mode)
Set-Location modules\user-interface
git describe --tags  # Should show v4.2.0
Set-Location ..\business-logic  
git describe --tags  # Should show v4.6.0
Set-Location libs\data-access
git describe --tags  # Should show v2.3.0
Set-Location ..\..\..\shared\common-controls
git describe --tags  # Should show v3.1.0 (single shared location)
Set-Location ..\database-utils
git describe --tags  # Should show v1.2.0 (single shared location)
```

### Key SemVer Migration Tips

#### Advantages of SemVer Migration

1. **No API Compatible Tags Maintenance**: The script automatically determines compatible versions using SemVer rules
2. **Automatic Conflict Resolution**: When conflicts occur, you get detailed error messages showing exactly which versions are compatible
3. **Simplified Future Updates**: Adding new compatible versions requires only updating the "Version" field, not maintaining arrays
4. **Clear Compatibility Rules**: SemVer 2.0.0 rules provide consistent, predictable compatibility behavior

#### SemVer Version Requirements During Migration

When filling out the "Version" field **after migration**:

1. **Specify Minimum Requirements**: Set the minimum version that includes required features/fixes
2. **Follow SemVer Rules**: Understand that the script will accept any compatible version >= your requirement
3. **Consider Major Version Boundaries**: Be careful with major version requirements as they may cause conflicts
4. **Test Compatibility**: Verify that your code works with the version range that SemVer rules will allow

**Example for future SemVer updates**:
```powershell
Set-Location SomeLibrary
git tag --list | grep -E "^v[0-9]+\.[0-9]+\.[0-9]+$"  # List semantic version tags
# If you need features from v2.4.0, set "Version": "2.4.0"
# The script will automatically accept v2.4.0, v2.4.1, v2.5.0, etc. but not v3.0.0
```

#### Handling Version Tag Formats

If your repositories use non-standard version tag formats, specify a custom regex:

```json
{
  "Repository URL": "https://github.com/yourorg/CustomLib.git",
  "Base Path": "libs/custom",
  "Dependency Resolution": "SemVer",
  "Version": "1.5.0",
  "Version Regex": "^release-(\\d+)\\.(\\d+)\\.(\\d+)$"
}
```

#### Validation for SemVer Migration

After completing SemVer migration:
1. **Test recursive cloning** from a clean workspace
2. **Verify SemVer conflict resolution** by temporarily creating incompatible version requirements
3. **Validate version selection** - confirm the script selects the lowest compatible version
4. **Test future version updates** by adding new compatible tags and verifying automatic resolution

### SemVer vs Agnostic Migration Comparison

| Aspect | Agnostic Mode | SemVer Mode |
|--------|---------------|-------------|
| **Configuration Complexity** | Higher (explicit API Compatible Tags) | Lower (just Version field) |
| **Maintenance Overhead** | Manual tag list maintenance | Automatic compatibility resolution |
| **Flexibility** | Maximum control over compatibility | Follows strict SemVer rules |
| **Version Requirements** | Must follow semantic versioning strictly | More flexible with version formats |
| **Conflict Resolution** | Intersection/Union algorithms | SemVer compatibility rules |
| **Future Updates** | Manual API Compatible Tags updates | Automatic based on version requirements |

### When to Choose Each Mode

**Choose SemVer Mode When:**
- Your repositories follow semantic versioning consistently
- You want to reduce maintenance overhead
- You prefer automatic compatibility resolution
- Your team understands SemVer rules well

**Choose Agnostic Mode When:**
- You need fine-grained control over compatibility
- Your repositories don't follow strict semantic versioning
- You have complex compatibility relationships
- You're migrating legacy systems with non-standard versioning

### Next Steps for SemVer Migration

Once your SemVer dependency tree is migrated:
- Ensure all new tags follow semantic versioning conventions
- Educate your team on SemVer 2.0.0 rules
- Set up processes to maintain semantic versioning discipline
- Consider using tools to validate semantic version bumps
- Monitor SemVer conflict resolution in practice

The SemVer migration approach provides the same dependency management benefits as Agnostic mode while significantly reducing configuration complexity and maintenance overhead through automatic compatibility resolution.

## Handling Shared Dependencies Version Changes

Once you have successfully migrated your dependency tree to LsiGitCheckout, you'll need to manage version changes in shared dependencies over time. This section demonstrates how to handle both API-compatible updates and API-breaking changes using the dependency tree from the migration example.

### Starting Point: Post-Migration Dependency Tree

After completing the migration example, we have this dependency tree with LsiGitCheckout support:

```
                    MyApplication
                      v1.0.0
                         │
           ┌─────────────┴─────────────┐
           │                           │
     UserInterface              BusinessLogic
        v4.2.0                      v4.6.0
           │                           │
           │                   ┌───────┴──────┐
           │                   │              │
     CommonControls            │          DataAccess
        v3.1.0 ────────────────┘            v2.3.0
           │                                  │
           └──────────────────────────────────┘
                               │
                          DatabaseUtils
                            v1.2.0
```

All repositories except DatabaseUtils contain `dependencies.json` files with LsiGitCheckout configuration.

### Scenario 1: API-Compatible Update (v1.2.0 → v1.2.1)

Let's assume DatabaseUtils releases a bug-fix version v1.2.1 that is fully API-compatible with v1.2.0. This is a straightforward update that requires minimal changes.

#### Step 1: Update Direct Dependencies

We need to update the repositories that directly depend on DatabaseUtils: **DataAccess** and **CommonControls**.

##### Update DataAccess

Since v1.2.1 is API-compatible with v1.2.0, we can add the old version to the "API Compatible Tags" array:

```powershell
Set-Location DataAccess
```

Update `dependencies.json`:
```json
[
  {
    "Repository URL": "https://github.com/yourorg/DatabaseUtils.git",
    "Base Path": "../shared/database-utils",
    "Tag": "v1.2.1",
    "API Compatible Tags": ["v1.2.0"]
  }
]
```

Commit and create a new tag:
```powershell
git add dependencies.json
git commit -m "Update DatabaseUtils to v1.2.1 (API compatible bug fix)"
git tag v2.3.1  # Minor version bump for compatible dependency update
git push origin v2.3.1
```

##### Update CommonControls

```powershell
Set-Location ..\CommonControls
```

Update `dependencies.json`:
```json
[
  {
    "Repository URL": "https://github.com/yourorg/DatabaseUtils.git",
    "Base Path": "../shared/database-utils",
    "Tag": "v1.2.1",
    "API Compatible Tags": ["v1.2.0"]
  }
]
```

Commit and tag:
```powershell
git add dependencies.json
git commit -m "Update DatabaseUtils to v1.2.1 (API compatible bug fix)"
git tag v3.1.1  # Minor version bump for compatible dependency update
git push origin v3.1.1
```

#### Step 2: Update Indirect Dependencies

Now we update the repositories that depend on DataAccess and CommonControls.

##### Update UserInterface

```powershell
Set-Location ..\UserInterface
```

Update `dependencies.json`:
```json
[
  {
    "Repository URL": "https://github.com/yourorg/CommonControls.git",
    "Base Path": "../shared/common-controls",
    "Tag": "v3.1.1",
    "API Compatible Tags": ["v3.1.0"]
  }
]
```

Commit and tag:
```powershell
git add dependencies.json
git commit -m "Update CommonControls to v3.1.1 (includes DatabaseUtils v1.2.1 bug fix)"
git tag v4.2.1  # Minor version bump for transitive dependency update
git push origin v4.2.1
```

##### Update BusinessLogic

```powershell
Set-Location ..\BusinessLogic
```

Update `dependencies.json`:
```json
[
  {
    "Repository URL": "https://github.com/yourorg/DataAccess.git",
    "Base Path": "libs/data-access",
    "Tag": "v2.3.1",
    "API Compatible Tags": ["v2.3.0"]
  },
  {
    "Repository URL": "https://github.com/yourorg/CommonControls.git",
    "Base Path": "../shared/common-controls",
    "Tag": "v3.1.1",
    "API Compatible Tags": ["v3.1.0"]
  }
]
```

Commit and tag:
```powershell
git add dependencies.json
git commit -m "Update dependencies for DatabaseUtils v1.2.1 bug fix"
git tag v4.6.1  # Minor version bump for transitive dependency update
git push origin v4.6.1
```

#### Step 3: Update Root Application

```powershell
Set-Location ..\MyApplication
```

Update `dependencies.json`:
```json
[
  {
    "Repository URL": "https://github.com/yourorg/UserInterface.git",
    "Base Path": "modules/user-interface",
    "Tag": "v4.2.1",
    "API Compatible Tags": ["v4.2.0"]
  },
  {
    "Repository URL": "https://github.com/yourorg/BusinessLogic.git", 
    "Base Path": "modules/business-logic",
    "Tag": "v4.6.1",
    "API Compatible Tags": ["v4.6.0"]
  }
]
```

Commit and tag:
```powershell
git add dependencies.json
git commit -m "Update to get DatabaseUtils v1.2.1 bug fix throughout dependency tree"
git tag v1.0.1  # Patch version bump for bug fix propagation
git push origin v1.0.1
```

#### Result: Updated Dependency Tree (API-Compatible)

```
                    MyApplication
                   v1.0.0 → v1.0.1
                         │
           ┌─────────────┴─────────────┐
           │                           │
     UserInterface              BusinessLogic
    v4.2.0 → v4.2.1            v4.6.0 → v4.6.1
           │                           │
           │                     ┌─────┴──────┐
           │                     │            │
     CommonControls              │        DataAccess
    v3.1.0 → v3.1.1 ─────────────┘       v2.3.0 → v2.3.1
           │                                  │
           └──────────────────────────────────┘
                                 │
                         DatabaseUtils
                       v1.2.0 → v1.2.1
```

**Key Benefits of This Approach:**
- All new tags are API-compatible with their predecessors
- LsiGitCheckout will intelligently resolve to the latest compatible versions
- Gradual rollout is possible by updating dependencies incrementally
- Rollback is easy due to preserved API compatibility

### Scenario 2: API-Breaking Update (v1.2.1 → v2.0.0)

Now let's assume DatabaseUtils releases v2.0.0 with breaking API changes that provide enhanced capabilities. This requires more careful handling, but the version bumps depend on whether each repository's own API changes.

#### Step 1: Analyze Impact and Plan Migration

Before making changes, analyze which parts of your codebase will be affected:

1. **Review DatabaseUtils v2.0.0 changes** to understand the breaking changes and new capabilities
2. **Test compatibility** with DataAccess and CommonControls
3. **Determine API impact** - which repositories need to change their own APIs vs. just internal implementation

For this example, let's assume:
- **DatabaseUtils v2.0.0** provides enhanced capabilities with breaking API changes
- **DataAccess** can leverage the new capabilities without changing its own API
- **CommonControls** can use enhanced logging features without changing its own API
- **Higher-level repositories** don't change their APIs but benefit from the enhanced capabilities

#### Step 2: Update Direct Dependencies (Internal Changes Only)

##### Update DataAccess (No API Changes)

```powershell
Set-Location DataAccess
```

Make internal implementation changes to use DatabaseUtils v2.0.0 enhanced capabilities, but keep DataAccess API unchanged:

```json
[
  {
    "Repository URL": "https://github.com/yourorg/DatabaseUtils.git",
    "Base Path": "../shared/database-utils",
    "Tag": "v2.0.0",
    "API Compatible Tags": []
  }
]
```

**Important Note:** The "API Compatible Tags" array is empty because DatabaseUtils v2.0.0 is not compatible with any v1.x versions.

Commit and tag with **minor version bump** (API unchanged):
```powershell
git add .  # Add all code changes + dependencies.json
git commit -m "Update to DatabaseUtils v2.0.0 with enhanced capabilities

- Updated internal database connection handling for new API
- Leveraged improved query performance features
- Enhanced error handling with new exception types
- Public API remains unchanged - internal improvements only"
git tag v2.4.0  # Minor version bump - API unchanged, enhanced capabilities
git push origin v2.4.0
```

##### Update CommonControls (No API Changes)

```powershell
Set-Location ..\CommonControls
```

Make internal changes to leverage enhanced DatabaseUtils features:

```json
[
  {
    "Repository URL": "https://github.com/yourorg/DatabaseUtils.git",
    "Base Path": "../shared/database-utils",
    "Tag": "v2.0.0",
    "API Compatible Tags": []
  }
]
```

Commit and tag with **minor version bump**:
```powershell
git add .
git commit -m "Update to DatabaseUtils v2.0.0 for enhanced logging

- Improved internal logging using new DatabaseUtils capabilities
- Enhanced configuration loading performance
- Public API remains unchanged - internal improvements only"
git tag v3.2.0  # Minor version bump - API unchanged, enhanced capabilities  
git push origin v3.2.0
```

#### Step 3: Update Indirect Dependencies (No API Changes)

##### Update UserInterface (No API Changes)

```powershell
Set-Location ..\UserInterface
```

Update dependency reference (no code changes needed):

```json
[
  {
    "Repository URL": "https://github.com/yourorg/CommonControls.git",
    "Base Path": "../shared/common-controls",
    "Tag": "v3.2.0",
    "API Compatible Tags": ["v3.1.0", "v3.1.1"]
  }
]
```

**Note:** UserInterface benefits from enhanced CommonControls capabilities without changing its own API.

Commit and tag with **minor version bump**:
```powershell
git add dependencies.json
git commit -m "Update to CommonControls v3.2.0 for enhanced capabilities

- Benefits from improved logging and performance in CommonControls
- Transitively benefits from DatabaseUtils v2.0.0 enhancements
- Public API remains unchanged"
git tag v4.3.0  # Minor version bump - API unchanged, enhanced capabilities
git push origin v4.3.0
```

##### Update BusinessLogic (No API Changes)


```powershell
Set-Location ..\BusinessLogic
```

Update both dependencies:

```json
[
  {
    "Repository URL": "https://github.com/yourorg/DataAccess.git",
    "Base Path": "libs/data-access",
    "Tag": "v2.4.0",
    "API Compatible Tags": ["v2.3.0", "v2.3.1"]
  },
  {
    "Repository URL": "https://github.com/yourorg/CommonControls.git",
    "Base Path": "../shared/common-controls",
    "Tag": "v3.2.0", 
    "API Compatible Tags": ["v3.1.0", "v3.1.1"]
  }
]
```

Commit and tag with **minor version bump**:
```powershell
git add dependencies.json
git commit -m "Update dependencies for DatabaseUtils v2.0.0 enhanced capabilities

- Benefits from improved DataAccess v2.4.0 performance
- Leverages enhanced CommonControls v3.2.0 features
- Transitively benefits from DatabaseUtils v2.0.0 enhancements
- Public API remains unchanged"
git tag v4.7.0  # Minor version bump - API unchanged, enhanced capabilities
git push origin v4.7.0
```

#### Step 4: Update Root Application (No API Changes)

```powershell
Set-Location ..\MyApplication
```

Update `dependencies.json`:

```json
[
  {
    "Repository URL": "https://github.com/yourorg/UserInterface.git",
    "Base Path": "modules/user-interface",
    "Tag": "v4.3.0",
    "API Compatible Tags": ["v4.2.0", "v4.2.1"]
  },
  {
    "Repository URL": "https://github.com/yourorg/BusinessLogic.git", 
    "Base Path": "modules/business-logic",
    "Tag": "v4.7.0",
    "API Compatible Tags": ["v4.6.0", "v4.6.1"]
  }
]
```

Commit and tag with **minor version bump**:
```powershell
git add dependencies.json
git commit -m "Update to get DatabaseUtils v2.0.0 enhanced capabilities throughout tree

- Benefits from enhanced UserInterface v4.3.0 performance
- Leverages improved BusinessLogic v4.7.0 features  
- Complete migration to DatabaseUtils v2.0.0 enhanced capabilities
- Application API remains unchanged"
git tag v1.1.0  # Minor version bump - API unchanged, enhanced capabilities
git push origin v1.1.0
```

#### Result: Updated Dependency Tree (Enhanced Capabilities, APIs Unchanged)

```
                    MyApplication
                   v1.0.1 → v1.1.0
                         │
           ┌─────────────┴─────────────┐
           │                           │
     UserInterface              BusinessLogic
    v4.2.1 → v4.3.0            v4.6.1 → v4.7.0
           │                           │
           │                     ┌─────┴──────┐
           │                     │            │
     CommonControls              │        DataAccess
    v3.1.1 → v3.2.0 ─────────────┘       v2.3.1 → v2.4.0
           │                                  │
           └──────────────────────────────────┘
                                 │
                         DatabaseUtils
                       v1.2.1 → v2.0.0
```

#### Alternative: When APIs Do Change

If some repositories needed to expose new capabilities or change their APIs, they would get **major version bumps**:

```
Example if DataAccess exposed new API features:
DataAccess: v2.3.1 → v3.0.0 (major - new API features)
BusinessLogic: v4.6.1 → v5.0.0 (major - uses new DataAccess API)
MyApplication: v1.0.1 → v2.0.0 (major - uses new BusinessLogic API)

Example if only internal enhancements (as shown above):
DataAccess: v2.3.1 → v2.4.0 (minor - internal improvements only)
BusinessLogic: v4.6.1 → v4.7.0 (minor - benefits from improvements)
MyApplication: v1.0.1 → v1.1.0 (minor - benefits from improvements)
```

### Key Differences Between Compatible and Breaking Updates

#### API-Compatible Updates (v1.2.0 → v1.2.1)
- **Version Bumps**: Minor/patch versions throughout the tree
- **API Compatible Tags**: Previous versions included in compatibility arrays
- **Rollback**: Easy due to preserved backward compatibility
- **Deployment**: Can be done incrementally
- **LsiGitCheckout Behavior**: Automatically resolves to latest compatible versions

#### Dependency Breaking Updates with Enhanced Capabilities (v1.2.1 → v2.0.0)
- **Version Bumps**: Minor versions when APIs don't change, major versions only when APIs change
- **API Compatible Tags**: Empty for the breaking dependency, but preserved for non-breaking dependents
- **Rollback**: Requires coordinated rollback, but easier than full API breaks
- **Deployment**: Can be coordinated but less risky than full API breaking changes
- **LsiGitCheckout Behavior**: Mix of automatic resolution (for API-compatible dependents) and explicit choices (for breaking dependency)

### Best Practices for Shared Dependency Updates

#### For API-Compatible Updates
1. **Start from the bottom** (leaf dependencies) and work upward
2. **Include previous versions** in API Compatible Tags
3. **Use minor/patch version bumps** for dependent repositories
4. **Test thoroughly** even for "compatible" changes
5. **Document changes** in commit messages
6. **Consider gradual rollout** across environments

#### For Dependency Breaking Updates (Enhanced Capabilities)
1. **Distinguish API changes from implementation changes** - only bump major versions when your repository's API actually changes
2. **Use minor version bumps** when benefiting from enhanced capabilities without changing your own API
3. **Preserve API Compatible Tags** for repositories that don't break their own APIs
4. **Document enhancement benefits** in commit messages
5. **Test thoroughly** to ensure enhanced capabilities work as expected
6. **Consider gradual rollout** to validate improvements

#### Version Numbering Strategy

**For Direct API Changes:**
- **Major bump** (1.0.0 → 2.0.0): When your repository's own API has breaking changes
- **Minor bump** (1.0.0 → 1.1.0): When your repository's own API gains new features
- **Patch bump** (1.0.0 → 1.0.1): When your repository's own API has bug fixes

**For Dependency Updates:**
- **Major bump**: Only when your repository's API must change due to dependency changes
- **Minor bump**: When updating to dependencies with enhanced capabilities but your API stays the same
- **Patch bump**: When updating to dependency bug fixes with no functional changes

**API Compatible Tags Guidelines:**
- **Include compatible versions**: Add older versions that your API can work with
- **Preserve for minor bumps**: Keep compatibility when your API doesn't change
- **Clear only for API breaks**: Empty the array only when your repository's API breaks compatibility
- **Test compatibility thoroughly**: Don't assume semantic versioning guarantees

#### Testing Strategy

1. **Unit test all changes** in each repository
2. **Integration test the complete tree** after updates
3. **Verify LsiGitCheckout resolution** works as expected
4. **Test rollback scenarios** for both compatible and breaking changes
5. **Validate in staging environments** before production deployment

This systematic approach ensures that shared dependency updates are managed safely and predictably, whether they're simple bug fixes or major API overhauls.

## Handling Shared Dependencies Version Changes (SemVer Mode)

Once you have migrated your dependency tree to SemVer mode, managing version changes becomes significantly simpler due to automatic compatibility resolution. This section demonstrates how SemVer mode handles the same scenarios as Agnostic mode but with reduced manual overhead.

### Starting Point: Post-SemVer Migration Dependency Tree

After completing the SemVer migration example, we have this dependency tree with SemVer LsiGitCheckout support:

```
                    MyApplication
                      v1.0.0 (SemVer)
                         │
           ┌─────────────┴─────────────┐
           │                           │
     UserInterface              BusinessLogic
      v4.2.0 (SemVer)              v4.6.0 (SemVer)
           │                           │
           │                   ┌───────┴──────┐
           │                   │              │
     CommonControls            │          DataAccess
      v3.1.0 (SemVer) ─────────┘          v2.3.0 (SemVer)
           │                                  │
           └──────────────────────────────────┘
                               │
                         DatabaseUtils
                          v1.2.0 (leaf)
```

All repositories except DatabaseUtils contain `dependencies.json` files with SemVer LsiGitCheckout configuration.

### Scenario 1: SemVer Compatible Update (v1.2.0 → v1.2.1)

Let's assume DatabaseUtils releases a patch version v1.2.1 that follows semantic versioning (bug fixes only, no breaking changes). With SemVer mode, this update is dramatically simpler than Agnostic mode.

#### The SemVer Advantage: Automatic Compatibility

**Key Insight**: With SemVer mode, when DatabaseUtils releases v1.2.1, **no configuration changes are needed** in any dependent repositories. The existing `"Version": "1.2.0"` requirements automatically accept v1.2.1 due to SemVer compatibility rules.

**Complete Update Process for SemVer Compatible Changes:**

1. **DatabaseUtils**: Release v1.2.1 (patch version)
2. **All dependent repositories**: No changes needed
3. **Next LsiGitCheckout run**: Automatically uses v1.2.1 when available

**Result**: The entire dependency tree automatically benefits from the bug fixes in v1.2.1 without any manual configuration updates.

#### Optional: Updating Minimum Version Requirements

If you specifically want to require v1.2.1 (for example, to ensure specific bug fixes are present), you can optionally update the minimum version requirements:

##### Update DataAccess (Optional)

```powershell
Set-Location DataAccess
```

Update `dependencies.json` (optional):
```json
[
  {
    "Repository URL": "https://github.com/yourorg/DatabaseUtils.git",
    "Base Path": "../shared/database-utils",
    "Dependency Resolution": "SemVer",
    "Version": "1.2.1"
  }
]
```

Commit and create a new tag:
```powershell
git add dependencies.json
git commit -m "Update DatabaseUtils minimum version to v1.2.1 for specific bug fixes"
git tag v2.3.1  # Minor version bump for dependency requirement change
git push origin v2.3.1
```

**Important**: This step is optional. Without any updates, SemVer mode will automatically use v1.2.1 when it becomes available.

#### Result: Updated SemVer Dependency Tree (Automatic Compatible Update)

With SemVer mode, the dependency tree automatically benefits from v1.2.1 without any configuration changes:

```
                    MyApplication
                      v1.0.0 (SemVer) - automatically uses latest compatible versions
                         │
           ┌─────────────┴─────────────┐
           │                           │
     UserInterface              BusinessLogic
      v4.2.0 (SemVer)              v4.6.0 (SemVer)
           │                           │
           │                   ┌───────┴──────┐
           │                   │              │
     CommonControls            │          DataAccess
      v3.1.0 (SemVer) ─────────┘          v2.3.0 (SemVer)
           │                                  │
           └──────────────────────────────────┘
                               │
                         DatabaseUtils
                       v1.2.0 → v1.2.1 (leaf)
```

**Key Benefits of SemVer Approach:**
- **Zero configuration changes required**: All dependencies automatically accept v1.2.1
- **Immediate availability**: As soon as v1.2.1 is available, the entire tree benefits
- **No maintenance overhead**: No API Compatible Tags to update
- **Clear semantics**: SemVer rules guarantee compatibility

### Scenario 2: SemVer Breaking Update (v1.2.1 → v2.0.0)

Now let's assume DatabaseUtils releases v2.0.0 with breaking API changes. SemVer mode provides clear conflict detection and resolution guidance.

#### Step 1: Analyze SemVer Impact and Plan Migration

Before making changes, the major version bump to v2.0.0 signals breaking changes. We need to:

1. **Review DatabaseUtils v2.0.0 changes** to understand the breaking changes
2. **Test compatibility** with DataAccess and CommonControls  
3. **Update code as needed** to handle the new API
4. **Decide on version strategy** for each repository

For this example, let's assume:
- **DatabaseUtils v2.0.0** has breaking API changes but provides enhanced capabilities
- **DataAccess** can be updated to use the new API without changing its own public API
- **CommonControls** can be updated to use new features without changing its own public API  
- **Higher-level repositories** don't change their APIs but benefit from the enhanced capabilities

#### Step 2: Update Direct Dependencies (SemVer Mode)

##### Update DataAccess (No Public API Changes)

```powershell
Set-Location DataAccess
```

Make internal implementation changes to use DatabaseUtils v2.0.0, then update dependencies:

```json
[
  {
    "Repository URL": "https://github.com/yourorg/DatabaseUtils.git",
    "Base Path": "../shared/database-utils",
    "Dependency Resolution": "SemVer",
    "Version": "2.0.0"
  }
]
```

Commit and tag with **minor version bump** (public API unchanged):
```powershell
git add .  # Add all code changes + dependencies.json
git commit -m "Update to DatabaseUtils v2.0.0 with enhanced capabilities

- Updated internal database connection handling for new API
- Leveraged improved query performance features  
- Enhanced error handling with new exception types
- Public API remains unchanged - internal improvements only"
git tag v2.4.0  # Minor version bump - public API unchanged, enhanced capabilities
git push origin v2.4.0
```

##### Update CommonControls (No Public API Changes)

```powershell
Set-Location ..\CommonControls
```

Make internal changes to leverage enhanced DatabaseUtils features:

```json
[
  {
    "Repository URL": "https://github.com/yourorg/DatabaseUtils.git",
    "Base Path": "../shared/database-utils",
    "Dependency Resolution": "SemVer",
    "Version": "2.0.0"
  }
]
```

Commit and tag with **minor version bump**:
```powershell
git add .
git commit -m "Update to DatabaseUtils v2.0.0 for enhanced logging

- Improved internal logging using new DatabaseUtils capabilities
- Enhanced configuration loading performance
- Public API remains unchanged - internal improvements only"
git tag v3.2.0  # Minor version bump - public API unchanged, enhanced capabilities  
git push origin v3.2.0
```

#### Step 3: Update Indirect Dependencies (SemVer Mode)

##### Update UserInterface (No API Changes)

```powershell
Set-Location ..\UserInterface
```

Update dependency reference (no code changes needed):

```json
[
  {
    "Repository URL": "https://github.com/yourorg/CommonControls.git",
    "Base Path": "../shared/common-controls",
    "Dependency Resolution": "SemVer",
    "Version": "3.2.0"
  }
]
```

**Note**: SemVer automatically maintains compatibility with v3.1.0

Commit and tag with **minor version bump**:
```powershell
git add dependencies.json
git commit -m "Update to CommonControls v3.2.0 for enhanced capabilities

- Benefits from improved logging and performance in CommonControls
- Transitively benefits from DatabaseUtils v2.0.0 enhancements
- Public API remains unchanged"
git tag v4.3.0  # Minor version bump - public API unchanged, enhanced capabilities
git push origin v4.3.0
```

##### Update BusinessLogic (No API Changes)

```powershell
Set-Location ..\BusinessLogic
```

Update both dependencies:

```json
[
  {
    "Repository URL": "https://github.com/yourorg/DataAccess.git",
    "Base Path": "libs/data-access",
    "Dependency Resolution": "SemVer",
    "Version": "2.4.0"
  },
  {
    "Repository URL": "https://github.com/yourorg/CommonControls.git",
    "Base Path": "../shared/common-controls",
    "Dependency Resolution": "SemVer", 
    "Version": "3.2.0"
  }
]
```

**Note**: SemVer automatically maintains compatibility with previous versions (v2.3.0 for DataAccess and v3.1.0 for CommonControls)

Commit and tag with **minor version bump**:
```powershell
git add dependencies.json
git commit -m "Update dependencies for DatabaseUtils v2.0.0 enhanced capabilities

- Benefits from improved DataAccess v2.4.0 performance
- Leverages enhanced CommonControls v3.2.0 features
- Transitively benefits from DatabaseUtils v2.0.0 enhancements
- Public API remains unchanged"
git tag v4.7.0  # Minor version bump - public API unchanged, enhanced capabilities
git push origin v4.7.0
```

#### Step 4: Update Root Application (SemVer Mode)

```powershell
Set-Location ..\MyApplication
```

Update `dependencies.json`:

```json
[
  {
    "Repository URL": "https://github.com/yourorg/UserInterface.git",
    "Base Path": "modules/user-interface",
    "Dependency Resolution": "SemVer",
    "Version": "4.3.0"
  },
  {
    "Repository URL": "https://github.com/yourorg/BusinessLogic.git",
    "Base Path": "modules/business-logic", 
    "Dependency Resolution": "SemVer",
    "Version": "4.7.0"
  }
]
```

**Note**: SemVer automatically maintains compatibility with v4.2.0 for UserInterface and v4.6.0 for BusinessLogic

Commit and tag with **minor version bump**:
```powershell
git add dependencies.json
git commit -m "Update to get DatabaseUtils v2.0.0 enhanced capabilities throughout tree

- Benefits from enhanced UserInterface v4.3.0 performance
- Leverages improved BusinessLogic v4.7.0 features
- Complete migration to DatabaseUtils v2.0.0 enhanced capabilities
- Application API remains unchanged"
git tag v1.1.0  # Minor version bump - public API unchanged, enhanced capabilities
git push origin v1.1.0
```

#### Result: Updated SemVer Dependency Tree (Enhanced Capabilities, APIs Unchanged)

```
                    MyApplication
                   v1.0.0 → v1.1.0 (SemVer)
                         │
           ┌─────────────┴─────────────┐
           │                           │
     UserInterface              BusinessLogic
    v4.2.0 → v4.3.0 (SemVer)    v4.6.0 → v4.7.0 (SemVer)
           │                           │
           │                     ┌─────┴──────┐
           │                     │            │
     CommonControls              │        DataAccess
    v3.1.0 → v3.2.0 (SemVer) ────┘       v2.3.0 → v2.4.0 (SemVer)
           │                                  │
           └──────────────────────────────────┘
                                 │
                         DatabaseUtils
                       v1.2.1 → v2.0.0 (leaf)
```

### Key Differences Between SemVer and Agnostic Updates

#### SemVer Compatible Updates (v1.2.0 → v1.2.1) 
- **Configuration**: **Zero changes required** - automatic compatibility via SemVer rules
- **Automatic Compatibility**: All existing version requirements automatically accept newer compatible versions
- **Rollback**: Easy due to SemVer compatibility guarantees
- **Deployment**: **Immediate availability** - entire tree benefits as soon as new version is released
- **LsiGitCheckout Behavior**: Automatically resolves to lowest compatible version that satisfies all requirements

#### SemVer Breaking Updates with Enhanced Capabilities (v1.2.1 → v2.0.0)
- **Clear Breaking Change Signal**: Major version bump clearly indicates breaking changes
- **Simplified Configuration**: No need to manage API Compatible Tags arrays
- **Automatic Conflict Detection**: Script automatically detects SemVer incompatibilities and provides detailed error messages
- **Version Strategy Clarity**: Each repository's version bump follows semantic versioning rules
- **Deployment Coordination**: Major version boundaries provide clear upgrade coordination points

### Best Practices for SemVer Shared Dependency Updates

#### For SemVer Compatible Updates (The Key Advantage)
1. **Embrace Automatic Compatibility**: For patch/minor updates, rely on SemVer automatic compatibility - no configuration changes needed
2. **Leverage Zero-Maintenance Updates**: The entire dependency tree automatically benefits from compatible updates
3. **Update Requirements Only When Necessary**: Only update minimum version requirements if you specifically need features/fixes from newer versions
4. **Trust SemVer Rules**: Semantic versioning guarantees compatibility within the same major version

#### For SemVer Breaking Updates
1. **Respect Major Version Boundaries**: Major version bumps signal breaking changes - handle them appropriately
2. **Distinguish Public vs Internal API Changes**: Only bump your major version if your public API breaks
3. **Use Minor Bumps for Internal Improvements**: When your public API remains stable despite dependency changes
4. **Coordinate Team Communication**: Major version updates require coordination across dependent teams
5. **Plan Migration Windows**: Major dependency updates need careful timing and testing

#### SemVer Version Strategy

**For Version Requirements:**
- **Be Conservative**: Specify the minimum version you actually need
- **Understand Implications**: Know that SemVer will automatically accept newer compatible versions
- **Consider Version Ranges**: Your specified version becomes the lower bound of an automatic range

**For Version Bumps:**
- **Follow SemVer Strictly**: Your version bumps signal compatibility to dependent repositories
- **Major for Breaking Changes**: Only when your public API has breaking changes
- **Minor for New Features**: When adding functionality without breaking existing API
- **Patch for Bug Fixes**: For bug fixes that don't change functionality

#### SemVer Conflict Resolution

When SemVer conflicts occur, the script provides detailed information:

```
SemVer conflict for repository 'https://github.com/yourorg/shared-lib.git':
No version satisfies all requirements:
- https://github.com/yourorg/app-a.git requests: 2.1.0 (compatible: v2.1.0, v2.1.1, v2.2.0)
- https://github.com/yourorg/app-b.git requests: 3.0.0 (compatible: v3.0.0, v3.1.0)
```

**Resolution strategies:**
1. **Update one requirement**: If app-a can work with v3.0.0, update its version requirement
2. **Coordinate version releases**: Release a v3.x compatible version of the code that app-a needs
3. **Use Agnostic mode**: For complex compatibility relationships that don't fit SemVer

#### Testing Strategy for SemVer

1. **Unit test all SemVer updates** in each repository
2. **Integration test version compatibility** across the dependency tree
3. **Verify automatic resolution** works as expected
4. **Test conflict scenarios** to understand error reporting
5. **Validate SemVer compliance** of your version bumps

### SemVer vs Agnostic Mode Summary

| Aspect | SemVer Mode | Agnostic Mode |
|--------|-------------|---------------|
| **Configuration Overhead** | Low (just Version field) | High (API Compatible Tags maintenance) |
| **Compatibility Rules** | Automatic (SemVer 2.0.0) | Manual (explicit tag lists) |
| **Conflict Detection** | Automatic with detailed reporting | Manual verification required |
| **Version Updates** | Simple version requirement changes | Complex tag list maintenance |
| **Flexibility** | Follows SemVer rules | Complete control over compatibility |
| **Learning Curve** | Requires SemVer understanding | Requires understanding of custom compatibility rules |

### When Each Mode Excels

**SemVer Mode is ideal when:**
- Your repositories follow semantic versioning consistently
- You want to reduce configuration maintenance overhead
- You prefer automatic compatibility resolution with clear rules
- Your team understands and follows SemVer 2.0.0 principles

**Agnostic Mode is better when:**
- You need fine-grained control over version compatibility
- Your repositories don't follow strict semantic versioning
- You have complex compatibility relationships that don't fit SemVer rules
- You're migrating legacy systems with inconsistent versioning approaches

Both modes provide sophisticated dependency management - choose based on your team's versioning practices and maintenance preferences.