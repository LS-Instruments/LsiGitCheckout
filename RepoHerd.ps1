#Requires -Version 7.6
<#
.SYNOPSIS
    RepoHerd - Checks out a collection of Git repositories to specified tags
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
    .\RepoHerd.ps1
    .\RepoHerd.ps1 -InputFile "C:\configs\myrepos.json" -CredentialsFile "C:\configs\my_credentials.json"
    .\RepoHerd.ps1 -DisableRecursion -MaxDepth 10
    .\RepoHerd.ps1 -InputFile "repos.json" -EnableDebug -ApiCompatibility Strict
    .\RepoHerd.ps1 -Verbose -DisablePostCheckoutScripts
    .\RepoHerd.ps1 -EnableDebug -EnableErrorContext
.NOTES
    Version: 9.1.0
    Last Modified: 2026-03-20

    Requires PowerShell 7.6 LTS or later (installs side-by-side with Windows PowerShell 5.1).
    Install via: winget install Microsoft.PowerShell

    SSH authentication is cross-platform: PuTTY/plink with .ppk keys on Windows,
    OpenSSH on macOS/Linux. Use PuTTYgen to convert OpenSSH keys to .ppk format on Windows.
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
Import-Module (Join-Path $scriptDir 'RepoHerd.psm1') -Force

# When run from the script, default InputFile and CredentialsFile to the script directory
if (-not $PSBoundParameters.ContainsKey('InputFile')) {
    $PSBoundParameters['InputFile'] = Join-Path $scriptDir "dependencies.json"
}
if (-not $PSBoundParameters.ContainsKey('CredentialsFile')) {
    $PSBoundParameters['CredentialsFile'] = Join-Path $scriptDir "git_credentials.json"
}

# Delegate to module function and exit with its return code
exit (Invoke-RepoHerd @PSBoundParameters)
