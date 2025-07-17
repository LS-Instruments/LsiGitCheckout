#Requires -Version 5.1
<#
.SYNOPSIS
    LsiGitCheckout - Checks out a collection of Git repositories to specified tags
.DESCRIPTION
    This script reads a JSON configuration file and checks out multiple Git repositories
    to their specified tags. It supports both HTTPS and SSH URLs, handles Git LFS,
    initializes submodules, and provides comprehensive error handling and logging.
    
    SSH credentials are managed through a separate git_credentials.json file.
    
    With the -Recursive option, it can discover and process nested dependencies.
    
    With the -EnableTagSorting option, it fetches tag dates from repositories and uses
    them to properly sort API Compatible Tags temporally, removing manual ordering requirements.
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
.PARAMETER Recursive
    Enables recursive dependency discovery and processing.
.PARAMETER MaxDepth
    Maximum recursion depth for dependency discovery. Defaults to 5.
.PARAMETER ApiCompatibility
    Default API compatibility mode when not specified in dependencies. Can be 'Strict' or 'Permissive'. Defaults to 'Permissive'.
.PARAMETER EnableTagSorting
    Enables automatic tag temporal sorting using git tag dates. This removes the requirement for manual temporal ordering in "API Compatible Tags" and suppresses related warnings in Permissive mode.
.EXAMPLE
    .\LsiGitCheckout.ps1
    .\LsiGitCheckout.ps1 -InputFile "C:\configs\myrepos.json" -CredentialsFile "C:\configs\my_credentials.json"
    .\LsiGitCheckout.ps1 -Recursive -MaxDepth 10
    .\LsiGitCheckout.ps1 -InputFile "repos.json" -EnableDebug -Recursive -ApiCompatibility Strict
    .\LsiGitCheckout.ps1 -Recursive -EnableTagSorting -Verbose
