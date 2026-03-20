#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

<#
.SYNOPSIS
    Unit tests for LsiGitCheckout module functions
.DESCRIPTION
    Tests pure and near-pure functions that require no network or git operations.
    Run with: Invoke-Pester ./tests/LsiGitCheckout.Unit.Tests.ps1 -Output Detailed
#>

BeforeAll {
    # Import the module from parent directory
    $modulePath = Join-Path $PSScriptRoot '..' 'LsiGitCheckout.psm1'
    Import-Module $modulePath -Force

    # Initialize module with test-safe defaults
    Initialize-LsiGitCheckout -ScriptPath $PSScriptRoot

    # Silence Write-Host output from Write-Log
    Mock Write-Host {} -ModuleName LsiGitCheckout
}

Describe 'Parse-VersionPattern' {
    It 'parses exact version x.y.z as LowestApplicable' {
        $result = Parse-VersionPattern -VersionPattern '3.2.1'
        $result.Type | Should -Be 'LowestApplicable'
        $result.Major | Should -Be 3
        $result.Minor | Should -Be 2
        $result.Patch | Should -Be 1
        $result.OriginalPattern | Should -Be '3.2.1'
    }

    It 'parses floating patch x.y.* as FloatingPatch' {
        $result = Parse-VersionPattern -VersionPattern '2.1.*'
        $result.Type | Should -Be 'FloatingPatch'
        $result.Major | Should -Be 2
        $result.Minor | Should -Be 1
        $result.Patch | Should -BeNullOrEmpty
    }

    It 'parses floating minor x.* as FloatingMinor' {
        $result = Parse-VersionPattern -VersionPattern '5.*'
        $result.Type | Should -Be 'FloatingMinor'
        $result.Major | Should -Be 5
        $result.Minor | Should -BeNullOrEmpty
        $result.Patch | Should -BeNullOrEmpty
    }

    It 'parses version 0.x.y correctly' {
        $result = Parse-VersionPattern -VersionPattern '0.2.3'
        $result.Type | Should -Be 'LowestApplicable'
        $result.Major | Should -Be 0
        $result.Minor | Should -Be 2
        $result.Patch | Should -Be 3
    }

    It 'throws on invalid pattern' {
        { Parse-VersionPattern -VersionPattern 'abc' } | Should -Throw '*Invalid version pattern*'
    }

    It 'throws on partial pattern x.y' {
        { Parse-VersionPattern -VersionPattern '1.2' } | Should -Throw '*Invalid version pattern*'
    }

    It 'throws on empty string' {
        { Parse-VersionPattern -VersionPattern '' } | Should -Throw '*Invalid version pattern*'
    }
}

