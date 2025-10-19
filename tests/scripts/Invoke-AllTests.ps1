<#
.SYNOPSIS
    Master test runner for all integration tests
.DESCRIPTION
    Executes all test suites and generates comprehensive reports
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet("All", "Unit", "Integration", "E2E", "Infrastructure", "Fast", "Slow")]
    [string]$TestSuite = "All",
    
    [Parameter()]
    [string]$OutputPath = ".\TestResults",
    
    [Parameter()]
    [switch]$GenerateReport,
    
    [Parameter()]
    [switch]$FailFast,
    
    [Parameter()]
    [ValidateSet("Detailed", "Normal", "Minimal")]
    [string]$Verbosity = "Normal"
)

#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.0.0" }

$ErrorActionPreference = "Stop"

# Configuration
$script:TestConfig = @{
    RootPath = Split-Path $PSScriptRoot -Parent
    OutputPath = $OutputPath
    Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
}

# Ensure output directory exists
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Integration Test Suite Runner" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Suite: $TestSuite" -ForegroundColor Yellow
Write-Host "Output: $OutputPath" -ForegroundColor Yellow
Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Cyan

# Define test categories
$testCategories = @{
    Unit = @{
        Path = Join-Path $TestConfig.RootPath "integration\Test-ADMTMigration.Tests.ps1"
        Tags = @("Unit", "Module")
        Description = "ADMT module unit tests"
    }
    Integration = @{
        Path = @(
            Join-Path $TestConfig.RootPath "integration\Test-ADMTMigration.Tests.ps1"
            Join-Path $TestConfig.RootPath "integration\Test-FileServerMigration.Tests.ps1"
        )
        Tags = @("Integration")
        Description = "Integration tests for ADMT and file servers"
    }
    Infrastructure = @{
        Path = Join-Path $TestConfig.RootPath "infrastructure\Test-AzureInfrastructure.Tests.ps1"
        Tags = @("Infrastructure")
        Description = "Azure infrastructure validation"
    }
    E2E = @{
        Path = Join-Path $TestConfig.RootPath "e2e\Test-EndToEndMigration.Tests.ps1"
        Tags = @("E2E")
        Description = "End-to-end workflow tests"
    }
    Fast = @{
        Path = $null  # Uses tags
        Tags = @("Unit", "Module", "Validation")
        Description = "Fast tests (< 5 min)"
    }
    Slow = @{
        Path = $null  # Uses tags
        Tags = @("E2E", "Performance", "Slow")
        Description = "Slow tests (> 5 min)"
    }
}

function Invoke-TestCategory {
    param(
        [string]$CategoryName,
        [hashtable]$Category
    )
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  Running: $CategoryName Tests" -ForegroundColor Cyan
    Write-Host "  $($Category.Description)" -ForegroundColor Gray
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    # Configure Pester
    $config = New-PesterConfiguration
    
    if ($Category.Path) {
        $config.Run.Path = $Category.Path
    } else {
        # Use root test directory
        $config.Run.Path = $TestConfig.RootPath
    }
    
    $config.Run.PassThru = $true
    $config.Filter.Tag = $Category.Tags
    
    # Output settings
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputPath = Join-Path $OutputPath "$CategoryName-results-$($TestConfig.Timestamp).xml"
    $config.TestResult.OutputFormat = "NUnitXml"
    
    # Code coverage
    if ($CategoryName -eq "Unit" -or $CategoryName -eq "Integration") {
        $config.CodeCoverage.Enabled = $true
        $config.CodeCoverage.Path = @(
            Join-Path (Split-Path $TestConfig.RootPath) "ansible\files\*.psm1"
            Join-Path (Split-Path $TestConfig.RootPath) "scripts\**\*.ps1"
        )
        $config.CodeCoverage.OutputPath = Join-Path $OutputPath "$CategoryName-coverage-$($TestConfig.Timestamp).xml"
    }
    
    # Verbosity
    switch ($Verbosity) {
        "Detailed" { $config.Output.Verbosity = "Detailed" }
        "Normal" { $config.Output.Verbosity = "Normal" }
        "Minimal" { $config.Output.Verbosity = "Minimal" }
    }
    
    # Run tests
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $result = Invoke-Pester -Configuration $config
    $stopwatch.Stop()
    
    # Display results
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  $CategoryName Test Results" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Total Tests: $($result.TotalCount)"
    Write-Host "Passed: $($result.PassedCount)" -ForegroundColor Green
    Write-Host "Failed: $($result.FailedCount)" -ForegroundColor $(if ($result.FailedCount -gt 0) { "Red" } else { "Green" })
    Write-Host "Skipped: $($result.SkippedCount)" -ForegroundColor Yellow
    Write-Host "Duration: $($stopwatch.Elapsed.ToString('mm\:ss'))"
    
    if ($result.CodeCoverage) {
        $coverage = [math]::Round($result.CodeCoverage.CoveragePercent, 2)
        Write-Host "Code Coverage: $coverage%" -ForegroundColor Cyan
    }
    
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    # Fail fast if requested
    if ($FailFast -and $result.FailedCount -gt 0) {
        throw "$CategoryName tests failed with $($result.FailedCount) failure(s)"
    }
    
    return $result
}

# Main execution
$allResults = @{}
$startTime = Get-Date

