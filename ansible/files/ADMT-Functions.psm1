# ADMT PowerShell Functions Module
# Purpose: Helper functions for ADMT automation

function Test-ADMTPrerequisites {
    <#
    .SYNOPSIS
        Tests if all ADMT prerequisites are met
    #>
    [CmdletBinding()]
    param(
        [string]$SourceDomain,
        [string]$TargetDomain
    )
    
    $results = @{
        ADMTInstalled = $false
        TrustEstablished = $false
        DNSConfigured = $false
        PermissionsGranted = $false
    }
    
    # Check ADMT installation
    if (Test-Path "C:\Program Files\Active Directory Migration Tool\ADMT.exe") {
        $results.ADMTInstalled = $true
        Write-Verbose "ADMT is installed"
    }
    
    # Check trust
    try {
        $trust = Get-ADTrust -Filter "Target -eq '$SourceDomain'" -ErrorAction Stop
        if ($trust) {
            $results.TrustEstablished = $true
            Write-Verbose "Trust relationship verified"
        }
    } catch {
        Write-Warning "Trust verification failed: $_"
    }
    
    # Check DNS
    try {
        $dnsTest = Resolve-DnsName -Name $SourceDomain -ErrorAction Stop
        if ($dnsTest) {
            $results.DNSConfigured = $true
            Write-Verbose "DNS resolution successful"
        }
    } catch {
        Write-Warning "DNS resolution failed: $_"
    }
    
    return $results
}

function Get-ADMTMigrationStatus {
    <#
    .SYNOPSIS
        Gets the status of ADMT migration operations
    #>
    [CmdletBinding()]
    param(
        [string]$LogPath = "C:\ADMT\Logs"
    )
    
    $latestLog = Get-ChildItem -Path $LogPath -Filter "*.log" | 
        Sort-Object LastWriteTime -Descending | 
        Select-Object -First 1
    
    if ($latestLog) {
        $logContent = Get-Content $latestLog.FullName
        
        # Parse log for status information
        $status = @{
            LogFile = $latestLog.FullName
            LastUpdate = $latestLog.LastWriteTime
            Errors = ($logContent | Select-String -Pattern "ERROR").Count
            Warnings = ($logContent | Select-String -Pattern "WARNING").Count
            Completed = ($logContent | Select-String -Pattern "completed successfully").Count
        }
        
        return $status
    }
    
    return $null
}

function Export-ADMTReport {
    <#
    .SYNOPSIS
        Exports ADMT migration report
    #>
    [CmdletBinding()]
    param(
        [string]$OutputPath,
        [string]$MigrationBatchId
    )
    
    $reportData = @{
        BatchId = $MigrationBatchId
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Status = Get-ADMTMigrationStatus
    }
    
    $reportData | ConvertTo-Json -Depth 5 | Out-File "$OutputPath\report_$MigrationBatchId.json"
    
    Write-Output "Report exported to: $OutputPath\report_$MigrationBatchId.json"
}

function New-ADMTMigrationBatch {
    <#
    .SYNOPSIS
        Creates a new migration batch configuration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BatchId,
        
        [string[]]$Users,
        [string[]]$Computers,
        [string[]]$Groups,
        
        [string]$SourceDomain,
        [string]$TargetDomain,
        [string]$TargetOU
    )
    
    $batch = @{
        BatchId = $BatchId
        Created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        SourceDomain = $SourceDomain
        TargetDomain = $TargetDomain
        TargetOU = $TargetOU
        Users = $Users
        Computers = $Computers
        Groups = $Groups
        Status = "Created"
    }
    
    $batchPath = "C:\ADMT\Batches\$BatchId.json"
    New-Item -Path (Split-Path $batchPath) -ItemType Directory -Force | Out-Null
    $batch | ConvertTo-Json -Depth 5 | Out-File $batchPath
    
    Write-Output "Migration batch created: $batchPath"
    return $batch
}