Describe 'Test-SemVerCompatibility' {
    Context 'LowestApplicable pattern' {
        BeforeAll {
            $pattern = @{ Type = 'LowestApplicable'; Major = 2; Minor = 1; Patch = 0; OriginalPattern = '2.1.0' }
        }

        It 'accepts exact version match' {
            Test-SemVerCompatibility -Available ([Version]::new(2, 1, 0)) -VersionPattern $pattern | Should -BeTrue
        }

        It 'accepts same major, higher minor' {
            Test-SemVerCompatibility -Available ([Version]::new(2, 3, 0)) -VersionPattern $pattern | Should -BeTrue
        }

        It 'accepts same major.minor, higher patch' {
            Test-SemVerCompatibility -Available ([Version]::new(2, 1, 5)) -VersionPattern $pattern | Should -BeTrue
        }

        It 'rejects different major version' {
            Test-SemVerCompatibility -Available ([Version]::new(3, 0, 0)) -VersionPattern $pattern | Should -BeFalse
        }

        It 'rejects lower minor.patch' {
            Test-SemVerCompatibility -Available ([Version]::new(2, 0, 9)) -VersionPattern $pattern | Should -BeFalse
        }
    }

    Context 'LowestApplicable 0.x special case' {
        BeforeAll {
            $pattern = @{ Type = 'LowestApplicable'; Major = 0; Minor = 2; Patch = 1; OriginalPattern = '0.2.1' }
        }

        It 'accepts same 0.minor with higher patch' {
            Test-SemVerCompatibility -Available ([Version]::new(0, 2, 3)) -VersionPattern $pattern | Should -BeTrue
        }

        It 'rejects different minor under 0.x' {
            Test-SemVerCompatibility -Available ([Version]::new(0, 3, 0)) -VersionPattern $pattern | Should -BeFalse
        }

        It 'rejects lower patch under 0.x' {
            Test-SemVerCompatibility -Available ([Version]::new(0, 2, 0)) -VersionPattern $pattern | Should -BeFalse
        }
    }

    Context 'FloatingPatch pattern' {
        BeforeAll {
            $pattern = @{ Type = 'FloatingPatch'; Major = 2; Minor = 1; OriginalPattern = '2.1.*' }
        }

        It 'accepts any patch within same major.minor' {
            Test-SemVerCompatibility -Available ([Version]::new(2, 1, 0)) -VersionPattern $pattern | Should -BeTrue
            Test-SemVerCompatibility -Available ([Version]::new(2, 1, 99)) -VersionPattern $pattern | Should -BeTrue
        }

        It 'rejects different minor' {
            Test-SemVerCompatibility -Available ([Version]::new(2, 2, 0)) -VersionPattern $pattern | Should -BeFalse
        }

        It 'rejects different major' {
            Test-SemVerCompatibility -Available ([Version]::new(3, 1, 0)) -VersionPattern $pattern | Should -BeFalse
        }
    }

    Context 'FloatingPatch 0.x special case' {
        BeforeAll {
            $pattern = @{ Type = 'FloatingPatch'; Major = 0; Minor = 3; OriginalPattern = '0.3.*' }
        }

        It 'accepts any patch within 0.3' {
            Test-SemVerCompatibility -Available ([Version]::new(0, 3, 0)) -VersionPattern $pattern | Should -BeTrue
            Test-SemVerCompatibility -Available ([Version]::new(0, 3, 15)) -VersionPattern $pattern | Should -BeTrue
        }

        It 'rejects different minor under 0.x' {
            Test-SemVerCompatibility -Available ([Version]::new(0, 4, 0)) -VersionPattern $pattern | Should -BeFalse
        }
    }

    Context 'FloatingMinor pattern' {
        BeforeAll {
            $pattern = @{ Type = 'FloatingMinor'; Major = 3; OriginalPattern = '3.*' }
        }

        It 'accepts any version within same major' {
            Test-SemVerCompatibility -Available ([Version]::new(3, 0, 0)) -VersionPattern $pattern | Should -BeTrue
            Test-SemVerCompatibility -Available ([Version]::new(3, 99, 99)) -VersionPattern $pattern | Should -BeTrue
        }

        It 'rejects different major' {
            Test-SemVerCompatibility -Available ([Version]::new(4, 0, 0)) -VersionPattern $pattern | Should -BeFalse
            Test-SemVerCompatibility -Available ([Version]::new(2, 0, 0)) -VersionPattern $pattern | Should -BeFalse
        }
    }

    Context 'FloatingMinor 0.x special case' {
        BeforeAll {
            $pattern = @{ Type = 'FloatingMinor'; Major = 0; OriginalPattern = '0.*' }
        }

        It 'accepts any 0.x version' {
            Test-SemVerCompatibility -Available ([Version]::new(0, 0, 0)) -VersionPattern $pattern | Should -BeTrue
            Test-SemVerCompatibility -Available ([Version]::new(0, 9, 9)) -VersionPattern $pattern | Should -BeTrue
        }

        It 'rejects major > 0' {
            Test-SemVerCompatibility -Available ([Version]::new(1, 0, 0)) -VersionPattern $pattern | Should -BeFalse
        }
    }
}

