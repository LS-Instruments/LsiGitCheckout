# Migration and Dependency Management Guide

This guide covers advanced scenarios for migrating existing projects to LsiGitCheckout and managing shared dependencies over time. Both Agnostic mode (explicit API Compatible Tags) and SemVer mode (automatic semantic versioning with floating versions) approaches are covered.

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
Level 1:     CommonControls (v3.0.8) ────────────   DataAccess (v2.2.5)
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
    v3.0.8 → v3.1.0 ─────────────┘       v2.2.5 → v2.3.0
           │                                  │
           └──────────────────────────────────┘
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

The migration process for SemVer mode follows the same bottom-up approach as Agnostic mode, but leverages Semantic Versioning 2.0.0 rules with floating version specifications for automatic compatibility resolution instead of explicit API Compatible Tags lists.

### SemVer Migration Strategy: Bottom-Up Approach with Floating Versions

The key principle remains the same: **start from the penultimate level** and work your way up to the root project. However, with SemVer mode using floating versions, you don't need to maintain explicit API Compatible Tags - the script automatically determines and uses compatible versions based on semantic versioning rules and floating version specifications.

#### Basic SemVer Concept with Floating Versions

1. **Identify Dependency Levels**: Map out your dependency tree (same as Agnostic mode)
2. **Prepare Leaf Dependencies**: Ensure leaf repositories have appropriate semantic version tags
3. **Start at Penultimate Level**: Begin with repositories that depend directly on leaf nodes
4. **Add SemVer Dependencies Files with Floating Versions**: For each level, add `dependencies.json` files with SemVer configuration using floating version specifications
5. **Tag with Semantic Versions**: Create semantic version tags for each level
6. **Work Upward**: Repeat until you reach your root project

#### The SemVer Migration Process with Floating Versions

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

### Practical SemVer Example with Floating Versions

Let's walk through migrating the same dependency tree using SemVer mode with floating versions. This assumes the same starting state as the Agnostic example.

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
Level 1:     CommonControls (v3.0.8) ────────────   DataAccess (v2.2.5)
                   │                         │        │
                   └─────────────────────────┼────────┘
                                             │
Level 0 (Leaf):                     DatabaseUtils (v1.2.0)
                                          (leaf)
