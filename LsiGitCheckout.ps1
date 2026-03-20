#Requires -Version 7.6
<#
.SYNOPSIS
    LsiGitCheckout - Checks out a collection of Git repositories to specified tags
.DESCRIPTION
    This script reads a JSON configuration file and checks out multiple Git repositories
    to their specified tags. It supports both HTTPS and SSH URLs, handles Git LFS,
    initializes submodules, and provides comprehensive error handling and logging.

    SSH credentials are managed through a separate git_credentials.json file.

    With the -DisableRecursion option, it processes only the main dependency file.

    The script uses intelligent tag temporal sorting based on actual git tag dates,
    eliminating the need for manual temporal ordering in "API Compatible Tags".

    Post-checkout PowerShell scripts can be executed after successful repository
    checkouts to integrate with external dependency management systems. Scripts
    can be configured at any depth level, including depth 0 (root level).
.PARAMETER InputFile
    Path to the JSON configuration file. Defaults to 'dependencies.json' in the script directory.
.PARAMETER CredentialsFile
    Path to the SSH credentials JSON file. Defaults to 'git_credentials.json' in the script directory.
.PARAMETER DryRun
    If specified, shows what would be done without actually executing Git commands.
.PARAMETER EnableDebug
    Enables debug logging to a timestamped log file.
.PARAMETER Verbose
    Increases verbosity of output messages.
.PARAMETER DisableRecursion
    Disables recursive dependency discovery and processing. By default, recursive mode is enabled.
.PARAMETER MaxDepth
    Maximum recursion depth for dependency discovery. Defaults to 5.
.PARAMETER ApiCompatibility
    Default API compatibility mode when not specified in dependencies. Can be 'Strict' or 'Permissive'. Defaults to 'Permissive'.
.PARAMETER DisablePostCheckoutScripts
    Disables execution of post-checkout PowerShell scripts. By default, post-checkout scripts are enabled.
.PARAMETER EnableErrorContext
    Enables detailed error context output including stack traces and line numbers.
    By default, only simple error messages are shown. Use this for advanced debugging.
.EXAMPLE
    .\LsiGitCheckout.ps1
    .\LsiGitCheckout.ps1 -InputFile "C:\configs\myrepos.json" -CredentialsFile "C:\configs\my_credentials.json"
    .\LsiGitCheckout.ps1 -DisableRecursion -MaxDepth 10
    .\LsiGitCheckout.ps1 -InputFile "repos.json" -EnableDebug -ApiCompatibility Strict
    .\LsiGitCheckout.ps1 -Verbose -DisablePostCheckoutScripts
    .\LsiGitCheckout.ps1 -EnableDebug -EnableErrorContext
.NOTES
    Version: 8.0.0
    Last Modified: 2026-03-20

    Requires PowerShell 7.6 LTS or later (installs side-by-side with Windows PowerShell 5.1).
    Install via: winget install Microsoft.PowerShell

    This script uses PuTTY/plink for SSH authentication. SSH keys must be in PuTTY format (.ppk).
    Use PuTTYgen to convert OpenSSH keys to PuTTY format if needed.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$InputFile,

    [Parameter()]
    [string]$CredentialsFile,

    [Parameter()]
    [switch]$DryRun,

    [Parameter()]
    [switch]$EnableDebug,

    [Parameter()]
    [switch]$DisableRecursion,

    [Parameter()]
    [int]$MaxDepth = 5,

    [Parameter()]
    [ValidateSet('Strict', 'Permissive')]
    [string]$ApiCompatibility = 'Permissive',

    [Parameter()]
    [switch]$DisablePostCheckoutScripts,

    [Parameter()]
    [switch]$EnableErrorContext,

    [Parameter()]
    [string]$OutputFile
)

# Import module from same directory as this script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $scriptDir 'LsiGitCheckout.psm1') -Force