Describe 'Get-CompatibleVersionsForPattern' {
    BeforeAll {
        $versions = @{
            'v1.0.0' = [Version]::new(1, 0, 0)
            'v1.1.0' = [Version]::new(1, 1, 0)
            'v1.1.5' = [Version]::new(1, 1, 5)
            'v1.2.0' = [Version]::new(1, 2, 0)
            'v2.0.0' = [Version]::new(2, 0, 0)
        }
    }

    It 'returns versions >= requested for LowestApplicable' {
        $pattern = @{ Type = 'LowestApplicable'; Major = 1; Minor = 1; Patch = 0; OriginalPattern = '1.1.0' }
        $result = Get-CompatibleVersionsForPattern -ParsedVersions $versions -VersionPattern $pattern
        $result.Count | Should -Be 3  # v1.1.0, v1.1.5, v1.2.0
        $result.Tag | Should -Contain 'v1.1.0'
        $result.Tag | Should -Contain 'v1.1.5'
        $result.Tag | Should -Contain 'v1.2.0'
    }

    It 'returns only matching major.minor for FloatingPatch' {
        $pattern = @{ Type = 'FloatingPatch'; Major = 1; Minor = 1; OriginalPattern = '1.1.*' }
        $result = Get-CompatibleVersionsForPattern -ParsedVersions $versions -VersionPattern $pattern
        $result.Count | Should -Be 2  # v1.1.0, v1.1.5
        $result.Tag | Should -Contain 'v1.1.0'
        $result.Tag | Should -Contain 'v1.1.5'
    }

    It 'returns all matching major for FloatingMinor' {
        $pattern = @{ Type = 'FloatingMinor'; Major = 1; OriginalPattern = '1.*' }
        $result = Get-CompatibleVersionsForPattern -ParsedVersions $versions -VersionPattern $pattern
        $result.Count | Should -Be 4  # all v1.x.x
        $result.Tag | Should -Not -Contain 'v2.0.0'
    }

    It 'throws when no compatible version found' {
        $pattern = @{ Type = 'LowestApplicable'; Major = 3; Minor = 0; Patch = 0; OriginalPattern = '3.0.0' }
        { Get-CompatibleVersionsForPattern -ParsedVersions $versions -VersionPattern $pattern } | Should -Throw '*No compatible version found*'
    }
}

Describe 'Select-VersionFromIntersection' {
    BeforeAll {
        $intersectionVersions = @(
            [PSCustomObject]@{ Tag = 'v1.1.0'; Version = [Version]::new(1, 1, 0) }
            [PSCustomObject]@{ Tag = 'v1.1.5'; Version = [Version]::new(1, 1, 5) }
            [PSCustomObject]@{ Tag = 'v1.2.0'; Version = [Version]::new(1, 2, 0) }
        )
    }

    It 'selects lowest version when all patterns are LowestApplicable' {
        $patterns = @{
            'caller1' = @{ Type = 'LowestApplicable'; Major = 1; Minor = 1; Patch = 0; OriginalPattern = '1.1.0' }
            'caller2' = @{ Type = 'LowestApplicable'; Major = 1; Minor = 0; Patch = 0; OriginalPattern = '1.0.0' }
        }
        $result = Select-VersionFromIntersection -IntersectionVersions $intersectionVersions -RequestedPatterns $patterns
        $result.Tag | Should -Be 'v1.1.0'
    }

    It 'selects highest version when any pattern is floating' {
        $patterns = @{
            'caller1' = @{ Type = 'LowestApplicable'; Major = 1; Minor = 1; Patch = 0; OriginalPattern = '1.1.0' }
            'caller2' = @{ Type = 'FloatingPatch'; Major = 1; Minor = 1; OriginalPattern = '1.1.*' }
        }
        $result = Select-VersionFromIntersection -IntersectionVersions $intersectionVersions -RequestedPatterns $patterns
        $result.Tag | Should -Be 'v1.2.0'
    }
}