```

#### Current Directory Structure (Same as Agnostic)

The directory structure remains identical to the Agnostic mode example.

#### SemVer Migration Target: New Semantic Versions with Floating Version Requirements

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

#### Step 2: Configure Penultimate Level Dependencies (Level 1) - SemVer Mode with Floating Versions

Now we start adding `dependencies.json` files with SemVer configuration using floating versions, beginning with repositories that depend directly on leaf nodes.

**Important Note About SemVer Migration with Floating Versions:**
During SemVer migration, we specify floating version requirements using the "Version" field with floating version syntax. This allows automatic updates for compatible versions while maintaining version boundaries.

##### Configure DataAccess (SemVer Mode with Floating Versions)

**Current tag**: `v2.2.5` → **New tag**: `v2.3.0` (minor version bump for adding dependencies)

```powershell
Set-Location DataAccess
```

Create `dependencies.json` with SemVer floating version configuration:
```json
[
  {
    "Repository URL": "https://github.com/yourorg/DatabaseUtils.git",
    "Base Path": "../shared/database-utils",
    "Dependency Resolution": "SemVer",
    "Version": "1.2.*"
  }
]
```

**Note**: `1.2.*` allows automatic updates to `v1.2.1`, `v1.2.2`, etc., but not `v1.3.0` or `v2.0.0`

Commit and tag:
```powershell
git add dependencies.json
git commit -m "Add LsiGitCheckout SemVer dependencies configuration with floating versions"
git tag v2.3.0  # Minor version bump, compatible with v2.2.5
git push origin v2.3.0
```

##### Configure CommonControls (SemVer Mode with Floating Versions)

**Current tag**: `v3.0.8` → **New tag**: `v3.1.0` (minor version bump for adding dependencies)

```powershell
Set-Location ..\CommonControls
```

Create `dependencies.json` with SemVer floating version configuration:
```json
[
  {
    "Repository URL": "https://github.com/yourorg/DatabaseUtils.git",
    "Base Path": "../shared/database-utils",
    "Dependency Resolution": "SemVer",
    "Version": "1.2.*"
  }
]
```

**Note**: Both DataAccess and CommonControls use the same floating version requirement, ensuring consistent dependency resolution.

Commit and tag:
```powershell
git add dependencies.json
git commit -m "Add LsiGitCheckout SemVer dependencies configuration with floating versions"
git tag v3.1.0  # Minor version bump, compatible with v3.0.8
git push origin v3.1.0
```

#### Step 3: Configure Level 2 Dependencies (SemVer Mode with Floating Versions)

##### Configure UserInterface (SemVer Mode with Floating Versions)

**Current tag**: `v4.1.3` → **New tag**: `v4.2.0` (minor version bump for adding dependencies)

```powershell
Set-Location ..\UserInterface
```

Create `dependencies.json` with SemVer floating version configuration:
```json
[
  {
    "Repository URL": "https://github.com/yourorg/CommonControls.git",
    "Base Path": "../shared/common-controls",
    "Dependency Resolution": "SemVer",
    "Version": "3.*"
  }
]
```

**Note**: `3.*` allows automatic updates to `v3.1.1`, `v3.2.0`, `v3.9.0`, but not `v4.0.0`

Commit and tag:
```powershell
git add dependencies.json
git commit -m "Add LsiGitCheckout SemVer dependencies configuration with floating versions"
git tag v4.2.0  # Minor version bump, compatible with v4.1.3
git push origin v4.2.0
```

##### Configure BusinessLogic (SemVer Mode with Floating Versions)

**Current tag**: `v4.5.1` → **New tag**: `v4.6.0` (minor version bump)

```powershell
Set-Location ..\BusinessLogic
```

Create `dependencies.json` with SemVer floating version configuration:
```json
[
  {
    "Repository URL": "https://github.com/yourorg/DataAccess.git",
    "Base Path": "libs/data-access",
    "Dependency Resolution": "SemVer",
    "Version": "2.*"
  },
  {
    "Repository URL": "https://github.com/yourorg/CommonControls.git",
    "Base Path": "../shared/common-controls",
    "Dependency Resolution": "SemVer",
    "Version": "3.*"
  }
]
```

**Note**: Both dependencies use floating ranges allowing automatic minor and patch updates.

Commit and tag:
```powershell
git add dependencies.json
git commit -m "Add LsiGitCheckout SemVer dependencies configuration with floating versions"
git tag v4.6.0  # Minor version bump - API compatible with v4.5.1
git push origin v4.6.0
```

#### Step 4: Configure Root Project (MyApplication) - SemVer Mode with Floating Versions

**Current tag**: `v0.9.2` → **New tag**: `v1.0.0` (major version bump for significant migration to LsiGitCheckout)

```powershell
Set-Location ..\MyApplication
```

Create `dependencies.json` with SemVer floating version configuration:
```json
[
  {
    "Repository URL": "https://github.com/yourorg/UserInterface.git",
    "Base Path": "modules/user-interface",
    "Dependency Resolution": "SemVer",
    "Version": "4.*"
  },
  {
    "Repository URL": "https://github.com/yourorg/BusinessLogic.git", 
    "Base Path": "modules/business-logic",
    "Dependency Resolution": "SemVer",
    "Version": "4.*"
  }
]
```

**Note**: Both dependencies use floating ranges for automatic compatible updates throughout the dependency tree.

Commit and tag:
```powershell
git add dependencies.json
git commit -m "Add LsiGitCheckout SemVer dependencies configuration with floating versions - Major migration to semantic dependency management"
git tag v1.0.0  # Major version for significant architectural change
git push origin v1.0.0
```

### Updated SemVer Dependency Tree After Migration with Floating Versions

Here's the dependency tree showing both **old tags** (existing) and **new SemVer tags** (with LsiGitCheckout SemVer floating version support):

```
                    MyApplication
                   v0.9.2 → v1.0.0 (4.*, 4.*)
                         │
           ┌─────────────┴─────────────┐
           │                           │
     UserInterface              BusinessLogic
    v4.1.3 → v4.2.0 (3.*)        v4.5.1 → v4.6.0 (2.*, 3.*)
           │                           │
           │                     ┌─────┴──────┐
           │                     │            │
     CommonControls              │        DataAccess
    v3.0.8 → v3.1.0 (1.2.*) ─────┘       v2.2.5 → v2.3.0 (1.2.*)
           │                                  │
           └──────────────────────────────────┘
                                 │
                         DatabaseUtils
                           v1.2.0
                         (unchanged)
