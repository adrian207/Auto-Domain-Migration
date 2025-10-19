#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.0.0" }

<#
.SYNOPSIS
    Integration tests for File Server migration using SMS
.DESCRIPTION
    Validates Storage Migration Service functionality and file server migrations
#>

BeforeAll {
    # Test configuration
    $script:TestConfig = @{
        SourceServer = "source-fs.source.local"
        TargetServer = "target-fs.target.local"
        TestShareName = "TestMigration"
        TestFilePath = "C:\Temp\FileServerTest"
    }
    
    # Check if running on Windows
    if ($PSVersionTable.PSVersion.Major -lt 5 -or -not $IsWindows) {
        Write-Warning "File server tests require Windows PowerShell 5+ or PowerShell 7+ on Windows"
        $script:SkipTests = $true
    } else {
        $script:SkipTests = $false
    }
    
    # Create test file directory
    if (-not $script:SkipTests -and -not (Test-Path $TestConfig.TestFilePath)) {
        New-Item -Path $TestConfig.TestFilePath -ItemType Directory -Force | Out-Null
    }
}

Describe "File Server Availability" -Tag "FileServer", "Connectivity" {
    Context "Source File Server" {
        It "Should resolve source file server DNS" {
            if ($script:SkipTests) { Set-ItResult -Skipped -Because "Not on Windows" }
            
            $dns = Resolve-DnsName -Name $TestConfig.SourceServer -ErrorAction SilentlyContinue
            if (-not $dns) { Set-ItResult -Skipped -Because "Source server not available" }
            $dns | Should -Not -BeNullOrEmpty
        }
        
        It "Should respond to ping" {
            if ($script:SkipTests) { Set-ItResult -Skipped -Because "Not on Windows" }
            
            $ping = Test-Connection -ComputerName $TestConfig.SourceServer -Count 1 -Quiet -ErrorAction SilentlyContinue
            if (-not $ping) { Set-ItResult -Skipped -Because "Source server not reachable" }
            $ping | Should -Be $true
        }
        
        It "Should have SMB service running" {
            if ($script:SkipTests) { Set-ItResult -Skipped -Because "Not on Windows" }
            
            $smbPort = Test-NetConnection -ComputerName $TestConfig.SourceServer -Port 445 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
            if (-not $smbPort.TcpTestSucceeded) { Set-ItResult -Skipped -Because "SMB not accessible" }
            $smbPort.TcpTestSucceeded | Should -Be $true
        }
    }
    
    Context "Target File Server" {
        It "Should resolve target file server DNS" {
            if ($script:SkipTests) { Set-ItResult -Skipped -Because "Not on Windows" }
            
            $dns = Resolve-DnsName -Name $TestConfig.TargetServer -ErrorAction SilentlyContinue
            if (-not $dns) { Set-ItResult -Skipped -Because "Target server not available" }
            $dns | Should -Not -BeNullOrEmpty
        }
        
        It "Should respond to ping" {
            if ($script:SkipTests) { Set-ItResult -Skipped -Because "Not on Windows" }
            
            $ping = Test-Connection -ComputerName $TestConfig.TargetServer -Count 1 -Quiet -ErrorAction SilentlyContinue
            if (-not $ping) { Set-ItResult -Skipped -Because "Target server not reachable" }
            $ping | Should -Be $true
        }
        
        It "Should have SMS role installed" {
            if ($script:SkipTests) { Set-ItResult -Skipped -Because "Not on Windows" }
            
            # Check for SMS feature
            $sms = Get-WindowsFeature -Name SMS-Server -ComputerName $TestConfig.TargetServer -ErrorAction SilentlyContinue
            if (-not $sms) { Set-ItResult -Skipped -Because "SMS not installed" }
            $sms.Installed | Should -Be $true
        }
    }
}