Describe 'Get-SemVersionIntersection' {
    It 'returns common tags between two sets' {
        $set1 = @(
            [PSCustomObject]@{ Tag = 'v1.0.0'; Version = [Version]::new(1, 0, 0) }
            [PSCustomObject]@{ Tag = 'v1.1.0'; Version = [Version]::new(1, 1, 0) }
            [PSCustomObject]@{ Tag = 'v1.2.0'; Version = [Version]::new(1, 2, 0) }
        )
        $set2 = @(
            [PSCustomObject]@{ Tag = 'v1.1.0'; Version = [Version]::new(1, 1, 0) }
            [PSCustomObject]@{ Tag = 'v1.2.0'; Version = [Version]::new(1, 2, 0) }
            [PSCustomObject]@{ Tag = 'v2.0.0'; Version = [Version]::new(2, 0, 0) }
        )
        $result = Get-SemVersionIntersection -Set1 $set1 -Set2 $set2
        $result.Count | Should -Be 2
        $result.Tag | Should -Contain 'v1.1.0'
        $result.Tag | Should -Contain 'v1.2.0'
    }

    It 'returns empty array when no intersection' {
        $set1 = @(
            [PSCustomObject]@{ Tag = 'v1.0.0'; Version = [Version]::new(1, 0, 0) }
        )
        $set2 = @(
            [PSCustomObject]@{ Tag = 'v2.0.0'; Version = [Version]::new(2, 0, 0) }
        )
        $result = Get-SemVersionIntersection -Set1 $set1 -Set2 $set2
        $result.Count | Should -Be 0
    }
}

Describe 'Format-SemVersion' {
    It 'formats Version object as major.minor.patch' {
        $v = [Version]::new(3, 2, 1)
        Format-SemVersion -Version $v | Should -Be '3.2.1'
    }

    It 'formats zero version correctly' {
        $v = [Version]::new(0, 0, 0)
        Format-SemVersion -Version $v | Should -Be '0.0.0'
    }
}

Describe 'Get-TagIntersection' {
    It 'returns common tags' {
        $result = Get-TagIntersection -Tags1 @('v1.0', 'v1.1', 'v2.0') -Tags2 @('v1.1', 'v2.0', 'v3.0')
        $result.Count | Should -Be 2
        $result | Should -Contain 'v1.1'
        $result | Should -Contain 'v2.0'
    }

    It 'returns empty when no overlap' {
        $result = Get-TagIntersection -Tags1 @('v1.0') -Tags2 @('v2.0')
        $result.Count | Should -Be 0
    }

    It 'handles empty arrays' {
        $result = Get-TagIntersection -Tags1 @() -Tags2 @('v1.0')
        $result.Count | Should -Be 0
    }
}

Describe 'Get-HostnameFromUrl' {
    It 'extracts hostname from HTTPS URL' {
        Get-HostnameFromUrl -Url 'https://github.com/org/repo.git' | Should -Be 'github.com'
    }

    It 'extracts hostname from git@ SSH URL' {
        Get-HostnameFromUrl -Url 'git@github.com:org/repo.git' | Should -Be 'github.com'
    }

    It 'extracts hostname from ssh:// URL' {
        Get-HostnameFromUrl -Url 'ssh://git@gitlab.com/org/repo.git' | Should -Be 'gitlab.com'
    }

    It 'extracts hostname from ssh:// URL with port' {
        Get-HostnameFromUrl -Url 'ssh://git@gitlab.com:2222/org/repo.git' | Should -Be 'gitlab.com'
    }

    It 'extracts hostname from HTTP URL' {
        Get-HostnameFromUrl -Url 'http://internal-git.company.com/repo.git' | Should -Be 'internal-git.company.com'
    }

    It 'returns null for unrecognized format' {
        Get-HostnameFromUrl -Url 'not-a-url' | Should -BeNullOrEmpty
    }
}