```

**Legend for Floating Versions:**
- `1.2.*`: Accepts v1.2.x (patch updates only)
- `3.*`: Accepts v3.x.x but not v4.0.0+ (minor and patch updates)
- `4.*`: Accepts v4.x.x but not v5.0.0+ (minor and patch updates)

### Step 5: Test Your SemVer Migration with Floating Versions

Test that the SemVer migration with floating versions worked correctly:

```powershell
# Navigate to a clean workspace
Set-Location C:\workspace\test-semver-floating-migration
New-Item -ItemType Directory -Name "test-semver-floating-migration" -Force
Set-Location test-semver-floating-migration

# Clone and run LsiGitCheckout on your root project
git clone https://github.com/yourorg/MyApplication.git
Set-Location MyApplication
git checkout v1.0.0  # Use the new tag with LsiGitCheckout SemVer floating version support

# Run LsiGitCheckout (assumes script is in PATH or current directory)
.\LsiGitCheckout.ps1

# Verify all dependencies were cloned recursively with correct versions
Get-ChildItem modules\      # Should show user-interface and business-logic
Get-ChildItem shared\       # Should show database-utils and common-controls (shared dependencies)
Get-ChildItem modules\business-logic\libs\    # Should show only data-access

# Verify the correct tags were checked out (should use the specified versions from floating ranges)
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

### Key SemVer Migration Tips with Floating Versions

#### Advantages of SemVer Migration with Floating Versions

1. **No API Compatible Tags Maintenance**: The script automatically determines compatible versions using SemVer rules and floating version ranges
2. **Automatic Dependency Updates**: When new compatible versions are released, they are automatically used on the next LsiGitCheckout run
3. **Simplified Future Updates**: Adding new compatible versions requires no configuration changes
4. **Clear Compatibility Rules**: SemVer 2.0.0 rules with floating version syntax provide consistent, predictable compatibility behavior
5. **True Set-and-Forget**: Once configured, the dependency tree automatically stays up-to-date with compatible releases

#### Floating Version Requirements During Migration

When filling out the "Version" field with floating versions **after migration**:

1. **Choose Appropriate Ranges**: Select the floating version pattern that matches your compatibility needs:
   - `1.2.*` - Accept patch updates only (1.2.x)
   - `1.*` - Accept minor and patch updates (1.x.x, but not 2.0.0)
2. **Consider Stability vs Freshness**: Tighter ranges (patch-level) provide more stability, wider ranges (minor-level) provide fresher updates
3. **Test Compatibility Ranges**: Verify that your code works with the version range that your floating specification will allow
4. **Align Team Practices**: Ensure your team understands the floating version patterns being used

**Example floating version strategies**:
```powershell
# Conservative: patch updates only
"Version": "2.4.*"  # Accepts 2.4.0, 2.4.1, 2.4.2, but not 2.5.0

# Balanced: minor and patch updates  
"Version": "2.*"  # Accepts 2.4.0, 2.5.0, 2.9.0, but not 3.0.0

# Fixed version: specific version only
"Version": "2.4.1"  # Accepts only 2.4.1 (lowest applicable mode)
```

#### Validation for SemVer Migration with Floating Versions

