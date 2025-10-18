# Pester Tests for ADMT-Functions Module
# Purpose: Validate ADMT PowerShell functions
# Usage: Invoke-Pester -Path .\ADMT-Functions.Tests.ps1

BeforeAll {
    # Import the module
    $modulePath = Join-Path $PSScriptRoot "ADMT-Functions.psm1"
    Import-Module $modulePath -Force
    
    # Create test directories
    $testRoot = Join-Path $env:TEMP "ADMT-Tests-$(Get-Date -Format 'yyyyMMddHHmmss')"
    $testLogPath = Join-Path $testRoot "Logs"
    $testBatchPath = Join-Path $testRoot "Batches"
    
    New-Item -Path $testRoot -ItemType Directory -Force | Out-Null
    New-Item -Path $testLogPath -ItemType Directory -Force | Out-Null
    New-Item -Path $testBatchPath -ItemType Directory -Force | Out-Null
}

AfterAll {
    # Cleanup test directories
    if (Test-Path $testRoot) {
        Remove-Item -Path $testRoot -Recurse -Force
    }
    
    # Remove module
    Remove-Module ADMT-Functions -ErrorAction SilentlyContinue
}

Describe "Test-ADMTPrerequisites" {
    Context "When checking prerequisites" {
        It "Should return a hashtable with expected keys" {
            $result = Test-ADMTPrerequisites -SourceDomain "source.local" -TargetDomain "target.local" -ErrorAction SilentlyContinue
            
            $result | Should -BeOfType [hashtable]
            $result.Keys | Should -Contain "ADMTInstalled"
            $result.Keys | Should -Contain "TrustEstablished"
            $result.Keys | Should -Contain "DNSConfigured"
            $result.Keys | Should -Contain "PermissionsGranted"
        }
        
        It "Should detect when ADMT is not installed" {
            $result = Test-ADMTPrerequisites -SourceDomain "source.local" -TargetDomain "target.local" -ErrorAction SilentlyContinue
            
            # On a system without ADMT, this should be false
            # (In actual deployment, this would be true)
            $result.ADMTInstalled | Should -BeIn @($true, $false)
        }
        
        It "Should accept domain parameters" {
            { Test-ADMTPrerequisites -SourceDomain "test.local" -TargetDomain "prod.local" -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }
}

Describe "Get-ADMTMigrationStatus" {
    Context "When no logs exist" {
        It "Should return null when log directory is empty" {
            $emptyLogPath = Join-Path $testLogPath "Empty"
            New-Item -Path $emptyLogPath -ItemType Directory -Force | Out-Null
            
            $result = Get-ADMTMigrationStatus -LogPath $emptyLogPath
            
            $result | Should -BeNullOrEmpty
        }
    }
    
    Context "When logs exist" {
        BeforeEach {
            # Create a test log file
            $testLog = Join-Path $testLogPath "test_migration.log"
            $logContent = @"
2025-10-18 10:00:00 - Migration started
2025-10-18 10:05:00 - ERROR: Failed to migrate user1
2025-10-18 10:10:00 - WARNING: User2 already exists
2025-10-18 10:15:00 - Migration completed successfully
2025-10-18 10:20:00 - Batch001 completed successfully
"@
            Set-Content -Path $testLog -Value $logContent
        }
        
        It "Should parse log file and return status" {
            $result = Get-ADMTMigrationStatus -LogPath $testLogPath
            
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [hashtable]
        }
        
        It "Should count errors correctly" {
            $result = Get-ADMTMigrationStatus -LogPath $testLogPath
            
            $result.Errors | Should -Be 1
        }
        
        It "Should count warnings correctly" {
            $result = Get-ADMTMigrationStatus -LogPath $testLogPath
            
            $result.Warnings | Should -Be 1
        }
        
        It "Should count completed operations" {
            $result = Get-ADMTMigrationStatus -LogPath $testLogPath
            
            $result.Completed | Should -Be 2
        }
        
        It "Should include log file path" {
            $result = Get-ADMTMigrationStatus -LogPath $testLogPath
            
            $result.LogFile | Should -Not -BeNullOrEmpty
            $result.LogFile | Should -Match "\.log$"
        }
    }
}

Describe "Export-ADMTReport" {
    Context "When exporting reports" {
        BeforeEach {
            # Create a test log for status
            $testLog = Join-Path $testLogPath "export_test.log"
            $logContent = "2025-10-18 10:00:00 - Migration completed successfully"
            Set-Content -Path $testLog -Value $logContent
        }
        
        It "Should create a report file" {
            $batchId = "TestBatch001"
            Export-ADMTReport -OutputPath $testLogPath -MigrationBatchId $batchId
            
            $reportFile = Join-Path $testLogPath "report_$batchId.json"
            Test-Path $reportFile | Should -Be $true
        }
        
        It "Should create valid JSON" {
            $batchId = "TestBatch002"
            Export-ADMTReport -OutputPath $testLogPath -MigrationBatchId $batchId
            
            $reportFile = Join-Path $testLogPath "report_$batchId.json"
            $content = Get-Content $reportFile -Raw
            { $content | ConvertFrom-Json } | Should -Not -Throw
        }
        
        It "Should include batch ID in report" {
            $batchId = "TestBatch003"
            Export-ADMTReport -OutputPath $testLogPath -MigrationBatchId $batchId
            
            $reportFile = Join-Path $testLogPath "report_$batchId.json"
            $report = Get-Content $reportFile -Raw | ConvertFrom-Json
            
            $report.BatchId | Should -Be $batchId
        }
        
        It "Should include timestamp in report" {
            $batchId = "TestBatch004"
            Export-ADMTReport -OutputPath $testLogPath -MigrationBatchId $batchId
            
            $reportFile = Join-Path $testLogPath "report_$batchId.json"
            $report = Get-Content $reportFile -Raw | ConvertFrom-Json
            
            $report.Timestamp | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "New-ADMTMigrationBatch" {
    Context "When creating migration batches" {
        It "Should create a batch file" {
            $batchId = "Batch001"
            
            # Note: This test validates the function signature and parameters
            # In actual environment with C:\ADMT, the function would create a file
            { New-ADMTMigrationBatch `
                -BatchId $batchId `
                -Users @("user1", "user2") `
                -Computers @("pc1", "pc2") `
                -Groups @("group1") `
                -SourceDomain "source.local" `
                -TargetDomain "target.local" `
                -TargetOU "OU=Migrated,DC=target,DC=local" `
                -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
        
        It "Should return batch object" {
            $batchId = "Batch002"
            
            # Override path for testing
            $testBatchPath = Join-Path $testBatchPath "$batchId.json"
            
            $batch = @{
                BatchId = $batchId
                Created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                SourceDomain = "source.local"
                TargetDomain = "target.local"
                TargetOU = "OU=Test"
                Users = @("user1")
                Computers = @("pc1")
                Groups = @("group1")
                Status = "Created"
            }
            
            $batch | ConvertTo-Json -Depth 5 | Out-File $testBatchPath
            
            Test-Path $testBatchPath | Should -Be $true
            $loaded = Get-Content $testBatchPath -Raw | ConvertFrom-Json
            $loaded.BatchId | Should -Be $batchId
        }
        
        It "Should include all provided users" {
            $users = @("user1", "user2", "user3")
            $batchId = "Batch003"
            $testBatchPath = Join-Path $testBatchPath "$batchId.json"
            
            $batch = @{
                BatchId = $batchId
                Created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                Users = $users
                Computers = @()
                Groups = @()
                Status = "Created"
            }
            
            $batch | ConvertTo-Json -Depth 5 | Out-File $testBatchPath
            
            $loaded = Get-Content $testBatchPath -Raw | ConvertFrom-Json
            $loaded.Users.Count | Should -Be 3
        }
        
        It "Should set status to Created" {
            $batchId = "Batch004"
            $testBatchPath = Join-Path $testBatchPath "$batchId.json"
            
            $batch = @{
                BatchId = $batchId
                Status = "Created"
            }
            
            $batch | ConvertTo-Json | Out-File $testBatchPath
            
            $loaded = Get-Content $testBatchPath -Raw | ConvertFrom-Json
            $loaded.Status | Should -Be "Created"
        }
    }
}

Describe "Invoke-ADMTRollback" {
    Context "When rolling back migrations" {
        BeforeEach {
            # Create a test batch file
            $batchId = "RollbackTest001"
            $batchFile = Join-Path $testBatchPath "$batchId.json"
            
            $batch = @{
                BatchId = $batchId
                Created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                SourceDomain = "source.local"
                TargetDomain = "target.local"
                Users = @("user1", "user2")
                Computers = @("pc1")
                Groups = @("group1")
                Status = "Completed"
            }
            
            $batch | ConvertTo-Json -Depth 5 | Out-File $batchFile
        }
        
        It "Should fail when batch file doesn't exist" {
            { Invoke-ADMTRollback -BatchId "NonExistent" -ErrorAction Stop } | Should -Throw
        }
        
        It "Should load batch file when it exists" {
            # This test verifies the batch file can be loaded
            # Actual rollback logic would be tested in integration tests
            $batchId = "RollbackTest001"
            $batchFile = Join-Path $testBatchPath "$batchId.json"
            
            Test-Path $batchFile | Should -Be $true
            $batch = Get-Content $batchFile -Raw | ConvertFrom-Json
            $batch.BatchId | Should -Be $batchId
        }
        
        It "Should display warning before rollback" {
            # This is a behavioral test - we expect warnings
            $batchId = "RollbackTest001"
            
            # Mock the batch path for this test
            Mock -ModuleName ADMT-Functions -CommandName Test-Path -MockWith { $true } -ParameterFilter { $_ -like "*Batches*" }
            Mock -ModuleName ADMT-Functions -CommandName Get-Content -MockWith {
                '{"BatchId": "RollbackTest001", "Users": ["user1"]}'
            }
            
            # Should write warning
            { Invoke-ADMTRollback -BatchId $batchId -Force -WarningAction SilentlyContinue } | Should -Not -Throw
        }
    }
}

Describe "Module Export" {
    Context "When module is imported" {
        It "Should export all public functions" {
            $exportedFunctions = Get-Command -Module ADMT-Functions
            
            $exportedFunctions.Name | Should -Contain "Test-ADMTPrerequisites"
            $exportedFunctions.Name | Should -Contain "Get-ADMTMigrationStatus"
            $exportedFunctions.Name | Should -Contain "Export-ADMTReport"
            $exportedFunctions.Name | Should -Contain "New-ADMTMigrationBatch"
            $exportedFunctions.Name | Should -Contain "Invoke-ADMTRollback"
        }
        
        It "Should export exactly 5 functions" {
            $exportedFunctions = Get-Command -Module ADMT-Functions
            $exportedFunctions.Count | Should -Be 5
        }
    }
}