Describe 'Validate-DependencyConfiguration' {
    It 'passes when no conflict exists' {
        $newRepo = [PSCustomObject]@{
            'Repository URL' = 'https://github.com/org/repo.git'
            'Dependency Resolution' = 'SemVer'
        }
        $existingRepo = @{
            DependencyResolution = 'SemVer'
        }
        { Validate-DependencyConfiguration -NewRepo $newRepo -ExistingRepo $existingRepo } | Should -Not -Throw
    }

    It 'throws when dependency resolution mode changes' {
        $newRepo = [PSCustomObject]@{
            'Repository URL' = 'https://github.com/org/repo.git'
            'Dependency Resolution' = 'SemVer'
        }
        $existingRepo = @{
            DependencyResolution = 'Agnostic'
        }
        { Validate-DependencyConfiguration -NewRepo $newRepo -ExistingRepo $existingRepo } | Should -Throw '*cannot change*'
    }

    It 'throws when version regex changes for SemVer mode' {
        $newRepo = [PSCustomObject]@{
            'Repository URL' = 'https://github.com/org/repo.git'
            'Dependency Resolution' = 'SemVer'
            'Version Regex' = '^v(\d+)\.(\d+)\.(\d+)-beta$'
        }
        $existingRepo = @{
            DependencyResolution = 'SemVer'
            VersionRegex = '^v?(\d+)\.(\d+)\.(\d+)$'
        }
        { Validate-DependencyConfiguration -NewRepo $newRepo -ExistingRepo $existingRepo } | Should -Throw '*cannot change*'
    }

    It 'defaults to Agnostic when Dependency Resolution not specified' {
        $newRepo = [PSCustomObject]@{
            'Repository URL' = 'https://github.com/org/repo.git'
        }
        $existingRepo = @{
            DependencyResolution = 'Agnostic'
        }
        { Validate-DependencyConfiguration -NewRepo $newRepo -ExistingRepo $existingRepo } | Should -Not -Throw
    }
}

Describe 'Get-AbsoluteBasePath' {
    It 'returns rooted path unchanged' {
        if ($IsWindows) {
            $result = Get-AbsoluteBasePath -BasePath 'C:\Projects\repo' -DependencyFilePath 'C:\config\deps.json'
            $result | Should -Be 'C:\Projects\repo'
        } else {
            $result = Get-AbsoluteBasePath -BasePath '/tmp/repo' -DependencyFilePath '/config/deps.json'
            $result | Should -Be '/tmp/repo'
        }
    }
}

