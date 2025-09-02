#Requires -Version 5.1
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
    Version: 7.1.0
    Last Modified: 2025-09-02

    This script uses PuTTY/plink for SSH authentication. SSH keys must be in PuTTY format (.ppk).
    Use PuTTYgen to convert OpenSSH keys to PuTTY format if needed.    
    
    Changes in 7.1.0:
    - Added "Floating Versions" support for SemVer dependency resolution
    - New version patterns: "x.y.*" (latest patch) and "x.*" (latest minor.patch)  
    - Mixed specification mode: if any dependency uses floating versions, select highest compatible
    - Backward compatible with existing "Lowest applicable version" specifications
    - Enhanced version parsing to handle wildcard patterns
    
    Changes in 7.0.0:
    - Added Semantic Versioning (SemVer) support with "Dependency Resolution" field
    - New "SemVer" mode automatically resolves compatible versions based on SemVer rules
    - Added "Version" field for specifying SemVer requirements (x.y.z format)
    - Added optional "Version Regex" field for custom version extraction patterns
    - Immutable configuration: Dependency Resolution mode and Version Regex cannot change
    - Mixed mode support: Can use both Agnostic and SemVer repositories in same tree
    
    SemVer Mode Configuration Examples:

    Lowest Applicable Version (existing):
    {
      "Repository URL": "https://github.com/myorg/library.git",
      "Base Path": "libs/library", 
      "Dependency Resolution": "SemVer",
      "Version": "2.1.0",
      "Version Regex": "^v(\d+)\.(\d+)\.(\d+)$"
    }

    Floating Patch Version (new in 7.1.0):
    {
      "Repository URL": "https://github.com/myorg/library.git",
      "Base Path": "libs/library",
      "Dependency Resolution": "SemVer", 
      "Version": "2.1.*",
      "Version Regex": "^v(\d+)\.(\d+)\.(\d+)$"
    }

    Floating Minor Version (new in 7.1.0):
    {
      "Repository URL": "https://github.com/myorg/library.git",
      "Base Path": "libs/library",
      "Dependency Resolution": "SemVer",
      "Version": "2.*",
      "Version Regex": "^v(\d+)\.(\d+)\.(\d+)$"
    }
    
    Changes in 6.2.1:
    - Added support for post-checkout scripts at depth 0 (root level) when configured in the input dependency file
    - Post-checkout scripts can now be configured in the main input dependency file and execute before processing repositories
    - At depth 0, environment variables are provided as empty strings (except LSIGIT_SCRIPT_VERSION)
    - Script path construction at depth 0 uses the input dependency file location as the base path
    
    Changes in 6.2.0:
    - Added support for post-checkout PowerShell script execution
    - New "Post-Checkout Script File Name" and "Post-Checkout Script File Path" configuration options
    - Scripts execute only after successful repository checkouts, not when repositories are already up-to-date
    - Added -DisablePostCheckoutScripts parameter to disable post-checkout script execution
    - Enhanced logging for post-checkout script execution and error handling
    - Added comprehensive security considerations for script execution
    
    Changes in 6.1.0:
    - Added support for custom "Dependency File Path" and "Dependency File Name" per repository
    - Custom dependency file settings are not propagated to nested repositories (isolation)
    - Enhanced recursive processing to handle per-repository dependency file configurations
    - Improved flexibility for managing different dependency file naming conventions
    
    Dependencies JSON Format:
    {
      "Post-Checkout Script File Name": "setup.ps1",
      "Post-Checkout Script File Path": "scripts/setup",
      "Repositories": [
        {
          "Repository URL": "https://github.com/user/repo.git",
          "Base Path": "C:\\Projects\\repo",
          "Tag": "v1.0.0",
          "API Compatible Tags": ["v1.0.0", "v1.0.1", "v1.1.0"],
          "API Compatibility": "Strict",
          "Skip LFS": false,
          "Dependency File Path": "config/deps",
          "Dependency File Name": "project-deps.json"
        }
      ]
    }
    
    Legacy Array Format (Backward Compatible):
    [
      {
        "Repository URL": "https://github.com/user/repo.git",
        "Base Path": "C:\\Projects\\repo",
        "Tag": "v1.0.0",
        "API Compatible Tags": ["v1.0.0", "v1.0.1", "v1.1.0"],
        "API Compatibility": "Strict",
        "Skip LFS": false,
        "Dependency File Path": "config/deps",
        "Dependency File Name": "project-deps.json"
      }
    ]
    
    Credentials JSON Format:
    {
      "github.com": "C:\\Users\\user\\.ssh\\github_key.ppk",
      "gitlab.com": "C:\\Users\\user\\.ssh\\gitlab_key.ppk",
      "ssh://git.company.com": "C:\\Users\\user\\.ssh\\company_key.ppk"
    }
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
    [switch]$EnableErrorContext
)

# Script configuration
$script:Version = "7.1.0"
$script:ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:ErrorFile = Join-Path $ScriptPath "LsiGitCheckout_Errors.txt"
$script:DebugLogFile = Join-Path $ScriptPath ("debug_log_{0}.txt" -f (Get-Date -Format "yyyyMMddHHmm"))
$script:SuccessCount = 0
$script:FailureCount = 0
$script:PostCheckoutScriptExecutions = 0
$script:PostCheckoutScriptFailures = 0
$script:SshCredentials = @{}
$script:RepositoryDictionary = @{}
$script:CurrentDepth = 0
$script:ProcessedDependencyFiles = @()
$script:DefaultApiCompatibility = $ApiCompatibility
$script:RecursiveMode = -not $DisableRecursion
$script:DefaultDependencyFileName = ""
$script:PostCheckoutScriptsEnabled = -not $DisablePostCheckoutScripts
$script:ErrorContextEnabled = $EnableErrorContext

# Initialize error file
if (Test-Path $script:ErrorFile) {
    Remove-Item $script:ErrorFile -Force
}

function Write-ErrorWithContext {
    <#
    .SYNOPSIS
        Writes an error with full context including line numbers and stack trace
    .DESCRIPTION
        Captures the error context including the exact line where the error occurred,
        the function name, and the full stack trace for debugging
    #>
    param(
        [Parameter(Mandatory=$true)]
        $ErrorRecord,
        
        [string]$AdditionalMessage = ""
    )
    
    # If error context is not enabled, just write a simple error message
    if (-not $script:ErrorContextEnabled) {
        $simpleMessage = $ErrorRecord.Exception.Message
        if ($AdditionalMessage) {
            $simpleMessage = "$AdditionalMessage : $simpleMessage"
        }
        Write-Log $simpleMessage -Level Error
        return
    }
    
    # Get error details
    $errorLine = $ErrorRecord.InvocationInfo.ScriptLineNumber
    $errorColumn = $ErrorRecord.InvocationInfo.OffsetInLine
    $errorScript = $ErrorRecord.InvocationInfo.ScriptName
    $errorCommand = $ErrorRecord.InvocationInfo.Line.Trim()
    $errorFunction = $ErrorRecord.InvocationInfo.MyCommand.Name
    $errorException = $ErrorRecord.Exception.Message
    
    # Build detailed error message
    $errorDetails = @"
========================================
ERROR DETAILS
========================================
Exception: $errorException
Location: Line $errorLine, Column $errorColumn
Script: $errorScript
Function: $errorFunction
Command: $errorCommand
"@

    if ($AdditionalMessage) {
        $errorDetails += "`nAdditional Info: $AdditionalMessage"
    }
    
    # Add stack trace
    if ($ErrorRecord.ScriptStackTrace) {
        $errorDetails += @"

Stack Trace:
----------------------------------------
$($ErrorRecord.ScriptStackTrace)
========================================
"@
    }
    
    Write-Log $errorDetails -Level Error
    
    # Also write a condensed version for quick reference
    Write-Log "ERROR at line $errorLine in $errorFunction : $errorException" -Level Error
}

function Invoke-WithErrorContext {
    <#
    .SYNOPSIS
        Executes a script block with enhanced error context reporting
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ScriptBlock]$ScriptBlock,
        
        [string]$Context = ""
    )
    
    try {
        & $ScriptBlock
    }
    catch {
        Write-ErrorWithContext -ErrorRecord $_ -AdditionalMessage $Context
        throw
    }
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Debug', 'Verbose')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        'Error' {
            Write-Host $logMessage -ForegroundColor Red
            Add-Content -Path $script:ErrorFile -Value $logMessage
        }
        'Warning' {
            Write-Host $logMessage -ForegroundColor Yellow
        }
        'Debug' {
            if ($EnableDebug) {
                Write-Host $logMessage -ForegroundColor Cyan
                Add-Content -Path $script:DebugLogFile -Value $logMessage
            }
        }
        'Verbose' {
            if ($VerbosePreference -eq 'Continue') {
                Write-Host $logMessage -ForegroundColor Gray
            }
        }
        default {
            Write-Host $logMessage
        }
    }
    
    if ($EnableDebug -and $Level -ne 'Debug') {
        Add-Content -Path $script:DebugLogFile -Value $logMessage
    }
}

function Parse-VersionPattern {
    <#
    .SYNOPSIS
        Parses a version pattern and determines its type and constraints
    .DESCRIPTION
        Supports three patterns:
        - x.y.z: Lowest applicable version (existing behavior)
        - x.y.*: Floating patch version
        - x.*: Floating minor.patch version
    #>
    param(
        [string]$VersionPattern
    )
    
    Write-Log "Parsing version pattern: $VersionPattern" -Level Debug
    
    # Check for floating version patterns
    if ($VersionPattern -match '^(\d+)\.(\d+)\.\*$') {
        # x.y.* pattern - floating patch
        return @{
            Type = "FloatingPatch"
            Major = [int]$Matches[1]
            Minor = [int]$Matches[2]
            Patch = $null
            OriginalPattern = $VersionPattern
        }
    }
    elseif ($VersionPattern -match '^(\d+)\.\*$') {
        # x.* pattern - floating minor.patch
        return @{
            Type = "FloatingMinor"
            Major = [int]$Matches[1]
            Minor = $null
            Patch = $null
            OriginalPattern = $VersionPattern
        }
    }
    elseif ($VersionPattern -match '^(\d+)\.(\d+)\.(\d+)$') {
        # x.y.z pattern - lowest applicable (existing)
        return @{
            Type = "LowestApplicable"
            Major = [int]$Matches[1]
            Minor = [int]$Matches[2]
            Patch = [int]$Matches[3]
            OriginalPattern = $VersionPattern
        }
    }
    else {
        throw "Invalid version pattern '$VersionPattern'. Supported formats: x.y.z, x.y.*, x.*"
    }
}

function Test-SemVerCompatibility {
    <#
    .SYNOPSIS
        Tests if an available version is compatible with a version pattern
    .DESCRIPTION
        Handles both traditional SemVer compatibility and new floating version patterns
    #>
    param(
        [Version]$Available,
        [hashtable]$VersionPattern
    )
    
    $major = $Available.Major
    $minor = $Available.Minor
    $patch = $Available.Build  # Build = Patch in Version object
    
    switch ($VersionPattern.Type) {
        "LowestApplicable" {
            # Existing SemVer logic
            if ($VersionPattern.Major -eq 0) {
                # Special handling for 0.x.y versions
                return $major -eq 0 -and 
                       $minor -eq $VersionPattern.Minor -and 
                       $patch -ge $VersionPattern.Patch
            }
            
            # Standard SemVer: compatible if same major and >= requested minor.patch
            return $major -eq $VersionPattern.Major -and
                   ($minor -gt $VersionPattern.Minor -or 
                   ($minor -eq $VersionPattern.Minor -and $patch -ge $VersionPattern.Patch))
        }
        
        "FloatingPatch" {
            # x.y.* - same major.minor, any patch >= 0
            if ($VersionPattern.Major -eq 0) {
                # Special handling for 0.x.* versions
                return $major -eq 0 -and $minor -eq $VersionPattern.Minor
            }
            
            return $major -eq $VersionPattern.Major -and $minor -eq $VersionPattern.Minor
        }
        
        "FloatingMinor" {
            # x.* - same major, any minor.patch >= 0
            if ($VersionPattern.Major -eq 0) {
                # Special handling for 0.* versions
                return $major -eq 0
            }
            
            return $major -eq $VersionPattern.Major
        }
        
        default {
            throw "Unknown version pattern type: $($VersionPattern.Type)"
        }
    }
}

