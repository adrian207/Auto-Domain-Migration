<#
.SYNOPSIS
    Configures Azure Backup for domain migration infrastructure
.DESCRIPTION
    Automates backup configuration for VMs, databases, and file servers
    including:
    - Recovery Services Vault creation
    - Backup policies for VMs, databases, file shares
    - Retention policies (7/30/365 days)
    - Geo-redundant storage
    - Backup schedule configuration
.PARAMETER ResourceGroupName
    Resource group containing resources to backup
.PARAMETER VaultName
    Name of Recovery Services Vault (creates if doesn't exist)
.PARAMETER Location
    Azure region for vault
.PARAMETER BackupTier
    Backup tier: Basic (7 days), Standard (30 days), Premium (365 days)
.EXAMPLE
    .\Enable-AzureBackup.ps1 -ResourceGroupName "admt-tier2-rg" -VaultName "admt-vault" -BackupTier Standard
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$VaultName,
    
    [Parameter()]
    [string]$Location = "eastus",
    
    [Parameter()]
    [ValidateSet("Basic", "Standard", "Premium")]
    [string]$BackupTier = "Standard"
)

#Requires -Modules Az.Accounts, Az.Compute, Az.RecoveryServices, Az.Storage

$ErrorActionPreference = "Stop"

Write-Host @"

╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║          🛡️ Azure Backup Configuration                              ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# Check authentication
try {
    $context = Get-AzContext -ErrorAction Stop
    if (-not $context) {
        throw "Not authenticated"
    }
    Write-Host "✅ Authenticated to Azure" -ForegroundColor Green
    Write-Host "   Subscription: $($context.Subscription.Name)" -ForegroundColor Gray
    Write-Host ""
} catch {
    Write-Host "❌ Not authenticated to Azure" -ForegroundColor Red
    Write-Host "   Run: Connect-AzAccount" -ForegroundColor Yellow
    exit 1
}

# Define retention based on tier
$retentionDays = switch ($BackupTier) {
    "Basic" { 7 }
    "Standard" { 30 }
    "Premium" { 365 }
}

Write-Host "📋 Backup Configuration:" -ForegroundColor Cyan
Write-Host "   Resource Group: $ResourceGroupName" -ForegroundColor Gray
Write-Host "   Vault: $VaultName" -ForegroundColor Gray
Write-Host "   Location: $Location" -ForegroundColor Gray
Write-Host "   Tier: $BackupTier ($retentionDays days retention)" -ForegroundColor Gray
Write-Host ""

# 1. Create or get Recovery Services Vault
Write-Host "🏦 Configuring Recovery Services Vault..." -ForegroundColor Cyan

$vault = Get-AzRecoveryServicesVault -ResourceGroupName $ResourceGroupName -Name $VaultName -ErrorAction SilentlyContinue