After completing SemVer migration with floating versions:
1. **Test recursive cloning** from a clean workspace
2. **Verify floating version resolution** by creating new compatible versions and confirming automatic resolution
3. **Test version conflict scenarios** to understand error reporting
4. **Validate automatic updates** by releasing new patch/minor versions and confirming they are automatically used
5. **Monitor dependency freshness** to ensure floating versions are working as expected

### SemVer vs Agnostic Migration Comparison

| Aspect | Agnostic Mode | SemVer Mode (Floating Versions) |
|--------|---------------|--------------------------------|
| **Configuration Complexity** | Higher (explicit API Compatible Tags) | Lower (floating version patterns) |
| **Maintenance Overhead** | Manual tag list maintenance | Zero maintenance for compatible updates |
| **Flexibility** | Maximum control over compatibility | Follows SemVer rules with floating ranges |
| **Version Requirements** | Must follow semantic versioning strictly | More flexible with version formats |
| **Automatic Updates** | Manual updates required | Automatic for compatible versions |
| **Future Updates** | Manual API Compatible Tags updates | Automatic based on floating version ranges |

### When to Choose Each Mode

**Choose SemVer Mode with Floating Versions When:**
- Your repositories follow semantic versioning consistently
- You want zero maintenance overhead for compatible updates
- You prefer automatic dependency resolution and updates
- Your team understands SemVer rules and floating version patterns well
- You want true "set-and-forget" dependency management

**Choose Agnostic Mode When:**
- You need fine-grained control over every version compatibility decision
- Your repositories don't follow strict semantic versioning
- You have complex compatibility relationships that don't fit SemVer rules
- You're migrating legacy systems with non-standard versioning
- You prefer explicit control over when dependency updates occur

### Next Steps for SemVer Migration with Floating Versions

Once your SemVer dependency tree with floating versions is migrated:
- Ensure all new tags follow semantic versioning conventions strictly
- Educate your team on SemVer 2.0.0 rules and floating version patterns
- Set up processes to maintain semantic versioning discipline
- Consider using tools to validate semantic version bumps
- Monitor automatic dependency resolution in practice
- Establish policies for when to update floating version ranges

The SemVer migration approach with floating versions provides the same dependency management benefits as Agnostic mode while significantly reducing configuration complexity and completely eliminating maintenance overhead through automatic compatibility resolution and updates.

## Handling Shared Dependencies Version Changes (Agnostic Mode)

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
        v3.1.0 ─────────────────┘            v2.3.0
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

Once you have migrated your dependency tree to SemVer mode with floating versions, managing version changes becomes dramatically simpler due to automatic compatibility resolution and updates. This section demonstrates how SemVer mode with floating versions handles version changes with minimal to zero manual intervention.

### Starting Point: Post-SemVer Migration Dependency Tree with Floating Versions

After completing the SemVer migration example with floating versions, we have this dependency tree with SemVer LsiGitCheckout support:

```
                    MyApplication
                  v1.0.0 (4.*, 4.*)
                         │
           ┌─────────────┴─────────────┐
           │                           │
     UserInterface              BusinessLogic
     v4.2.0 (3.*)              v4.6.0 (2.*, 3.*)
           │                           │
           │                   ┌───────┴──────┐
           │                   │              │
     CommonControls            │          DataAccess
     v3.1.0 (1.2.*) ───────────┘          v2.3.0 (1.2.*)
           │                                  │
           └──────────────────────────────────┘
                               │
                         DatabaseUtils
                          v1.2.0 (leaf)
```

All repositories except DatabaseUtils contain `dependencies.json` files with SemVer floating version LsiGitCheckout configuration.

### Scenario 1: SemVer Compatible Update (v1.2.0 → v1.2.1) - The True Power of Floating Versions

Let's assume DatabaseUtils releases a patch version v1.2.1 that follows semantic versioning (bug fixes only, no breaking changes). With SemVer mode using floating versions, this update demonstrates the true power of the approach.

#### The SemVer Floating Version Advantage: Zero-Configuration Automatic Updates

