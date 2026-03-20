#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

<#
.SYNOPSIS
    Integration tests for LsiGitCheckout - runs the script against all test configs
.DESCRIPTION
    Executes LsiGitCheckout.ps1 against each of the 16 test JSON configs and asserts
    the expected exit code and structured JSON output. Tests perform actual git clones
    with recursive dependency processing to exercise the full checkout flow including
    API compatibility checks. Requires network access to GitHub test repos.

    Run with: Invoke-Pester ./tests/LsiGitCheckout.Integration.Tests.ps1 -Output Detailed
    Skip with: Use -ExcludeTag 'Integration' to skip when no network is available
#>

BeforeDiscovery {
    $script:ScriptRoot = Split-Path $PSScriptRoot -Parent
    $script:TestConfigDir = Join-Path $script:ScriptRoot 'tests'

    # Test matrix: config filename -> expected exit code and repository count
    # All test configs are named dependencies.json in subdirectories so the filename
    # propagates correctly through all recursive depth levels.
    # ExpectedRepos = total unique repositories discovered across all depth levels.
    $script:TestCases = @(
        # SemVer mode tests - expected to succeed
        @{ Config = 'semver-basic/dependencies.json';                         ExpectedExit = 0; ExpectedRepos = 5; Mode = 'SemVer';   HasRootScript = $false; Label = 'SemVer basic' }
        @{ Config = 'semver-floating-versions/dependencies.json';             ExpectedExit = 0; ExpectedRepos = 5; Mode = 'SemVer';   HasRootScript = $false; Label = 'SemVer floating versions' }
        @{ Config = 'semver-floating-versions-2/dependencies.json';           ExpectedExit = 0; ExpectedRepos = 5; Mode = 'SemVer';   HasRootScript = $false; Label = 'SemVer floating versions 2' }
        @{ Config = 'semver-custom-dep-path-1/dependencies.json';             ExpectedExit = 0; ExpectedRepos = 5; Mode = 'SemVer';   HasRootScript = $false; Label = 'SemVer custom dep path 1' }
        @{ Config = 'semver-custom-dep-path-2/dependencies.json';             ExpectedExit = 0; ExpectedRepos = 5; Mode = 'SemVer';   HasRootScript = $false; Label = 'SemVer custom dep path 2' }
        @{ Config = 'semver-post-checkout-scripts/dependencies.json';         ExpectedExit = 0; ExpectedRepos = 5; Mode = 'SemVer';   HasRootScript = $false; Label = 'SemVer post-checkout scripts' }
        @{ Config = 'semver-post-checkout-scripts-2/dependencies.json';       ExpectedExit = 0; ExpectedRepos = 5; Mode = 'SemVer';   HasRootScript = $false; Label = 'SemVer post-checkout scripts 2' }
        @{ Config = 'semver-post-checkout-scripts-depth-0/dependencies.json'; ExpectedExit = 0; ExpectedRepos = 5; Mode = 'SemVer';   HasRootScript = $true;  Label = 'SemVer post-checkout depth 0' }

        # Agnostic mode tests - expected to succeed
        @{ Config = 'agnostic-recursive/dependencies.json';                   ExpectedExit = 0; ExpectedRepos = 5; Mode = 'Agnostic'; HasRootScript = $false; Label = 'Agnostic recursive' }
        @{ Config = 'agnostic-custom-dep-path/dependencies.json';             ExpectedExit = 0; ExpectedRepos = 5; Mode = 'Agnostic'; HasRootScript = $false; Label = 'Agnostic custom dep path' }
        @{ Config = 'agnostic-partial-api-overlap/dependencies.json';         ExpectedExit = 0; ExpectedRepos = 5; Mode = 'Agnostic'; HasRootScript = $false; Label = 'Agnostic partial API overlap' }
        @{ Config = 'agnostic-post-checkout-scripts/dependencies.json';       ExpectedExit = 0; ExpectedRepos = 5; Mode = 'Agnostic'; HasRootScript = $false; Label = 'Agnostic post-checkout scripts' }
        @{ Config = 'agnostic-post-checkout-scripts-2/dependencies.json';     ExpectedExit = 0; ExpectedRepos = 5; Mode = 'Agnostic'; HasRootScript = $false; Label = 'Agnostic post-checkout scripts 2' }
        @{ Config = 'agnostic-post-checkout-scripts-depth-0/dependencies.json'; ExpectedExit = 0; ExpectedRepos = 5; Mode = 'Agnostic'; HasRootScript = $true;  Label = 'Agnostic post-checkout depth 0' }

        # API incompatibility tests - Permissive resolves Agnostic conflicts; Strict rejects them.
        @{ Config = 'api-incompatibility-agnostic/dependencies.json';         ExpectedExit = 0; ExpectedRepos = 5; Mode = 'Agnostic'; HasRootScript = $false; ApiMode = 'Permissive'; Label = 'Agnostic API incompatibility (Permissive)' }
        @{ Config = 'api-incompatibility-agnostic/dependencies.json';         ExpectedExit = 1; ExpectedRepos = 5; Mode = 'Agnostic'; HasRootScript = $false; ApiMode = 'Strict';     Label = 'Agnostic API incompatibility (Strict)' }
        @{ Config = 'api-incompatibility-semver/dependencies.json';           ExpectedExit = 1; ExpectedRepos = 5; Mode = 'SemVer';   HasRootScript = $false; ApiMode = 'Permissive'; Label = 'SemVer API incompatibility' }
    )
}