.NOTES
    Version: 4.2.0-dev
    Last Modified: 2025-01-16
    
    This script uses PuTTY/plink for SSH authentication. SSH keys must be in PuTTY format (.ppk).
    Use PuTTYgen to convert OpenSSH keys to PuTTY format if needed.
    
    Changes in 4.2.0-dev:
    - Added -EnableTagSorting parameter for automatic tag temporal sorting
    - Added tag date fetching functionality after repository checkout
    - Enhanced tag sorting using actual git tag dates instead of manual ordering
    - Improved compatibility tag merging with temporal ordering
    - Suppressed manual ordering warnings when tag sorting is enabled
    - Added comprehensive debug logging for tag sorting operations
    
    Changes in 4.1.1:
    - Fixed temporal ordering in union operations for Permissive mode
    - Added warnings for incompatible tag lists (different starting tags or same length with different content)
    - Improved union algorithm to preserve temporal order when constraints are met
    
    Changes in 4.1.0:
    - Added "API Compatibility" field with "Strict" and "Permissive" modes
    - Added -ApiCompatibility parameter to set default compatibility mode
    - Enhanced tag selection algorithm based on compatibility mode
    - Permissive mode now uses union instead of intersection for compatible tags
    
    Changes in 4.0.2:
    - Fixed git checkout error capture to properly display stderr messages
    - Improved error reporting for missing tags
    
    Changes in 4.0.1:
    - Fixed error handling for missing tags with detailed error messages
    - Added cleanup of failed clones to prevent undefined repository states
    - Added CheckoutFailed tracking to skip dependency processing for failed repos
    - Improved error message capture and display
    
    Changes in 4.0.0:
    - Added -Recursive option for nested dependency discovery
    - Added "API Compatible Tags" field support
    - Implemented API compatibility checking for duplicate repositories
    - Added -MaxDepth parameter to control recursion depth
    
    Dependencies JSON Format:
    [
      {
        "Repository URL": "https://github.com/user/repo.git",
        "Base Path": "C:\\Projects\\repo",
        "Tag": "v1.0.0",
        "API Compatible Tags": ["v1.0.0", "v1.0.1", "v1.1.0"],
        "API Compatibility": "Strict",
        "Skip LFS": false
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
    [switch]$Recursive,
    
    [Parameter()]
    [int]$MaxDepth = 5,
    
    [Parameter()]
    [ValidateSet('Strict', 'Permissive')]
    [string]$ApiCompatibility = 'Permissive',
    
    [Parameter()]
    [switch]$EnableTagSorting
)

# Script configuration
$script:Version = "4.2.0-dev"
$script:ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:ErrorFile = Join-Path $ScriptPath "LsiGitCheckout_Errors.txt"
$script:DebugLogFile = Join-Path $ScriptPath ("debug_log_{0}.txt" -f (Get-Date -Format "yyyyMMddHHmm"))
$script:SuccessCount = 0
$script:FailureCount = 0
$script:Repositories = @()
$script:SshCredentials = @{}
$script:RepositoryDictionary = @{}
$script:CurrentDepth = 0
$script:ProcessedDependencyFiles = @()
$script:DefaultApiCompatibility = $ApiCompatibility
$script:EnableTagSorting = $EnableTagSorting

# Initialize error file
if (Test-Path $script:ErrorFile) {
    Remove-Item $script:ErrorFile -Force
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
        [string]$RepositoryUrl
    )
    
    if (-not $script:EnableTagSorting -or $TagDates.Count -eq 0) {
        Write-Log "Tag sorting disabled or no tag dates available, returning tags in original order" -Level Debug
        return $Tags
    }
    
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
    
    # Only show verbose output for temporal sorting results
    if ($VerbosePreference -eq 'Continue') {
        Write-Log "Tag temporal sorting for $RepositoryUrl :" -Level Verbose
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
        [string]$DependencyFilePath
    )
    
    if ([System.IO.Path]::IsPathRooted($BasePath)) {
        # Normalize the path to remove any ".." or "." segments
        return [System.IO.Path]::GetFullPath($BasePath)
    }
    
    $dependencyDir = Split-Path -Parent (Resolve-Path $DependencyFilePath)
    $combinedPath = Join-Path $dependencyDir $BasePath
    # Normalize the combined path to resolve ".." segments
    return [System.IO.Path]::GetFullPath($combinedPath)
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
    
    # If tag sorting is enabled and we have tag dates, use temporal sorting
    if ($script:EnableTagSorting -and $TagDates.Count -gt 0) {
        Write-Log "Using temporal sorting for tag union" -Level Debug
        
        # Create union of all tags
        $unionSet = @{}
        foreach ($tag in $Tags1) {
            $unionSet[$tag] = $true
        }
        foreach ($tag in $Tags2) {
            $unionSet[$tag] = $true
        }
        
        $allTags = @($unionSet.Keys)
        $sortedUnion = Sort-TagsByDate -Tags $allTags -TagDates $TagDates -RepositoryUrl $RepositoryUrl
        
        Write-Log "Temporal union result: $($sortedUnion -join ', ')" -Level Debug
        return $sortedUnion
    }
    
    # Fall back to original logic when tag sorting is disabled
    # Check if both lists start with the same tag
    if ($Tags1.Count -gt 0 -and $Tags2.Count -gt 0 -and $Tags1[0] -ne $Tags2[0]) {
        Write-Log "Warning: Tag lists for union do not start with the same tag. List1 starts with '$($Tags1[0])', List2 starts with '$($Tags2[0])'. Using unordered union." -Level Warning
        
        # Fall back to unordered union
        $unionSet = @{}
        foreach ($tag in $Tags1) {
            $unionSet[$tag] = $true
        }
        foreach ($tag in $Tags2) {
            $unionSet[$tag] = $true
        }
        return @($unionSet.Keys)
    }
    
    # Check if lists have same length but are not equal
    if ($Tags1.Count -eq $Tags2.Count -and $Tags1.Count -gt 0) {
        $areEqual = $true
        for ($i = 0; $i -lt $Tags1.Count; $i++) {
            if ($Tags1[$i] -ne $Tags2[$i]) {
                $areEqual = $false
                break
            }
        }
        
        if (-not $areEqual) {
            Write-Log "Warning: Tag lists have the same length ($($Tags1.Count)) but contain different tags. Using unordered union." -Level Warning
            Write-Log "List1: $($Tags1 -join ', ')" -Level Debug
            Write-Log "List2: $($Tags2 -join ', ')" -Level Debug
            
            # Fall back to unordered union
            $unionSet = @{}
            foreach ($tag in $Tags1) {
                $unionSet[$tag] = $true
            }
            foreach ($tag in $Tags2) {
                $unionSet[$tag] = $true
            }
            return @($unionSet.Keys)
        }
    }
    
    # Normal case: Lists are compatible for ordered union
    # Since lists start with same tag and are temporally ordered,
    # we can use the longer list as base and add any unique tags from shorter list
    
    if ($Tags1.Count -ge $Tags2.Count) {
        $longerList = $Tags1
        $shorterList = $Tags2
    } else {
        $longerList = $Tags2
        $shorterList = $Tags1
    }
    
    # Create ordered union
    $orderedUnion = @()
    $addedTags = @{}
    
    # Add all tags from longer list (preserves temporal order)
    foreach ($tag in $longerList) {
        if (-not $addedTags.ContainsKey($tag)) {
            $orderedUnion += $tag
            $addedTags[$tag] = $true
        }
    }
    
    # Add any remaining tags from shorter list (should typically be none if constraints are met)
    foreach ($tag in $shorterList) {
        if (-not $addedTags.ContainsKey($tag)) {
            $orderedUnion += $tag
            $addedTags[$tag] = $true
            Write-Log "Note: Tag '$tag' from shorter list was not in longer list, added at end" -Level Debug
        }
    }
    
    return $orderedUnion
}

