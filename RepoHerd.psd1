@{
    # Module manifest for RepoHerd
    RootModule        = 'RepoHerd.psm1'
    ModuleVersion     = '9.0.0'
    GUID              = '55dbb622-24f8-4f70-b16e-5412d436f94f'
    Author            = 'LS Instruments AG'
    CompanyName       = 'LS Instruments AG'
    Copyright         = '(c) LS Instruments AG. All rights reserved.'
    Description       = 'Multi-repository Git dependency manager with SemVer version resolution, recursive dependency discovery, and cross-platform SSH support. Clone and checkout multiple Git repositories to pinned versions from a single JSON config. An alternative to git submodules for managing shared libraries across repos.'
    PowerShellVersion = '7.6'

    FunctionsToExport = @(
        'Initialize-RepoHerd',
        'Write-ErrorWithContext',
        'Invoke-WithErrorContext',
        'Write-Log',
        'ConvertTo-VersionPattern',
        'Test-SemVerCompatibility',
        'Get-CompatibleVersionsForPattern',
        'Select-VersionFromIntersection',
        'Get-RepositoryVersions',
        'Get-SemVersionIntersection',
        'Format-SemVersion',
        'Test-DependencyConfiguration',
        'Show-ErrorDialog',
        'Show-ConfirmDialog',
        'Test-GitInstalled',
        'Test-GitLfsInstalled',
        'Test-SshTransportAvailable',
        'Get-RepositoryUrl',
        'Get-HostnameFromUrl',
        'Get-SshKeyForUrl',
        'Set-GitSshKey',
        'Get-GitTagDates',
        'Resolve-TagsByDate',
        'Reset-GitRepository',
        'Get-AbsoluteBasePath',
        'Get-TagIntersection',
        'Get-TagUnion',
        'Get-CustomDependencyFilePath',
        'Invoke-PostCheckoutScript',
        'Update-RepositoryDictionary',
        'Update-SemVerRepository',
        'Invoke-GitCheckout',
        'Invoke-DependencyFile',
        'Invoke-RecursiveDependencies',
        'Read-CredentialsFile',
        'Set-PostCheckoutScriptResult',
        'Export-CheckoutResults',
        'Show-Summary'
    )

    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('Git', 'Dependency', 'SemVer', 'Checkout', 'MultiRepo', 'DevOps', 'Automation', 'SSH', 'CrossPlatform', 'DependencyManagement', 'VersionPinning', 'Repository', 'Submodules')
            LicenseUri   = 'https://github.com/LS-Instruments/RepoHerd/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/LS-Instruments/RepoHerd'
            ReleaseNotes = 'v9.0.0: Project renamed from LsiGitCheckout to RepoHerd. Breaking: module, entry point, and initialization function renamed. Added GitHub Pages landing page with SEO.'
        }
    }
}