function Get-CompatibleVersionsForPattern {
    <#
    .SYNOPSIS
        Gets all versions compatible with a specific version pattern
    #>
    param(
        [hashtable]$ParsedVersions,  # tag -> Version mapping
        [hashtable]$VersionPattern
    )
    
    $compatible = @()
    
    foreach ($entry in $ParsedVersions.GetEnumerator()) {
        if (Test-SemVerCompatibility -Available $entry.Value -VersionPattern $VersionPattern) {
            $compatible += [PSCustomObject]@{
                Tag = $entry.Key
                Version = $entry.Value
            }
        }
    }
    
    if ($compatible.Count -eq 0) {
        # Format available versions for error message
        $availableFormatted = $ParsedVersions.GetEnumerator() | 
            Sort-Object { $_.Value } | 
            ForEach-Object { "$($_.Key) ($($_.Value.Major).$($_.Value.Minor).$($_.Value.Build))" }
        
        throw "No compatible version found for pattern '$($VersionPattern.OriginalPattern)'. " +
              "Available versions: $($availableFormatted -join ', ')"
    }
    
    # Sort by version to ensure consistent ordering
    $compatible = $compatible | Sort-Object { $_.Version }
    
    Write-Log "Found $($compatible.Count) compatible versions for pattern '$($VersionPattern.OriginalPattern)'" -Level Debug
    
    return $compatible
}

function Select-VersionFromIntersection {
    <#
    .SYNOPSIS
        Selects the appropriate version from intersection based on specification types
    .DESCRIPTION
        If any pattern is floating, select highest version; otherwise select lowest
    #>
    param(
        [array]$IntersectionVersions,  # Array of PSCustomObject with Tag and Version
        [hashtable]$RequestedPatterns  # caller -> VersionPattern mapping
    )
    
    # Check if any pattern is floating
    $hasFloatingPattern = $false
    foreach ($pattern in $RequestedPatterns.Values) {
        if ($pattern.Type -eq "FloatingPatch" -or $pattern.Type -eq "FloatingMinor") {
            $hasFloatingPattern = $true
            break
        }
    }
    
    if ($hasFloatingPattern) {
        # Select highest (most recent) version
        $selected = $IntersectionVersions | Sort-Object { $_.Version } | Select-Object -Last 1
        Write-Log "Floating version detected - selecting highest compatible version: $(Format-SemVersion $selected.Version) (tag: $($selected.Tag))" -Level Info
    }
    else {
        # Select lowest version (existing behavior)
        $selected = $IntersectionVersions | Sort-Object { $_.Version } | Select-Object -First 1
        Write-Log "All patterns are lowest-applicable - selecting lowest compatible version: $(Format-SemVersion $selected.Version) (tag: $($selected.Tag))" -Level Info
    }
    
    return $selected
}

function Parse-RepositoryVersions {
    <#
    .SYNOPSIS
        Parses all repository tags using the specified regex pattern to extract SemVer versions
    .DESCRIPTION
        One-time parsing of all tags in a repository to build a cache of tag->version mappings
    #>
    param(
        [string]$RepoPath,
        [string]$VersionRegex = "^v?(\d+)\.(\d+)\.(\d+)$"
    )
    
    Write-Log "Parsing SemVer versions from repository at: $RepoPath" -Level Debug
    Write-Log "Using version regex: $VersionRegex" -Level Debug
    
    # Validate regex has at least 3 capture groups
    try {
        $compiledRegex = [regex]::new($VersionRegex)
        $testMatch = $compiledRegex.Match("v1.2.3")
        if ($compiledRegex.GetGroupNumbers().Count -lt 4) {  # 0 + 3 groups
            throw "Version regex must have at least 3 capture groups for major.minor.patch"
        }
    }
    catch {
        throw "Invalid version regex '$VersionRegex': $_"
    }
    
    $parsedVersions = @{}
    $parseErrors = @()
    
    # Get all tags from repository
    try {
        Push-Location $RepoPath
        
        # Get all tags
        $gitCommand = "git tag -l"
        Write-Log "Executing: $gitCommand" -Level Debug
        
        $tags = Invoke-Expression $gitCommand 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to get tags: $tags"
        }
        
        Pop-Location
        
        foreach ($tag in $tags) {
            if ([string]::IsNullOrWhiteSpace($tag)) { continue }
            
            $tag = $tag.Trim()
            $match = $compiledRegex.Match($tag)
            
            if ($match.Success -and $match.Groups.Count -ge 4) {
                try {
                    $major = [int]$match.Groups[1].Value
                    $minor = [int]$match.Groups[2].Value
                    $patch = [int]$match.Groups[3].Value
                    
                    # Version constructor expects Major.Minor.Build.Revision
                    # We use Build for Patch and leave Revision as -1
                    $version = [Version]::new($major, $minor, $patch)
                    $parsedVersions[$tag] = $version
                    
                    Write-Log "Parsed tag '$tag' as version $($major).$($minor).$($patch)" -Level Debug
                }
                catch {
                    $parseErrors += "Failed to parse version from tag '$tag': $_"
                    Write-Log "Failed to parse version from tag '$tag': $_" -Level Warning
                }
            }
        }
        
        if ($parsedVersions.Count -eq 0) {
            $errorMsg = "No tags matching SemVer pattern '$VersionRegex' found in repository.`n"
            $errorMsg += "Found tags: $($tags -join ', ')"
            if ($parseErrors.Count -gt 0) {
                $errorMsg += "`nParse errors:`n" + ($parseErrors -join "`n")
            }
            throw $errorMsg
        }
        
        Write-Log "Successfully parsed $($parsedVersions.Count) SemVer tags" -Level Info
        return @{
            ParsedVersions = $parsedVersions
            CompiledRegex = $compiledRegex
        }
    }
    catch {
        Pop-Location -ErrorAction SilentlyContinue
        throw
    }
}

function Get-SemVersionIntersection {
    <#
    .SYNOPSIS
        Gets the intersection of two sets of version objects
    #>
    param(
        [array]$Set1,  # Array of PSCustomObject with Tag and Version properties
        [array]$Set2
    )
    
    $intersection = @()
    
    foreach ($v1 in $Set1) {
        foreach ($v2 in $Set2) {
            if ($v1.Tag -eq $v2.Tag) {
                $intersection += $v1
                break
            }
        }
    }
    
    return $intersection
}

function Format-SemVersion {
    <#
    .SYNOPSIS
        Formats a Version object as a SemVer string
    #>
    param(
        [Version]$Version
    )
    
    return "$($Version.Major).$($Version.Minor).$($Version.Build)"
}

function Validate-DependencyConfiguration {
    <#
    .SYNOPSIS
        Validates that repository configuration hasn't changed in incompatible ways
    #>
    param(
        [PSCustomObject]$NewRepo,
        [hashtable]$ExistingRepo
    )
    
    $repoUrl = $NewRepo.'Repository URL'
    
    # Determine dependency resolution mode
    $newMode = if ($NewRepo.PSObject.Properties['Dependency Resolution']) { 
        $NewRepo.'Dependency Resolution' 
    } else { 
        "Agnostic" 
    }
    
    # Rule 1: Dependency Resolution mode cannot change
    if ($ExistingRepo.ContainsKey('DependencyResolution') -and 
        $ExistingRepo.DependencyResolution -ne $newMode) {
        $errorMessage = "Repository '$repoUrl' configuration conflict:`n" +
                       "Previously discovered with Dependency Resolution: $($ExistingRepo.DependencyResolution)`n" +
                       "Now attempting to use Dependency Resolution: $newMode`n" +
                       "Dependency Resolution mode cannot change once established."
        throw $errorMessage
    }
    
    # Rule 2: Version Regex cannot change (for SemVer mode)
    if ($newMode -eq "SemVer" -and $ExistingRepo.ContainsKey('VersionRegex')) {
        $newRegex = if ($NewRepo.PSObject.Properties['Version Regex']) { 
            $NewRepo.'Version Regex' 
        } else { 
            "^v?(\d+)\.(\d+)\.(\d+)$" 
        }
        
        if ($ExistingRepo.VersionRegex -ne $newRegex) {
            $errorMessage = "Repository '$repoUrl' configuration conflict:`n" +
                           "Previously discovered with Version Regex: $($ExistingRepo.VersionRegex)`n" +
                           "Now attempting to use Version Regex: $newRegex`n" +
                           "Version Regex cannot change once established."
            throw $errorMessage
        }
    }
}

function Show-ErrorDialog {
    param(
        [string]$Title = "Git Error",
        [string]$Message
    )
    
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show($Message, $Title, 'OK', 'Error')
}

function Show-ConfirmDialog {
    param(
        [string]$Title = "Confirmation Required",
        [string]$Message
    )
    
    Add-Type -AssemblyName System.Windows.Forms
    $result = [System.Windows.Forms.MessageBox]::Show($Message, $Title, 'YesNo', 'Question')
    return $result -eq 'Yes'
}

function Test-GitInstalled {
    try {
        $null = git --version
        return $true
    }
    catch {
        Write-Log "Git is not installed or not in PATH" -Level Error
        Show-ErrorDialog -Message "Git is not installed or not accessible in PATH. Please install Git and try again."
        return $false
    }
}

function Test-GitLfsInstalled {
    try {
        $null = git lfs version
        return $true
    }
    catch {
        Write-Log "Git LFS is not installed" -Level Warning
        return $false
    }
}

function Test-PlinkInstalled {
    try {
        $null = Get-Command plink.exe -ErrorAction Stop
        return $true
    }
    catch {
        Write-Log "Plink is not installed or not in PATH" -Level Warning
        return $false
    }
}

function Get-RepositoryUrl {
    param(
        [string]$RepoPath
    )
    
    try {
        Push-Location $RepoPath
        $url = git config --get remote.origin.url 2>$null
        Pop-Location
        return $url
    }
    catch {
        Pop-Location
        return $null
    }
}

function Get-HostnameFromUrl {
    param(
        [string]$Url
    )
    
    Write-Log "Extracting hostname from URL: $Url" -Level Debug
    
    # Handle different URL formats
    if ($Url -match '^git@([^:]+):') {
        # git@hostname:path format
        $hostname = $matches[1]
        Write-Log "Matched git@ format, extracted hostname: $hostname" -Level Debug
        return $hostname
    }
    elseif ($Url -match '^ssh://(?:[^@]+@)?([^:/]+)(?::\d+)?') {
        # ssh://[user@]hostname[:port]/path format
        $hostname = $matches[1]
        Write-Log "Matched ssh:// format, extracted hostname: $hostname" -Level Debug
        return $hostname
    }
    elseif ($Url -match '^https?://(?:[^@]+@)?([^:/]+)') {
        # http(s)://[user@]hostname[:port]/path format
        $hostname = $matches[1]
        Write-Log "Matched http(s):// format, extracted hostname: $hostname" -Level Debug
        return $hostname
    }
    
    Write-Log "No matching URL format found for: $Url" -Level Debug
    return $null
}

function Get-SshKeyForUrl {
    param(
        [string]$Url
    )
    
    $hostname = Get-HostnameFromUrl -Url $Url
    if (-not $hostname) {
        Write-Log "Could not extract hostname from URL: $Url" -Level Debug
        return $null
    }
    
    Write-Log "Looking for SSH key for hostname: $hostname (from URL: $Url)" -Level Debug
    
    # Check exact hostname match first
    if ($script:SshCredentials.ContainsKey($hostname)) {
        Write-Log "Found SSH key for hostname: $hostname" -Level Debug
        return $script:SshCredentials[$hostname]
    }
    
    # Check with ssh:// prefix
    $sshHostname = "ssh://$hostname"
    if ($script:SshCredentials.ContainsKey($sshHostname)) {
        Write-Log "Found SSH key for ssh://$hostname" -Level Debug
        return $script:SshCredentials[$sshHostname]
    }
    
    Write-Log "No SSH key found for hostname: $hostname" -Level Debug
    return $null
}

