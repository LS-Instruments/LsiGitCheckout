# Choosing Between Dependency Resolution Modes

> [← Back to README](../README.md)

Each mode offers distinct advantages and is suited for different scenarios:

## SemVer Mode Advantages
- **Zero maintenance overhead**: Compatible updates require no configuration changes
- **Automatic conflict detection**: Clear error messages when version requirements conflict
- **Immediate availability**: Entire dependency tree benefits from compatible updates as soon as they're released
- **Simplified configuration**: Only need to specify minimum version requirements or floating patterns
- **Floating versions**: Automatically select latest compatible versions using patterns like `2.1.*` or `2.*`
- **Industry standard**: Follows well-understood Semantic Versioning 2.0.0 rules

## Agnostic Mode Advantages
- **Maximum control**: Fine-grained control over version compatibility relationships
- **Flexible versioning**: Works with any tagging scheme, not just semantic versioning
- **Complex compatibility**: Handle intricate compatibility relationships that don't fit SemVer rules
- **Legacy support**: Ideal for migrating projects with inconsistent versioning practices

## When to Choose SemVer Mode
- Your repositories follow semantic versioning consistently
- You want to minimize configuration maintenance overhead
- Your team understands and follows SemVer 2.0.0 principles
- You prefer automatic compatibility resolution with clear, predictable rules
- You want to leverage floating versions for automatic latest version selection
- You're starting a new project or can enforce semantic versioning discipline

## When to Choose Agnostic Mode
- You need fine-grained control over version compatibility
- Your repositories don't follow strict semantic versioning
- You have complex compatibility relationships that don't fit SemVer rules
- You're migrating legacy systems with inconsistent versioning approaches
- You require maximum flexibility in defining version relationships

**Mixed Mode Support**: You can use both modes in the same dependency tree, choosing the appropriate mode for each repository based on its versioning practices and requirements.

## Best Practices

1. **Choose SemVer mode** when your repositories follow semantic versioning consistently
2. **Use floating versions** (`x.y.*`, `x.*`) when you want automatic latest version selection
3. **Use lowest-applicable versions** (`x.y.z`) when you need stability and predictable versions
4. **Use Agnostic mode** when you need fine-grained control over compatibility or don't follow strict semver
5. **Mix modes appropriately** - use SemVer for well-versioned libraries and Agnostic for experimental or legacy components
6. **Test your dependency tree** with `-DryRun` before actual checkouts
7. **Use consistent version tag formats** across your organization when using SemVer mode