function Update-RepositoryDictionary {
    param(
        [PSCustomObject]$Repository,
        [string]$DependencyFilePath
    )
    
    $repoUrl = $Repository.'Repository URL'
    $basePath = $Repository.'Base Path'
    $newRepositoryTag = $Repository.Tag
    $apiCompatibleTags = $Repository.'API Compatible Tags'
    $apiCompatibility = if ($Repository.'API Compatibility') { $Repository.'API Compatibility' } else { $script:DefaultApiCompatibility }
    
    # Calculate absolute base path
    $absoluteBasePath = Get-AbsoluteBasePath -BasePath $basePath -DependencyFilePath $DependencyFilePath
    
    if ($script:RepositoryDictionary.ContainsKey($repoUrl)) {
        # Repository already exists, check compatibility
        $existingRepo = $script:RepositoryDictionary[$repoUrl]
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
        
        # Create ordered tag lists (API Compatible Tags + Tag at the end)
        # For existing repository - use as-is since already sorted when added to dictionary
        $existingOrderedTags = @()
        if ($existingRepo.ApiCompatibleTags) {
            $existingOrderedTags += $existingRepo.ApiCompatibleTags
        }
        $existingOrderedTags += $existingRepo.Tag
        
        # For new repository - use as-is, will be sorted in final union/intersection if needed
        $newOrderedTags = @()
        if ($apiCompatibleTags) {
            $newOrderedTags += $apiCompatibleTags
        }
        $newOrderedTags += $newRepositoryTag
        
        Write-Log "Existing tags (ordered): $($existingOrderedTags -join ', ')" -Level Debug
        Write-Log "New tags (ordered): $($newOrderedTags -join ', ')" -Level Debug
        Write-Log "Existing API Compatibility: $($existingRepo.ApiCompatibility)" -Level Debug
        Write-Log "New API Compatibility: $apiCompatibility" -Level Debug
        
        # Calculate intersection for compatibility check (always performed)
        $intersection = @()
        foreach ($tag in $existingOrderedTags) {
            if ($tag -in $newOrderedTags) {
                $intersection += $tag
            }
        }
        
        if ($intersection.Count -eq 0) {
            $errorMessage = "API incompatibility for repository '$repoUrl':`nExisting tags: $($existingOrderedTags -join ', ')`nNew tags: $($newOrderedTags -join ', ')`nNo common API-compatible tags found."
            Write-Log $errorMessage -Level Error
            Show-ErrorDialog -Message $errorMessage
            throw $errorMessage
        }
        
        Write-Log "API compatibility check passed for '$repoUrl'. Intersection: $($intersection -join ', ')" -Level Debug
        
        # Apply API Compatibility rules
        $oldTag = $existingRepo.Tag
        $newTag = $oldTag
        $newApiCompatibleTags = @()
        $newApiCompatibility = $existingRepo.ApiCompatibility
        $needCheckout = $false
        $finalOrderedTags = @()
        
        if ($existingRepo.ApiCompatibility -eq 'Strict') {
            if ($apiCompatibility -eq 'Strict') {
                # Both Strict: Use intersection algorithm
                Write-Log "Both repositories are Strict mode, using intersection algorithm" -Level Debug
                
                # Sort intersection if tag sorting is enabled
                if ($script:EnableTagSorting -and $tagDates.Count -gt 0) {
                    $finalOrderedTags = Sort-TagsByDate -Tags $intersection -TagDates $tagDates -RepositoryUrl $repoUrl
                    Write-Log "Intersection after temporal sorting: $($finalOrderedTags -join ', ')" -Level Debug
                } else {
                    $finalOrderedTags = $intersection
                }
                
                # Select tag based on EnableTagSorting setting
                if ($finalOrderedTags.Count -gt 0) {
                    if ($script:EnableTagSorting -and $tagDates.Count -gt 0) {
                        # Enhanced logic: Check if existing or new Tag are in the compatible list
                        $existingTagInList = $existingRepo.Tag -in $finalOrderedTags
                        $newTagInList = $newRepositoryTag -in $finalOrderedTags
                        
                        Write-Log "Existing tag '$($existingRepo.Tag)' in compatible list: $existingTagInList" -Level Debug
                        Write-Log "New tag '$newRepositoryTag' in compatible list: $newTagInList" -Level Debug
                        
                        if ($existingTagInList -and $newTagInList) {
                            # Both tags are compatible, choose the chronologically most recent
                            $existingTagDate = $tagDates[$existingRepo.Tag]
                            $newTagDate = $tagDates[$newRepositoryTag]
                            
                            if ($newTagDate -gt $existingTagDate) {
                                $selectedTag = $newRepositoryTag
                                Write-Log "Selected new tag '$newRepositoryTag' (newer: $($newTagDate.ToString('yyyy-MM-dd HH:mm:ss')) vs $($existingTagDate.ToString('yyyy-MM-dd HH:mm:ss')))" -Level Debug
                            } else {
                                $selectedTag = $existingRepo.Tag
                                Write-Log "Selected existing tag '$($existingRepo.Tag)' (newer: $($existingTagDate.ToString('yyyy-MM-dd HH:mm:ss')) vs $($newTagDate.ToString('yyyy-MM-dd HH:mm:ss')))" -Level Debug
                            }
                        } elseif ($existingTagInList) {
                            # Only existing tag is compatible
                            $selectedTag = $existingRepo.Tag
                            Write-Log "Selected existing tag '$($existingRepo.Tag)' (only existing tag is compatible)" -Level Debug
                        } elseif ($newTagInList) {
                            # Only new tag is compatible
                            $selectedTag = $newRepositoryTag
                            Write-Log "Selected new tag '$newRepositoryTag' (only new tag is compatible)" -Level Debug
                        } else {
                            # Neither tag is in the compatible list, choose chronologically most recent from list
                            $mostRecentTag = $null
                            $mostRecentDate = [DateTime]::MinValue
                            
                            foreach ($compatibleTag in $finalOrderedTags) {
                                if ($tagDates.ContainsKey($compatibleTag) -and $tagDates[$compatibleTag] -gt $mostRecentDate) {
                                    $mostRecentDate = $tagDates[$compatibleTag]
                                    $mostRecentTag = $compatibleTag
                                }
                            }
                            
                            $selectedTag = if ($mostRecentTag) { $mostRecentTag } else { $finalOrderedTags[-1] }
                            Write-Log "Neither existing nor new tag compatible, selected most recent from list: '$selectedTag'" -Level Debug
                        }
                        
                        $newTag = $selectedTag
                        $newApiCompatibleTags = @($finalOrderedTags | Where-Object { $_ -ne $selectedTag })
                    } else {
                        # Original logic when tag sorting is disabled
                        if ($existingRepo.Tag -in $finalOrderedTags) {
                            # Existing tag is in final list, remove it and use the rest as API compatible tags
                            $newApiCompatibleTags = @($finalOrderedTags | Where-Object { $_ -ne $existingRepo.Tag })
                            Write-Log "Keeping existing tag '$oldTag' for repository '$repoUrl'" -Level Debug
                        } else {
                            # Existing tag not in final list, use the most recent (last) tag
                            $mostRecentTag = $finalOrderedTags[-1]
                            $newTag = $mostRecentTag
                            $newApiCompatibleTags = @($finalOrderedTags | Where-Object { $_ -ne $mostRecentTag })
                            Write-Log "Existing tag not compatible, selected rightmost tag: '$newTag'" -Level Debug
                        }
                    }
                    
                    if ($newTag -ne $oldTag) {
                        $needCheckout = $true
                        Write-Log "Updating tag from '$oldTag' to '$newTag' for repository '$repoUrl' (intersection result)" -Level Info
                    } else {
                        Write-Log "Keeping existing tag '$oldTag' for repository '$repoUrl'" -Level Debug
                    }
                }
            } else {
                # Existing Strict, new Permissive: Leave unchanged
                Write-Log "Existing repository is Strict, new is Permissive - leaving tags unchanged" -Level Debug
                $newTag = $existingRepo.Tag
                $newApiCompatibleTags = $existingRepo.ApiCompatibleTags
            }
        } else {
            # Existing Permissive
            if ($apiCompatibility -eq 'Permissive') {
                # Both Permissive: Use union
                Write-Log "Both repositories are Permissive mode, using union algorithm" -Level Debug
                
                $union = Get-TagUnion -Tags1 $existingOrderedTags -Tags2 $newOrderedTags -TagDates $tagDates -RepositoryUrl $repoUrl
                Write-Log "Union of tags: $($union -join ', ')" -Level Debug
                
                # Select tag based on EnableTagSorting setting
                if ($union.Count -gt 0) {
                    if ($script:EnableTagSorting -and $tagDates.Count -gt 0) {
                        # Enhanced logic: Check if existing or new Tag are in the union
                        $existingTagInList = $existingRepo.Tag -in $union
                        $newTagInList = $newRepositoryTag -in $union
                        
                        Write-Log "Existing tag '$($existingRepo.Tag)' in union: $existingTagInList" -Level Debug
                        Write-Log "New tag '$newRepositoryTag' in union: $newTagInList" -Level Debug
                        
                        if ($existingTagInList -and $newTagInList) {
                            # Both tags are in union, choose the chronologically most recent
                            $existingTagDate = $tagDates[$existingRepo.Tag]
                            $newTagDate = $tagDates[$newRepositoryTag]
                            
                            if ($newTagDate -gt $existingTagDate) {
                                $selectedTag = $newRepositoryTag
                                Write-Log "Selected new tag '$newRepositoryTag' (newer: $($newTagDate.ToString('yyyy-MM-dd HH:mm:ss')) vs $($existingTagDate.ToString('yyyy-MM-dd HH:mm:ss')))" -Level Debug
                            } else {
                                $selectedTag = $existingRepo.Tag
                                Write-Log "Selected existing tag '$($existingRepo.Tag)' (newer: $($existingTagDate.ToString('yyyy-MM-dd HH:mm:ss')) vs $($newTagDate.ToString('yyyy-MM-dd HH:mm:ss')))" -Level Debug
                            }
                        } elseif ($existingTagInList) {
                            # Only existing tag is in union
                            $selectedTag = $existingRepo.Tag
                            Write-Log "Selected existing tag '$($existingRepo.Tag)' (only existing tag in union)" -Level Debug
                        } elseif ($newTagInList) {
                            # Only new tag is in union
                            $selectedTag = $newRepositoryTag
                            Write-Log "Selected new tag '$newRepositoryTag' (only new tag in union)" -Level Debug
                        } else {
                            # Neither tag is in union, choose chronologically most recent from union
                            $mostRecentTag = $null
                            $mostRecentDate = [DateTime]::MinValue
                            
                            foreach ($unionTag in $union) {
                                if ($tagDates.ContainsKey($unionTag) -and $tagDates[$unionTag] -gt $mostRecentDate) {
                                    $mostRecentDate = $tagDates[$unionTag]
                                    $mostRecentTag = $unionTag
                                }
                            }
                            
                            $selectedTag = if ($mostRecentTag) { $mostRecentTag } else { $union[-1] }
                            Write-Log "Neither existing nor new tag in union, selected most recent from union: '$selectedTag'" -Level Debug
                        }
                        
                        $newTag = $selectedTag
                        $newApiCompatibleTags = @($union | Where-Object { $_ -ne $selectedTag })
                    } else {
                        # Original logic when tag sorting is disabled
                        $mostRecentTag = $union[-1]
                        $newTag = $mostRecentTag
                        $newApiCompatibleTags = @($union | Where-Object { $_ -ne $mostRecentTag })
                        Write-Log "Tag sorting disabled, selected rightmost tag: '$newTag'" -Level Debug
                    }
                    
                    if ($newTag -ne $oldTag) {
                        $needCheckout = $true
                        Write-Log "Updating tag from '$oldTag' to '$newTag' for repository '$repoUrl' (union result)" -Level Info
                    } else {
                        Write-Log "Keeping existing tag '$oldTag' for repository '$repoUrl' (already optimal)" -Level Debug
                    }
                }
            } else {
                # Existing Permissive, new Strict: Copy from new and set to Strict
                Write-Log "Existing repository is Permissive, new is Strict - adopting Strict mode" -Level Debug
                
                # When switching to Strict mode, use the new repository's settings
                if ($script:EnableTagSorting -and $tagDates.Count -gt 0) {
                    $sortedNewTags = Sort-TagsByDate -Tags $newOrderedTags -TagDates $tagDates -RepositoryUrl $repoUrl
                    # In this case, the new tag is the definitive choice since we're adopting Strict mode
                    $newTag = $newRepositoryTag
                    $newApiCompatibleTags = $apiCompatibleTags
                    Write-Log "Adopting Strict mode with new tag: '$newRepositoryTag'" -Level Debug
                } else {
                    $newTag = $newRepositoryTag
                    $newApiCompatibleTags = $apiCompatibleTags
                    Write-Log "Tag sorting disabled, adopting new tag: '$newRepositoryTag'" -Level Debug
                }
                
                $newApiCompatibility = 'Strict'
                
                if ($newTag -ne $oldTag) {
                    $needCheckout = $true
                    Write-Log "Updating tag from '$oldTag' to '$newTag' for repository '$repoUrl' (switching to Strict mode)" -Level Info
                }
            }
        }
        
        # Update dictionary
        $script:RepositoryDictionary[$repoUrl] = @{
            AbsolutePath = $existingAbsolutePath
            Tag = $newTag
            ApiCompatibleTags = $newApiCompatibleTags
            ApiCompatibility = $newApiCompatibility
            AlreadyCheckedOut = $true
            NeedCheckout = $needCheckout
            CheckoutFailed = $false
            TagDates = $tagDates  # Preserve existing tag dates
        }
        
        Write-Log "Updated repository '$repoUrl' - Tag: $newTag, API Compatible Tags: $($newApiCompatibleTags -join ', '), API Compatibility: $newApiCompatibility" -Level Debug
        
        # Return special value to indicate need for checkout
        if ($needCheckout) {
            return "NeedCheckout"
        } else {
            return $true  # Repository already checked out with correct tag
        }
    } else {
        # New repository, add to dictionary with sorted API Compatible Tags if tag sorting enabled
        $sortedApiCompatibleTags = $apiCompatibleTags
        if ($script:EnableTagSorting -and $Recursive) {
            # We'll sort the API Compatible Tags when we get the tag dates after checkout
            # For now, store them as-is
            $sortedApiCompatibleTags = $apiCompatibleTags
        }
        
        $script:RepositoryDictionary[$repoUrl] = @{
            AbsolutePath = $absoluteBasePath
            Tag = $newRepositoryTag
            ApiCompatibleTags = $sortedApiCompatibleTags
            ApiCompatibility = $apiCompatibility
            AlreadyCheckedOut = $false
            NeedCheckout = $false
            CheckoutFailed = $false
            TagDates = @{}  # Will be populated after checkout
        }
        
        Write-Log "Added new repository to dictionary: '$repoUrl' with API Compatibility: $apiCompatibility" -Level Debug
        
        return $false  # Repository needs to be checked out
    }
}

