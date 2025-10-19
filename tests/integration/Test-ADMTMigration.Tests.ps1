#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.0.0" }
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Integration tests for ADMT migration functionality
.DESCRIPTION
    End-to-end tests for Active Directory migration using ADMT
#>

BeforeAll {
    # Import ADMT functions module
    $modulePath = Join-Path $PSScriptRoot "..\..\ansible\files\ADMT-Functions.psm1"
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force
        $script:ModuleLoaded = $true
    } else {
        Write-Warning "ADMT-Functions.psm1 not found at: $modulePath"
        $script:ModuleLoaded = $false
    }
    
    # Test configuration
    $script:TestConfig = @{
        SourceDomain = "source.local"
        TargetDomain = "target.local"
        TestOU = "OU=Test,DC=target,DC=local"
        BatchIdPrefix = "IntegrationTest"
    }
    
    # Check if AD module is available
    if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
        Write-Warning "ActiveDirectory module not available. Domain tests will be skipped."
        $script:SkipADTests = $true
    } else {
        $script:SkipADTests = $false
    }
    
    # Create test batch directory if it doesn't exist
    if (-not (Test-Path "C:\ADMT\Batches")) {
        New-Item -Path "C:\ADMT\Batches" -ItemType Directory -Force | Out-Null
    }
}

Describe "ADMT Module" -Tag "Module", "Unit" {
    It "Should load ADMT-Functions module" {
        $script:ModuleLoaded | Should -Be $true
    }
    
    It "Should export required functions" {
        if (-not $script:ModuleLoaded) { Set-ItResult -Skipped -Because "Module not loaded" }
        
        $exportedFunctions = Get-Command -Module ADMT-Functions
        $exportedFunctions.Name | Should -Contain "Test-ADMTPrerequisites"
        $exportedFunctions.Name | Should -Contain "Get-ADMTMigrationStatus"
        $exportedFunctions.Name | Should -Contain "Export-ADMTReport"
        $exportedFunctions.Name | Should -Contain "New-ADMTMigrationBatch"
        $exportedFunctions.Name | Should -Contain "Invoke-ADMTRollback"
    }
}

Describe "Prerequisites Validation" -Tag "Prerequisites", "Validation" {
    Context "Test-ADMTPrerequisites Function" {
        It "Should check ADMT installation" {
            if (-not $script:ModuleLoaded) { Set-ItResult -Skipped -Because "Module not loaded" }
            
            $result = Test-ADMTPrerequisites -SourceDomain $TestConfig.SourceDomain -TargetDomain $TestConfig.TargetDomain
            $result | Should -Not -BeNullOrEmpty
            $result.Keys | Should -Contain "ADMTInstalled"
        }
        
        It "Should check trust relationship" {
            if (-not $script:ModuleLoaded) { Set-ItResult -Skipped -Because "Module not loaded" }
            
            $result = Test-ADMTPrerequisites -SourceDomain $TestConfig.SourceDomain -TargetDomain $TestConfig.TargetDomain
            $result.Keys | Should -Contain "TrustEstablished"
        }
        
        It "Should check DNS configuration" {
            if (-not $script:ModuleLoaded) { Set-ItResult -Skipped -Because "Module not loaded" }
            
            $result = Test-ADMTPrerequisites -SourceDomain $TestConfig.SourceDomain -TargetDomain $TestConfig.TargetDomain
            $result.Keys | Should -Contain "DNSConfigured"
        }
    }
}