Describe 'Export-CheckoutResults' {
    BeforeEach {
        # Set up module state for testing
        & (Get-Module LsiGitCheckout) {
            $script:SuccessCount = 2
            $script:FailureCount = 0
            $script:PostCheckoutScriptExecutions = 0
            $script:PostCheckoutScriptFailures = 0
            $script:PostCheckoutScriptsEnabled = $false
            $script:RecursiveMode = $true
            $script:MaxDepth = 5
            $script:DefaultApiCompatibility = 'Permissive'
            $script:DefaultDependencyFileName = 'dependencies.json'
            $script:DryRun = $false
            $script:ProcessedDependencyFiles = @('C:\test\dependencies.json')
            $script:ErrorMessages = @()
            $script:RepositoryDictionary = @{
                'https://github.com/org/repoA.git' = @{
                    AbsolutePath = 'C:\test\repo-a'
                    DependencyResolution = 'Agnostic'
                    Tag = 'v1.0.0'
                    AlreadyCheckedOut = $true
                    NeedCheckout = $false
                    CheckoutFailed = $false
                    RequestedBy = @('root-dependency-file')
                }
                'https://github.com/org/repoB.git' = @{
                    AbsolutePath = 'C:\test\repo-b'
                    DependencyResolution = 'SemVer'
                    AlreadyCheckedOut = $true
                    NeedCheckout = $false
                    CheckoutFailed = $false
                    SelectedTag = 'v3.0.0'
                    SelectedVersion = [Version]::new(3, 0, 0)
                    RequestedPatterns = @{
                        'root-dependency-file' = @{ OriginalPattern = '3.0.0'; Type = 'LowestApplicable' }
                    }
                    RequestedBy = @('root-dependency-file')
                }
            }
        }
    }

    It 'writes valid JSON with correct schema version' {
        $outputFile = Join-Path $TestDrive 'result.json'
        Export-CheckoutResults -OutputFile $outputFile

        $outputFile | Should -Exist
        $result = Get-Content $outputFile -Raw | ConvertFrom-Json
        $result.schemaVersion | Should -Be '1.0.0'
    }

    It 'includes correct metadata' {
        $outputFile = Join-Path $TestDrive 'result.json'
        Export-CheckoutResults -OutputFile $outputFile

        $result = Get-Content $outputFile -Raw | ConvertFrom-Json
        $result.metadata.toolVersion | Should -Be '8.0.0'
        $result.metadata.recursiveMode | Should -Be $true
        $result.metadata.maxDepth | Should -Be 5
        $result.metadata.apiCompatibility | Should -Be 'Permissive'
        $result.metadata.inputFile | Should -Be 'dependencies.json'
    }

    It 'includes correct summary counters' {
        $outputFile = Join-Path $TestDrive 'result.json'
        Export-CheckoutResults -OutputFile $outputFile

        $result = Get-Content $outputFile -Raw | ConvertFrom-Json
        $result.summary.success | Should -Be $true
        $result.summary.successCount | Should -Be 2
        $result.summary.failureCount | Should -Be 0
        $result.summary.totalRepositories | Should -Be 2
    }

    It 'includes repository entries with correct fields' {
        $outputFile = Join-Path $TestDrive 'result.json'
        Export-CheckoutResults -OutputFile $outputFile

        $result = Get-Content $outputFile -Raw | ConvertFrom-Json
        $result.repositories.Count | Should -Be 2

        foreach ($repo in $result.repositories) {
            $repo.url | Should -Not -BeNullOrEmpty
            $repo.path | Should -Not -BeNullOrEmpty
            $repo.dependencyResolution | Should -BeIn @('SemVer', 'Agnostic')
            $repo.status | Should -BeIn @('success', 'failed', 'skipped')
        }
    }

    It 'populates SemVer-specific fields for SemVer repos' {
        $outputFile = Join-Path $TestDrive 'result.json'
        Export-CheckoutResults -OutputFile $outputFile

        $result = Get-Content $outputFile -Raw | ConvertFrom-Json
        $semVerRepo = $result.repositories | Where-Object { $_.dependencyResolution -eq 'SemVer' }

        $semVerRepo | Should -Not -BeNullOrEmpty
        $semVerRepo.tag | Should -Be 'v3.0.0'
        $semVerRepo.selectedVersion | Should -Be '3.0.0'
        $semVerRepo.requestedVersion | Should -Be '3.0.0'
    }

    It 'sets null for SemVer fields on Agnostic repos' {
        $outputFile = Join-Path $TestDrive 'result.json'
        Export-CheckoutResults -OutputFile $outputFile

        $result = Get-Content $outputFile -Raw | ConvertFrom-Json
        $agnosticRepo = $result.repositories | Where-Object { $_.dependencyResolution -eq 'Agnostic' }

        $agnosticRepo | Should -Not -BeNullOrEmpty
        $agnosticRepo.tag | Should -Be 'v1.0.0'
        $agnosticRepo.requestedVersion | Should -BeNullOrEmpty
        $agnosticRepo.selectedVersion | Should -BeNullOrEmpty
    }

    It 'includes error messages when failures occur' {
        & (Get-Module LsiGitCheckout) {
            $script:FailureCount = 1
            $script:ErrorMessages = @('Repository clone failed', 'Tag not found')
        }

        $outputFile = Join-Path $TestDrive 'result.json'
        Export-CheckoutResults -OutputFile $outputFile

        $result = Get-Content $outputFile -Raw | ConvertFrom-Json
        $result.summary.success | Should -Be $false
        $result.errors.Count | Should -Be 2
        $result.errors[0] | Should -Be 'Repository clone failed'
    }

    It 'handles empty repository dictionary' {
        & (Get-Module LsiGitCheckout) {
            $script:RepositoryDictionary = @{}
            $script:SuccessCount = 0
            $script:ProcessedDependencyFiles = @()
        }

        $outputFile = Join-Path $TestDrive 'result.json'
        Export-CheckoutResults -OutputFile $outputFile

        $result = Get-Content $outputFile -Raw | ConvertFrom-Json
        $result.repositories.Count | Should -Be 0
        $result.summary.totalRepositories | Should -Be 0
    }

    It 'includes requestedBy field for each repository' {
        $outputFile = Join-Path $TestDrive 'result.json'
        Export-CheckoutResults -OutputFile $outputFile

        $result = Get-Content $outputFile -Raw | ConvertFrom-Json
        foreach ($repo in $result.repositories) {
            $repo.requestedBy | Should -Not -BeNullOrEmpty -Because "every repo should have a requestedBy"
            $repo.requestedBy | Should -Contain 'root-dependency-file'
        }
    }

    It 'includes postCheckoutScript field when script was tracked' {
        & (Get-Module LsiGitCheckout) {
            $script:RepositoryDictionary['https://github.com/org/repoA.git'].PostCheckoutScript = @{
                Configured = $true
                ScriptPath = 'C:\test\repo-a\post-checkout.ps1'
                Found      = $true
                Executed   = $false
                Status     = 'skipped'
                Reason     = 'Disabled globally via -DisablePostCheckoutScripts'
            }
        }

        $outputFile = Join-Path $TestDrive 'result.json'
        Export-CheckoutResults -OutputFile $outputFile

        $result = Get-Content $outputFile -Raw | ConvertFrom-Json
        $repoWithScript = $result.repositories | Where-Object { $_.url -eq 'https://github.com/org/repoA.git' }
        $repoWithScript.postCheckoutScript | Should -Not -BeNullOrEmpty
        $repoWithScript.postCheckoutScript.configured | Should -Be $true
        $repoWithScript.postCheckoutScript.found | Should -Be $true
        $repoWithScript.postCheckoutScript.executed | Should -Be $false
        $repoWithScript.postCheckoutScript.status | Should -Be 'skipped'
        $repoWithScript.postCheckoutScript.reason | Should -Be 'Disabled globally via -DisablePostCheckoutScripts'
    }

    It 'sets postCheckoutScript to null when no script configured' {
        $outputFile = Join-Path $TestDrive 'result.json'
        Export-CheckoutResults -OutputFile $outputFile

        $result = Get-Content $outputFile -Raw | ConvertFrom-Json
        $repoWithout = $result.repositories | Where-Object { $_.url -eq 'https://github.com/org/repoB.git' }
        $repoWithout.postCheckoutScript | Should -BeNullOrEmpty
    }

    It 'includes rootPostCheckoutScripts for depth-0 scripts' {
        & (Get-Module LsiGitCheckout) {
            $script:PostCheckoutScriptResults = @(
                @{
                    Configured    = $true
                    ScriptPath    = 'C:\test\build\config\post-checkout.ps1'
                    Found         = $false
                    Executed      = $false
                    Status        = 'skipped'
                    Reason        = 'Disabled globally via -DisablePostCheckoutScripts'
                    RepositoryUrl = ''
                }
            )
        }

        $outputFile = Join-Path $TestDrive 'result.json'
        Export-CheckoutResults -OutputFile $outputFile

        $result = Get-Content $outputFile -Raw | ConvertFrom-Json
        $result.rootPostCheckoutScripts.Count | Should -Be 1
        $result.rootPostCheckoutScripts[0].configured | Should -Be $true
        $result.rootPostCheckoutScripts[0].status | Should -Be 'skipped'
    }
}

