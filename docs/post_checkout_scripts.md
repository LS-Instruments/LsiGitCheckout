# Post-Checkout Scripts

> [← Back to README](../README.md)

## Overview

Post-checkout scripts are PowerShell scripts (.ps1) that execute automatically after a repository is successfully checked out to a specific tag. These scripts run only when an actual checkout occurs - they are skipped when repositories are already up-to-date with the correct tag. Post-checkout scripts enable integration with external dependency management systems and custom setup procedures.

**Key Characteristics:**
- **Execution Trigger**: Only after successful repository checkouts (clone or tag change)
- **Working Directory**: Scripts execute with the repository root as the working directory
- **Environment Variables**: Scripts receive context about the checkout operation
- **Timeout Protection**: Scripts are terminated if they exceed 5 minutes execution time
- **Error Handling**: Script failures are logged but don't prevent repository checkout success
- **Security**: Scripts run with `-ExecutionPolicy Bypass` for maximum compatibility
- **Root-Level Support**: Scripts can execute at depth 0 (root level) for global setup tasks

## Configuration

Post-checkout scripts are configured at the dependency file level and can execute at any depth:

### New Object Format

```json
{
  "Post-Checkout Script File Name": "setup-environment.ps1",
  "Post-Checkout Script File Path": "scripts/build",
  "Repositories": [
    {
      "Repository URL": "https://github.com/myorg/project.git",
      "Base Path": "repos/project",
      "Dependency Resolution": "SemVer",
      "Version": "1.*"
    }
  ]
}
```

### Configuration Fields

- **Post-Checkout Script File Name** (optional): Name of the PowerShell script to execute
- **Post-Checkout Script File Path** (optional): Subdirectory within each repository where the script is located (default: repository root)

## Script Execution Context

When a post-checkout script executes, it receives the following environment variables:

- **`$env:LSIGIT_REPOSITORY_URL`**: The repository URL that was checked out
- **`$env:LSIGIT_REPOSITORY_PATH`**: Absolute path to the repository on disk
- **`$env:LSIGIT_TAG`**: The git tag that was checked out
- **`$env:LSIGIT_SCRIPT_VERSION`**: Version of LsiGitCheckout executing the script

## Command Line Control

```powershell
# Default behavior (post-checkout scripts enabled)
.\LsiGitCheckout.ps1

# Disable post-checkout script execution
.\LsiGitCheckout.ps1 -DisablePostCheckoutScripts

# Debug script execution with detailed logging
.\LsiGitCheckout.ps1 -EnableDebug -Verbose

# Dry run shows what scripts would be executed
.\LsiGitCheckout.ps1 -DryRun
```

## Example Use Cases

### Package Manager Integration

```powershell
# setup-dependencies.ps1
Write-Host "Setting up dependencies for $env:LSIGIT_REPOSITORY_URL at tag $env:LSIGIT_TAG"

# Install npm dependencies if package.json exists
if (Test-Path "package.json") {
    Write-Host "Installing npm dependencies..."
    npm install
}

# Install NuGet packages if packages.config exists
if (Test-Path "packages.config") {
    Write-Host "Restoring NuGet packages..."
    nuget restore
}

# Install Python requirements if requirements.txt exists
if (Test-Path "requirements.txt") {
    Write-Host "Installing Python requirements..."
    pip install -r requirements.txt
}

Write-Host "Dependency setup completed for $env:LSIGIT_REPOSITORY_PATH"
```
