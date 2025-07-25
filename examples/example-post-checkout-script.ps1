#Requires -Version 5.1
<#
.SYNOPSIS
    Complete Post-Checkout Script for LsiGitCheckout
.DESCRIPTION
    This script demonstrates comprehensive post-checkout functionality including
    GUI dialogs, package manager detection, and environment setup.
.NOTES
    Environment variables available:
    - $env:LSIGIT_REPOSITORY_URL: The repository URL that was checked out
    - $env:LSIGIT_REPOSITORY_PATH: Absolute path to the repository on disk
    - $env:LSIGIT_TAG: The git tag that was checked out
    - $env:LSIGIT_SCRIPT_VERSION: Version of LsiGitCheckout executing the script
#>

# Add required assemblies for Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Function to show dialog window
function Show-PostCheckoutDialog {
    param(
        [string]$RepositoryUrl,
        [string]$RepositoryPath,
        [string]$Tag,
        [string]$ScriptVersion
    )
    
    # Create the form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "LsiGitCheckout - Post-Checkout Complete"
    $form.Size = New-Object System.Drawing.Size(500, 450)  # Increased height from 400 to 450
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.Icon = [System.Drawing.SystemIcons]::Information
    
    # Create main label
    $mainLabel = New-Object System.Windows.Forms.Label
    $mainLabel.Location = New-Object System.Drawing.Point(20, 20)
    $mainLabel.Size = New-Object System.Drawing.Size(450, 30)
    $mainLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 12, [System.Drawing.FontStyle]::Bold)
    $mainLabel.Text = "Repository Checkout Completed Successfully!"
    $mainLabel.ForeColor = [System.Drawing.Color]::DarkGreen
    $form.Controls.Add($mainLabel)
    
    # Create info text box
    $infoTextBox = New-Object System.Windows.Forms.TextBox
    $infoTextBox.Location = New-Object System.Drawing.Point(20, 60)
    $infoTextBox.Size = New-Object System.Drawing.Size(450, 200)
    $infoTextBox.Multiline = $true
    $infoTextBox.ReadOnly = $true
    $infoTextBox.ScrollBars = "Vertical"
    $infoTextBox.Font = New-Object System.Drawing.Font("Consolas", 9)
    
    $infoText = @"
Repository Information:
=======================
URL: $RepositoryUrl
Path: $RepositoryPath
Tag: $Tag
LsiGitCheckout Version: $ScriptVersion

Post-Checkout Actions Performed:
================================
- Repository successfully checked out
- Environment variables configured
- Working directory set to repository root
- Post-checkout script executed successfully

This dialog demonstrates how post-checkout scripts can:
- Show user notifications
- Access checkout context via environment variables
- Perform custom setup tasks
- Integrate with external tools and package managers

Click 'Continue' to close this dialog and complete the checkout process.
"@
    
    $infoTextBox.Text = $infoText
    $form.Controls.Add($infoTextBox)
    
    # Create package manager status section
    $packageLabel = New-Object System.Windows.Forms.Label
    $packageLabel.Location = New-Object System.Drawing.Point(20, 280)
    $packageLabel.Size = New-Object System.Drawing.Size(450, 20)
    $packageLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)
    $packageLabel.Text = "Package Manager Integration:"
    $form.Controls.Add($packageLabel)
    
    $packageStatus = New-Object System.Windows.Forms.Label
    $packageStatus.Location = New-Object System.Drawing.Point(20, 300)
    $packageStatus.Size = New-Object System.Drawing.Size(450, 40)
    $packageStatus.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 8)
    
    # Check for common package manager files
    $packageInfo = @()
    if (Test-Path "package.json") { $packageInfo += "- package.json found (npm install would run)" }
    if (Test-Path "requirements.txt") { $packageInfo += "- requirements.txt found (pip install would run)" }
    if (Test-Path "*.csproj") { $packageInfo += "- .csproj found (dotnet restore would run)" }
    if (Test-Path "Gemfile") { $packageInfo += "- Gemfile found (bundle install would run)" }
    if (Test-Path "composer.json") { $packageInfo += "- composer.json found (composer install would run)" }
    
    if ($packageInfo.Count -eq 0) {
        $packageStatus.Text = "No package manager files detected in this repository."
    } else {
        $packageStatus.Text = $packageInfo -join "`n"
    }
    
    $form.Controls.Add($packageStatus)
    
    # Create Continue button
    $continueButton = New-Object System.Windows.Forms.Button
    $continueButton.Location = New-Object System.Drawing.Point(200, 390)  # Moved down from 350 to 390
    $continueButton.Size = New-Object System.Drawing.Size(100, 30)
    $continueButton.Text = "Continue"
    $continueButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $continueButton.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($continueButton)
    $form.AcceptButton = $continueButton
    
    # Show the form
    $result = $form.ShowDialog()
    
    # Clean up
    $form.Dispose()
    
    return $result
}