try {
    if ($TestSuite -eq "All") {
        # Run all test categories
        foreach ($category in @("Unit", "Integration", "Infrastructure", "E2E")) {
            if ($testCategories.ContainsKey($category)) {
                $allResults[$category] = Invoke-TestCategory -CategoryName $category -Category $testCategories[$category]
            }
        }
    } else {
        # Run specific suite
        if ($testCategories.ContainsKey($TestSuite)) {
            $allResults[$TestSuite] = Invoke-TestCategory -CategoryName $TestSuite -Category $testCategories[$TestSuite]
        } else {
            throw "Unknown test suite: $TestSuite"
        }
    }
    
    # Generate summary report
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  OVERALL TEST SUMMARY" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    $totalTests = 0
    $totalPassed = 0
    $totalFailed = 0
    $totalSkipped = 0
    
    foreach ($category in $allResults.Keys) {
        $result = $allResults[$category]
        $totalTests += $result.TotalCount
        $totalPassed += $result.PassedCount
        $totalFailed += $result.FailedCount
        $totalSkipped += $result.SkippedCount
        
        $status = if ($result.FailedCount -eq 0) { "✅" } else { "❌" }
        Write-Host "$status $category : $($result.PassedCount)/$($result.TotalCount) passed" -ForegroundColor $(if ($result.FailedCount -eq 0) { "Green" } else { "Red" })
    }
    
    Write-Host "`n----------------------------------------" -ForegroundColor Cyan
    Write-Host "Total Tests: $totalTests"
    Write-Host "Passed: $totalPassed" -ForegroundColor Green
    Write-Host "Failed: $totalFailed" -ForegroundColor $(if ($totalFailed -gt 0) { "Red" } else { "Green" })
    Write-Host "Skipped: $totalSkipped" -ForegroundColor Yellow
    
    $duration = (Get-Date) - $startTime
    Write-Host "Total Duration: $($duration.ToString('hh\:mm\:ss'))"
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    # Generate HTML report if requested
    if ($GenerateReport) {
        Write-Host "Generating HTML report..." -ForegroundColor Yellow
        
        $reportPath = Join-Path $OutputPath "TestReport-$($TestConfig.Timestamp).html"
        
        $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Test Report - $($TestConfig.Timestamp)</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        h1 { color: #0078d4; }
        h2 { color: #106ebe; margin-top: 30px; }
        .summary { background: white; padding: 20px; border-radius: 5px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .category { background: white; padding: 15px; border-radius: 5px; margin-bottom: 15px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .passed { color: #107c10; font-weight: bold; }
        .failed { color: #d13438; font-weight: bold; }
        .skipped { color: #ff8c00; font-weight: bold; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #0078d4; color: white; }
        tr:hover { background: #f5f5f5; }
        .metric { display: inline-block; margin-right: 30px; }
    </style>
</head>
<body>
    <h1>🧪 Integration Test Report</h1>
    <div class="summary">
        <h2>Overall Summary</h2>
        <div class="metric">Total Tests: <strong>$totalTests</strong></div>
        <div class="metric"><span class="passed">Passed: $totalPassed</span></div>
        <div class="metric"><span class="failed">Failed: $totalFailed</span></div>
        <div class="metric"><span class="skipped">Skipped: $totalSkipped</span></div>
        <div class="metric">Duration: <strong>$($duration.ToString('hh\:mm\:ss'))</strong></div>
        <div class="metric">Timestamp: <strong>$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</strong></div>
    </div>
"@
        
        foreach ($category in $allResults.Keys) {
            $result = $allResults[$category]
            $passRate = if ($result.TotalCount -gt 0) { [math]::Round(($result.PassedCount / $result.TotalCount) * 100, 2) } else { 0 }
            
            $html += @"
    <div class="category">
        <h2>$category Tests</h2>
        <div class="metric">Total: <strong>$($result.TotalCount)</strong></div>
        <div class="metric"><span class="passed">Passed: $($result.PassedCount)</span></div>
        <div class="metric"><span class="failed">Failed: $($result.FailedCount)</span></div>
        <div class="metric"><span class="skipped">Skipped: $($result.SkippedCount)</span></div>
        <div class="metric">Pass Rate: <strong>$passRate%</strong></div>
    </div>
"@
        }
        
        $html += @"
    <div class="summary">
        <h2>Test Files</h2>
        <table>
            <tr>
                <th>Category</th>
                <th>Results File</th>
            </tr>
"@
        
        foreach ($category in $allResults.Keys) {
            $resultFile = "$category-results-$($TestConfig.Timestamp).xml"
            $html += @"
            <tr>
                <td>$category</td>
                <td>$resultFile</td>
            </tr>
"@
        }
        
        $html += @"
        </table>
    </div>
</body>
</html>
"@
        
        $html | Out-File $reportPath -Encoding UTF8
        Write-Host "Report generated: $reportPath" -ForegroundColor Green
        
        # Open report in browser
        Start-Process $reportPath
    }
    
    # Exit with appropriate code
    if ($totalFailed -gt 0) {
        Write-Host "❌ Tests FAILED" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "✅ All tests PASSED" -ForegroundColor Green
        exit 0
    }
    
} catch {
    Write-Host "`n❌ Test execution failed: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