function Set-GitSshKey {
    param(
        [string]$SshKeyPath,
        [string]$RepoUrl = ""
    )
    
    if (-not (Test-Path $SshKeyPath)) {
        Write-Log "SSH key file not found: $SshKeyPath" -Level Error
        return $false
    }
    
    # Check key file permissions (Windows)
    $keyFile = Get-Item $SshKeyPath
    $acl = Get-Acl $SshKeyPath
    Write-Log "SSH key file permissions: $($acl.Owner)" -Level Debug
    
    # Check if the key is in PuTTY format
    $keyContent = Get-Content $SshKeyPath -Raw -ErrorAction SilentlyContinue
    $isPuttyKey = $keyContent -match 'PuTTY-User-Key-File'
    
    if (-not (Test-PlinkInstalled)) {
        Write-Log "Plink not found. Please install PuTTY or add plink.exe to PATH" -Level Error
        Show-ErrorDialog -Message "Plink.exe not found!`n`nPlease either:`n1. Install PuTTY (which includes plink)`n2. Add plink.exe to your PATH"
        return $false
    }
    
    if (-not $isPuttyKey) {
        Write-Log "SSH key is not in PuTTY format" -Level Error
        Show-ErrorDialog -Message "The SSH key is not in PuTTY format (.ppk).`n`nPlease convert your key to PuTTY format using PuTTYgen."
        return $false
    }
    
    # Check if Pageant is running
    $pageantProcess = Get-Process pageant -ErrorAction SilentlyContinue
    if (-not $pageantProcess) {
        Write-Log "Pageant not running. Attempting to start it..." -Level Info
        
        # Try to find and start Pageant
        $pageantPath = Get-Command pageant.exe -ErrorAction SilentlyContinue
        if ($pageantPath) {
            Start-Process pageant.exe
            Start-Sleep -Seconds 2
            
            Show-ErrorDialog -Title "Pageant Started" -Message "Pageant has been started.`n`nPlease add your SSH key to Pageant:`n1. Right-click the Pageant icon in system tray`n2. Select 'Add Key'`n3. Browse to: $SshKeyPath`n4. Enter your passphrase`n`nThen click OK to continue."
        } else {
            Show-ErrorDialog -Message "Pageant not found. Please start Pageant and add your key before continuing."
            return $false
        }
    }
    
    # Configure Git to use plink
    $plinkPath = (Get-Command plink.exe).Source
    $env:GIT_SSH = $plinkPath
    Write-Log "Configured Git to use PuTTY/plink: $plinkPath" -Level Debug
    
    return $true
}

function Get-GitTagDates {
    param(
        [string]$RepoPath
    )
    
    Write-Log "Fetching tag dates for repository at: $RepoPath" -Level Debug
    
    if (-not (Test-Path $RepoPath)) {
        Write-Log "Repository path does not exist: $RepoPath" -Level Warning
        return @{}
    }
    
    try {
        Push-Location $RepoPath
        
        # Fetch all tags with their dates using git for-each-ref
        # This is more efficient than git log for each tag
        $gitCommand = "git for-each-ref --sort=creatordate --format='%(refname:short)|%(creatordate:iso8601)' refs/tags"
        Write-Log "Executing tag date fetch: $gitCommand" -Level Debug
        
        if ($DryRun) {
            Write-Log "DRY RUN: Would fetch tag dates from repository" -Level Verbose
            Pop-Location
            return @{}
        }
        
        $output = Invoke-Expression $gitCommand 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Git command failed to fetch tag dates: $output" -Level Warning
            Pop-Location
            return @{}
        }
        
        $tagDates = @{}
        $tagCount = 0
        
        foreach ($line in $output) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            
            $parts = $line -split '\|', 2
            if ($parts.Count -eq 2) {
                $tagName = $parts[0].Trim()
                $dateString = $parts[1].Trim()
                
                try {
                    $tagDate = [DateTime]::Parse($dateString)
                    $tagDates[$tagName] = $tagDate
                    $tagCount++
                    Write-Log "Parsed tag: $tagName -> $($tagDate.ToString('yyyy-MM-dd HH:mm:ss'))" -Level Debug
                }
                catch {
                    Write-Log "Failed to parse date for tag '$tagName': $dateString" -Level Warning
                }
            }
        }
        
        Pop-Location
        
        Write-Log "Successfully fetched dates for $tagCount tags" -Level Info
        
        # Output discovered tags in verbose mode
        if ($VerbosePreference -eq 'Continue') {
            Write-Log "Discovered tags and dates:" -Level Verbose
            $sortedTags = $tagDates.GetEnumerator() | Sort-Object Value
            foreach ($tag in $sortedTags) {
                Write-Log "  $($tag.Key): $($tag.Value.ToString('yyyy-MM-dd HH:mm:ss'))" -Level Verbose
            }
        }
        
        return $tagDates
    }
    catch {
        Pop-Location -ErrorAction SilentlyContinue
        Write-Log "Error fetching tag dates: $_" -Level Warning
        return @{}
    }
}

function Sort-TagsByDate {
    param(
        [array]$Tags,
        [hashtable]$TagDates,
        [string]$RepositoryUrl,
        [string]$Context = "compatibility resolution"
    )
    
    if ($TagDates.Count -eq 0) {
        Write-Log "No tag dates available for $Context, returning tags in original order" -Level Debug
        return $Tags
    }
    
    Write-Log "Performing tag temporal sorting for $Context on repository: $RepositoryUrl" -Level Debug
    
    # Separate tags that have dates from those that don't
    $tagsWithDates = @()
    $tagsWithoutDates = @()
    
    foreach ($tag in $Tags) {
        if ($TagDates.ContainsKey($tag)) {
            $tagsWithDates += [PSCustomObject]@{
                Tag = $tag
                Date = $TagDates[$tag]
            }
        } else {
            $tagsWithoutDates += $tag
        }
    }
    
    # Sort tags with dates by their creation date (oldest first)
    $sortedTagsWithDates = $tagsWithDates | Sort-Object { $_.Date } | ForEach-Object { $_.Tag }
    
    # Combine: sorted tags with dates first, then tags without dates in original order
    $sortedTags = @()
    $sortedTags += $sortedTagsWithDates
    $sortedTags += $tagsWithoutDates
    
    # Show verbose output for temporal sorting results
    if ($VerbosePreference -eq 'Continue') {
        Write-Log "Tag temporal sorting for $RepositoryUrl ($Context):" -Level Verbose
        Write-Log "  Original: $($Tags -join ', ')" -Level Verbose
        Write-Log "  Temporal: $($sortedTags -join ', ')" -Level Verbose
    }
    
    return $sortedTags
}

function Reset-GitRepository {
    param(
        [string]$RepoPath,
        [bool]$SkipLfs = $false
    )
    
    Write-Log "Resetting repository at: $RepoPath" -Level Verbose
    
    try {
        Push-Location $RepoPath
        
        # Reset main repository
        $gitCommands = @(
            "git reset --hard HEAD",
            "git clean -fdx"
        )
        
        foreach ($cmd in $gitCommands) {
            Write-Log "Executing: $cmd" -Level Debug
            if (-not $DryRun) {
                $output = Invoke-Expression $cmd 2>&1
                if ($LASTEXITCODE -ne 0) {
                    # If reset fails, try to recover
                    if ($cmd -match "reset") {
                        Write-Log "Reset failed, trying alternative approach..." -Level Warning
                        # Try to remove LFS hooks temporarily
                        $alternativeCmd = "git lfs uninstall"
                        Invoke-Expression $alternativeCmd 2>&1
                        # Try reset again
                        $output = Invoke-Expression $cmd 2>&1
                        # Reinstall LFS hooks
                        $reinstallCmd = "git lfs install --local"
                        Invoke-Expression $reinstallCmd 2>&1
                    }
                    if ($LASTEXITCODE -ne 0) {
                        throw "Command failed: $cmd`n$output"
                    }
                }
            }
        }
        
        # Reset submodules
        $submoduleCommands = @(
            "git submodule foreach --recursive git reset --hard",
            "git submodule foreach --recursive git clean -fdx"
        )
        
        foreach ($cmd in $submoduleCommands) {
            Write-Log "Executing: $cmd" -Level Debug
            if (-not $DryRun) {
                $output = Invoke-Expression $cmd 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Log "Warning: Submodule command had issues: $cmd`n$output" -Level Warning
                }
            }
        }
        
        # Update submodules to their correct commits
        if (Test-Path ".gitmodules") {
            Write-Log "Updating submodules to correct commits..." -Level Debug
            $submoduleCmd = "git submodule update --init --recursive --force"
            Write-Log "Executing: $submoduleCmd" -Level Debug
            if (-not $DryRun) {
                $output = Invoke-Expression $submoduleCmd 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Log "Warning: Submodule update had issues: $output" -Level Warning
                }
            }
        }
        
        Pop-Location
        return $true
    }
    catch {
        Pop-Location
        Write-Log "Failed to reset repository: $_" -Level Error
        return $false
    }
}

function Get-AbsoluteBasePath {
    param(
        [string]$BasePath,
        [string]$DependencyFilePath,
        [string]$RepositoryRootPath = $null
    )
    
    if ([System.IO.Path]::IsPathRooted($BasePath)) {
        # Normalize the path to remove any ".." or "." segments
        return [System.IO.Path]::GetFullPath($BasePath)
    }
    
    # If we have a repository root path (for nested dependencies), use that as the base
    # Otherwise, use the dependency file's directory (for root-level dependencies)
    if (-not [string]::IsNullOrWhiteSpace($RepositoryRootPath)) {
        $baseDir = $RepositoryRootPath
        Write-Log "Using repository root path as base: $baseDir" -Level Debug
    } else {
        $baseDir = Split-Path -Parent (Resolve-Path $DependencyFilePath)
        Write-Log "Using dependency file directory as base: $baseDir" -Level Debug
    }
    
    $combinedPath = Join-Path $baseDir $BasePath
    # Normalize the combined path to resolve ".." segments
    $resolvedPath = [System.IO.Path]::GetFullPath($combinedPath)
    Write-Log "Resolved relative path '$BasePath' to: $resolvedPath" -Level Debug
    
    return $resolvedPath
}

function Get-TagIntersection {
    param(
        [array]$Tags1,
        [array]$Tags2
    )
    
    # Use hashtable for intersection since HashSet constructor has issues in some PowerShell versions
    $set1 = @{}
    foreach ($tag in $Tags1) {
        $set1[$tag] = $true
    }
    
    $intersection = @()
    foreach ($tag in $Tags2) {
        if ($set1.ContainsKey($tag)) {
            $intersection += $tag
        }
    }
    
    return $intersection
}

function Get-TagUnion {
    param(
        [array]$Tags1,
        [array]$Tags2,
        [hashtable]$TagDates = @{},
        [string]$RepositoryUrl = ""
    )
    
    Write-Log "Computing tag union for repository: $RepositoryUrl" -Level Debug
    Write-Log "Tags1: $($Tags1 -join ', ')" -Level Debug
    Write-Log "Tags2: $($Tags2 -join ', ')" -Level Debug
    
    # Create union of all tags
    $unionSet = @{}
    foreach ($tag in $Tags1) {
        $unionSet[$tag] = $true
    }
    foreach ($tag in $Tags2) {
        $unionSet[$tag] = $true
    }
    
    $allTags = @($unionSet.Keys)
    $sortedUnion = Sort-TagsByDate -Tags $allTags -TagDates $TagDates -RepositoryUrl $RepositoryUrl -Context "union calculation"
    
    Write-Log "Temporal union result: $($sortedUnion -join ', ')" -Level Debug
    return $sortedUnion
}

function Get-CustomDependencyFilePath {
    param(
        [PSCustomObject]$Repository,
        [string]$RepoAbsolutePath,
        [string]$DefaultFileName
    )
    
    $dependencyFilePath = $Repository.'Dependency File Path'
    $dependencyFileName = $Repository.'Dependency File Name'
    
    # Start with the repository root path
    $basePath = $RepoAbsolutePath
    
    # Add custom subdirectory if specified
    if (-not [string]::IsNullOrWhiteSpace($dependencyFilePath)) {
        $basePath = Join-Path $basePath $dependencyFilePath
        Write-Log "Using custom dependency file path: $dependencyFilePath" -Level Debug
    }
    
    # Use custom file name if specified, otherwise use default
    $fileName = if (-not [string]::IsNullOrWhiteSpace($dependencyFileName)) {
        Write-Log "Using custom dependency file name: $dependencyFileName" -Level Debug
        $dependencyFileName
    } else {
        $DefaultFileName
    }
    
    $fullPath = Join-Path $basePath $fileName
    Write-Log "Resolved dependency file path: $fullPath" -Level Debug
    
    return $fullPath
}