function Invoke-GitCheckout {
    param(
        [PSCustomObject]$Repository,
        [string]$DependencyFilePath
    )
    
    $repoUrl = $Repository.'Repository URL'
    $basePath = $Repository.'Base Path'
    $tag = $Repository.Tag
    $skipLfs = if ($null -eq $Repository.'Skip LFS') { $false } else { $Repository.'Skip LFS' }
    $wasNewClone = $false
    
    # Check if we should skip this repository (already checked out with compatible API)
    if ($Recursive) {
        $checkoutResult = Update-RepositoryDictionary -Repository $Repository -DependencyFilePath $DependencyFilePath
        if ($checkoutResult -eq $true) {
            Write-Log "Skipping repository '$repoUrl' - already checked out with compatible API" -Level Info
            return $true
        }
        elseif ($checkoutResult -eq "NeedCheckout") {
            # Repository exists but needs to be checked out to a different tag
            $repoInfo = $script:RepositoryDictionary[$repoUrl]
            $newTag = $repoInfo.Tag
            $absoluteBasePath = $repoInfo.AbsolutePath
            
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
    
    # Convert relative path to absolute
    $absoluteBasePath = Get-AbsoluteBasePath -BasePath $basePath -DependencyFilePath $DependencyFilePath
    
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
                } finally {
                    Pop-Location
                }
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
            }
        }
        
        # Fetch tag dates if tag sorting is enabled and this is the first checkout
        if ($script:EnableTagSorting -and $Recursive) {
            Write-Log "Tag sorting enabled, fetching tag dates for repository: $repoUrl" -Level Info
            $tagDates = Get-GitTagDates -RepoPath $absoluteBasePath
            
            # Store tag dates in repository dictionary and sort API Compatible Tags
            if ($script:RepositoryDictionary.ContainsKey($repoUrl)) {
                $script:RepositoryDictionary[$repoUrl].TagDates = $tagDates
                
                # Sort the API Compatible Tags now that we have tag dates
                $currentApiTags = $script:RepositoryDictionary[$repoUrl].ApiCompatibleTags
                if ($currentApiTags -and $tagDates.Count -gt 0) {
                    $sortedApiTags = Sort-TagsByDate -Tags $currentApiTags -TagDates $tagDates -RepositoryUrl $repoUrl
                    $script:RepositoryDictionary[$repoUrl].ApiCompatibleTags = $sortedApiTags
                    Write-Log "Sorted API Compatible Tags for repository '$repoUrl': $($sortedApiTags -join ', ')" -Level Debug
                }
                
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
        if ($Recursive -and $script:RepositoryDictionary.ContainsKey($repoUrl)) {
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
        if ($Recursive -and $script:RepositoryDictionary.ContainsKey($repoUrl)) {
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
        [int]$Depth
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
        
        $repositories = $jsonContent | ConvertFrom-Json
        
        if (-not $repositories) {
            Write-Log "No repositories found in dependency file: $DependencyFilePath" -Level Warning
            return @()
        }
        
        Write-Log "Found $($repositories.Count) repositories in $DependencyFilePath" -Level Debug
        
        $checkedOutRepos = @()
        
        foreach ($repo in $repositories) {
            $wasNewCheckout = $false
            $checkoutSucceeded = $false
            
            # Track if this repository exists before processing
            if ($Recursive) {
                $repoUrl = $repo.'Repository URL'
                $wasNewCheckout = -not $script:RepositoryDictionary.ContainsKey($repoUrl)
            }
            
            if (Invoke-GitCheckout -Repository $repo -DependencyFilePath $DependencyFilePath) {
                $script:SuccessCount++
                $checkoutSucceeded = $true
                
                # Add to checked out repos list for recursive processing
                if ($Recursive -and $Depth -lt $MaxDepth -and $checkoutSucceeded) {
                    # Only process if this was a new checkout or required a tag update
                    if ($wasNewCheckout) {
                        $repoInfo = $script:RepositoryDictionary[$repo.'Repository URL']
                        # Skip if checkout failed
                        if (-not $repoInfo.CheckoutFailed) {
                            $checkedOutRepos += @{
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
        }
        
        return $checkedOutRepos
    }
    catch {
        Write-Log "Failed to parse dependency file '$DependencyFilePath': $_" -Level Error
        return @()
    }
}

function Process-RecursiveDependencies {
    param(
        [array]$CheckedOutRepos,
        [string]$DependencyFileName,
        [int]$CurrentDepth
    )
    
    if ($CurrentDepth -ge $MaxDepth) {
        Write-Log "Maximum recursion depth ($MaxDepth) reached" -Level Warning
        return
    }
    
    if ($CheckedOutRepos.Count -eq 0) {
        Write-Log "No new repositories to process at depth $CurrentDepth" -Level Debug
        return
    }
    
    Write-Log "Processing $($CheckedOutRepos.Count) repositories at depth $CurrentDepth" -Level Info
    
    $newlyCheckedOutRepos = @()
    
    foreach ($repoInfo in $CheckedOutRepos) {
        $repoPath = $repoInfo.AbsolutePath
        $repoUrl = $repoInfo.Repository.'Repository URL'
        
        # Skip if repository checkout failed
        if ($script:RepositoryDictionary.ContainsKey($repoUrl) -and 
            $script:RepositoryDictionary[$repoUrl].CheckoutFailed) {
            Write-Log "Skipping dependency processing for failed repository: $repoUrl" -Level Warning
            continue
        }
        
        $nestedDependencyFile = Join-Path $repoPath $DependencyFileName
        
        if (Test-Path $nestedDependencyFile) {
            Write-Log "Found nested dependency file: $nestedDependencyFile" -Level Info
            $newRepos = Process-DependencyFile -DependencyFilePath $nestedDependencyFile -Depth ($CurrentDepth + 1)
            $newlyCheckedOutRepos += $newRepos
        } else {
            Write-Log "No dependency file found in: $repoPath" -Level Debug
        }
    }
    
    # Recursively process newly checked out repositories
    if ($newlyCheckedOutRepos.Count -gt 0) {
        Process-RecursiveDependencies -CheckedOutRepos $newlyCheckedOutRepos -DependencyFileName $DependencyFileName -CurrentDepth ($CurrentDepth + 1)
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
Total Repositories: $($script:Repositories.Count)
Successful: $($script:SuccessCount)
Failed: $($script:FailureCount)
"@
    
    if ($Recursive) {
        $summary += "`nRecursive Mode: Enabled"
        $summary += "`nMax Depth: $MaxDepth"
        $summary += "`nDefault API Compatibility: $($script:DefaultApiCompatibility)"
        $summary += "`nTotal Unique Repositories: $($script:RepositoryDictionary.Count)"
    }
    
    if ($script:EnableTagSorting) {
        $summary += "`nTag Temporal Sorting: Enabled"
        
        # Show tag statistics in debug mode
        if ($EnableDebug -and $script:RepositoryDictionary.Count -gt 0) {
            $totalTags = 0
            $reposWithTags = 0
            foreach ($repo in $script:RepositoryDictionary.Values) {
                if ($repo.ContainsKey('TagDates') -and $repo.TagDates.Count -gt 0) {
                    $totalTags += $repo.TagDates.Count
                    $reposWithTags++
                }
            }
            $summary += "`nRepositories with Tag Data: $reposWithTags"
            $summary += "`nTotal Tags Processed: $totalTags"
        }
    } else {
        $summary += "`nTag Temporal Sorting: Disabled"
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
    
    if ($script:EnableTagSorting) {
        Write-Log "Tag temporal sorting: ENABLED" -Level Info
        Write-Log "Manual temporal ordering requirements relaxed in Permissive mode" -Level Info
    } else {
        Write-Log "Tag temporal sorting: DISABLED" -Level Info
        Write-Log "Manual temporal ordering required for API Compatible Tags" -Level Info
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
    
    if ($Recursive) {
        Write-Log "Recursive mode enabled with max depth: $MaxDepth" -Level Info
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
    $dependencyFileName = Split-Path -Leaf $InputFile
    
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
    
    # Process the initial dependency file
    $checkedOutRepos = Process-DependencyFile -DependencyFilePath $InputFile -Depth 0
    
    # If recursive mode is enabled, process nested dependencies
    if ($Recursive -and $checkedOutRepos.Count -gt 0) {
        Process-RecursiveDependencies -CheckedOutRepos $checkedOutRepos -DependencyFileName $DependencyFileName -CurrentDepth 1
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
    $errorMessage = "Unexpected error: $_"
    Write-Log $errorMessage -Level Error
    Show-ErrorDialog -Message $errorMessage
    exit 1
}