Describe 'LsiGitCheckout Integration Tests' -Tag 'Integration' {
    BeforeAll {
        $script:ScriptRoot = Split-Path $PSScriptRoot -Parent
        $script:ScriptPath = Join-Path $script:ScriptRoot 'LsiGitCheckout.ps1'
        $script:TestConfigDir = Join-Path $script:ScriptRoot 'tests'

        # Verify the script exists
        $script:ScriptPath | Should -Exist
    }

    BeforeEach {
        # Clean up cloned test repositories to ensure each test starts fresh
        # Repos are cloned inside each test's subdirectory
        $cleanupPatterns = @('test-root-a', 'test-root-b', 'libs')
        $testSubDirs = Get-ChildItem -Path $script:TestConfigDir -Directory |
            Where-Object { Test-Path (Join-Path $_.FullName 'dependencies.json') }
        foreach ($subDir in $testSubDirs) {
            foreach ($pattern in $cleanupPatterns) {
                $dir = Join-Path $subDir.FullName $pattern
                if (Test-Path $dir) {
                    Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    It '<Label> (<Config>) exits with code <ExpectedExit>' -TestCases $script:TestCases {
        param($Config, $ExpectedExit, $ExpectedRepos, $Mode, $HasRootScript, $ApiMode, $Label)

        $configPath = Join-Path $script:TestConfigDir $Config
        $configPath | Should -Exist

        # Write JSON output to Pester's auto-cleaned temp directory
        $outputJson = Join-Path $TestDrive ("result_{0}.json" -f ($Config -replace '[^a-zA-Z0-9]', '_'))

        # Run the script as a child process — no DryRun so recursive checkout is exercised
        $scriptArgs = @(
            '-NoProfile', '-NonInteractive', '-File', $script:ScriptPath,
            '-InputFile', $configPath,
            '-OutputFile', $outputJson,
            '-DisablePostCheckoutScripts'
        )
        if ($ApiMode) {
            $scriptArgs += @('-ApiCompatibility', $ApiMode)
        }
        $output = & pwsh @scriptArgs 2>&1
        $actualExit = $LASTEXITCODE

        # Validate exit code
        $actualExit | Should -Be $ExpectedExit -Because (
            "Config '$Config' should exit $ExpectedExit but got $actualExit.`n" +
            "Output (last 20 lines):`n$($output | Select-Object -Last 20 | Out-String)"
        )

        # Validate structured JSON output
        $outputJson | Should -Exist -Because "JSON output file should be written"
        $result = Get-Content $outputJson -Raw | ConvertFrom-Json

        # Schema version
        $result.schemaVersion | Should -Be '1.0.0'

        # Metadata
        $result.metadata.toolVersion | Should -Be '8.0.0'
        $result.metadata.recursiveMode | Should -Be $true
        $result.metadata.apiCompatibility | Should -BeIn @('Strict', 'Permissive')
        $result.metadata.powershellVersion | Should -Not -BeNullOrEmpty

        # Summary
        $result.summary.success | Should -Be ($ExpectedExit -eq 0) -Because "summary.success should match exit code"
        $result.summary.totalRepositories | Should -Be $ExpectedRepos -Because "should have exactly $ExpectedRepos unique repositories"

        # Repositories array
        $result.repositories | Should -Not -BeNullOrEmpty -Because "should have repository entries"
        foreach ($repo in $result.repositories) {
            $repo.url | Should -Not -BeNullOrEmpty
            $repo.path | Should -Not -BeNullOrEmpty
            $repo.dependencyResolution | Should -BeIn @('SemVer', 'Agnostic')
            $repo.status | Should -BeIn @('success', 'failed', 'skipped')
            $repo.requestedBy | Should -Not -BeNullOrEmpty -Because "every repo should have a requestedBy"
        }

        # Mode-specific validations
        if ($Mode -eq 'SemVer') {
            $semVerRepos = $result.repositories | Where-Object { $_.dependencyResolution -eq 'SemVer' }
            $semVerRepos | Should -Not -BeNullOrEmpty -Because "SemVer test should have SemVer repositories"
            foreach ($repo in $semVerRepos) {
                $repo.tag | Should -Not -BeNullOrEmpty -Because "SemVer repo should have a selected tag"
                $repo.selectedVersion | Should -Not -BeNullOrEmpty -Because "SemVer repo should have a selected version"
            }
        }

        # Processed dependency files
        $result.processedDependencyFiles | Should -Not -BeNullOrEmpty -Because "at least one dependency file should be processed"

        # Post-checkout script tracking
        $result.summary.postCheckoutScripts.enabled | Should -Be $false -Because "tests run with -DisablePostCheckoutScripts"

        if ($HasRootScript) {
            $result.rootPostCheckoutScripts | Should -Not -BeNullOrEmpty -Because "depth-0 config declares a post-checkout script"
            foreach ($pcs in $result.rootPostCheckoutScripts) {
                $pcs.configured | Should -Be $true
                $pcs.status | Should -Be 'skipped'
                $pcs.reason | Should -Be 'Disabled globally via -DisablePostCheckoutScripts'
            }
        }

        # Errors array should be empty for successful tests
        if ($ExpectedExit -eq 0) {
            $result.errors.Count | Should -Be 0 -Because "successful run should have no errors"
        }
    }
}