**Key Insight**: With SemVer mode using floating versions, when DatabaseUtils releases v1.2.1, **absolutely no configuration changes are needed** anywhere in the dependency tree. The existing floating version requirements (`1.2.*`) automatically accept v1.2.1, and the entire dependency tree immediately benefits from the bug fixes.

**Complete Update Process for SemVer Compatible Changes with Floating Versions:**

1. **DatabaseUtils**: Release v1.2.1 (patch version)
2. **All dependent repositories**: **No changes needed whatsoever**
3. **Next LsiGitCheckout run**: Automatically uses v1.2.1 when available

**Result**: The entire dependency tree automatically benefits from the bug fixes in v1.2.1 without any manual configuration updates.

#### Demonstration: Automatic Updates in Action

Let's see this in practice:

```powershell
# Navigate to an existing workspace with the SemVer dependency tree
Set-Location C:\workspace\my-application
Set-Location MyApplication

# Before the update - check current versions
.\LsiGitCheckout.ps1 -Verbose
# This shows DatabaseUtils v1.2.0 being used

# DatabaseUtils team releases v1.2.1 (patch version) - no config changes needed anywhere

# Run LsiGitCheckout again
.\LsiGitCheckout.ps1 -Verbose
# This now automatically uses DatabaseUtils v1.2.1 throughout the entire tree!

# Verify the update
Set-Location shared\database-utils
git describe --tags  # Should now show v1.2.1
```

#### Updated SemVer Dependency Tree (Automatic Compatible Update)

With floating versions, the dependency tree automatically uses v1.2.1 without any configuration changes:

```
                    MyApplication
                  v1.0.0 (4.*, 4.*)
                         │                        🔄 Automatically benefits
           ┌─────────────┴─────────────┐           from v1.2.1
           │                           │
     UserInterface              BusinessLogic
     v4.2.0 (3.*)              v4.6.0 (2.*, 3.*)
           │                           │           🔄 Automatically benefits
           │                   ┌───────┴──────┐     from v1.2.1
           │                   │              │
     CommonControls            │          DataAccess
     v3.1.0 (1.2.*) ───────────┘          v2.3.0 (1.2.*)
           │                                  │
           │     🔄 Auto-updates to v1.2.1   │     🔄 Auto-updates to v1.2.1
           └──────────────────────────────────┘
                               │
                         DatabaseUtils
                       v1.2.0 → v1.2.1
                        (automatic)
```

**Key Benefits of Floating Version Approach:**
- **Zero manual work**: No configuration files to update
- **Immediate propagation**: Bug fixes flow automatically through the entire tree
- **No deployment coordination**: Each team gets updates automatically on their next build
- **Rollback safety**: If v1.2.1 has issues, teams can temporarily pin to v1.2.0 until fixed

### Scenario 2: SemVer Breaking Update (v1.2.1 → v2.0.0) - Clear Boundaries and Explicit Updates

Now let's assume DatabaseUtils releases v2.0.0 with breaking API changes. SemVer mode with floating versions provides clear boundaries and explicit opt-in for breaking changes.

#### Step 1: Breaking Changes Are Automatically Blocked

**Key Insight**: When DatabaseUtils releases v2.0.0, **floating versions automatically prevent the breaking change from propagating** until teams explicitly opt-in.

```powershell
# DatabaseUtils releases v2.0.0 with breaking changes

# Run LsiGitCheckout - still uses v1.2.1 (or latest v1.x)
.\LsiGitCheckout.ps1 -Verbose
# Output shows: "Using DatabaseUtils v1.2.1 (blocked from v2.0.0 by 1.2.* constraint)"

# The entire tree continues to work with v1.2.x until explicit updates
```

**Automatic Protection**: The `1.2.*` floating versions in DataAccess and CommonControls automatically reject v2.0.0, providing protection against unintended breaking changes.

#### Step 2: Selective Opt-In to Breaking Changes

Teams can now evaluate and opt-in to DatabaseUtils v2.0.0 at their own pace:

##### Update DataAccess to Use DatabaseUtils v2.0.0

**Current configuration**: `"Version": "1.2.*"` → **New configuration**: `"Version": "2.*"`