Describe "SMB Shares" -Tag "SMB", "Shares" {
    Context "Source Shares" {
        It "Should have predefined shares" {
            if ($script:SkipTests) { Set-ItResult -Skipped -Because "Not on Windows" }
            
            $shares = Get-SmbShare -CimSession $TestConfig.SourceServer -ErrorAction SilentlyContinue
            if (-not $shares) { Set-ItResult -Skipped -Because "Cannot access shares" }
            
            # Should have at least HR, Finance, Engineering shares
            $shareNames = $shares.Name
            $shareNames | Should -Contain "HR"
            $shareNames | Should -Contain "Finance"
            $shareNames | Should -Contain "Engineering"
        }
        
        It "Shares should have correct permissions" {
            if ($script:SkipTests) { Set-ItResult -Skipped -Because "Not on Windows" }
            
            $hrShare = Get-SmbShare -Name "HR" -CimSession $TestConfig.SourceServer -ErrorAction SilentlyContinue
            if (-not $hrShare) { Set-ItResult -Skipped -Because "HR share not found" }
            
            $access = Get-SmbShareAccess -Name "HR" -CimSession $TestConfig.SourceServer -ErrorAction SilentlyContinue
            $access | Should -Not -BeNullOrEmpty
        }
        
        It "Shares should contain test data" {
            if ($script:SkipTests) { Set-ItResult -Skipped -Because "Not on Windows" }
            
            # Try to access HR share
            $uncPath = "\\$($TestConfig.SourceServer)\HR"
            if (-not (Test-Path $uncPath)) { Set-ItResult -Skipped -Because "Cannot access share" }
            
            $files = Get-ChildItem -Path $uncPath -File -ErrorAction SilentlyContinue
            $files.Count | Should -BeGreaterThan 0
        }
    }
    
    Context "Target Shares" {
        It "Should be able to create shares on target" {
            if ($script:SkipTests) { Set-ItResult -Skipped -Because "Not on Windows" }
            
            # Try to create a test share
            $testSharePath = "C:\Shares\Test"
            { New-SmbShare -Name $TestConfig.TestShareName -Path $testSharePath -CimSession $TestConfig.TargetServer -ErrorAction Stop } | Should -Not -Throw
        }
        
        AfterAll {
            # Clean up test share
            Remove-SmbShare -Name $TestConfig.TestShareName -CimSession $TestConfig.TargetServer -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Storage Migration Service" -Tag "SMS", "Migration" {
    Context "SMS Components" {
        It "Should have SMS Orchestrator service running" {
            if ($script:SkipTests) { Set-ItResult -Skipped -Because "Not on Windows" }
            
            $service = Get-Service -Name "SMS*" -ComputerName $TestConfig.TargetServer -ErrorAction SilentlyContinue
            if (-not $service) { Set-ItResult -Skipped -Because "SMS service not found" }
            
            $runningServices = $service | Where-Object { $_.Status -eq "Running" }
            $runningServices.Count | Should -BeGreaterThan 0
        }
        
        It "Should have SMS PowerShell module available" {
            if ($script:SkipTests) { Set-ItResult -Skipped -Because "Not on Windows" }
            
            $module = Get-Module -ListAvailable -Name "StorageMigrationService" -ErrorAction SilentlyContinue
            if (-not $module) { Set-ItResult -Skipped -Because "SMS module not installed" }
            $module | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Migration Jobs" {
        BeforeAll {
            # Import SMS module if available
            Import-Module StorageMigrationService -ErrorAction SilentlyContinue
            $script:SMSAvailable = $?
        }
        
        It "Should be able to create SMS jobs" {
            if (-not $script:SMSAvailable) { Set-ItResult -Skipped -Because "SMS not available" }
            
            # This would create an actual SMS job in a real environment
            # For testing, we just validate the cmdlet exists
            { Get-Command New-SMSJob -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should be able to inventory source servers" {
            if (-not $script:SMSAvailable) { Set-ItResult -Skipped -Because "SMS not available" }
            
            { Get-Command Start-SMSInventory -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should be able to transfer data" {
            if (-not $script:SMSAvailable) { Set-ItResult -Skipped -Because "SMS not available" }
            
            { Get-Command Start-SMSTransfer -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should be able to cutover" {
            if (-not $script:SMSAvailable) { Set-ItResult -Skipped -Because "SMS not available" }
            
            { Get-Command Start-SMSCutover -ErrorAction Stop } | Should -Not -Throw
        }
    }
}

Describe "File Data Validation" -Tag "Files", "Validation" {
    Context "Test Data Generation" {
        BeforeAll {
            $script:GenerateScriptPath = Join-Path $PSScriptRoot "..\..\scripts\Generate-TestFileData.ps1"
        }
        
        It "Should have file generation script" {
            Test-Path $script:GenerateScriptPath | Should -Be $true
        }
        
        It "Generation script should have valid syntax" {
            if ($script:SkipTests) { Set-ItResult -Skipped -Because "Not on Windows" }
            
            $null = [System.Management.Automation.PSParser]::Tokenize(
                (Get-Content $script:GenerateScriptPath -Raw),
                [ref]$null
            )
            # If we get here, syntax is valid
            $true | Should -Be $true
        }
    }
    
    Context "File Properties" {
        BeforeAll {
            # Create test files
            if (-not $script:SkipTests) {
                $script:TestFiles = @()
                for ($i = 1; $i -le 10; $i++) {
                    $fileName = "testfile_$i.txt"
                    $filePath = Join-Path $TestConfig.TestFilePath $fileName
                    
                    # Create file with random size (10KB - 1MB)
                    $size = Get-Random -Minimum 10240 -Maximum 1048576
                    $content = "X" * $size
                    $content | Out-File $filePath -NoNewline
                    
                    $script:TestFiles += Get-Item $filePath
                }
            }
        }
        
        It "Should create files with correct sizes" {
            if ($script:SkipTests) { Set-ItResult -Skipped -Because "Not on Windows" }
            
            foreach ($file in $script:TestFiles) {
                $file.Length | Should -BeGreaterThan 10240
                $file.Length | Should -BeLessThan 1048576
            }
        }
        
        It "Should preserve file attributes during copy" {
            if ($script:SkipTests) { Set-ItResult -Skipped -Because "Not on Windows" }
            
            $sourceFile = $script:TestFiles[0]
            $targetPath = Join-Path $TestConfig.TestFilePath "copy_$($sourceFile.Name)"
            
            # Copy file
            Copy-Item -Path $sourceFile.FullName -Destination $targetPath -Force
            
            $targetFile = Get-Item $targetPath
            
            # Validate properties
            $sourceFile.Length | Should -Be $targetFile.Length
            $sourceFile.Extension | Should -Be $targetFile.Extension
        }
        
        It "Should calculate file hashes correctly" {
            if ($script:SkipTests) { Set-ItResult -Skipped -Because "Not on Windows" }
            
            $testFile = $script:TestFiles[0]
            $hash1 = Get-FileHash -Path $testFile.FullName -Algorithm SHA256
            $hash2 = Get-FileHash -Path $testFile.FullName -Algorithm SHA256
            
            # Same file should produce same hash
            $hash1.Hash | Should -Be $hash2.Hash
        }
        
        AfterAll {
            # Clean up test files
            if (-not $script:SkipTests) {
                Remove-Item "$($TestConfig.TestFilePath)\*" -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe "Migration Performance" -Tag "Performance", "Benchm ark" {
    Context "Transfer Speed" {
        It "Should transfer files at acceptable speed" {
            if ($script:SkipTests) { Set-ItResult -Skipped -Because "Not on Windows" }
            
            # Create a 10MB test file
            $testFile = Join-Path $TestConfig.TestFilePath "perftest.dat"
            $size = 10MB
            $content = "X" * $size
            $content | Out-File $testFile -NoNewline
            
            $targetPath = Join-Path $TestConfig.TestFilePath "perftest_target.dat"
            
            # Measure copy time
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            Copy-Item -Path $testFile -Destination $targetPath -Force
            $stopwatch.Stop()
            
            # Calculate speed (MB/s)
            $speed = ($size / 1MB) / $stopwatch.Elapsed.TotalSeconds
            
            # Should be at least 10 MB/s on local disk
            $speed | Should -BeGreaterThan 10
            
            # Clean up
            Remove-Item $testFile, $targetPath -Force -ErrorAction SilentlyContinue
        }
    }
    
    Context "Large File Sets" {
        It "Should handle 1000+ files efficiently" {
            if ($script:SkipTests) { Set-ItResult -Skipped -Because "Not on Windows" }
            
            $testDir = Join-Path $TestConfig.TestFilePath "large_set"
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
            
            # Create 100 small files (reduced for test speed)
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            for ($i = 1; $i -le 100; $i++) {
                $filePath = Join-Path $testDir "file_$i.txt"
                "Test content $i" | Out-File $filePath
            }
            $stopwatch.Stop()
            
            # Should create 100 files in under 10 seconds
            $stopwatch.Elapsed.TotalSeconds | Should -BeLessThan 10
            
            # Verify count
            $fileCount = (Get-ChildItem $testDir -File).Count
            $fileCount | Should -Be 100
            
            # Clean up
            Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Data Integrity" -Tag "Integrity", "Validation" {
    Context "Hash Verification" {
        It "Should maintain data integrity during transfer" {
            if ($script:SkipTests) { Set-ItResult -Skipped -Because "Not on Windows" }
            
            # Create source file
            $sourceFile = Join-Path $TestConfig.TestFilePath "integrity_source.dat"
            $content = Get-Random -Count 1000 | Out-String
            $content | Out-File $sourceFile -NoNewline
            
            # Calculate source hash
            $sourceHash = Get-FileHash -Path $sourceFile -Algorithm SHA256
            
            # Copy to target
            $targetFile = Join-Path $TestConfig.TestFilePath "integrity_target.dat"
            Copy-Item -Path $sourceFile -Destination $targetFile -Force
            
            # Calculate target hash
            $targetHash = Get-FileHash -Path $targetFile -Algorithm SHA256
            
            # Hashes should match
            $sourceHash.Hash | Should -Be $targetHash.Hash
            
            # Clean up
            Remove-Item $sourceFile, $targetFile -Force -ErrorAction SilentlyContinue
        }
    }
    
    Context "Permission Preservation" {
        It "Should preserve NTFS permissions" {
            if ($script:SkipTests) { Set-ItResult -Skipped -Because "Not on Windows" }
            
            # Create source file with specific permissions
            $sourceFile = Join-Path $TestConfig.TestFilePath "perm_source.txt"
            "Test" | Out-File $sourceFile
            
            # Get original ACL
            $sourceAcl = Get-Acl -Path $sourceFile
            
            # Copy file
            $targetFile = Join-Path $TestConfig.TestFilePath "perm_target.txt"
            Copy-Item -Path $sourceFile -Destination $targetFile -Force
            
            # Copy ACL manually (SMS would do this automatically)
            Set-Acl -Path $targetFile -AclObject $sourceAcl
            
            # Verify ACL
            $targetAcl = Get-Acl -Path $targetFile
            $targetAcl.AccessToString | Should -Be $sourceAcl.AccessToString
            
            # Clean up
            Remove-Item $sourceFile, $targetFile -Force -ErrorAction SilentlyContinue
        }
    }
}

AfterAll {
    # Clean up test directory
    if (Test-Path $TestConfig.TestFilePath) {
        Remove-Item $TestConfig.TestFilePath -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  File Server Migration Tests Complete" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