function Invoke-ADMTRollback {
    <#
    .SYNOPSIS
        Rolls back ADMT migration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BatchId,
        
        [switch]$Force
    )
    
    Write-Warning "Initiating rollback for batch: $BatchId"
    
    $batchPath = "C:\ADMT\Batches\$BatchId.json"
    
    if (-not (Test-Path $batchPath)) {
        Write-Error "Batch file not found: $batchPath"
        return
    }
    
    $batch = Get-Content $batchPath | ConvertFrom-Json
    
    # Log batch information
    Write-Verbose "Rolling back batch created on: $($batch.Created)"
    Write-Verbose "Source Domain: $($batch.SourceDomain)"
    Write-Verbose "Target Domain: $($batch.TargetDomain)"
    Write-Verbose "Users to rollback: $($batch.Users.Count)"
    Write-Verbose "Computers to rollback: $($batch.Computers.Count)"
    
    # Rollback results
    $rollbackResults = @{
        BatchId = $BatchId
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        UsersRemoved = @()
        ComputersRemoved = @()
        GroupsRemoved = @()
        Errors = @()
    }
    
    # Rollback users from target domain
    if ($batch.Users -and $batch.Users.Count -gt 0) {
        Write-Verbose "Removing $($batch.Users.Count) users from target domain"
        
        foreach ($user in $batch.Users) {
            try {
                # Check if user exists in target domain
                $adUser = Get-ADUser -Identity $user -Server $batch.TargetDomain -ErrorAction SilentlyContinue
                
                if ($adUser) {
                    if ($Force) {
                        # Remove user without confirmation
                        Remove-ADUser -Identity $user -Server $batch.TargetDomain -Confirm:$false -ErrorAction Stop
                        Write-Verbose "Removed user: $user"
                        $rollbackResults.UsersRemoved += $user
                    } else {
                        Write-Warning "User $user exists but -Force not specified. Skipping."
                    }
                } else {
                    Write-Verbose "User $user not found in target domain. Already removed or never migrated."
                }
            } catch {
                $errorMsg = "Failed to remove user $user : $_"
                Write-Error $errorMsg
                $rollbackResults.Errors += $errorMsg
            }
        }
    }
    
    # Rollback computers from target domain
    if ($batch.Computers -and $batch.Computers.Count -gt 0) {
        Write-Verbose "Removing $($batch.Computers.Count) computers from target domain"
        
        foreach ($computer in $batch.Computers) {
            try {
                # Check if computer exists in target domain
                $adComputer = Get-ADComputer -Identity $computer -Server $batch.TargetDomain -ErrorAction SilentlyContinue
                
                if ($adComputer) {
                    if ($Force) {
                        # Remove computer without confirmation
                        Remove-ADComputer -Identity $computer -Server $batch.TargetDomain -Confirm:$false -ErrorAction Stop
                        Write-Verbose "Removed computer: $computer"
                        $rollbackResults.ComputersRemoved += $computer
                    } else {
                        Write-Warning "Computer $computer exists but -Force not specified. Skipping."
                    }
                } else {
                    Write-Verbose "Computer $computer not found in target domain. Already removed or never migrated."
                }
            } catch {
                $errorMsg = "Failed to remove computer $computer : $_"
                Write-Error $errorMsg
                $rollbackResults.Errors += $errorMsg
            }
        }
    }
    
    # Rollback groups from target domain
    if ($batch.Groups -and $batch.Groups.Count -gt 0) {
        Write-Verbose "Removing $($batch.Groups.Count) groups from target domain"
        
        foreach ($group in $batch.Groups) {
            try {
                # Check if group exists in target domain
                $adGroup = Get-ADGroup -Identity $group -Server $batch.TargetDomain -ErrorAction SilentlyContinue
                
                if ($adGroup) {
                    if ($Force) {
                        # Remove group without confirmation
                        Remove-ADGroup -Identity $group -Server $batch.TargetDomain -Confirm:$false -ErrorAction Stop
                        Write-Verbose "Removed group: $group"
                        $rollbackResults.GroupsRemoved += $group
                    } else {
                        Write-Warning "Group $group exists but -Force not specified. Skipping."
                    }
                } else {
                    Write-Verbose "Group $group not found in target domain. Already removed or never migrated."
                }
            } catch {
                $errorMsg = "Failed to remove group $group : $_"
                Write-Error $errorMsg
                $rollbackResults.Errors += $errorMsg
            }
        }
    }
    
    # Update batch status
    $batch.Status = "RolledBack"
    $batch.RollbackTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $batch.RollbackResults = $rollbackResults
    $batch | ConvertTo-Json -Depth 10 | Out-File $batchPath -Force
    
    # Save rollback log
    $rollbackLogPath = Split-Path $batchPath
    $rollbackLogFile = Join-Path $rollbackLogPath "rollback_$BatchId.json"
    $rollbackResults | ConvertTo-Json -Depth 10 | Out-File $rollbackLogFile
    
    # Output summary
    Write-Output "========================================" 
    Write-Output "Rollback completed for batch $BatchId"
    Write-Output "========================================"
    Write-Output "Users removed: $($rollbackResults.UsersRemoved.Count)"
    Write-Output "Computers removed: $($rollbackResults.ComputersRemoved.Count)"
    Write-Output "Groups removed: $($rollbackResults.GroupsRemoved.Count)"
    Write-Output "Errors encountered: $($rollbackResults.Errors.Count)"
    Write-Output "========================================" 
    Write-Output "Rollback log saved to: $rollbackLogFile"
    
    return $rollbackResults
}

# Export functions
Export-ModuleMember -Function @(
    'Test-ADMTPrerequisites',
    'Get-ADMTMigrationStatus',
    'Export-ADMTReport',
    'New-ADMTMigrationBatch',
    'Invoke-ADMTRollback'
)