```powershell
Set-Location DataAccess
```

Make code changes to handle DatabaseUtils v2.0.0 API changes, then update dependencies:

```json
[
  {
    "Repository URL": "https://github.com/yourorg/DatabaseUtils.git",
    "Base Path": "../shared/database-utils",
    "Dependency Resolution": "SemVer",
    "Version": "2.*"
  }
]
```

Commit and tag with **minor version bump** (if DataAccess public API unchanged):
```powershell
git add .
git commit -m "Update to DatabaseUtils v2.0.0 with enhanced capabilities

- Updated internal database connection handling for new API
- Leveraged improved query performance features  
- Enhanced error handling with new exception types
- Public API remains unchanged - internal improvements only"
git tag v2.4.0  # Minor version bump - public API unchanged
git push origin v2.4.0
```

##### Update CommonControls to Use DatabaseUtils v2.0.0

```powershell
Set-Location ..\CommonControls
```

Make code changes and update to floating version for v2.x:

```json
[
  {
    "Repository URL": "https://github.com/yourorg/DatabaseUtils.git",
    "Base Path": "../shared/database-utils",
    "Dependency Resolution": "SemVer",
    "Version": "2.*"
  }
]
```

Commit and tag:
```powershell
git add .
git commit -m "Update to DatabaseUtils v2.0.0 for enhanced logging

- Improved internal logging using new DatabaseUtils capabilities
- Enhanced configuration loading performance
- Public API remains unchanged"
git tag v3.2.0  # Minor version bump - public API unchanged
git push origin v3.2.0
```

#### Step 3: Gradual Propagation Through the Tree

Now that the direct dependencies have been updated, the updates can propagate upward:

##### Update BusinessLogic to Use Enhanced Dependencies

**Current configuration**: Uses `2.*` and `3.*` → **New benefit**: Automatically gets v2.4.0 and v3.2.0

```powershell
Set-Location ..\BusinessLogic

# Run LsiGitCheckout to see automatic updates
.\LsiGitCheckout.ps1 -Verbose
# Shows: DataAccess v2.4.0 (2.* allows this), CommonControls v3.2.0 (3.* allows this)
# Transitively now uses DatabaseUtils v2.0.0!
```

**No configuration changes needed** - BusinessLogic automatically benefits from the enhanced capabilities because:
- `^2.3.0` automatically accepts v2.4.0 (minor version update)
- `^3.1.0` automatically accepts v3.2.0 (minor version update)

Optionally, update BusinessLogic version to document the enhancement:
```powershell
git tag v4.7.0 -m "Transitively updated to DatabaseUtils v2.0.0 enhanced capabilities"
git push origin v4.7.0
```

##### Update UserInterface Automatically

**Current configuration**: Uses `3.*` → **New benefit**: Automatically gets v3.2.0

```powershell
Set-Location ..\UserInterface

# UserInterface automatically benefits from CommonControls v3.2.0
.\LsiGitCheckout.ps1 -Verbose
# Shows: CommonControls v3.2.0 (3.* allows this)
# Transitively now uses DatabaseUtils v2.0.0!
```

Again, no configuration changes needed.

##### Update Root Application Automatically

**Current configuration**: Uses `4.*` and `4.*` → **New benefit**: Automatically gets latest compatible versions

```powershell
Set-Location ..\MyApplication

# MyApplication automatically benefits from all updates
.\LsiGitCheckout.ps1 -Verbose
# Shows: UserInterface v4.2.0 (still compatible), BusinessLogic v4.7.0 (4.* allows this)
# Entire tree now uses DatabaseUtils v2.0.0!
```

No configuration changes needed for the root application either.

#### Result: Updated SemVer Dependency Tree with Selective Breaking Change Adoption