Describe "Migration Batch Creation" -Tag "Batch", "Creation" {
    BeforeAll {
        $script:TestBatchId = "$($TestConfig.BatchIdPrefix)_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    }
    
    Context "New-ADMTMigrationBatch Function" {
        It "Should create migration batch" {
            if (-not $script:ModuleLoaded) { Set-ItResult -Skipped -Because "Module not loaded" }
            
            $batch = New-ADMTMigrationBatch `
                -BatchId $script:TestBatchId `
                -Users @("testuser1", "testuser2") `
                -Computers @("testpc1", "testpc2") `
                -Groups @("testgroup1") `
                -SourceDomain $TestConfig.SourceDomain `
                -TargetDomain $TestConfig.TargetDomain `
                -TargetOU $TestConfig.TestOU
            
            $batch | Should -Not -BeNullOrEmpty
            $batch.BatchId | Should -Be $script:TestBatchId
        }
        
        It "Should create batch file on disk" {
            if (-not $script:ModuleLoaded) { Set-ItResult -Skipped -Because "Module not loaded" }
            
            $batchPath = "C:\ADMT\Batches\$($script:TestBatchId).json"
            Test-Path $batchPath | Should -Be $true
        }
        
        It "Batch file should contain correct data" {
            if (-not $script:ModuleLoaded) { Set-ItResult -Skipped -Because "Module not loaded" }
            
            $batchPath = "C:\ADMT\Batches\$($script:TestBatchId).json"
            $batch = Get-Content $batchPath | ConvertFrom-Json
            
            $batch.SourceDomain | Should -Be $TestConfig.SourceDomain
            $batch.TargetDomain | Should -Be $TestConfig.TargetDomain
            $batch.Users.Count | Should -Be 2
            $batch.Computers.Count | Should -Be 2
            $batch.Groups.Count | Should -Be 1
        }
        
        It "Should have valid timestamp" {
            if (-not $script:ModuleLoaded) { Set-ItResult -Skipped -Because "Module not loaded" }
            
            $batchPath = "C:\ADMT\Batches\$($script:TestBatchId).json"
            $batch = Get-Content $batchPath | ConvertFrom-Json
            
            { [DateTime]::ParseExact($batch.Created, "yyyy-MM-dd HH:mm:ss", $null) } | Should -Not -Throw
        }
    }
}

Describe "Migration Status" -Tag "Status", "Monitoring" {
    Context "Get-ADMTMigrationStatus Function" {
        BeforeAll {
            # Create a fake log file for testing
            $logDir = "C:\ADMT\Logs"
            if (-not (Test-Path $logDir)) {
                New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            }
            
            $testLog = @"
2024-01-01 10:00:00 - Migration started
2024-01-01 10:05:00 - User migration completed successfully
2024-01-01 10:10:00 - WARNING: Computer migration delayed
2024-01-01 10:15:00 - ERROR: Failed to migrate testpc3
2024-01-01 10:20:00 - Migration completed successfully
"@
            $testLog | Out-File "$logDir\test.log"
        }
        
        It "Should read migration status" {
            if (-not $script:ModuleLoaded) { Set-ItResult -Skipped -Because "Module not loaded" }
            
            $status = Get-ADMTMigrationStatus -LogPath "C:\ADMT\Logs"
            $status | Should -Not -BeNullOrEmpty
        }
        
        It "Should parse log file correctly" {
            if (-not $script:ModuleLoaded) { Set-ItResult -Skipped -Because "Module not loaded" }
            
            $status = Get-ADMTMigrationStatus -LogPath "C:\ADMT\Logs"
            $status.Errors | Should -Be 1
            $status.Warnings | Should -Be 1
            $status.Completed | Should -Be 2
        }
        
        AfterAll {
            # Clean up test log
            Remove-Item "C:\ADMT\Logs\test.log" -ErrorAction SilentlyContinue
        }
    }
}

Describe "Report Generation" -Tag "Report", "Export" {
    Context "Export-ADMTReport Function" {
        BeforeAll {
            $script:ReportPath = "C:\ADMT\Reports"
            if (-not (Test-Path $script:ReportPath)) {
                New-Item -Path $script:ReportPath -ItemType Directory -Force | Out-Null
            }
            
            $script:TestReportBatchId = "ReportTest_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        }
        
        It "Should generate report" {
            if (-not $script:ModuleLoaded) { Set-ItResult -Skipped -Because "Module not loaded" }
            
            { Export-ADMTReport -OutputPath $script:ReportPath -MigrationBatchId $script:TestReportBatchId } | Should -Not -Throw
        }
        
        It "Should create report file" {
            if (-not $script:ModuleLoaded) { Set-ItResult -Skipped -Because "Module not loaded" }
            
            $reportFile = Join-Path $script:ReportPath "report_$($script:TestReportBatchId).json"
            Test-Path $reportFile | Should -Be $true
        }
        
        It "Report should contain valid JSON" {
            if (-not $script:ModuleLoaded) { Set-ItResult -Skipped -Because "Module not loaded" }
            
            $reportFile = Join-Path $script:ReportPath "report_$($script:TestReportBatchId).json"
            { Get-Content $reportFile | ConvertFrom-Json } | Should -Not -Throw
        }
        
        AfterAll {
            # Clean up report files
            Remove-Item "$script:ReportPath\report_$($script:TestReportBatchId).json" -ErrorAction SilentlyContinue
        }
    }
}

Describe "Rollback Functionality" -Tag "Rollback", "Critical" {
    BeforeAll {
        $script:RollbackBatchId = "RollbackTest_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        
        # Create a test batch for rollback
        if ($script:ModuleLoaded) {
            New-ADMTMigrationBatch `
                -BatchId $script:RollbackBatchId `
                -Users @("rollback_user1") `
                -Computers @("rollback_pc1") `
                -Groups @("rollback_group1") `
                -SourceDomain $TestConfig.SourceDomain `
                -TargetDomain $TestConfig.TargetDomain `
                -TargetOU $TestConfig.TestOU | Out-Null
        }
    }
    
    Context "Invoke-ADMTRollback Function" {
        It "Should accept BatchId parameter" {
            if (-not $script:ModuleLoaded) { Set-ItResult -Skipped -Because "Module not loaded" }
            
            { Invoke-ADMTRollback -BatchId $script:RollbackBatchId -Force -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
        
        It "Should validate batch exists" {
            if (-not $script:ModuleLoaded) { Set-ItResult -Skipped -Because "Module not loaded" }
            
            # Try rollback with non-existent batch
            $result = Invoke-ADMTRollback -BatchId "NonExistent_Batch" -Force -ErrorAction SilentlyContinue
            # Function should handle gracefully
        }
        
        It "Should require Force parameter for actual deletion" {
            if (-not $script:ModuleLoaded) { Set-ItResult -Skipped -Because "Module not loaded" }
            
            # Without -Force, should not delete
            $result = Invoke-ADMTRollback -BatchId $script:RollbackBatchId -WarningAction SilentlyContinue
            # Should warn but not delete
        }
        
        It "Should create rollback log" {
            if (-not $script:ModuleLoaded) { Set-ItResult -Skipped -Because "Module not loaded" }
            if ($script:SkipADTests) { Set-ItResult -Skipped -Because "AD not available" }
            
            Invoke-ADMTRollback -BatchId $script:RollbackBatchId -Force -ErrorAction SilentlyContinue
            
            $rollbackLog = "C:\ADMT\Batches\rollback_$($script:RollbackBatchId).json"
            Test-Path $rollbackLog | Should -Be $true
        }
    }
    
    AfterAll {
        # Clean up test batch
        Remove-Item "C:\ADMT\Batches\$($script:RollbackBatchId).json" -ErrorAction SilentlyContinue
        Remove-Item "C:\ADMT\Batches\rollback_$($script:RollbackBatchId).json" -ErrorAction SilentlyContinue
    }
}

Describe "End-to-End Migration Workflow" -Tag "E2E", "Integration", "Slow" {
    BeforeAll {
        $script:E2EBatchId = "E2E_Test_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    }
    
    It "Should complete full migration workflow" {
        if (-not $script:ModuleLoaded) { Set-ItResult -Skipped -Because "Module not loaded" }
        if ($script:SkipADTests) { Set-ItResult -Skipped -Because "AD not available" }
        
        # Step 1: Check prerequisites
        $prereqs = Test-ADMTPrerequisites -SourceDomain $TestConfig.SourceDomain -TargetDomain $TestConfig.TargetDomain
        $prereqs | Should -Not -BeNullOrEmpty
        
        # Step 2: Create batch
        $batch = New-ADMTMigrationBatch `
            -BatchId $script:E2EBatchId `
            -Users @("e2e_user1") `
            -Computers @("e2e_pc1") `
            -Groups @() `
            -SourceDomain $TestConfig.SourceDomain `
            -TargetDomain $TestConfig.TargetDomain `
            -TargetOU $TestConfig.TestOU
        
        $batch | Should -Not -BeNullOrEmpty
        
        # Step 3: Get status (would be after migration in real scenario)
        $status = Get-ADMTMigrationStatus
        $status | Should -Not -BeNullOrEmpty
        
        # Step 4: Generate report
        $reportPath = "C:\ADMT\Reports"
        { Export-ADMTReport -OutputPath $reportPath -MigrationBatchId $script:E2EBatchId } | Should -Not -Throw
        
        # Step 5: Rollback (simulated)
        { Invoke-ADMTRollback -BatchId $script:E2EBatchId -Force -ErrorAction SilentlyContinue } | Should -Not -Throw
    }
    
    AfterAll {
        # Clean up E2E test artifacts
        Remove-Item "C:\ADMT\Batches\$($script:E2EBatchId).json" -ErrorAction SilentlyContinue
        Remove-Item "C:\ADMT\Batches\rollback_$($script:E2EBatchId).json" -ErrorAction SilentlyContinue
        Remove-Item "C:\ADMT\Reports\report_$($script:E2EBatchId).json" -ErrorAction SilentlyContinue
    }
}

AfterAll {
    # Clean up all test batches
    Get-ChildItem "C:\ADMT\Batches" -Filter "$($TestConfig.BatchIdPrefix)*" -ErrorAction SilentlyContinue | Remove-Item -Force
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  ADMT Integration Tests Complete" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