function Invoke-PostCheckoutScript {
    param(
        [string]$RepoAbsolutePath,
        [string]$ScriptFileName,
        [string]$ScriptFilePath = "",
        [string]$RepositoryUrl = "",
        [string]$Tag = ""
    )
    
    if (-not $script:PostCheckoutScriptsEnabled) {
        Write-Log "Post-checkout scripts are disabled, skipping script execution" -Level Debug
        return $true
    }
    
    # Determine script location
    $scriptLocation = $RepoAbsolutePath
    if (-not [string]::IsNullOrWhiteSpace($ScriptFilePath)) {
        $scriptLocation = Join-Path $RepoAbsolutePath $ScriptFilePath
        Write-Log "Using custom post-checkout script path: $ScriptFilePath" -Level Debug
    }
    
    $scriptFullPath = Join-Path $scriptLocation $ScriptFileName
    Write-Log "Looking for post-checkout script at: $scriptFullPath" -Level Debug
    
    if (-not (Test-Path $scriptFullPath)) {
        Write-Log "Post-checkout script not found: $scriptFullPath" -Level Warning
        return $false
    }
    
    # Verify it's a PowerShell script
    if (-not $scriptFullPath.EndsWith('.ps1')) {
        Write-Log "Post-checkout script is not a PowerShell script (.ps1): $scriptFullPath" -Level Warning
        return $false
    }
    
    Write-Log "Executing post-checkout script: $scriptFullPath" -Level Info
    
    if ($DryRun) {
        Write-Log "DRY RUN: Would execute post-checkout script: $scriptFullPath" -Level Verbose
        return $true
    }
    
    try {
        # Set environment variables for the script
        $env:LSIGIT_REPOSITORY_URL = $RepositoryUrl
        $env:LSIGIT_REPOSITORY_PATH = $RepoAbsolutePath
        $env:LSIGIT_TAG = $Tag
        $env:LSIGIT_SCRIPT_VERSION = $script:Version
        
        # Change to repository directory for script execution
        Push-Location $RepoAbsolutePath
        
        # Execute the script with restricted execution policy
        $scriptStartTime = Get-Date
        Write-Log "Starting post-checkout script execution at: $($scriptStartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -Level Debug
        
        # Use Start-Process to execute with proper error handling and timeout
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = "powershell.exe"
        $processInfo.Arguments = "-ExecutionPolicy Bypass -File `"$scriptFullPath`""
        $processInfo.WorkingDirectory = $RepoAbsolutePath
        $processInfo.UseShellExecute = $false
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.CreateNoWindow = $true
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        
        # Start the process
        $started = $process.Start()
        if (-not $started) {
            throw "Failed to start post-checkout script process"
        }
        
        # Wait for completion with timeout (5 minutes)
        $timeoutMs = 300000  # 5 minutes
        $completed = $process.WaitForExit($timeoutMs)
        
        if (-not $completed) {
            Write-Log "Post-checkout script timed out after 5 minutes, terminating process" -Level Error
            try {
                $process.Kill()
                $process.WaitForExit(5000)  # Wait 5 seconds for cleanup
            } catch {
                Write-Log "Failed to terminate timed-out process: $_" -Level Warning
            }
            throw "Post-checkout script execution timed out after 5 minutes"
        }
        
        # Get output and error streams
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $exitCode = $process.ExitCode
        
        $scriptEndTime = Get-Date
        $executionDuration = $scriptEndTime - $scriptStartTime
        Write-Log "Post-checkout script completed in $($executionDuration.TotalSeconds) seconds with exit code: $exitCode" -Level Debug
        
        # Log script output
        if (-not [string]::IsNullOrWhiteSpace($stdout)) {
            Write-Log "Post-checkout script output: $stdout" -Level Debug
        }
        
        if (-not [string]::IsNullOrWhiteSpace($stderr)) {
            Write-Log "Post-checkout script errors: $stderr" -Level Warning
        }
        
        if ($exitCode -ne 0) {
            throw "Post-checkout script failed with exit code: $exitCode"
        }
        
        Pop-Location
        
        # Clean up environment variables
        Remove-Item Env:\LSIGIT_REPOSITORY_URL -ErrorAction SilentlyContinue
        Remove-Item Env:\LSIGIT_REPOSITORY_PATH -ErrorAction SilentlyContinue
        Remove-Item Env:\LSIGIT_TAG -ErrorAction SilentlyContinue
        Remove-Item Env:\LSIGIT_SCRIPT_VERSION -ErrorAction SilentlyContinue
        
        $script:PostCheckoutScriptExecutions++
        Write-Log "Successfully executed post-checkout script: $scriptFullPath" -Level Info
        return $true
    }
    catch {
        Pop-Location -ErrorAction SilentlyContinue
        
        # Clean up environment variables
        Remove-Item Env:\LSIGIT_REPOSITORY_URL -ErrorAction SilentlyContinue
        Remove-Item Env:\LSIGIT_REPOSITORY_PATH -ErrorAction SilentlyContinue
        Remove-Item Env:\LSIGIT_TAG -ErrorAction SilentlyContinue
        Remove-Item Env:\LSIGIT_SCRIPT_VERSION -ErrorAction SilentlyContinue
        
        $script:PostCheckoutScriptFailures++
        $errorMessage = "Failed to execute post-checkout script '$scriptFullPath': $_"
        Write-Log $errorMessage -Level Error
        return $false
    }
}

function Update-RepositoryDictionary {
    param(
        [PSCustomObject]$Repository,
        [string]$DependencyFilePath,
        [string]$CallingRepositoryRootPath = $null
    )
    
    try {
        $repoUrl = $Repository.'Repository URL'
        
        # Determine dependency resolution mode
        $dependencyMode = if ($Repository.PSObject.Properties['Dependency Resolution']) { 
            $Repository.'Dependency Resolution' 
        } else { 
            "Agnostic" 
        }
        
        # If repository exists, validate configuration hasn't changed
        if ($script:RepositoryDictionary.ContainsKey($repoUrl)) {
            Invoke-WithErrorContext -Context "Validating configuration for existing repository: $repoUrl" -ScriptBlock {
                Validate-DependencyConfiguration -NewRepo $Repository -ExistingRepo $script:RepositoryDictionary[$repoUrl]
            }
        }
        
        Write-Log "Processing repository '$repoUrl' with Dependency Resolution: $dependencyMode" -Level Debug
        
        if ($dependencyMode -eq "SemVer") {
            # Check if Update-SemVerRepository function exists
            $funcExists = Get-Command -Name Update-SemVerRepository -ErrorAction SilentlyContinue
            if (-not $funcExists) {
                throw "Update-SemVerRepository function is not defined. Ensure all SemVer functions are added to the script."
            }
            
            # Delegate to SemVer-specific logic with error context
            return Invoke-WithErrorContext -Context "Updating SemVer repository: $repoUrl" -ScriptBlock {
                Update-SemVerRepository -Repository $Repository `
                                       -DependencyFilePath $DependencyFilePath `
                                       -CallingRepositoryRootPath $CallingRepositoryRootPath
            }
        } else {
            # Agnostic mode logic
            $basePath = $Repository.'Base Path'
            $tag = $Repository.Tag
            $apiCompatibleTags = $Repository.'API Compatible Tags'
            $apiCompatibility = if ($Repository.PSObject.Properties['API Compatibility']) { 
                $Repository.'API Compatibility' 
            } else { 
                $script:DefaultApiCompatibility 
            }
            
            # Calculate absolute base path
            $absoluteBasePath = Get-AbsoluteBasePath -BasePath $basePath -DependencyFilePath $DependencyFilePath -RepositoryRootPath $CallingRepositoryRootPath
            
            if ($script:RepositoryDictionary.ContainsKey($repoUrl)) {
                # Repository already exists
                Write-Log "Repository already exists in dictionary, checking compatibility..." -Level Info
                
                $existingRepo = $script:RepositoryDictionary[$repoUrl]
                $existingTag = $existingRepo.Tag
                $existingApiCompatibleTags = $existingRepo.ApiCompatibleTags
                $existingAbsolutePath = $existingRepo.AbsolutePath
                
                # Check if paths match
                if ($existingAbsolutePath -ne $absoluteBasePath) {
                    $errorMessage = "Repository path conflict for '$repoUrl':`nExisting path: $existingAbsolutePath`nNew path: $absoluteBasePath"
                    Write-Log $errorMessage -Level Error
                    Show-ErrorDialog -Message $errorMessage
                    throw $errorMessage
                }
                
                # Get tag dates if available
                $tagDates = if ($existingRepo.ContainsKey('TagDates')) { $existingRepo.TagDates } else { @{} }
                
                # Check API compatibility
                if ($apiCompatibility -eq 'Strict') {
                    # Strict mode: tags must match exactly
                    if ($tag -ne $existingTag) {
                        $errorMessage = "Tag conflict for repository '$repoUrl' in Strict mode:`nExisting tag: $existingTag`nRequired tag: $tag"
                        Write-Log $errorMessage -Level Error
                        Show-ErrorDialog -Message $errorMessage
                        throw $errorMessage
                    }
                    Write-Log "Repository '$repoUrl' already checked out with matching tag (Strict mode)" -Level Debug
                    return $true
                } else {
                    # Permissive mode: check if current tag is compatible
                    $allCompatibleTags = if ($existingApiCompatibleTags) {
                        # Merge and sort API compatible tags using temporal sorting
                        $union = Get-TagUnion -Tags1 $existingApiCompatibleTags -Tags2 @($tag) -TagDates $tagDates -RepositoryUrl $repoUrl
                        
                        # If new repository has API compatible tags, merge those too
                        if ($apiCompatibleTags) {
                            $union = Get-TagUnion -Tags1 $union -Tags2 $apiCompatibleTags -TagDates $tagDates -RepositoryUrl $repoUrl
                        }
                        
                        $union
                    } elseif ($apiCompatibleTags) {
                        # Use temporal sorting for API compatible tags
                        $sorted = Sort-TagsByDate -Tags $apiCompatibleTags -TagDates $tagDates -RepositoryUrl $repoUrl
                        $sorted
                    } else {
                        @($existingTag, $tag) | Select-Object -Unique
                    }
                    
                    # Check if existing tag is compatible with new requirement
                    if ($existingTag -eq $tag -or ($apiCompatibleTags -and $existingTag -in $apiCompatibleTags)) {
                        Write-Log "Repository '$repoUrl' already checked out with compatible tag: $existingTag" -Level Debug
                        
                        # Update API compatible tags in dictionary
                        $existingRepo.ApiCompatibleTags = $allCompatibleTags
                        
                        return $true
                    } else {
                        # Need to checkout a different tag
                        Write-Log "Repository '$repoUrl' needs different tag. Current: $existingTag, Required: $tag" -Level Info
                        
                        # Update repository info
                        $existingRepo.Tag = $tag
                        $existingRepo.ApiCompatibleTags = $allCompatibleTags
                        $existingRepo.NeedCheckout = $true
                        
                        return "NeedCheckout"
                    }
                }
            } else {
                # New repository - add to dictionary
                Write-Log "First discovery of repository: $repoUrl" -Level Info
                
                $script:RepositoryDictionary[$repoUrl] = @{
                    AbsolutePath = $absoluteBasePath
                    Tag = $tag
                    ApiCompatibleTags = $apiCompatibleTags
                    ApiCompatibility = $apiCompatibility
                    AlreadyCheckedOut = $false
                    NeedCheckout = $false
                    CheckoutFailed = $false
                    DependencyResolution = "Agnostic"
                    DependencyFilePath = $Repository.'Dependency File Path'
                    DependencyFileName = $Repository.'Dependency File Name'
                }
                
                Write-Log "Added new repository to dictionary: '$repoUrl' with tag: $tag" -Level Debug
                
                return $false  # Repository needs to be checked out
            }
        }
    }
    catch {
        Write-ErrorWithContext -ErrorRecord $_ -AdditionalMessage "Repository: $($Repository.'Repository URL')"
        throw
    }
}

function Update-SemVerRepository {
    <#
    .SYNOPSIS
        Updates repository dictionary for SemVer mode repositories with floating version support
    #>
    param(
        [PSCustomObject]$Repository,
        [string]$DependencyFilePath,
        [string]$CallingRepositoryRootPath = $null
    )
    
    $repoUrl = $Repository.'Repository URL'
    $basePath = $Repository.'Base Path'
    
    # Parse version pattern (now supports floating versions)
    $versionPattern = $Repository.Version
    if (-not $versionPattern) {
        throw "Repository '$repoUrl' uses SemVer mode but no 'Version' field specified"
    }
    
    try {
        $parsedPattern = Parse-VersionPattern -VersionPattern $versionPattern
        Write-Log "Parsed version pattern '$versionPattern' as type: $($parsedPattern.Type)" -Level Debug
    }
    catch {
        throw "Repository '$repoUrl' has invalid Version pattern '$versionPattern': $($_.Exception.Message)"
    }
    
    # Get version regex
    $versionRegex = if ($Repository.PSObject.Properties['Version Regex']) { 
        $Repository.'Version Regex' 
    } else { 
        "^v?(\d+)\.(\d+)\.(\d+)$" 
    }
    
    # Calculate absolute base path
    $absoluteBasePath = Get-AbsoluteBasePath -BasePath $basePath -DependencyFilePath $DependencyFilePath -RepositoryRootPath $CallingRepositoryRootPath
    
    # Determine calling repository URL for tracking
    $callerUrl = if ($CallingRepositoryRootPath) {
        # Find the calling repository URL by matching the path
        $caller = $script:RepositoryDictionary.GetEnumerator() | 
            Where-Object { $_.Value.AbsolutePath -eq $CallingRepositoryRootPath } | 
            Select-Object -First 1
        if ($caller) { $caller.Key } else { "unknown-caller" }
    } else {
        "root-dependency-file"
    }
    
    if ($script:RepositoryDictionary.ContainsKey($repoUrl)) {
        # Existing repository
        Write-Log "SemVer repository already exists in dictionary, checking version pattern compatibility..." -Level Info
        
        $existingRepo = $script:RepositoryDictionary[$repoUrl]
        $existingAbsolutePath = $existingRepo.AbsolutePath
        
        # Check if paths match
        if ($existingAbsolutePath -ne $absoluteBasePath) {
            $errorMessage = "Repository path conflict for '$repoUrl':`nExisting path: $existingAbsolutePath`nNew path: $absoluteBasePath"
            Write-Log $errorMessage -Level Error
            Show-ErrorDialog -Message $errorMessage
            throw $errorMessage
        }
        
        # Add new caller's requested version pattern
        if (-not $existingRepo.ContainsKey('RequestedPatterns')) {
            $existingRepo.RequestedPatterns = @{}
        }
        $existingRepo.RequestedPatterns[$callerUrl] = $parsedPattern
        
        Write-Log "Caller '$callerUrl' requests version pattern: $($parsedPattern.OriginalPattern) (type: $($parsedPattern.Type))" -Level Debug
        
        # Get compatible versions for new request
        $newCompatible = Get-CompatibleVersionsForPattern -ParsedVersions $existingRepo.ParsedVersions -VersionPattern $parsedPattern
        
        # Intersect with existing compatible versions
        $intersection = Get-SemVersionIntersection -Set1 $existingRepo.CompatibleVersions -Set2 $newCompatible
        
        if ($intersection.Count -eq 0) {
            # Build detailed error message
            $callerDetails = @()
            foreach ($caller in $existingRepo.RequestedPatterns.GetEnumerator()) {
                $pattern = $caller.Value.OriginalPattern
                $compatible = Get-CompatibleVersionsForPattern -ParsedVersions $existingRepo.ParsedVersions -VersionPattern $caller.Value
                $compatibleStr = ($compatible | ForEach-Object { $_.Tag }) -join ', '
                $callerDetails += "- $($caller.Key) requests: $pattern (type: $($caller.Value.Type), compatible: $compatibleStr)"
            }
            
            $errorMessage = "SemVer conflict for repository '$repoUrl':`n" +
                           "No version satisfies all requirements:`n" +
                           ($callerDetails -join "`n")
            
            Write-Log $errorMessage -Level Error
            Show-ErrorDialog -Message $errorMessage
            throw $errorMessage
        }
        
        # Select version based on pattern types (floating vs lowest-applicable)
        $selected = Select-VersionFromIntersection -IntersectionVersions $intersection -RequestedPatterns $existingRepo.RequestedPatterns
        
        $oldTag = $existingRepo.SelectedTag
        $newTag = $selected.Tag
        
        Write-Log "SemVer resolution: Selected version $(Format-SemVersion $selected.Version) (tag: $newTag)" -Level Info
        
        # Update repository state
        $existingRepo.CompatibleVersions = $intersection
        $existingRepo.SelectedVersion = $selected.Version
        $existingRepo.SelectedTag = $selected.Tag
        
        # Check if we need to checkout a different version
        if ($oldTag -ne $newTag) {
            $existingRepo.NeedCheckout = $true
            Write-Log "Repository '$repoUrl' needs checkout from tag '$oldTag' to '$newTag'" -Level Info
            return "NeedCheckout"
        } else {
            Write-Log "Repository '$repoUrl' already at correct tag '$oldTag'" -Level Debug
            return $true
        }
        
    } else {
        # New repository
        Write-Log "First discovery of SemVer repository: $repoUrl" -Level Info
        Write-Log "Requested version pattern: $($parsedPattern.OriginalPattern) (type: $($parsedPattern.Type))" -Level Debug
        
        # For new repositories, we need to mark that versions need to be parsed after clone
        $script:RepositoryDictionary[$repoUrl] = @{
            AbsolutePath = $absoluteBasePath
            DependencyResolution = "SemVer"
            VersionRegex = $versionRegex
            RequestedPatterns = @{ $callerUrl = $parsedPattern }
            NeedVersionParsing = $true  # Flag to parse versions after clone
            AlreadyCheckedOut = $false
            NeedCheckout = $false
            CheckoutFailed = $false
            DependencyFilePath = $Repository.'Dependency File Path'
            DependencyFileName = $Repository.'Dependency File Name'
        }
        
        Write-Log "Added new SemVer repository to dictionary: '$repoUrl'" -Level Debug
        
        return $false  # Repository needs to be checked out
    }
}

