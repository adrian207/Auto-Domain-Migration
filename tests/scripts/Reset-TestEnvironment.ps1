<#
.SYNOPSIS
    Resets test environment to clean state
.DESCRIPTION
    Cleans up test data, batches, and temporary files from previous test runs
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$IncludeAzure,
    
    [Parameter()]
    [switch]$IncludeAD,
    
    [Parameter()]
    [switch]$Force,
    
    [Parameter()]
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Test Environment Reset" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Clean up ADMT test batches
Write-Host "Cleaning ADMT test batches..." -ForegroundColor Yellow

$admtPaths = @(
    "C:\ADMT\Batches"
    "C:\ADMT\Reports"
    "C:\ADMT\Logs"
)

foreach ($path in $admtPaths) {
    if (Test-Path $path) {
        $testFiles = Get-ChildItem -Path $path -Filter "*Test*" -File -ErrorAction SilentlyContinue
        
        foreach ($file in $testFiles) {
            if ($WhatIf) {
                Write-Host "  Would remove: $($file.FullName)" -ForegroundColor Gray
            } else {
                Remove-Item $file.FullName -Force
                Write-Host "  Removed: $($file.Name)" -ForegroundColor Green
            }
        }
    }
}

# Clean up file server test data
Write-Host "`nCleaning file server test data..." -ForegroundColor Yellow

$fileTestPaths = @(
    "C:\Temp\FileServerTest"
    "C:\Shares\Test"
)

foreach ($path in $fileTestPaths) {
    if (Test-Path $path) {
        if ($WhatIf) {
            Write-Host "  Would remove: $path" -ForegroundColor Gray
        } else {
            Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  Removed: $path" -ForegroundColor Green
        }
    }
}

# Clean up test results
Write-Host "`nCleaning test results..." -ForegroundColor Yellow

$testResultsPath = Join-Path $PSScriptRoot "..\TestResults"
if (Test-Path $testResultsPath) {
    $oldResults = Get-ChildItem -Path $testResultsPath -Filter "*.xml" | 
                  Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) }
    
    foreach ($result in $oldResults) {
        if ($WhatIf) {
            Write-Host "  Would remove: $($result.Name)" -ForegroundColor Gray
        } else {
            Remove-Item $result.FullName -Force
            Write-Host "  Removed: $($result.Name)" -ForegroundColor Green
        }
    }
}

# Clean up Active Directory test data
if ($IncludeAD) {
    Write-Host "`nCleaning Active Directory test data..." -ForegroundColor Yellow
    
    if (-not $Force) {
        $confirm = Read-Host "This will remove test users, computers, and groups from AD. Continue? (yes/no)"
        if ($confirm -ne "yes") {
            Write-Host "  Skipped AD cleanup" -ForegroundColor Yellow
            $IncludeAD = $false
        }
    }
    
    if ($IncludeAD) {
        try {
            Import-Module ActiveDirectory -ErrorAction Stop
            
            # Remove test OUs (this will remove all contained objects)
            $testOUs = @("OU=Test,DC=source,DC=local", "OU=Tier1,DC=source,DC=local")
            
            foreach ($ou in $testOUs) {
                if ($WhatIf) {
                    Write-Host "  Would remove OU: $ou" -ForegroundColor Gray
                } else {
                    try {
                        # Enable recursive deletion
                        Set-ADObject -Identity $ou -ProtectedFromAccidentalDeletion $false -ErrorAction SilentlyContinue
                        Remove-ADOrganizationalUnit -Identity $ou -Recursive -Confirm:$false -ErrorAction SilentlyContinue
                        Write-Host "  Removed OU: $ou" -ForegroundColor Green
                    } catch {
                        Write-Host "  Could not remove OU: $ou ($($_.Exception.Message))" -ForegroundColor Yellow
                    }
                }
            }
            
        } catch {
            Write-Host "  AD cleanup failed: $_" -ForegroundColor Red
        }
    }
}

# Clean up Azure test resources
if ($IncludeAzure) {
    Write-Host "`nCleaning Azure test resources..." -ForegroundColor Yellow
    
    if (-not $Force) {
        $confirm = Read-Host "This will remove Azure test resources. Continue? (yes/no)"
        if ($confirm -ne "yes") {
            Write-Host "  Skipped Azure cleanup" -ForegroundColor Yellow
            $IncludeAzure = $false
        }
    }
    
    if ($IncludeAzure) {
        try {
            Import-Module Az.Accounts -ErrorAction Stop
            
            $context = Get-AzContext -ErrorAction SilentlyContinue
            if (-not $context) {
                Write-Host "  Not authenticated to Azure. Skipping..." -ForegroundColor Yellow
            } else {
                # Find test resource groups
                $testRGs = Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -like "*test*" -or $_.Tags["Purpose"] -eq "Testing" }
                
                foreach ($rg in $testRGs) {
                    if ($WhatIf) {
                        Write-Host "  Would remove RG: $($rg.ResourceGroupName)" -ForegroundColor Gray
                    } else {
                        Write-Host "  Removing RG: $($rg.ResourceGroupName)..." -ForegroundColor Yellow
                        Remove-AzResourceGroup -Name $rg.ResourceGroupName -Force -AsJob | Out-Null
                        Write-Host "  Removal started (background job): $($rg.ResourceGroupName)" -ForegroundColor Green
                    }
                }
            }
        } catch {
            Write-Host "  Azure cleanup failed: $_" -ForegroundColor Red
        }
    }
}

# Clean up temporary Pester files
Write-Host "`nCleaning Pester temporary files..." -ForegroundColor Yellow

$tempFiles = Get-ChildItem -Path $env:TEMP -Filter "Pester*" -ErrorAction SilentlyContinue
foreach ($file in $tempFiles) {
    if ($WhatIf) {
        Write-Host "  Would remove: $($file.Name)" -ForegroundColor Gray
    } else {
        Remove-Item $file.FullName -Force -Recurse -ErrorAction SilentlyContinue
        Write-Host "  Removed: $($file.Name)" -ForegroundColor Green
    }
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Reset Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($WhatIf) {
    Write-Host "`n⚠️ This was a dry run. Use without -WhatIf to actually remove files." -ForegroundColor Yellow
} else {
    Write-Host "`n✅ Test environment has been reset" -ForegroundColor Green
}

Write-Host "`nOptions used:" -ForegroundColor Gray
Write-Host "  Include Azure: $IncludeAzure" -ForegroundColor Gray
Write-Host "  Include AD: $IncludeAD" -ForegroundColor Gray
Write-Host "  Force: $Force" -ForegroundColor Gray
Write-Host "  WhatIf: $WhatIf`n" -ForegroundColor Gray

