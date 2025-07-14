#Requires -Version 5.1
<#
.SYNOPSIS
    LsiGitCheckout - Checks out a collection of Git repositories to specified tags
.DESCRIPTION
    This script reads a JSON configuration file and checks out multiple Git repositories
    to their specified tags. It supports both HTTPS and SSH URLs, handles Git LFS,
    initializes submodules, and provides comprehensive error handling and logging.
    
    SSH credentials are managed through a separate git_credentials.json file.
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
.EXAMPLE
    .\LsiGitCheckout.ps1
    .\LsiGitCheckout.ps1 -InputFile "C:\configs\myrepos.json" -CredentialsFile "C:\configs\my_credentials.json"
    .\LsiGitCheckout.ps1 -InputFile "repos.json" -EnableDebug
.NOTES
    Version: 3.0.0
    Last Modified: 2025-01-14
    
    This script uses PuTTY/plink for SSH authentication. SSH keys must be in PuTTY format (.ppk).
    Use PuTTYgen to convert OpenSSH keys to PuTTY format if needed.
    
    Changes in 3.0.0:
    - BREAKING CHANGE: Moved SSH key configuration from dependencies.json to separate credentials file
    - Added -CredentialsFile parameter for specifying SSH credentials file
    - SSH keys are now mapped by hostname instead of per-repository
    - Improved security by separating credentials from repository configuration
    - Removed "Submodule Config" as it's no longer needed (submodules are auto-discovered)
    
    Dependencies JSON Format:
    [
      {
        "Repository URL": "https://github.com/user/repo.git",
        "Base Path": "C:\\Projects\\repo",
        "Tag": "v1.0.0",
        "Skip LFS": false
      }
    ]
    
    Credentials JSON Format:
    {
      "github.com": "C:\\Users\\user\\.ssh\\github_key.ppk",
      "gitlab.com": "C:\\Users\\user\\.ssh\\gitlab_key.ppk",
      "ssh://git.company.com": "C:\\Users\\user\\.ssh\\company_key.ppk"
    }
    
    Note: The "SSH Key Path" field in Repository and Submodule Config has been removed.
    SSH keys are now determined by the hostname in the repository URL.
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
    [switch]$EnableDebug
)

# Script configuration
$script:Version = "3.0.0"
$script:ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:ErrorFile = Join-Path $ScriptPath "LsiGitCheckout_Errors.txt"
$script:DebugLogFile = Join-Path $ScriptPath ("debug_log_{0}.txt" -f (Get-Date -Format "yyyyMMddHHmm"))
$script:SuccessCount = 0
$script:FailureCount = 0
$script:Repositories = @()
$script:SshCredentials = @{}

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

function Invoke-GitCheckout {
    param(
        [PSCustomObject]$Repository
    )
    
    $repoUrl = $Repository.'Repository URL'
    $basePath = $Repository.'Base Path'
    $tag = $Repository.Tag
    $skipLfs = if ($null -eq $Repository.'Skip LFS') { $false } else { $Repository.'Skip LFS' }
    
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
    if (-not [System.IO.Path]::IsPathRooted($basePath)) {
        $basePath = Join-Path $script:ScriptPath $basePath
    }
    
    # Check if base path exists
    if (Test-Path $basePath) {
        Write-Log "Base path exists: $basePath" -Level Verbose
        
        # Check if it's a git repository
        $gitDir = Join-Path $basePath ".git"
        if (Test-Path $gitDir) {
            # Check if it points to the same repository
            $existingUrl = Get-RepositoryUrl -RepoPath $basePath
            if ($existingUrl -eq $repoUrl) {
                Write-Log "Repository already exists with correct URL, resetting..." -Level Info
                $skipLfsValue = if ($null -eq $skipLfs) { $false } else { [bool]$skipLfs }
                if (-not (Reset-GitRepository -RepoPath $basePath -SkipLfs $skipLfsValue)) {
                    Show-ErrorDialog -Message "Failed to reset repository at: $basePath"
                    return $false
                }
            }
            else {
                Write-Log "Different repository exists at path" -Level Warning
                $message = "The folder '$basePath' contains a different repository.`n`nExisting: $existingUrl`nRequired: $repoUrl`n`nDo you want to delete the existing content?"
                if (Show-ConfirmDialog -Message $message) {
                    Write-Log "User agreed to delete existing content" -Level Info
                    if (-not $DryRun) {
                        Remove-Item -Path $basePath -Recurse -Force
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
            $message = "The folder '$basePath' exists but is not a Git repository.`n`nDo you want to delete the existing content?"
            if (Show-ConfirmDialog -Message $message) {
                Write-Log "User agreed to delete existing content" -Level Info
                if (-not $DryRun) {
                    Remove-Item -Path $basePath -Recurse -Force
                }
            }
            else {
                Write-Log "User declined to delete existing content, stopping script" -Level Warning
                exit 1
            }
        }
    }
    
    # Create base path if it doesn't exist
    if (-not (Test-Path $basePath)) {
        Write-Log "Creating base path: $basePath" -Level Info
        if (-not $DryRun) {
            New-Item -ItemType Directory -Path $basePath -Force | Out-Null
        }
    }
    
    try {
        # Clone or fetch repository
        if (-not (Test-Path (Join-Path $basePath ".git"))) {
            Write-Log "Cloning repository..." -Level Info
            
            # Use direct git command with proper quoting
            Write-Log "Executing: git clone `"$repoUrl`" `"$basePath`"" -Level Debug
            
            if (-not $DryRun) {
                # Change to parent directory to avoid path issues
                $parentPath = Split-Path $basePath -Parent
                $repoName = Split-Path $basePath -Leaf
                
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
            Push-Location $basePath
            
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
        Push-Location $basePath
        
        # Skip checkout if we already did it during clone for LFS skip
        if (-not ($skipLfs -and -not (Test-Path (Join-Path $basePath ".git")))) {
            Write-Log "Checking out tag: $tag" -Level Info
            $checkoutCmd = "git checkout $tag"
            Write-Log "Executing: $checkoutCmd" -Level Debug
            
            if (-not $DryRun) {
                $output = Invoke-Expression $checkoutCmd 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Pop-Location
                    throw "Checkout failed: $output"
                }
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
        Write-Log "Successfully processed repository: $repoUrl" -Level Info
        return $true
    }
    catch {
        if (Get-Location | Where-Object { $_.Path -ne $basePath }) {
            Pop-Location -ErrorAction SilentlyContinue
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
========================================
"@
    
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
    
    # Read and parse JSON file
    Write-Log "Reading input file: $InputFile" -Level Info
    try {
        $jsonContent = Get-Content -Path $InputFile -Raw
        $script:Repositories = $jsonContent | ConvertFrom-Json
        
        if (-not $script:Repositories) {
            throw "No repositories found in input file"
        }
        
        Write-Log "Found $($script:Repositories.Count) repositories to process" -Level Info
    }
    catch {
        $errorMessage = "Failed to parse input file: $_"
        Write-Log $errorMessage -Level Error
        Show-ErrorDialog -Message $errorMessage
        exit 1
    }
    
    # Process each repository
    foreach ($repo in $script:Repositories) {
        if (Invoke-GitCheckout -Repository $repo) {
            $script:SuccessCount++
        }
        else {
            $script:FailureCount++
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
    $errorMessage = "Unexpected error: $_"
    Write-Log $errorMessage -Level Error
    Show-ErrorDialog -Message $errorMessage
    exit 1
}