@{
    # Module manifest for LsiGitCheckout
    RootModule        = 'LsiGitCheckout.psm1'
    ModuleVersion     = '8.0.0'
    GUID              = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author            = 'LS Instruments AG'
    CompanyName       = 'LS Instruments AG'
    Copyright         = '(c) LS Instruments AG. All rights reserved.'
    Description       = 'PowerShell-based dependency management tool that checks out multiple Git repositories to specified versions.'
    PowerShellVersion = '7.6'

    FunctionsToExport = @(
        'Initialize-LsiGitCheckout',
        'Write-ErrorWithContext',
        'Invoke-WithErrorContext',
        'Write-Log',
        'Parse-VersionPattern',
        'Test-SemVerCompatibility',
        'Get-CompatibleVersionsForPattern',
        'Select-VersionFromIntersection',
        'Parse-RepositoryVersions',
        'Get-SemVersionIntersection',
        'Format-SemVersion',
        'Validate-DependencyConfiguration',
        'Show-ErrorDialog',
        'Show-ConfirmDialog',
        'Test-GitInstalled',
        'Test-GitLfsInstalled',
        'Test-PlinkInstalled',
        'Get-RepositoryUrl',
        'Get-HostnameFromUrl',
        'Get-SshKeyForUrl',
        'Set-GitSshKey',
        'Get-GitTagDates',
        'Sort-TagsByDate',
        'Reset-GitRepository',
        'Get-AbsoluteBasePath',
        'Get-TagIntersection',
        'Get-TagUnion',
        'Get-CustomDependencyFilePath',
        'Invoke-PostCheckoutScript',
        'Update-RepositoryDictionary',
        'Update-SemVerRepository',
        'Invoke-GitCheckout',
        'Process-DependencyFile',
        'Process-RecursiveDependencies',
        'Read-CredentialsFile',
        'Show-Summary'
    )

    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @()

    PrivateData = @{
        PSData = @{
            Tags       = @('Git', 'Dependency', 'SemVer', 'Checkout')
            ProjectUri = 'https://github.com/LS-Instruments/LsiGitCheckout'
        }
    }
}