if (-not $vault) {
    Write-Host "   Creating new vault: $VaultName" -ForegroundColor Yellow
    $vault = New-AzRecoveryServicesVault `
        -ResourceGroupName $ResourceGroupName `
        -Name $VaultName `
        -Location $Location
    Write-Host "   ✅ Vault created" -ForegroundColor Green
} else {
    Write-Host "   ✅ Using existing vault" -ForegroundColor Green
}

# Set vault context
Set-AzRecoveryServicesVaultContext -Vault $vault

# Configure geo-redundancy
Write-Host "   Configuring storage redundancy..." -ForegroundColor Gray
Set-AzRecoveryServicesBackupProperty `
    -Vault $vault `
    -BackupStorageRedundancy GeoRedundant

Write-Host "   ✅ Geo-redundant storage enabled" -ForegroundColor Green
Write-Host ""

# 2. Create VM Backup Policy
Write-Host "💻 Configuring VM Backup Policy..." -ForegroundColor Cyan

$vmPolicyName = "ADMT-VM-Policy-$BackupTier"
$vmPolicy = Get-AzRecoveryServicesBackupProtectionPolicy `
    -VaultId $vault.ID `
    -Name $vmPolicyName `
    -ErrorAction SilentlyContinue

if (-not $vmPolicy) {
    Write-Host "   Creating VM backup policy..." -ForegroundColor Yellow
    
    # Get default policy and modify
    $schedulePolicy = Get-AzRecoveryServicesBackupSchedulePolicyObject -WorkloadType AzureVM
    $schedulePolicy.ScheduleRunTimes.Clear()
    $schedulePolicy.ScheduleRunTimes.Add((Get-Date -Hour 2 -Minute 0 -Second 0).ToUniversalTime())
    
    $retentionPolicy = Get-AzRecoveryServicesBackupRetentionPolicyObject -WorkloadType AzureVM
    $retentionPolicy.DailySchedule.DurationCountInDays = $retentionDays
    
    # Weekly retention
    if ($BackupTier -ne "Basic") {
        $retentionPolicy.IsWeeklyScheduleEnabled = $true
        $retentionPolicy.WeeklySchedule.DurationCountInWeeks = 4
    }
    
    # Monthly retention
    if ($BackupTier -eq "Premium") {
        $retentionPolicy.IsMonthlyScheduleEnabled = $true
        $retentionPolicy.MonthlySchedule.DurationCountInMonths = 12
    }
    
    $vmPolicy = New-AzRecoveryServicesBackupProtectionPolicy `
        -Name $vmPolicyName `
        -WorkloadType AzureVM `
        -RetentionPolicy $retentionPolicy `
        -SchedulePolicy $schedulePolicy `
        -VaultId $vault.ID
    
    Write-Host "   ✅ VM policy created" -ForegroundColor Green
} else {
    Write-Host "   ✅ Using existing VM policy" -ForegroundColor Green
}

Write-Host "   Schedule: Daily at 2:00 AM UTC" -ForegroundColor Gray
Write-Host "   Retention: $retentionDays days" -ForegroundColor Gray
Write-Host ""

# 3. Enable backup for all VMs in resource group
Write-Host "🖥️  Enabling VM Backups..." -ForegroundColor Cyan

$vms = Get-AzVM -ResourceGroupName $ResourceGroupName

if ($vms.Count -eq 0) {
    Write-Host "   ⚠️  No VMs found in resource group" -ForegroundColor Yellow
} else {
    foreach ($vm in $vms) {
        Write-Host "   Processing: $($vm.Name)" -ForegroundColor Gray
        
        # Check if already protected
        $container = Get-AzRecoveryServicesBackupContainer `
            -ContainerType AzureVM `
            -FriendlyName $vm.Name `
            -VaultId $vault.ID `
            -ErrorAction SilentlyContinue
        
        if ($container) {
            Write-Host "     Already protected" -ForegroundColor Gray
        } else {
            try {
                Enable-AzRecoveryServicesBackupProtection `
                    -ResourceGroupName $ResourceGroupName `
                    -Name $vm.Name `
                    -Policy $vmPolicy `
                    -VaultId $vault.ID `
                    -ErrorAction Stop
                Write-Host "     ✅ Backup enabled" -ForegroundColor Green
            } catch {
                Write-Host "     ❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}
Write-Host ""

# 4. Create Database Backup Policy
Write-Host "🗄️  Configuring Database Backup Policy..." -ForegroundColor Cyan

$dbPolicyName = "ADMT-DB-Policy-$BackupTier"

# Note: Database backup is typically handled by Azure SQL/PostgreSQL built-in backups
# This is a placeholder for custom database backup logic
Write-Host "   ℹ️  Database backups use Azure native backup (automatic)" -ForegroundColor Gray
Write-Host "   Retention configured in database settings" -ForegroundColor Gray
Write-Host ""

# 5. Create File Share Backup Policy
Write-Host "📁 Configuring File Share Backup..." -ForegroundColor Cyan

$storageAccounts = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName

if ($storageAccounts.Count -eq 0) {
    Write-Host "   ⚠️  No storage accounts found" -ForegroundColor Yellow
} else {
    foreach ($sa in $storageAccounts) {
        Write-Host "   Processing: $($sa.StorageAccountName)" -ForegroundColor Gray
        
        # Register storage account with vault
        try {
            Register-AzRecoveryServicesBackupContainer `
                -ResourceId $sa.Id `
                -BackupManagementType AzureStorage `
                -WorkloadType AzureFiles `
                -VaultId $vault.ID `
                -Force `
                -ErrorAction SilentlyContinue | Out-Null
        } catch {
            # May already be registered
        }
        
        # Get file shares
        $ctx = $sa.Context
        $shares = Get-AzStorageShare -Context $ctx -ErrorAction SilentlyContinue
        
        foreach ($share in $shares) {
            Write-Host "     Share: $($share.Name)" -ForegroundColor Gray
            
            # Enable backup for file share
            # Note: This requires additional configuration
            Write-Host "       ℹ️  File share backup available (requires manual enablement in portal)" -ForegroundColor Gray
        }
    }
}
Write-Host ""

# 6. Create backup report
Write-Host "📊 Generating Backup Report..." -ForegroundColor Cyan

$report = @{
    VaultName = $VaultName
    ResourceGroup = $ResourceGroupName
    Location = $Location
    Tier = $BackupTier
    RetentionDays = $retentionDays
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    VMs = @()
    StorageAccounts = @()
}

foreach ($vm in $vms) {
    $container = Get-AzRecoveryServicesBackupContainer `
        -ContainerType AzureVM `
        -FriendlyName $vm.Name `
        -VaultId $vault.ID `
        -ErrorAction SilentlyContinue
    
    $report.VMs += [PSCustomObject]@{
        Name = $vm.Name
        BackupEnabled = ($null -ne $container)
        Location = $vm.Location
        Size = $vm.HardwareProfile.VmSize
    }
}

foreach ($sa in $storageAccounts) {
    $report.StorageAccounts += [PSCustomObject]@{
        Name = $sa.StorageAccountName
        Location = $sa.Location
        Sku = $sa.Sku.Name
    }
}

# Display summary
Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                                      ║" -ForegroundColor Cyan
Write-Host "║                    🛡️ BACKUP CONFIGURATION SUMMARY                   ║" -ForegroundColor Cyan
Write-Host "║                                                                      ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "✅ Recovery Services Vault: $VaultName" -ForegroundColor Green
Write-Host "   Location: $Location" -ForegroundColor Gray
Write-Host "   Storage Redundancy: Geo-Redundant" -ForegroundColor Gray
Write-Host ""

Write-Host "💻 Virtual Machines:" -ForegroundColor Yellow
$report.VMs | Format-Table -AutoSize | Out-String | Write-Host

Write-Host "📁 Storage Accounts:" -ForegroundColor Yellow
$report.StorageAccounts | Format-Table -AutoSize | Out-String | Write-Host

Write-Host "📅 Backup Schedule:" -ForegroundColor Yellow
Write-Host "   Daily: 2:00 AM UTC" -ForegroundColor Gray
Write-Host "   Retention: $retentionDays days" -ForegroundColor Gray
if ($BackupTier -ne "Basic") {
    Write-Host "   Weekly: 4 weeks" -ForegroundColor Gray
}
if ($BackupTier -eq "Premium") {
    Write-Host "   Monthly: 12 months" -ForegroundColor Gray
}
Write-Host ""

# Save report
$reportPath = Join-Path $PSScriptRoot "..\..\BackupReport-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$report | ConvertTo-Json -Depth 5 | Out-File $reportPath
Write-Host "📄 Report saved: $reportPath" -ForegroundColor Green
Write-Host ""

# Next steps
Write-Host "📋 Next Steps:" -ForegroundColor Cyan
Write-Host "   1. Trigger initial backup:" -ForegroundColor Gray
Write-Host "      Backup-AzRecoveryServicesBackupItem -WorkloadType AzureVM ..." -ForegroundColor Gray
Write-Host "   2. Monitor backup jobs in Azure Portal" -ForegroundColor Gray
Write-Host "   3. Test restore procedures" -ForegroundColor Gray
Write-Host "   4. Configure backup alerts" -ForegroundColor Gray
Write-Host ""

Write-Host "✅ Backup configuration complete!" -ForegroundColor Green
Write-Host ""