Describe 'Test-SshTransportAvailable' {
    It 'returns true when ssh is available on this system' {
        # On macOS/Linux, ssh should always be present
        if (-not $IsWindows) {
            Test-SshTransportAvailable | Should -Be $true
        } else {
            Set-ItResult -Skipped -Because 'this test validates OpenSSH availability on Unix'
        }
    }
}

Describe 'Set-GitSshKey' {
    BeforeAll {
        # Create a temporary OpenSSH key for testing (no passphrase)
        $script:testKeyPath = Join-Path $TestDrive 'test_key'
        ssh-keygen -t ed25519 -f $script:testKeyPath -N '""' -q 2>$null
        if (-not (Test-Path $script:testKeyPath)) {
            # Fallback: create a fake OpenSSH-format key file
            Set-Content -Path $script:testKeyPath -Value "-----BEGIN OPENSSH PRIVATE KEY-----`ntest`n-----END OPENSSH PRIVATE KEY-----"
        }

        # Create a fake PuTTY key for rejection testing
        $script:testPuttyKeyPath = Join-Path $TestDrive 'test_key.ppk'
        Set-Content -Path $script:testPuttyKeyPath -Value "PuTTY-User-Key-File-3: ssh-ed25519`nfake-putty-key-content"
    }

    Context 'OpenSSH path (macOS/Linux)' {
        BeforeAll {
            if ($IsWindows) {
                $script:skipUnix = $true
            }
        }

        It 'configures GIT_SSH_COMMAND with explicit key path' {
            if ($script:skipUnix) {
                Set-ItResult -Skipped -Because 'OpenSSH tests only run on macOS/Linux'
                return
            }

            # Save and clear env vars
            $originalSshCmd = $env:GIT_SSH_COMMAND
            $originalSsh = $env:GIT_SSH
            $env:GIT_SSH_COMMAND = $null
            $env:GIT_SSH = $null

            try {
                $result = Set-GitSshKey -SshKeyPath $script:testKeyPath
                $result | Should -Be $true
                $env:GIT_SSH_COMMAND | Should -BeLike "ssh -i *test_key* -o IdentitiesOnly=yes"
                $env:GIT_SSH | Should -BeNullOrEmpty
            }
            finally {
                $env:GIT_SSH_COMMAND = $originalSshCmd
                $env:GIT_SSH = $originalSsh
            }
        }

        It 'rejects PuTTY format keys' {
            if ($script:skipUnix) {
                Set-ItResult -Skipped -Because 'OpenSSH tests only run on macOS/Linux'
                return
            }

            $result = Set-GitSshKey -SshKeyPath $script:testPuttyKeyPath
            $result | Should -Be $false
        }

        It 'returns false for non-existent key file' {
            $result = Set-GitSshKey -SshKeyPath (Join-Path $TestDrive 'nonexistent_key')
            $result | Should -Be $false
        }
    }

    Context 'Permission check (macOS/Linux)' {
        It 'warns on overly permissive key file' {
            if ($IsWindows) {
                Set-ItResult -Skipped -Because 'Unix permission tests only run on macOS/Linux'
                return
            }

            # Make key world-readable
            chmod 644 $script:testKeyPath

            # Save env
            $originalSshCmd = $env:GIT_SSH_COMMAND
            $env:GIT_SSH_COMMAND = $null

            try {
                # Should still succeed but produce a warning
                $result = Set-GitSshKey -SshKeyPath $script:testKeyPath
                $result | Should -Be $true
            }
            finally {
                chmod 600 $script:testKeyPath
                $env:GIT_SSH_COMMAND = $originalSshCmd
            }
        }
    }
}