```
                    MyApplication
                  v1.0.0 (^4.2.0, ^4.6.0)
                         │                     🔄 Auto-benefits from all updates
           ┌─────────────┴─────────────┐        throughout the tree
           │                           │
     UserInterface              BusinessLogic
     v4.2.0 (^3.1.0)              v4.6.0→v4.7.0 (^2.3.0, ^3.1.0)
           │                           │        🔄 Auto-gets v2.4.0 & v3.2.0
           │                   ┌───────┴──────┐
           │                   │              │
     CommonControls            │          DataAccess
     v3.1.0→v3.2.0 (^2.0.0) ───┘          v2.3.0→v2.4.0 (^2.0.0)
           │                                  │
           │       ✅ Opted in to v2.0.0      │      ✅ Opted in to v2.0.0
           └──────────────────────────────────┘
                               │
                         DatabaseUtils
                       v1.2.1 → v2.0.0
                      (breaking change)
```

### Scenario 3: Mixed Version Updates - Some Teams Adopt, Others Stay Behind

A powerful aspect of floating versions is that teams can adopt breaking changes at their own pace:

#### Team A Updates, Team B Stays on Stable

Let's assume only the DataAccess team updates to DatabaseUtils v2.0.0, but CommonControls stays on v1.x:

##### DataAccess Updates to v2.0.0

```json
[
  {
    "Repository URL": "https://github.com/yourorg/DatabaseUtils.git",
    "Base Path": "../shared/database-utils",
    "Dependency Resolution": "SemVer",
    "Version": "2.*"
  }
]
```

##### CommonControls Stays on v1.x

```json
[
  {
    "Repository URL": "https://github.com/yourorg/DatabaseUtils.git",
    "Base Path": "../shared/database-utils",
    "Dependency Resolution": "SemVer",
    "Version": "1.2.*"
  }
]
```

#### Result: SemVer Conflict Detection

When BusinessLogic tries to use both dependencies:

```powershell
Set-Location BusinessLogic
.\LsiGitCheckout.ps1 -Verbose
```

**LsiGitCheckout automatically detects the version conflict and reports:**

```
SemVer conflict for repository 'https://github.com/yourorg/DatabaseUtils.git':
No version satisfies all requirements:
- DataAccess (v2.4.0) requests: 2.* (compatible: v2.0.0, v2.1.0, v2.2.0)
- CommonControls (v3.1.0) requests: 1.2.* (compatible: v1.2.0, v1.2.1, v1.2.2)

Resolution options:
1. Update CommonControls to support DatabaseUtils v2.x
2. Keep DataAccess on DatabaseUtils v1.x until CommonControls is ready
3. Use different dependency paths to avoid shared dependency conflicts
```

This clear error message helps teams coordinate their updates appropriately.

### Key Differences Between SemVer Floating Versions and Agnostic Updates

#### SemVer Compatible Updates (v1.2.0 → v1.2.1) 
- **Configuration**: **Zero changes required** - automatic compatibility via floating versions
- **Automatic Updates**: All compatible updates flow automatically through the entire tree
- **Rollback**: Easy - temporarily pin specific versions if needed
- **Deployment**: **Immediate benefit** - entire organization gets bug fixes automatically
- **Team Coordination**: **None required** - updates flow automatically

#### SemVer Breaking Updates (v1.2.1 → v2.0.0)
- **Automatic Protection**: Breaking changes are blocked until explicit opt-in
- **Clear Boundaries**: Major version changes signal breaking changes clearly
- **Selective Adoption**: Teams can adopt at their own pace
- **Conflict Detection**: Automatic detection and clear error messages for version conflicts
- **Gradual Migration**: Updates propagate automatically once dependencies are updated

### Best Practices for SemVer Floating Version Updates

#### For SemVer Compatible Updates (The Zero-Maintenance Advantage)

1. **Trust Floating Versions**: For patch/minor updates, rely completely on automatic updates
2. **No Configuration Needed**: Resist the urge to update configuration files for compatible updates
3. **Monitor Automatic Updates**: Set up monitoring to track which versions are being used automatically
4. **Use Explicit Pins Only When Needed**: Only pin to specific versions when debugging issues

#### For SemVer Breaking Updates