# Main script execution
try {
    Write-Host "=== LsiGitCheckout Post-Checkout Script Started ===" -ForegroundColor Green
    Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host ""
    
    # Display environment variables provided by LsiGitCheckout
    Write-Host "Repository Context:" -ForegroundColor Yellow
    Write-Host "  Repository URL: $env:LSIGIT_REPOSITORY_URL"
    Write-Host "  Repository Path: $env:LSIGIT_REPOSITORY_PATH"
    Write-Host "  Git Tag: $env:LSIGIT_TAG"
    Write-Host "  LsiGitCheckout Version: $env:LSIGIT_SCRIPT_VERSION"
    Write-Host ""
    
    # Verify we're in the correct directory
    $currentLocation = Get-Location
    Write-Host "Current Working Directory: $currentLocation" -ForegroundColor Cyan
    
    # Example: Package manager integration
    Write-Host "Checking for package manager files..." -ForegroundColor Yellow
    
    $packagesFound = $false
    
    # Check for npm (Node.js)
    if (Test-Path "package.json") {
        Write-Host "  - Found package.json - Node.js/npm project detected" -ForegroundColor Green
        $packagesFound = $true
        
        # Uncomment the following lines to actually install npm packages
        # Write-Host "  Installing npm dependencies..." -ForegroundColor Cyan
        # npm install
        # if ($LASTEXITCODE -eq 0) {
        #     Write-Host "  - npm install completed successfully" -ForegroundColor Green
        # } else {
        #     Write-Host "  - npm install failed" -ForegroundColor Red
        # }
    }
    
    # Check for Python
    if (Test-Path "requirements.txt") {
        Write-Host "  - Found requirements.txt - Python project detected" -ForegroundColor Green
        $packagesFound = $true
        
        # Uncomment the following lines to actually install Python packages
        # Write-Host "  Installing Python requirements..." -ForegroundColor Cyan
        # pip install -r requirements.txt
        # if ($LASTEXITCODE -eq 0) {
        #     Write-Host "  - pip install completed successfully" -ForegroundColor Green
        # } else {
        #     Write-Host "  - pip install failed" -ForegroundColor Red
        # }
    }
    
    # Check for .NET
    $csprojFiles = Get-ChildItem -Name "*.csproj" -ErrorAction SilentlyContinue
    if ($csprojFiles.Count -gt 0) {
        Write-Host "  - Found .csproj files - .NET project detected" -ForegroundColor Green
        $packagesFound = $true
        
        # Uncomment the following lines to actually restore NuGet packages
        # Write-Host "  Restoring .NET packages..." -ForegroundColor Cyan
        # dotnet restore
        # if ($LASTEXITCODE -eq 0) {
        #     Write-Host "  - dotnet restore completed successfully" -ForegroundColor Green
        # } else {
        #     Write-Host "  - dotnet restore failed" -ForegroundColor Red
        # }
    }
    
    # Check for Ruby
    if (Test-Path "Gemfile") {
        Write-Host "  - Found Gemfile - Ruby project detected" -ForegroundColor Green
        $packagesFound = $true
        
        # Uncomment the following lines to actually install Ruby gems
        # Write-Host "  Installing Ruby gems..." -ForegroundColor Cyan
        # bundle install
        # if ($LASTEXITCODE -eq 0) {
        #     Write-Host "  - bundle install completed successfully" -ForegroundColor Green
        # } else {
        #     Write-Host "  - bundle install failed" -ForegroundColor Red
        # }
    }
    
    # Check for PHP
    if (Test-Path "composer.json") {
        Write-Host "  - Found composer.json - PHP project detected" -ForegroundColor Green
        $packagesFound = $true
        
        # Uncomment the following lines to actually install Composer packages
        # Write-Host "  Installing Composer dependencies..." -ForegroundColor Cyan
        # composer install
        # if ($LASTEXITCODE -eq 0) {
        #     Write-Host "  - composer install completed successfully" -ForegroundColor Green
        # } else {
        #     Write-Host "  - composer install failed" -ForegroundColor Red
        # }
    }
    
    if (-not $packagesFound) {
        Write-Host "  - No package manager files detected" -ForegroundColor Gray
    }
    
    Write-Host ""
    
    # Example: Custom setup tasks
    Write-Host "Performing custom setup tasks..." -ForegroundColor Yellow
    
    # Create a simple metadata file
    $metadata = @{
        CheckoutTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        RepositoryUrl = $env:LSIGIT_REPOSITORY_URL
        Tag = $env:LSIGIT_TAG
        LsiGitCheckoutVersion = $env:LSIGIT_SCRIPT_VERSION
        WorkingDirectory = $currentLocation.Path
        PostCheckoutScriptExecuted = $true
    }
    
    $metadataJson = $metadata | ConvertTo-Json -Depth 2
    $metadataFile = "lsigit-checkout-metadata.json"
    $metadataJson | Out-File -FilePath $metadataFile -Encoding UTF8
    Write-Host "  - Created checkout metadata file: $metadataFile" -ForegroundColor Green
    
    # Show the dialog window
    Write-Host "Displaying post-checkout dialog..." -ForegroundColor Yellow
    $dialogResult = Show-PostCheckoutDialog -RepositoryUrl $env:LSIGIT_REPOSITORY_URL -RepositoryPath $env:LSIGIT_REPOSITORY_PATH -Tag $env:LSIGIT_TAG -ScriptVersion $env:LSIGIT_SCRIPT_VERSION
    
    if ($dialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
        Write-Host "  - Dialog closed by user" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "=== Post-Checkout Script Completed Successfully ===" -ForegroundColor Green
    
    # Exit with success
    exit 0
}
catch {
    Write-Host ""
    Write-Host "=== Post-Checkout Script Failed ===" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    
    # Exit with error code
    exit 1
}