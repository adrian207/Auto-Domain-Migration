<#
.SYNOPSIS
    Quick Start - Sets up and runs the Integration Test Suite
.DESCRIPTION
    One-command setup and test execution for the Auto Domain Migration test suite
.NOTES
    Must be run as Administrator for first-time setup
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$SkipSetup,
    
    [Parameter()]
    [ValidateSet("Fast", "Unit", "Integration", "All")]
    [string]$TestSuite = "Fast"
)

Write-Host @"

╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║          🧪 Integration Test Suite - Quick Start                    ║
║                                                                      ║
║          Auto Domain Migration Solution v4.0                        ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin -and -not $SkipSetup) {
    Write-Host "⚠️  Not running as Administrator" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "For first-time setup, you need Administrator rights." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Cyan
    Write-Host "  1. Right-click PowerShell → Run as Administrator" -ForegroundColor Gray
    Write-Host "  2. Run this script again" -ForegroundColor Gray
    Write-Host "  3. Or run with -SkipSetup to skip prerequisites" -ForegroundColor Gray
    Write-Host ""
    
    $response = Read-Host "Continue without setup? (yes/no)"
    if ($response -ne "yes") {
        Write-Host "Exiting. Please re-run as Administrator." -ForegroundColor Yellow
        exit 1
    }
    $SkipSetup = $true
}

# Step 1: Check Prerequisites
Write-Host "📋 Step 1: Checking Prerequisites..." -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Gray

# Check PowerShell version
$psVersion = $PSVersionTable.PSVersion
Write-Host "PowerShell Version: $($psVersion.Major).$($psVersion.Minor).$($psVersion.Build)" -ForegroundColor Gray

if ($psVersion.Major -lt 5) {
    Write-Host "❌ PowerShell 5.0+ required. Current: $psVersion" -ForegroundColor Red
    exit 1
}
Write-Host "✅ PowerShell version OK" -ForegroundColor Green

# Check Pester
$pester = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge [Version]"5.0.0" } | Select-Object -First 1

if (-not $pester -and -not $SkipSetup) {
    Write-Host "📦 Installing Pester 5.x..." -ForegroundColor Yellow
    
    try {
        # Install NuGet provider
        Write-Host "  Installing NuGet provider..." -ForegroundColor Gray
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction Stop | Out-Null
        
        # Trust PSGallery
        Write-Host "  Trusting PSGallery..." -ForegroundColor Gray
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
        
        # Install Pester
        Write-Host "  Installing Pester module..." -ForegroundColor Gray
        Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser -SkipPublisherCheck -ErrorAction Stop
        
        Write-Host "✅ Pester installed successfully" -ForegroundColor Green
        
        # Reload
        $pester = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge [Version]"5.0.0" } | Select-Object -First 1
    } catch {
        Write-Host "❌ Failed to install Pester: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Manual installation:" -ForegroundColor Yellow
        Write-Host "  Install-Module -Name Pester -MinimumVersion 5.0.0 -Force" -ForegroundColor Gray
        exit 1
    }
}

if ($pester) {
    Write-Host "✅ Pester $($pester.Version) installed" -ForegroundColor Green
} else {
    Write-Host "⚠️  Pester not installed - tests may not run" -ForegroundColor Yellow
}

Write-Host ""

# Step 2: Create Test Directories
Write-Host "📁 Step 2: Creating Test Directories..." -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Gray

$directories = @(
    "C:\ADMT\Batches",
    "C:\ADMT\Logs",
    "C:\ADMT\Reports",
    "C:\Temp\FileServerTest",
    "$PSScriptRoot\TestResults"
)

foreach ($dir in $directories) {
    try {
        if (-not (Test-Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Write-Host "  Created: $dir" -ForegroundColor Gray
        } else {
            Write-Host "  Exists: $dir" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  ⚠️  Could not create: $dir" -ForegroundColor Yellow
    }
}

Write-Host "✅ Test directories ready" -ForegroundColor Green
Write-Host ""

# Step 3: Verify Test Files
Write-Host "📄 Step 3: Verifying Test Files..." -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Gray

$testFiles = @(
    "$PSScriptRoot\infrastructure\Test-AzureInfrastructure.Tests.ps1",
    "$PSScriptRoot\integration\Test-ADMTMigration.Tests.ps1",
    "$PSScriptRoot\integration\Test-FileServerMigration.Tests.ps1",
    "$PSScriptRoot\e2e\Test-EndToEndMigration.Tests.ps1"
)

$missingFiles = @()
foreach ($file in $testFiles) {
    if (Test-Path $file) {
        $fileName = Split-Path $file -Leaf
        Write-Host "  ✅ $fileName" -ForegroundColor Green
    } else {
        $fileName = Split-Path $file -Leaf
        Write-Host "  ❌ $fileName (missing)" -ForegroundColor Red
        $missingFiles += $fileName
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "❌ Missing test files. Cannot proceed." -ForegroundColor Red
    exit 1
}

Write-Host "✅ All test files found" -ForegroundColor Green
Write-Host ""

# Step 4: Run Tests
Write-Host "🧪 Step 4: Running Tests ($TestSuite suite)..." -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Gray
Write-Host ""

$testScript = Join-Path $PSScriptRoot "scripts\Invoke-AllTests.ps1"

if (-not (Test-Path $testScript)) {
    Write-Host "❌ Test runner not found: $testScript" -ForegroundColor Red
    exit 1
}

try {
    # Run the test suite
    & $testScript -TestSuite $TestSuite -Verbosity Normal -GenerateReport
    
    $exitCode = $LASTEXITCODE
    
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                                                                      ║" -ForegroundColor Cyan
    
    if ($exitCode -eq 0) {
        Write-Host "║                    ✅ ALL TESTS PASSED! 🎉                          ║" -ForegroundColor Green
    } else {
        Write-Host "║                    ❌ SOME TESTS FAILED                             ║" -ForegroundColor Red
    }
    
    Write-Host "║                                                                      ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    # Show test results location
    $resultsPath = Join-Path $PSScriptRoot "TestResults"
    if (Test-Path $resultsPath) {
        Write-Host "📊 Test Results:" -ForegroundColor Cyan
        Write-Host "  Location: $resultsPath" -ForegroundColor Gray
        
        $htmlReports = Get-ChildItem -Path $resultsPath -Filter "*.html" -ErrorAction SilentlyContinue | 
                       Sort-Object LastWriteTime -Descending | 
                       Select-Object -First 1
        
        if ($htmlReports) {
            Write-Host "  HTML Report: $($htmlReports.Name)" -ForegroundColor Gray
            Write-Host ""
            Write-Host "  Opening HTML report in browser..." -ForegroundColor Yellow
            Start-Process $htmlReports.FullName
        }
        
        Write-Host ""
    }
    
    exit $exitCode
    
} catch {
    Write-Host ""
    Write-Host "❌ Error running tests: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}