1. **Respect Major Version Boundaries**: Never ignore major version bumps - they signal real breaking changes
2. **Plan Breaking Change Adoption**: Coordinate with dependent teams when adopting major version updates
3. **Update Floating Ranges**: Change `~1.2.0` to `^2.0.0` to opt into new major versions
4. **Test Compatibility Thoroughly**: Major version updates require thorough testing
5. **Coordinate Team Migration**: Use version conflict detection to coordinate team updates

#### SemVer Floating Version Strategy

**For Floating Version Specifications:**

| Pattern | Accepts | Use When |
|---------|---------|----------|
| `1.2.*` | 1.2.x only | You want only patch updates |
| `1.*` | 1.x.x (not 2.0.0) | You want minor and patch updates |
| `1.2.0` | Exactly 1.2.0 | You want lowest applicable behavior |
| `2.*` | 2.x.x (not 3.0.0) | You've adopted a major version update |

**For Version Requirements:**
- **Be Conservative Initially**: Start with tighter ranges (`~1.2.0`) and widen as confidence grows
- **Understand Update Implications**: Know what updates your floating versions will automatically accept
- **Monitor Automatic Updates**: Track which versions are actually being used in practice
- **Coordinate Major Updates**: Plan major version adoptions across teams

#### SemVer Floating Version Benefits

1. **Zero Maintenance for Compatible Updates**: Bug fixes and feature updates flow automatically
2. **Automatic Protection from Breaking Changes**: Major version boundaries prevent unwanted breaks
3. **Clear Upgrade Paths**: Explicit decisions required only for major version updates
4. **Team Independence**: Teams can adopt breaking changes at their own pace
5. **Conflict Detection**: Automatic detection of incompatible version requirements

### Troubleshooting SemVer Floating Version Issues

#### Issue: Unwanted Automatic Updates

**Problem**: A minor version update breaks functionality despite following SemVer

**Solution**:
1. Temporarily pin to the working version: `"Version": "1.2.3"` (exact version)
2. Investigate the breaking change and report to the library maintainer
3. Once fixed, return to floating version: `"Version": "1.2.*"`

#### Issue: Stuck on Old Versions

**Problem**: Dependencies aren't updating to newer compatible versions

**Solution**:
1. Check floating version specification: `1.2.*` only accepts 1.2.x
2. Widen range if appropriate: `1.*` accepts 1.x.x
3. Verify the dependency actually has newer versions available
4. Check for version conflicts with other dependencies

#### Issue: Version Conflicts

**Problem**: SemVer reports version conflicts between dependencies

**Solution**:
1. Review the conflict report to understand incompatible requirements
2. Coordinate with teams to align on compatible version ranges
3. Consider updating floating version ranges to find common compatible versions
4. Plan staged rollouts for major version updates

### SemVer vs Agnostic Mode Summary for Version Changes

| Aspect | SemVer Mode (Floating Versions) | Agnostic Mode |
|--------|--------------------------------|---------------|
| **Compatible Updates** | Fully automatic, zero config | Manual updates required everywhere |
| **Breaking Updates** | Automatic protection + explicit opt-in | Manual evaluation and updates |
| **Team Coordination** | Minimal (only for major versions) | High (for all updates) |
| **Maintenance Overhead** | Near zero | High (API Compatible Tags) |
| **Update Speed** | Immediate for compatible changes | Depends on manual update schedule |
| **Safety** | Automatic protection from breaking changes | Manual evaluation required |

### When Each Mode Excels for Version Management

**SemVer Mode with Floating Versions is ideal for:**
- Organizations with many repositories and frequent updates
- Teams that follow semantic versioning consistently  
- Environments where automatic security/bug fix propagation is critical
- Projects where manual dependency maintenance is a bottleneck

**Agnostic Mode is better for:**
- Legacy systems with inconsistent versioning
- High-security environments requiring explicit approval for all changes
- Complex compatibility relationships that don't fit SemVer patterns
- Teams that prefer explicit control over every dependency update

The SemVer floating version approach transforms dependency management from a high-maintenance, error-prone manual process into a largely automatic system that provides both safety and agility.