# Initialize module state from script parameters
Initialize-LsiGitCheckout `
    -ScriptPath $scriptDir `
    -DryRun:$DryRun `
    -EnableDebug:$EnableDebug `
    -DisableRecursion:$DisableRecursion `
    -MaxDepth $MaxDepth `
    -ApiCompatibility $ApiCompatibility `
    -DisablePostCheckoutScripts:$DisablePostCheckoutScripts `
    -EnableErrorContext:$EnableErrorContext `
    -OutputFile $OutputFile

# Main execution
$exitCode = 0
try {
    Write-Log "LsiGitCheckout started - Version 8.0.0" -Level Info
    Write-Log "Script path: $scriptDir" -Level Debug
    Write-Log "PowerShell version: $($PSVersionTable.PSVersion)" -Level Debug
    Write-Log "Operating System: $([System.Environment]::OSVersion.VersionString)" -Level Debug
    Write-Log "Default API Compatibility: $ApiCompatibility" -Level Info

    if (-not $DisableRecursion) {
        Write-Log "Recursive mode: ENABLED (default) with max depth: $MaxDepth" -Level Info
    } else {
        Write-Log "Recursive mode: DISABLED" -Level Info
    }

    if (-not $DisablePostCheckoutScripts) {
        Write-Log "Post-checkout scripts: ENABLED (default)" -Level Info
    } else {
        Write-Log "Post-checkout scripts: DISABLED" -Level Info
    }

    if ($EnableErrorContext) {
        Write-Log "Error context: ENABLED - Detailed error information will be shown" -Level Info
    } else {
        Write-Log "Error context: DISABLED - Use -EnableErrorContext for detailed error information" -Level Debug
    }

    if ($OutputFile) {
        Write-Log "Structured output will be written to: $OutputFile" -Level Info
    }

    # Calculate and log script hash in debug mode
    if ($EnableDebug) {
        $scriptContent = Get-Content -Path $MyInvocation.MyCommand.Path -Raw
        $scriptBytes = [System.Text.Encoding]::UTF8.GetBytes($scriptContent)
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $sha256.ComputeHash($scriptBytes)
        $scriptHash = [System.BitConverter]::ToString($hashBytes).Replace('-', '')
        Write-Log "Script SHA256 hash: $($scriptHash.Substring(0, 16))..." -Level Debug
        Write-Log "Full script hash: $scriptHash" -Level Debug
    }

    if ($DryRun) {
        Write-Log "DRY RUN MODE - No actual changes will be made" -Level Warning
    }

    if ($EnableDebug) {
        Write-Log "Debug logging enabled" -Level Info
    }

    # Check Git installation
    if (-not (Test-GitInstalled)) {
        throw "Git is not installed or not accessible in PATH"
    }

    # Determine input file path
    if ([string]::IsNullOrEmpty($InputFile)) {
        $InputFile = Join-Path $scriptDir "dependencies.json"
        Write-Log "Using default input file: $InputFile" -Level Verbose
    }

    # Store the dependency file name for recursive processing
    # Access module internals for setting the default dependency file name
    & (Get-Module LsiGitCheckout) { $script:DefaultDependencyFileName = $args[0] } (Split-Path -Leaf $InputFile)
    Write-Log "Default dependency file name for recursive processing: $(Split-Path -Leaf $InputFile)" -Level Debug

    # Determine credentials file path
    if ([string]::IsNullOrEmpty($CredentialsFile)) {
        $CredentialsFile = Join-Path $scriptDir "git_credentials.json"
        Write-Log "Using default credentials file: $CredentialsFile" -Level Verbose
    }

    # Read SSH credentials
    $sshCreds = Read-CredentialsFile -FilePath $CredentialsFile
    & (Get-Module LsiGitCheckout) { $script:SshCredentials = $args[0] } $sshCreds

    # Check if input file exists
    if (-not (Test-Path $InputFile)) {
        throw "Input file not found: $InputFile"
    }

    # Process the initial dependency file with enhanced error handling
    Write-Log "Starting dependency processing at depth 0" -Level Info

    $checkedOutRepos = Invoke-WithErrorContext -Context "Processing root dependency file" -ScriptBlock {
        Process-DependencyFile -DependencyFilePath $InputFile -Depth 0
    }

    # Handle null return
    if ($null -eq $checkedOutRepos) {
        Write-Log "WARNING: Process-DependencyFile returned null, initializing as empty array" -Level Warning
        $checkedOutRepos = @()
    } else {
        Write-Log "Process-DependencyFile returned type: $($checkedOutRepos.GetType().FullName)" -Level Debug
    }
    if ($null -eq $checkedOutRepos) {
        Write-Log "WARNING: checkedOutRepos is null!" -Level Warning
        $checkedOutRepos = @()
    }

    Write-Log "Completed depth 0 processing: 1 dependency file processed, $($checkedOutRepos.Count) repositories checked out" -Level Info

    # Additional debug information
    if ($EnableDebug) {
        Write-Log "Detailed checkedOutRepos information:" -Level Debug
        Write-Log "  Count: $($checkedOutRepos.Count)" -Level Debug
        Write-Log "  IsArray: $($checkedOutRepos -is [Array])" -Level Debug
        if ($checkedOutRepos.Count -gt 0) {
            Write-Log "  Repository details:" -Level Debug
            foreach ($repo in $checkedOutRepos) {
                Write-Log "    - Repository: $($repo.Repository.'Repository URL'), Path: $($repo.AbsolutePath)" -Level Debug
            }
        }
    }

    # If recursive mode is enabled, process nested dependencies
    $isRecursiveMode = -not $DisableRecursion
    Write-Log "Checking recursive processing conditions - RecursiveMode: $isRecursiveMode, CheckedOutRepos.Count: $($checkedOutRepos.Count)" -Level Debug

    if ($isRecursiveMode -and $checkedOutRepos.Count -gt 0) {
        Write-Log "Entering recursive processing with $($checkedOutRepos.Count) repositories" -Level Info
        $defaultDepFileName = Split-Path -Leaf $InputFile
        Invoke-WithErrorContext -Context "Processing recursive dependencies" -ScriptBlock {
            Process-RecursiveDependencies -CheckedOutRepos $checkedOutRepos -DefaultDependencyFileName $defaultDepFileName -CurrentDepth 0
        }
    } else {
        if ($DisableRecursion) {
            Write-Log "Recursive processing skipped - recursive mode is disabled" -Level Info
        } elseif ($checkedOutRepos.Count -eq 0) {
            Write-Log "Recursive processing skipped - no new repositories were checked out at depth 0" -Level Info
        }
    }

    # Show summary
    Show-Summary

    # Determine exit code from failure count
    $failureCount = & (Get-Module LsiGitCheckout) { $script:FailureCount }
    if ($failureCount -gt 0) {
        $exitCode = 1
    }
}
catch {
    Write-ErrorWithContext -ErrorRecord $_ -AdditionalMessage "Unexpected error in main execution"
    Show-ErrorDialog -Message $_.Exception.Message
    $exitCode = 1
}
finally {
    # Write structured output if requested — guaranteed even on failure
    if (-not [string]::IsNullOrEmpty($OutputFile)) {
        try {
            Export-CheckoutResults -OutputFile $OutputFile
        }
        catch {
            Write-Host "Failed to write output file: $_" -ForegroundColor Red
        }
    }
}

exit $exitCode