function Invoke-GitCheckout {
    param(
        [PSCustomObject]$Repository,
        [string]$DependencyFilePath,
        [string]$CallingRepositoryRootPath = $null
    )
    
    $repoUrl = $Repository.'Repository URL'
    $basePath = $Repository.'Base Path'
    $tag = $Repository.Tag
    $skipLfs = if ($null -eq $Repository.'Skip LFS') { $false } else { $Repository.'Skip LFS' }
    $wasNewClone = $false
    $wasActualCheckout = $false
    
    # Check if we should skip this repository (already checked out with compatible API)
    if ($script:RecursiveMode) {
        $checkoutResult = Update-RepositoryDictionary -Repository $Repository -DependencyFilePath $DependencyFilePath -CallingRepositoryRootPath $CallingRepositoryRootPath
        if ($checkoutResult -eq $true) {
            Write-Log "Skipping repository '$repoUrl' - already checked out with compatible API" -Level Info
            return $true
        }
        elseif ($checkoutResult -eq "NeedCheckout") {
            # Repository exists but needs to be checked out to a different tag
            $repoInfo = $script:RepositoryDictionary[$repoUrl]
            $newTag = $repoInfo.Tag
            $absoluteBasePath = $repoInfo.AbsolutePath
            
            # For SemVer repositories, use SelectedTag
            if ($repoInfo.ContainsKey('DependencyResolution') -and $repoInfo.DependencyResolution -eq "SemVer") {
                $newTag = $repoInfo.SelectedTag
            }
            
            Write-Log "Repository '$repoUrl' already exists but needs checkout to tag: $newTag" -Level Info
            
            try {
                Push-Location $absoluteBasePath
                
                # Fetch latest tags
                $fetchCmd = "git fetch --all --tags"
                Write-Log "Executing: $fetchCmd" -Level Debug
                if (-not $DryRun) {
                    $output = Invoke-Expression $fetchCmd 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        throw "Fetch failed: $output"
                    }
                }
                
                # Checkout the new tag
                Write-Log "Checking out updated tag: $newTag" -Level Info
                $checkoutCmd = "git checkout $newTag"
                Write-Log "Executing: $checkoutCmd" -Level Debug
                if (-not $DryRun) {
                    # Use & operator to properly capture stderr
                    $gitOutput = & git checkout $newTag 2>&1
                    
                    if ($LASTEXITCODE -ne 0) {
                        # Combine all output for error details
                        $errorDetails = ($gitOutput | Out-String).Trim()
                        
                        # Check for common git error patterns
                        if ($errorDetails -match "pathspec '(.+)' did not match" -or 
                            $errorDetails -match "error: pathspec '(.+)' did not match any file\(s\) known to git") {
                            throw "Tag '$newTag' does not exist in repository '$repoUrl'"
                        } elseif ($errorDetails) {
                            throw "Checkout failed: $errorDetails"
                        } else {
                            throw "Checkout failed with exit code $LASTEXITCODE (no error details available)"
                        }
                    }
                    $wasActualCheckout = $true
                }
                
                Pop-Location
                
                # Mark as no longer needing checkout
                $script:RepositoryDictionary[$repoUrl].NeedCheckout = $false
                
                Write-Log "Successfully updated repository '$repoUrl' to tag: $newTag" -Level Info
                return $true
            }
            catch {
                Pop-Location -ErrorAction SilentlyContinue
                $errorMessage = "Error updating repository '$repoUrl' to tag '$newTag': $_"
                Write-Log $errorMessage -Level Error
                Show-ErrorDialog -Message $errorMessage
                
                # Mark as failed
                if ($script:RepositoryDictionary.ContainsKey($repoUrl)) {
                    $script:RepositoryDictionary[$repoUrl].CheckoutFailed = $true
                }
                
                return $false
            }
        }
        # Otherwise, continue with normal checkout process
    }
    
    Write-Log "Processing repository: $repoUrl" -Level Info
    Write-Log "Base Path: $basePath" -Level Verbose
    Write-Log "Tag: $tag" -Level Verbose
    if ($skipLfs) {
        Write-Log "Skip LFS: Yes" -Level Verbose
    }
    
    # Log custom dependency file settings if present
    $customDependencyFilePath = $Repository.'Dependency File Path'
    $customDependencyFileName = $Repository.'Dependency File Name'
    if (-not [string]::IsNullOrWhiteSpace($customDependencyFilePath)) {
        Write-Log "Custom Dependency File Path: $customDependencyFilePath" -Level Verbose
    }
    if (-not [string]::IsNullOrWhiteSpace($customDependencyFileName)) {
        Write-Log "Custom Dependency File Name: $customDependencyFileName" -Level Verbose
    }
    
    # Handle SSH key if URL is SSH
    if ($repoUrl -match '^git@|^ssh://') {
        $sshKeyPath = Get-SshKeyForUrl -Url $repoUrl
        if ($sshKeyPath) {
            Write-Log "Found SSH key for repository: $sshKeyPath" -Level Debug
            if (-not (Set-GitSshKey -SshKeyPath $sshKeyPath -RepoUrl $repoUrl)) {
                return $false
            }
        } else {
            Write-Log "No SSH key configured for repository URL: $repoUrl" -Level Warning
        }
    }
    
    # Convert relative path to absolute using repository root if available
    $absoluteBasePath = Get-AbsoluteBasePath -BasePath $basePath -DependencyFilePath $DependencyFilePath -RepositoryRootPath $CallingRepositoryRootPath
    
    # Check if base path exists
    if (Test-Path $absoluteBasePath) {
        Write-Log "Base path exists: $absoluteBasePath" -Level Verbose
        
        # Check if it's a git repository
        $gitDir = Join-Path $absoluteBasePath ".git"
        if (Test-Path $gitDir) {
            # Check if it points to the same repository
            $existingUrl = Get-RepositoryUrl -RepoPath $absoluteBasePath
            if ($existingUrl -eq $repoUrl) {
                Write-Log "Repository already exists with correct URL, resetting..." -Level Info
                $skipLfsValue = if ($null -eq $skipLfs) { $false } else { [bool]$skipLfs }
                if (-not (Reset-GitRepository -RepoPath $absoluteBasePath -SkipLfs $skipLfsValue)) {
                    Show-ErrorDialog -Message "Failed to reset repository at: $absoluteBasePath"
                    return $false
                }
            }
            else {
                Write-Log "Different repository exists at path" -Level Warning
                $message = "The folder '$absoluteBasePath' contains a different repository.`n`nExisting: $existingUrl`nRequired: $repoUrl`n`nDo you want to delete the existing content?"
                if (Show-ConfirmDialog -Message $message) {
                    Write-Log "User agreed to delete existing content" -Level Info
                    if (-not $DryRun) {
                        Remove-Item -Path $absoluteBasePath -Recurse -Force
                    }
                }
                else {
                    Write-Log "User declined to delete existing content, stopping script" -Level Warning
                    exit 1
                }
            }
        }
        else {
            # Not a git repository
            $message = "The folder '$absoluteBasePath' exists but is not a Git repository.`n`nDo you want to delete the existing content?"
            if (Show-ConfirmDialog -Message $message) {
                Write-Log "User agreed to delete existing content" -Level Info
                if (-not $DryRun) {
                    Remove-Item -Path $absoluteBasePath -Recurse -Force
                }
            }
            else {
                Write-Log "User declined to delete existing content, stopping script" -Level Warning
                exit 1
            }
        }
    }
    
    # Track if this is a new clone
    $wasNewClone = -not (Test-Path (Join-Path $absoluteBasePath ".git"))
    
    # Create base path if it doesn't exist
    if (-not (Test-Path $absoluteBasePath)) {
        Write-Log "Creating base path: $absoluteBasePath" -Level Info
        if (-not $DryRun) {
            New-Item -ItemType Directory -Path $absoluteBasePath -Force | Out-Null
        }
    }
    
    try {
        # Clone or fetch repository
        if (-not (Test-Path (Join-Path $absoluteBasePath ".git"))) {
            Write-Log "Cloning repository..." -Level Info
            
            # Use direct git command with proper quoting
            Write-Log "Executing: git clone `"$repoUrl`" `"$absoluteBasePath`"" -Level Debug
            
            if (-not $DryRun) {
                # Change to parent directory to avoid path issues
                $parentPath = Split-Path $absoluteBasePath -Parent
                $repoName = Split-Path $absoluteBasePath -Leaf
                
                Push-Location $parentPath
                try {
                    # If LFS should be skipped, use --no-checkout to avoid LFS downloads during clone
                    if ($skipLfs) {
                        Write-Log "Cloning without checkout to skip LFS..." -Level Debug
                        $gitOutput = & git clone --no-checkout $repoUrl $repoName 2>&1
                        
                        if ($LASTEXITCODE -eq 0) {
                            # Now checkout without LFS
                            Push-Location $repoName
                            Write-Log "Configuring Git to skip LFS..." -Level Debug
                            & git config --local lfs.fetchexclude "*"
                            & git checkout $tag 2>&1
                            Pop-Location
                        }
                    } else {
                        # Normal clone
                        $gitOutput = & git clone $repoUrl $repoName 2>&1
                    }
                    
                    if ($LASTEXITCODE -ne 0) {
                        throw "Clone failed: $($gitOutput -join "`n")"
                    }
                    $wasActualCheckout = $true
                } finally {
                    Pop-Location
                }
            } else {
                $wasActualCheckout = $true  # For dry run, assume checkout would happen
            }
        }
        else {
            Write-Log "Fetching latest changes..." -Level Info
            Push-Location $absoluteBasePath
            
            $fetchCmd = "git fetch --all --tags"
            Write-Log "Executing: $fetchCmd" -Level Debug
            
            if (-not $DryRun) {
                $output = Invoke-Expression $fetchCmd 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Pop-Location
                    throw "Fetch failed: $output"
                }
            }
            
            Pop-Location
        }
        
        # Handle SemVer version parsing for new repositories
        if ($script:RecursiveMode -and 
            $script:RepositoryDictionary.ContainsKey($repoUrl) -and
            $script:RepositoryDictionary[$repoUrl].ContainsKey('NeedVersionParsing') -and
            $script:RepositoryDictionary[$repoUrl].NeedVersionParsing) {
            
            Write-Log "Parsing SemVer versions for newly cloned repository" -Level Info
            
            Push-Location $absoluteBasePath
            try {
                $repoDict = $script:RepositoryDictionary[$repoUrl]
                
                # Parse all versions from tags
                $parseResult = Parse-RepositoryVersions -RepoPath $absoluteBasePath `
                                                       -VersionRegex $repoDict.VersionRegex
                
                $repoDict.ParsedVersions = $parseResult.ParsedVersions
                $repoDict.CompiledRegex = $parseResult.CompiledRegex
                
                # Get all requested patterns and find compatible ones
                $allCompatible = $null
                foreach ($request in $repoDict.RequestedPatterns.GetEnumerator()) {
                    $compatible = Get-CompatibleVersionsForPattern -ParsedVersions $repoDict.ParsedVersions `
                                                                 -VersionPattern $request.Value
                    
                    if ($null -eq $allCompatible) {
                        $allCompatible = $compatible
                    } else {
                        # Intersect with previous compatible versions
                        $allCompatible = Get-SemVersionIntersection -Set1 $allCompatible -Set2 $compatible
                    }
                }
                
                if ($allCompatible.Count -eq 0) {
                    throw "No compatible SemVer version found after parsing repository"
                }
                
                # Select version based on pattern types
                $selected = Select-VersionFromIntersection -IntersectionVersions $allCompatible -RequestedPatterns $repoDict.RequestedPatterns
                
                $repoDict.CompatibleVersions = $allCompatible
                $repoDict.SelectedVersion = $selected.Version
                $repoDict.SelectedTag = $selected.Tag
                $repoDict.Remove('NeedVersionParsing')
                
                # Update the tag variable for checkout
                $tag = $selected.Tag
                
                Write-Log "SemVer: Selected version $(Format-SemVersion $selected.Version) (tag: $tag) for checkout" -Level Info
                
            }
            catch {
                Pop-Location -ErrorAction SilentlyContinue
                throw "Failed to parse SemVer versions: $_"
            }
            Pop-Location
        }
        
        # For SemVer repositories that need checkout to different version
        if ($script:RecursiveMode -and 
            $script:RepositoryDictionary.ContainsKey($repoUrl) -and
            $script:RepositoryDictionary[$repoUrl].ContainsKey('DependencyResolution') -and
            $script:RepositoryDictionary[$repoUrl].DependencyResolution -eq "SemVer") {
            
            # Use the selected tag for SemVer repositories
            if ($script:RepositoryDictionary[$repoUrl].ContainsKey('SelectedTag')) {
                $tag = $script:RepositoryDictionary[$repoUrl].SelectedTag
            }
        }
        
        # Checkout tag
        Push-Location $absoluteBasePath
        
        # Skip checkout if we already did it during clone for LFS skip
        if (-not ($skipLfs -and $wasNewClone)) {
            Write-Log "Checking out tag: $tag" -Level Info
            $checkoutCmd = "git checkout $tag"
            Write-Log "Executing: $checkoutCmd" -Level Debug
            
            if (-not $DryRun) {
                # Use & operator to properly capture stderr
                $gitOutput = & git checkout $tag 2>&1
                
                if ($LASTEXITCODE -ne 0) {
                    Pop-Location
                    # Combine all output for error details
                    $errorDetails = ($gitOutput | Out-String).Trim()
                    
                    # Check for common git error patterns
                    if ($errorDetails -match "pathspec '(.+)' did not match" -or 
                        $errorDetails -match "error: pathspec '(.+)' did not match any file\(s\) known to git") {
                        throw "Tag '$tag' does not exist in repository '$repoUrl'"
                    } elseif ($errorDetails) {
                        throw "Checkout failed: $errorDetails"
                    } else {
                        throw "Checkout failed with exit code $LASTEXITCODE (no error details available)"
                    }
                }
                $wasActualCheckout = $true
            } else {
                $wasActualCheckout = $true  # For dry run, assume checkout would happen
            }
        }
        
        # Fetch tag dates for recursive mode (only for Agnostic mode)
        if ($script:RecursiveMode -and 
            (!$script:RepositoryDictionary.ContainsKey($repoUrl) -or 
             !$script:RepositoryDictionary[$repoUrl].ContainsKey('DependencyResolution') -or 
             $script:RepositoryDictionary[$repoUrl].DependencyResolution -ne "SemVer")) {
            
            Write-Log "Fetching tag dates for repository: $repoUrl" -Level Info
            $tagDates = Get-GitTagDates -RepoPath $absoluteBasePath
            
            # Store tag dates in repository dictionary
            if ($script:RepositoryDictionary.ContainsKey($repoUrl)) {
                $script:RepositoryDictionary[$repoUrl].TagDates = $tagDates
                Write-Log "Stored tag dates for $($tagDates.Count) tags in repository dictionary" -Level Debug
            }
        }
        
        # Initialize and update submodules
        if (Test-Path ".gitmodules") {
            Write-Log "Initializing and updating submodules..." -Level Info
            
            # Initialize submodules
            $initCmd = "git submodule init"
            Write-Log "Executing: $initCmd" -Level Debug
            if (-not $DryRun) {
                $output = Invoke-Expression $initCmd 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Log "Warning: Submodule init had issues: $($output -join "`n")" -Level Warning
                }
            }
            
            # Get list of submodules for SSH configuration
            $submodules = git config --file .gitmodules --get-regexp path | ForEach-Object {
                if ($_ -match 'submodule\.(.+)\.path\s+(.+)') {
                    @{
                        Name = $matches[1]
                        Path = $matches[2]
                        Url = git config --file .gitmodules --get "submodule.$($matches[1]).url"
                    }
                }
            }
            
            # Update each submodule individually for better control
            foreach ($submodule in $submodules) {
                $submoduleName = $submodule.Name
                $submodulePath = $submodule.Path
                
                Write-Log "Updating submodule: $submoduleName" -Level Debug
                
                # Check if submodule needs SSH
                $submoduleUrl = $submodule.Url
                $needsSsh = $submoduleUrl -match '^git@|^ssh://'
                
                if ($needsSsh) {
                    # Look up SSH key based on hostname
                    $submoduleSshKey = Get-SshKeyForUrl -Url $submoduleUrl
                    
                    if ($submoduleSshKey) {
                        Write-Log "Updating submodule '$submoduleName' with SSH key: $submoduleSshKey" -Level Debug
                        
                        # Temporarily set SSH key for this submodule update
                        $originalGitSsh = $env:GIT_SSH
                        $originalGitSshCommand = $env:GIT_SSH_COMMAND
                        
                        if (Set-GitSshKey -SshKeyPath $submoduleSshKey -RepoUrl $submoduleUrl) {
                            $updateCmd = "git submodule update --force `"$submodulePath`""
                            Write-Log "Executing: $updateCmd" -Level Debug
                            $output = Invoke-Expression $updateCmd 2>&1
                            
                            # Restore original SSH settings
                            if ($originalGitSsh) {
                                $env:GIT_SSH = $originalGitSsh
                            } else {
                                Remove-Item Env:\GIT_SSH -ErrorAction SilentlyContinue
                            }
                            if ($originalGitSshCommand) {
                                $env:GIT_SSH_COMMAND = $originalGitSshCommand
                            } else {
                                Remove-Item Env:\GIT_SSH_COMMAND -ErrorAction SilentlyContinue
                            }
                        } else {
                            Write-Log "Failed to set SSH key for submodule '$submoduleName'" -Level Error
                            $LASTEXITCODE = 1
                            $output = "Failed to configure SSH authentication"
                        }
                    } else {
                        Write-Log "No SSH key configured for SSH submodule '$submoduleName' (URL: $submoduleUrl)" -Level Warning
                        $updateCmd = "git submodule update --force `"$submodulePath`""
                        Write-Log "Executing: $updateCmd" -Level Debug
                        $output = Invoke-Expression $updateCmd 2>&1
                    }
                } else {
                    # No SSH needed
                    $updateCmd = "git submodule update --force `"$submodulePath`""
                    Write-Log "Executing: $updateCmd" -Level Debug
                    $output = Invoke-Expression $updateCmd 2>&1
                }
                
                if ($LASTEXITCODE -ne 0) {
                    Write-Log "Warning: Submodule update failed for '$submoduleName': $($output -join "`n")" -Level Warning
                } else {
                    Write-Log "Successfully updated submodule: $submoduleName" -Level Debug
                }
            }
        }
        
        # Handle Git LFS if available and not skipped
        if ((Test-GitLfsInstalled) -and (-not $skipLfs)) {
            Write-Log "Initializing Git LFS..." -Level Info
            $lfsCommands = @(
                "git lfs install",
                "git lfs pull"
            )
            
            foreach ($cmd in $lfsCommands) {
                Write-Log "Executing: $cmd" -Level Debug
                if (-not $DryRun) {
                    $output = Invoke-Expression $cmd 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        Write-Log "LFS command failed (non-fatal): $cmd`n$output" -Level Warning
                    }
                }
            }
        } elseif ($skipLfs) {
            Write-Log "Skipping Git LFS pull as configured" -Level Info
        }
        
        Pop-Location
        
        # Mark repository as checked out in dictionary
        if ($script:RecursiveMode -and $script:RepositoryDictionary.ContainsKey($repoUrl)) {
            $script:RepositoryDictionary[$repoUrl].AlreadyCheckedOut = $true
            $script:RepositoryDictionary[$repoUrl].CheckoutFailed = $false
        }
        
        Write-Log "Successfully processed repository: $repoUrl" -Level Info
        return $true
    }
    catch {
        if (Get-Location | Where-Object { $_.Path -ne $absoluteBasePath }) {
            Pop-Location -ErrorAction SilentlyContinue
        }
        
        # If this was a fresh clone that failed during checkout, remove it
        if ($wasNewClone -and (Test-Path $absoluteBasePath)) {
            Write-Log "Removing incomplete clone at: $absoluteBasePath" -Level Warning
            try {
                Remove-Item -Path $absoluteBasePath -Recurse -Force -ErrorAction Stop
            } catch {
                Write-Log "Failed to remove incomplete clone: $_" -Level Warning
            }
        }
        
        # Mark repository as failed in dictionary
        if ($script:RecursiveMode -and $script:RepositoryDictionary.ContainsKey($repoUrl)) {
            $script:RepositoryDictionary[$repoUrl].CheckoutFailed = $true
        }
        
        $errorMessage = "Error processing repository '$repoUrl': $_"
        Write-Log $errorMessage -Level Error
        Show-ErrorDialog -Message $errorMessage
        return $false
    }
    finally {
        # Clear SSH environment variables
        if ($env:GIT_SSH_COMMAND) {
            Remove-Item Env:\GIT_SSH_COMMAND -ErrorAction SilentlyContinue
        }
        if ($env:GIT_SSH) {
            Remove-Item Env:\GIT_SSH -ErrorAction SilentlyContinue
        }
    }
}

function Process-DependencyFile {
    param(
        [string]$DependencyFilePath,
        [int]$Depth,
        [string]$CallingRepositoryRootPath = $null
    )
    
    # Check if we've already processed this file (circular dependency)
    $resolvedPath = Resolve-Path $DependencyFilePath -ErrorAction SilentlyContinue
    if ($resolvedPath -and $script:ProcessedDependencyFiles -contains $resolvedPath.Path) {
        Write-Log "Skipping already processed dependency file: $DependencyFilePath" -Level Debug
        return @()
    }
    
    if ($resolvedPath) {
        $script:ProcessedDependencyFiles += $resolvedPath.Path
    }
    
    Write-Log "Processing dependency file: $DependencyFilePath (Depth: $Depth)" -Level Info
    if (-not [string]::IsNullOrWhiteSpace($CallingRepositoryRootPath)) {
        Write-Log "Using calling repository root: $CallingRepositoryRootPath" -Level Debug
    }
    
    if (-not (Test-Path $DependencyFilePath)) {
        Write-Log "Dependency file not found: $DependencyFilePath" -Level Warning
        return @()
    }
    
    try {
        $jsonContent = Get-Content -Path $DependencyFilePath -Raw
        
        # Log JSON content in debug mode
        if ($EnableDebug) {
            Write-Log "JSON content of $DependencyFilePath :" -Level Debug
            $jsonContent -split "`n" | ForEach-Object { Write-Log "  $_" -Level Debug }
        }
        
        $jsonObject = $jsonContent | ConvertFrom-Json
        
        # Handle both new object format and legacy array format
        $repositories = $null
        $postCheckoutScriptFileName = ""
        $postCheckoutScriptFilePath = ""
        
        if ($jsonObject -is [Array]) {
            # Legacy array format - repositories only
            $repositories = $jsonObject
            Write-Log "Processing legacy array format dependency file" -Level Debug
        } else {
            # New object format - may have post-checkout script configuration
            if ($jsonObject.PSObject.Properties['Repositories']) {
                $repositories = $jsonObject.Repositories
                Write-Log "Processing new object format dependency file" -Level Debug
            } elseif ($jsonObject.PSObject.Properties['repositories']) {
                # Support lowercase for backward compatibility during transition
                $repositories = $jsonObject.repositories
                Write-Log "Processing new object format dependency file (lowercase repositories field)" -Level Debug
            } else {
                # Fallback: treat the object as if it were the repositories array
                $repositories = @($jsonObject)
                Write-Log "Processing single repository object format" -Level Debug
            }
            
            # Extract post-checkout script configuration
            if ($jsonObject.PSObject.Properties['Post-Checkout Script File Name']) {
                $postCheckoutScriptFileName = $jsonObject.'Post-Checkout Script File Name'
                Write-Log "Found post-checkout script file name: $postCheckoutScriptFileName" -Level Debug
            }
            
            if ($jsonObject.PSObject.Properties['Post-Checkout Script File Path']) {
                $postCheckoutScriptFilePath = $jsonObject.'Post-Checkout Script File Path'
                Write-Log "Found post-checkout script file path: $postCheckoutScriptFilePath" -Level Debug
            }
        }
        
        if (-not $repositories) {
            Write-Log "No repositories found in dependency file: $DependencyFilePath" -Level Warning
            return @()
        }
        
        # Ensure repositories is an array
        if ($repositories -isnot [Array]) {
            $repositories = @($repositories)
        }
        
        Write-Log "Found $($repositories.Count) repositories in $DependencyFilePath" -Level Debug
        if (-not [string]::IsNullOrWhiteSpace($postCheckoutScriptFileName)) {
            Write-Log "Post-checkout script configured: $postCheckoutScriptFileName" -Level Info
        }
        
        # Execute post-checkout script for depth 0 (root level) or when processing nested dependencies
        if (-not [string]::IsNullOrWhiteSpace($postCheckoutScriptFileName)) {
            if ($Depth -eq 0) {
                # Depth 0: Execute from input dependency file location with empty environment variables
                Write-Log "Executing post-checkout script at depth 0 (root level)" -Level Info
                
                # For depth 0, use the directory containing the input dependency file as the base path
                $inputFileDirectory = Split-Path -Parent (Resolve-Path $DependencyFilePath)
                Write-Log "Using input dependency file directory as base path for depth 0: $inputFileDirectory" -Level Debug
                
                # Execute script with empty environment variables (except LSIGIT_SCRIPT_VERSION)
                $scriptResult = Invoke-PostCheckoutScript -RepoAbsolutePath $inputFileDirectory -ScriptFileName $postCheckoutScriptFileName -ScriptFilePath $postCheckoutScriptFilePath -RepositoryUrl "" -Tag ""
                if (-not $scriptResult) {
                    Write-Log "Post-checkout script failed at depth 0, but continuing with repository processing" -Level Warning
                }
            } elseif ($Depth -gt 0 -and -not [string]::IsNullOrWhiteSpace($CallingRepositoryRootPath)) {
                # Depth > 0: Execute for the repository containing the dependency file
                Write-Log "Executing post-checkout script for repository containing dependency file at depth $Depth" -Level Info
                
                # Get the repository URL for the calling repository (the one containing the dependency file)
                $callingRepositoryUrl = ""
                $callingRepositoryTag = ""
                
                # Find the calling repository in our dictionary by matching the path
                foreach ($repoEntry in $script:RepositoryDictionary.GetEnumerator()) {
                    if ($repoEntry.Value.AbsolutePath -eq $CallingRepositoryRootPath) {
                        $callingRepositoryUrl = $repoEntry.Key
                        $callingRepositoryTag = $repoEntry.Value.Tag
                        break
                    }
                }
                
                if (-not [string]::IsNullOrWhiteSpace($callingRepositoryUrl)) {
                    Write-Log "Executing post-checkout script for repository containing dependency file: $callingRepositoryUrl" -Level Info
                    $scriptResult = Invoke-PostCheckoutScript -RepoAbsolutePath $CallingRepositoryRootPath -ScriptFileName $postCheckoutScriptFileName -ScriptFilePath $postCheckoutScriptFilePath -RepositoryUrl $callingRepositoryUrl -Tag $callingRepositoryTag
                    if (-not $scriptResult) {
                        Write-Log "Post-checkout script failed for repository '$callingRepositoryUrl', but continuing with dependency processing" -Level Warning
                    }
                } else {
                    Write-Log "Could not determine repository URL for calling repository at path: $CallingRepositoryRootPath" -Level Warning
                }
            }
        }
        
        $checkedOutRepos = @()
        
        foreach ($repo in $repositories) {
            try {
                $checkoutSucceeded = $false
                $existedBefore = $false
                
                # Track if this repository exists before processing
                if ($script:RecursiveMode) {
                    $repoUrl = $repo.'Repository URL'
                    
                    # Check if repository was in dictionary BEFORE Update-RepositoryDictionary
                    # For SemVer repos, they get added to dictionary before actual checkout
                    $existedBefore = $script:RepositoryDictionary.ContainsKey($repoUrl) -and 
                                    $script:RepositoryDictionary[$repoUrl].AlreadyCheckedOut
                    
                    # Log repository processing status
                    if ($existedBefore) {
                        Write-Log "Processing repository: $repoUrl (already in dictionary and checked out)" -Level Info
                    } else {
                        Write-Log "Processing repository: $repoUrl (new repository or needs checkout)" -Level Info
                    }
                }
                
                # Use enhanced error context for the actual checkout
                $repoToAdd = Invoke-WithErrorContext -Context "Processing repository: $($repo.'Repository URL')" -ScriptBlock {
                    if (Invoke-GitCheckout -Repository $repo -DependencyFilePath $DependencyFilePath -CallingRepositoryRootPath $CallingRepositoryRootPath) {
                        $script:SuccessCount++
                        $checkoutSucceeded = $true
                        
                        # Add to checked out repos list for recursive processing
                        if ($script:RecursiveMode -and $Depth -lt $MaxDepth -and $checkoutSucceeded) {
                            # Determine if this was actually a new checkout or update
                            $wasActuallyProcessed = -not $existedBefore
                            
                            if ($wasActuallyProcessed) {
                                $repoInfo = $script:RepositoryDictionary[$repo.'Repository URL']
                                # Skip if checkout failed
                                if (-not $repoInfo.CheckoutFailed) {
                                    # Return the repo info to be added to the array
                                    return @{
                                        Repository = $repo
                                        AbsolutePath = $repoInfo.AbsolutePath
                                    }
                                }
                            }
                        }
                    }
                    else {
                        $script:FailureCount++
                    }
                    return $null
                }
                
                # Add the repository if it was returned from the script block
                if ($null -ne $repoToAdd) {
                    $checkedOutRepos += $repoToAdd
                    Write-Log "Adding repository for recursive processing: $($repo.'Repository URL')" -Level Debug
                    Write-Log "Current checkedOutRepos count: $($checkedOutRepos.Count)" -Level Debug
                }
            }
            catch {
                Write-ErrorWithContext -ErrorRecord $_ -AdditionalMessage "Failed processing repository: $($repo.'Repository URL')"
                $script:FailureCount++
                # Continue with next repository instead of failing entire file
                continue
            }
        }
        
        # Ensure we return a proper array, not null
        if ($null -eq $checkedOutRepos) {
            $checkedOutRepos = @()
        }
        
        Write-Log "Process-DependencyFile returning $($checkedOutRepos.Count) repositories for recursive processing" -Level Debug
        return ,$checkedOutRepos  # The comma ensures we return an array
    }
    catch {
        Write-ErrorWithContext -ErrorRecord $_ -AdditionalMessage "Failed to parse dependency file: $DependencyFilePath"
        return ,@()  # Return empty array with comma operator
    }
}

function Process-RecursiveDependencies {
    param(
        [array]$CheckedOutRepos,
        [string]$DefaultDependencyFileName,
        [int]$CurrentDepth
    )
    
    $targetDepth = $CurrentDepth + 1
    
    if ($CurrentDepth -ge $MaxDepth) {
        Write-Log "Maximum recursion depth ($MaxDepth) reached" -Level Warning
        return
    }
    
    if ($CheckedOutRepos.Count -eq 0) {
        Write-Log "No new repositories to process at depth $CurrentDepth" -Level Debug
        return
    }
    
    Write-Log "Processing nested dependencies from $($CheckedOutRepos.Count) repositories (moving to depth $targetDepth)" -Level Info
    Write-Log "Starting dependency processing at depth $targetDepth" -Level Info
    
    $newlyCheckedOutRepos = @()
    $processedRepos = 0
    $foundDependencies = 0
    
    foreach ($repoInfo in $CheckedOutRepos) {
        $repoPath = $repoInfo.AbsolutePath
        $repoUrl = $repoInfo.Repository.'Repository URL'
        $processedRepos++
        
        # Skip if repository checkout failed
        if ($script:RepositoryDictionary.ContainsKey($repoUrl) -and 
            $script:RepositoryDictionary[$repoUrl].CheckoutFailed) {
            Write-Log "Skipping dependency processing for failed repository: $repoUrl" -Level Warning
            continue
        }
        
        # Get custom dependency file path for this repository (if any)
        # Note: Custom settings are NOT propagated to nested repositories
        $customDependencyFilePath = Get-CustomDependencyFilePath -Repository $repoInfo.Repository -RepoAbsolutePath $repoPath -DefaultFileName $DefaultDependencyFileName
        
        if (Test-Path $customDependencyFilePath) {
            Write-Log "Found nested dependency file: $customDependencyFilePath" -Level Info
            $foundDependencies++
            
            # Process nested dependencies using the DEFAULT dependency file name
            # Custom dependency file settings are isolated to the current repository only
            # Pass the repository root path for correct relative path resolution
            $newRepos = Process-DependencyFile -DependencyFilePath $customDependencyFilePath -Depth $targetDepth -CallingRepositoryRootPath $repoPath
            $newlyCheckedOutRepos += $newRepos
        } else {
            Write-Log "No dependency file found at: $customDependencyFilePath" -Level Debug
        }
    }
    
    Write-Log "Completed depth $targetDepth processing: $processedRepos repositories examined, $foundDependencies dependency files found, $($newlyCheckedOutRepos.Count) new repositories checked out" -Level Info
    
    # Recursively process newly checked out repositories
    # Use the default dependency file name for all recursive processing
    if ($newlyCheckedOutRepos.Count -gt 0) {
        Process-RecursiveDependencies -CheckedOutRepos $newlyCheckedOutRepos -DefaultDependencyFileName $DefaultDependencyFileName -CurrentDepth $targetDepth
    } else {
        Write-Log "Recursive processing complete - no more nested dependencies found" -Level Info
    }
}

function Read-CredentialsFile {
    param(
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Log "Credentials file not found: $FilePath" -Level Debug
        return @{}
    }
    
    try {
        Write-Log "Reading credentials file: $FilePath" -Level Info
        $jsonContent = Get-Content -Path $FilePath -Raw
        $credentials = $jsonContent | ConvertFrom-Json
        
        # Convert to hashtable for easier lookup
        $credentialsHash = @{}
        $credentials.PSObject.Properties | ForEach-Object {
            $credentialsHash[$_.Name] = $_.Value
        }
        
        Write-Log "Loaded SSH credentials for $($credentialsHash.Count) host(s)" -Level Info
        
        # Validate all SSH key files exist
        foreach ($hostname in $credentialsHash.Keys) {
            $keyPath = $credentialsHash[$hostname]
            if (-not (Test-Path $keyPath)) {
                Write-Log "Warning: SSH key file not found for $hostname : $keyPath" -Level Warning
            } else {
                Write-Log "Found SSH key for $hostname : $keyPath" -Level Debug
            }
        }
        
        return $credentialsHash
    }
    catch {
        Write-Log "Failed to parse credentials file: $_" -Level Error
        return @{}
    }
}

function Show-Summary {
    $summary = @"
========================================
LsiGitCheckout Execution Summary
========================================
Script Version: $($script:Version)
Successful: $($script:SuccessCount)
Failed: $($script:FailureCount)
"@
    
    if ($script:RecursiveMode) {
        $summary += "`nRecursive Mode: Enabled"
        $summary += "`nMax Depth: $MaxDepth"
        $summary += "`nDefault API Compatibility: $($script:DefaultApiCompatibility)"
        $summary += "`nTotal Unique Repositories: $($script:RepositoryDictionary.Count)"
        
        # Count SemVer vs Agnostic repositories
        $semVerRepos = 0
        $agnosticRepos = 0
        foreach ($repo in $script:RepositoryDictionary.Values) {
            if ($repo.ContainsKey('DependencyResolution')) {
                if ($repo.DependencyResolution -eq 'SemVer') {
                    $semVerRepos++
                } else {
                    $agnosticRepos++
                }
            } else {
                $agnosticRepos++
            }
        }
        
        if ($semVerRepos -gt 0) {
            $summary += "`nDependency Resolution Modes: $agnosticRepos Agnostic, $semVerRepos SemVer"
        }
        
        # Show custom dependency file statistics
        $reposWithCustomPath = 0
        $reposWithCustomName = 0
        foreach ($repo in $script:RepositoryDictionary.Values) {
            if ($repo.ContainsKey('DependencyFilePath') -and -not [string]::IsNullOrWhiteSpace($repo.DependencyFilePath)) {
                $reposWithCustomPath++
            }
            if ($repo.ContainsKey('DependencyFileName') -and -not [string]::IsNullOrWhiteSpace($repo.DependencyFileName)) {
                $reposWithCustomName++
            }
        }
        
        if ($reposWithCustomPath -gt 0 -or $reposWithCustomName -gt 0) {
            $summary += "`nCustom Dependency Files: $reposWithCustomPath paths, $reposWithCustomName names"
        }
    }
    
    # Show post-checkout script statistics
    if ($script:PostCheckoutScriptsEnabled) {
        $summary += "`nPost-Checkout Scripts: Enabled"
        $summary += "`nScript Executions: $($script:PostCheckoutScriptExecutions)"
        if ($script:PostCheckoutScriptFailures -gt 0) {
            $summary += "`nScript Failures: $($script:PostCheckoutScriptFailures)"
        }
    } else {
        $summary += "`nPost-Checkout Scripts: Disabled"
    }
    
    # Show tag statistics in debug mode
    if ($EnableDebug -and $script:RepositoryDictionary.Count -gt 0) {
        $totalTags = 0
        $reposWithTags = 0
        $totalSemVerTags = 0
        $reposWithSemVerTags = 0
        
        foreach ($repo in $script:RepositoryDictionary.Values) {
            if ($repo.ContainsKey('TagDates') -and $repo.TagDates.Count -gt 0) {
                $totalTags += $repo.TagDates.Count
                $reposWithTags++
            }
            if ($repo.ContainsKey('ParsedVersions') -and $repo.ParsedVersions.Count -gt 0) {
                $totalSemVerTags += $repo.ParsedVersions.Count
                $reposWithSemVerTags++
            }
        }
        
        $summary += "`nRepositories with Tag Data: $reposWithTags"
        $summary += "`nTotal Tags Processed: $totalTags"
        
        if ($reposWithSemVerTags -gt 0) {
            $summary += "`nRepositories with SemVer Tags: $reposWithSemVerTags"
            $summary += "`nTotal SemVer Tags Parsed: $totalSemVerTags"
        }
    }
    
    $summary += "`n========================================"
    
    Write-Log $summary -Level Info
    
    if ($script:FailureCount -gt 0) {
        Write-Log "Errors were logged to: $script:ErrorFile" -Level Warning
    }
    
    if ($EnableDebug) {
        Write-Log "Debug log saved to: $script:DebugLogFile" -Level Info
    }
}

# Main execution
try {
    Write-Log "LsiGitCheckout started - Version $script:Version" -Level Info
    Write-Log "Script path: $script:ScriptPath" -Level Debug
    Write-Log "PowerShell version: $($PSVersionTable.PSVersion)" -Level Debug
    Write-Log "Operating System: $([System.Environment]::OSVersion.VersionString)" -Level Debug
    Write-Log "Default API Compatibility: $($script:DefaultApiCompatibility)" -Level Info
    
    if ($script:RecursiveMode) {
        Write-Log "Recursive mode: ENABLED (default) with max depth: $MaxDepth" -Level Info
    } else {
        Write-Log "Recursive mode: DISABLED" -Level Info
    }
    
    if ($script:PostCheckoutScriptsEnabled) {
        Write-Log "Post-checkout scripts: ENABLED (default)" -Level Info
    } else {
        Write-Log "Post-checkout scripts: DISABLED" -Level Info
    }

    if ($script:ErrorContextEnabled) {
        Write-Log "Error context: ENABLED - Detailed error information will be shown" -Level Info
    } else {
        Write-Log "Error context: DISABLED - Use -EnableErrorContext for detailed error information" -Level Debug
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
        exit 1
    }
    
    # Determine input file path
    if ([string]::IsNullOrEmpty($InputFile)) {
        $InputFile = Join-Path $script:ScriptPath "dependencies.json"
        Write-Log "Using default input file: $InputFile" -Level Verbose
    }
    
    # Store the dependency file name for recursive processing
    $script:DefaultDependencyFileName = Split-Path -Leaf $InputFile
    Write-Log "Default dependency file name for recursive processing: $($script:DefaultDependencyFileName)" -Level Debug
    
    # Determine credentials file path
    if ([string]::IsNullOrEmpty($CredentialsFile)) {
        $CredentialsFile = Join-Path $script:ScriptPath "git_credentials.json"
        Write-Log "Using default credentials file: $CredentialsFile" -Level Verbose
    }
    
    # Read SSH credentials
    $script:SshCredentials = Read-CredentialsFile -FilePath $CredentialsFile
    
    # Check if input file exists
    if (-not (Test-Path $InputFile)) {
        $errorMessage = "Input file not found: $InputFile"
        Write-Log $errorMessage -Level Error
        Show-ErrorDialog -Message $errorMessage
        exit 1
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
    Write-Log "Checking recursive processing conditions - RecursiveMode: $($script:RecursiveMode), CheckedOutRepos.Count: $($checkedOutRepos.Count)" -Level Debug
    
    if ($script:RecursiveMode -and $checkedOutRepos.Count -gt 0) {
        Write-Log "Entering recursive processing with $($checkedOutRepos.Count) repositories" -Level Info
        Invoke-WithErrorContext -Context "Processing recursive dependencies" -ScriptBlock {
            Process-RecursiveDependencies -CheckedOutRepos $checkedOutRepos -DefaultDependencyFileName $script:DefaultDependencyFileName -CurrentDepth 0
        }
    } else {
        if (-not $script:RecursiveMode) {
            Write-Log "Recursive processing skipped - recursive mode is disabled" -Level Info
        } elseif ($checkedOutRepos.Count -eq 0) {
            Write-Log "Recursive processing skipped - no new repositories were checked out at depth 0" -Level Info
        }
    }
    
    # Show summary
    Show-Summary
    
    # Exit with appropriate code
    if ($script:FailureCount -gt 0) {
        exit 1
    }
    else {
        exit 0
    }
}
catch {
    Write-ErrorWithContext -ErrorRecord $_ -AdditionalMessage "Unexpected error in main execution"
    Show-ErrorDialog -Message $_.Exception.Message
    exit 1
}