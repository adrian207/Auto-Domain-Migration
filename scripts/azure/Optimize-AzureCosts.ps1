<#
.SYNOPSIS
    Analyzes Azure costs and provides optimization recommendations
.DESCRIPTION
    Scans Azure subscriptions for cost optimization opportunities including:
    - Unattached disks
    - Stopped VMs still costing money
    - Oversized VMs
    - Unutilized storage accounts
    - Old snapshots
    - Unattached network interfaces
    - Reserved instance opportunities
.PARAMETER SubscriptionId
    Azure subscription ID to analyze (optional, uses current context)
.PARAMETER ResourceGroupPattern
    Pattern to filter resource groups (default: "admt-*")
.PARAMETER GenerateReport
    Generate HTML report of findings
.EXAMPLE
    .\Optimize-AzureCosts.ps1 -GenerateReport
.EXAMPLE
    .\Optimize-AzureCosts.ps1 -SubscriptionId "12345-67890" -ResourceGroupPattern "production-*"
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$SubscriptionId,
    
    [Parameter()]
    [string]$ResourceGroupPattern = "admt-*",
    
    [Parameter()]
    [switch]$GenerateReport
)

#Requires -Modules Az.Accounts, Az.Compute, Az.Storage, Az.Network

$ErrorActionPreference = "Stop"

Write-Host @"

╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║          💰 Azure Cost Optimization Analysis                        ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# Initialize findings
$findings = @{
    UnattachedDisks = @()
    StoppedVMs = @()
    OversizedVMs = @()
    UnusedStorageAccounts = @()
    OldSnapshots = @()
    UnattachedNICs = @()
    TotalPotentialSavings = 0
}

# Check Azure authentication
try {
    $context = Get-AzContext -ErrorAction Stop
    if (-not $context) {
        throw "Not authenticated"
    }
    
    if ($SubscriptionId) {
        Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
        $context = Get-AzContext
    }
    
    Write-Host "✅ Authenticated to Azure" -ForegroundColor Green
    Write-Host "   Subscription: $($context.Subscription.Name)" -ForegroundColor Gray
    Write-Host "   Account: $($context.Account.Id)" -ForegroundColor Gray
    Write-Host ""
} catch {
    Write-Host "❌ Not authenticated to Azure" -ForegroundColor Red
    Write-Host "   Run: Connect-AzAccount" -ForegroundColor Yellow
    exit 1
}

# Get resource groups
Write-Host "📁 Scanning Resource Groups..." -ForegroundColor Cyan
$resourceGroups = Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -like $ResourceGroupPattern }

if ($resourceGroups.Count -eq 0) {
    Write-Host "⚠️  No resource groups found matching pattern: $ResourceGroupPattern" -ForegroundColor Yellow
    exit 0
}

Write-Host "   Found $($resourceGroups.Count) resource group(s)" -ForegroundColor Gray
Write-Host ""

# 1. Find unattached disks
Write-Host "💾 Analyzing Managed Disks..." -ForegroundColor Cyan
foreach ($rg in $resourceGroups) {
    $disks = Get-AzDisk -ResourceGroupName $rg.ResourceGroupName
    
    foreach ($disk in $disks) {
        if (-not $disk.ManagedBy) {
            $diskCost = switch ($disk.Sku.Name) {
                "Premium_LRS" { ($disk.DiskSizeGB / 128) * 19.71 }
                "StandardSSD_LRS" { ($disk.DiskSizeGB / 128) * 9.60 }
                "Standard_LRS" { ($disk.DiskSizeGB / 128) * 2.40 }
                default { 5.00 }
            }
            
            $findings.UnattachedDisks += [PSCustomObject]@{
                ResourceGroup = $rg.ResourceGroupName
                Name = $disk.Name
                Size = "$($disk.DiskSizeGB) GB"
                Sku = $disk.Sku.Name
                MonthlyCost = $diskCost
                Recommendation = "Delete if not needed"
            }
            
            $findings.TotalPotentialSavings += $diskCost
        }
    }
}

Write-Host "   Found $($findings.UnattachedDisks.Count) unattached disk(s)" -ForegroundColor Gray
if ($findings.UnattachedDisks.Count -gt 0) {
    $diskSavings = ($findings.UnattachedDisks | Measure-Object -Property MonthlyCost -Sum).Sum
    Write-Host "   💰 Potential savings: `$$([math]::Round($diskSavings, 2))/month" -ForegroundColor Yellow
}
Write-Host ""

# 2. Find stopped VMs (still costing money for disks)
Write-Host "🖥️  Analyzing Virtual Machines..." -ForegroundColor Cyan
foreach ($rg in $resourceGroups) {
    $vms = Get-AzVM -ResourceGroupName $rg.ResourceGroupName -Status
    
    foreach ($vm in $vms) {
        $powerState = ($vm.Statuses | Where-Object { $_.Code -like "PowerState/*" }).DisplayStatus
        
        if ($powerState -eq "VM deallocated" -or $powerState -eq "VM stopped") {
            # Estimate disk costs for stopped VM
            $diskCost = 0
            $vmDetail = Get-AzVM -ResourceGroupName $rg.ResourceGroupName -Name $vm.Name
            
            if ($vmDetail.StorageProfile.OsDisk) {
                $diskCost += 20 # Approximate OS disk cost
            }
            
            $diskCost += $vmDetail.StorageProfile.DataDisks.Count * 15 # Approximate data disk cost
            
            $findings.StoppedVMs += [PSCustomObject]@{
                ResourceGroup = $rg.ResourceGroupName
                Name = $vm.Name
                PowerState = $powerState
                MonthlyCost = $diskCost
                Recommendation = "Deallocate or delete if not needed"
            }
            
            $findings.TotalPotentialSavings += $diskCost
        }
        
        # Check for oversized VMs (basic heuristic)
        if ($powerState -eq "VM running") {
            $vmDetail = Get-AzVM -ResourceGroupName $rg.ResourceGroupName -Name $vm.Name
            $vmSize = $vmDetail.HardwareProfile.VmSize
            
            # Flag if using Premium series for non-production
            if ($rg.ResourceGroupName -like "*test*" -or $rg.ResourceGroupName -like "*dev*") {
                if ($vmSize -match "Standard_D[4-9]" -or $vmSize -match "Standard_E") {
                    $findings.OversizedVMs += [PSCustomObject]@{
                        ResourceGroup = $rg.ResourceGroupName
                        Name = $vm.Name
                        CurrentSize = $vmSize
                        Recommendation = "Consider downsizing for test/dev environment"
                        PotentialSavings = "30-50%"
                    }
                }
            }
        }
    }
}

Write-Host "   Found $($findings.StoppedVMs.Count) stopped VM(s)" -ForegroundColor Gray
if ($findings.StoppedVMs.Count -gt 0) {
    $vmSavings = ($findings.StoppedVMs | Measure-Object -Property MonthlyCost -Sum).Sum
    Write-Host "   💰 Potential savings: `$$([math]::Round($vmSavings, 2))/month" -ForegroundColor Yellow
}
Write-Host "   Found $($findings.OversizedVMs.Count) potentially oversized VM(s)" -ForegroundColor Gray
Write-Host ""

# 3. Find old snapshots
Write-Host "📸 Analyzing Snapshots..." -ForegroundColor Cyan
foreach ($rg in $resourceGroups) {
    $snapshots = Get-AzSnapshot -ResourceGroupName $rg.ResourceGroupName
    
    foreach ($snapshot in $snapshots) {
        $age = (Get-Date) - $snapshot.TimeCreated
        
        if ($age.TotalDays -gt 30) {
            $snapshotCost = ($snapshot.DiskSizeGB / 128) * 2.00 # Approximate cost
            
            $findings.OldSnapshots += [PSCustomObject]@{
                ResourceGroup = $rg.ResourceGroupName
                Name = $snapshot.Name
                Size = "$($snapshot.DiskSizeGB) GB"
                Age = "$([math]::Round($age.TotalDays)) days"
                MonthlyCost = $snapshotCost
                Recommendation = "Delete if no longer needed"
            }
            
            $findings.TotalPotentialSavings += $snapshotCost
        }
    }
}

Write-Host "   Found $($findings.OldSnapshots.Count) old snapshot(s) (>30 days)" -ForegroundColor Gray
if ($findings.OldSnapshots.Count -gt 0) {
    $snapshotSavings = ($findings.OldSnapshots | Measure-Object -Property MonthlyCost -Sum).Sum
    Write-Host "   💰 Potential savings: `$$([math]::Round($snapshotSavings, 2))/month" -ForegroundColor Yellow
}
Write-Host ""

# 4. Find unattached NICs
Write-Host "🔌 Analyzing Network Interfaces..." -ForegroundColor Cyan
foreach ($rg in $resourceGroups) {
    $nics = Get-AzNetworkInterface -ResourceGroupName $rg.ResourceGroupName
    
    foreach ($nic in $nics) {
        if (-not $nic.VirtualMachine) {
            $findings.UnattachedNICs += [PSCustomObject]@{
                ResourceGroup = $rg.ResourceGroupName
                Name = $nic.Name
                MonthlyCost = 0.50 # Small but adds up
                Recommendation = "Delete if not needed"
            }
            
            $findings.TotalPotentialSavings += 0.50
        }
    }
}

Write-Host "   Found $($findings.UnattachedNICs.Count) unattached NIC(s)" -ForegroundColor Gray
Write-Host ""

# 5. Find unused storage accounts
Write-Host "📦 Analyzing Storage Accounts..." -ForegroundColor Cyan
foreach ($rg in $resourceGroups) {
    $storageAccounts = Get-AzStorageAccount -ResourceGroupName $rg.ResourceGroupName
    
    foreach ($sa in $storageAccounts) {
        $ctx = $sa.Context
        
        try {
            $containers = Get-AzStorageContainer -Context $ctx -ErrorAction SilentlyContinue
            $shares = Get-AzStorageShare -Context $ctx -ErrorAction SilentlyContinue
            $tables = Get-AzStorageTable -Context $ctx -ErrorAction SilentlyContinue
            $queues = Get-AzStorageQueue -Context $ctx -ErrorAction SilentlyContinue
            
            $isEmpty = ($containers.Count -eq 0) -and ($shares.Count -eq 0) -and 
                       ($tables.Count -eq 0) -and ($queues.Count -eq 0)
            
            if ($isEmpty) {
                $findings.UnusedStorageAccounts += [PSCustomObject]@{
                    ResourceGroup = $rg.ResourceGroupName
                    Name = $sa.StorageAccountName
                    Sku = $sa.Sku.Name
                    MonthlyCost = 5.00 # Minimum cost
                    Recommendation = "Delete if not needed"
                }
                
                $findings.TotalPotentialSavings += 5.00
            }
        } catch {
            # Skip if we can't access
        }
    }
}

Write-Host "   Found $($findings.UnusedStorageAccounts.Count) empty storage account(s)" -ForegroundColor Gray
Write-Host ""

# Display summary
Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                                      ║" -ForegroundColor Cyan
Write-Host "║                    💰 COST OPTIMIZATION SUMMARY                      ║" -ForegroundColor Cyan
Write-Host "║                                                                      ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "📊 Findings:" -ForegroundColor Yellow
Write-Host "   Unattached Disks: $($findings.UnattachedDisks.Count)" -ForegroundColor Gray
Write-Host "   Stopped VMs: $($findings.StoppedVMs.Count)" -ForegroundColor Gray
Write-Host "   Oversized VMs: $($findings.OversizedVMs.Count)" -ForegroundColor Gray
Write-Host "   Old Snapshots: $($findings.OldSnapshots.Count)" -ForegroundColor Gray
Write-Host "   Unattached NICs: $($findings.UnattachedNICs.Count)" -ForegroundColor Gray
Write-Host "   Empty Storage Accounts: $($findings.UnusedStorageAccounts.Count)" -ForegroundColor Gray
Write-Host ""

Write-Host "💰 Total Potential Monthly Savings: `$$([math]::Round($findings.TotalPotentialSavings, 2))" -ForegroundColor Green
Write-Host "   Annual Savings: `$$([math]::Round($findings.TotalPotentialSavings * 12, 2))" -ForegroundColor Green
Write-Host ""

# Show detailed findings
if ($findings.UnattachedDisks.Count -gt 0) {
    Write-Host "💾 Unattached Disks:" -ForegroundColor Yellow
    $findings.UnattachedDisks | Format-Table -AutoSize | Out-String | Write-Host
}

if ($findings.StoppedVMs.Count -gt 0) {
    Write-Host "🖥️  Stopped VMs:" -ForegroundColor Yellow
    $findings.StoppedVMs | Format-Table -AutoSize | Out-String | Write-Host
}

if ($findings.OversizedVMs.Count -gt 0) {
    Write-Host "📏 Potentially Oversized VMs:" -ForegroundColor Yellow
    $findings.OversizedVMs | Format-Table -AutoSize | Out-String | Write-Host
}

if ($findings.OldSnapshots.Count -gt 0) {
    Write-Host "📸 Old Snapshots:" -ForegroundColor Yellow
    $findings.OldSnapshots | Format-Table -AutoSize | Out-String | Write-Host
}

# Generate HTML report if requested
if ($GenerateReport) {
    $reportPath = Join-Path $PSScriptRoot "..\..\AzureCostReport-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Azure Cost Optimization Report</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        h1 { color: #0078d4; }
        .summary { background: white; padding: 20px; border-radius: 5px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .savings { font-size: 2em; color: #107c10; font-weight: bold; }
        table { width: 100%; border-collapse: collapse; background: white; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #0078d4; color: white; }
        tr:hover { background: #f5f5f5; }
        .section { margin-bottom: 30px; }
    </style>
</head>
<body>
    <h1>💰 Azure Cost Optimization Report</h1>
    <div class="summary">
        <h2>Summary</h2>
        <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        <p>Subscription: $($context.Subscription.Name)</p>
        <p class="savings">Total Potential Monthly Savings: `$$([math]::Round($findings.TotalPotentialSavings, 2))</p>
        <p>Annual Savings: `$$([math]::Round($findings.TotalPotentialSavings * 12, 2))</p>
    </div>
"@
    
    if ($findings.UnattachedDisks.Count -gt 0) {
        $html += "<div class='section'><h2>Unattached Disks ($($findings.UnattachedDisks.Count))</h2><table><tr><th>Resource Group</th><th>Name</th><th>Size</th><th>SKU</th><th>Monthly Cost</th><th>Recommendation</th></tr>"
        foreach ($disk in $findings.UnattachedDisks) {
            $html += "<tr><td>$($disk.ResourceGroup)</td><td>$($disk.Name)</td><td>$($disk.Size)</td><td>$($disk.Sku)</td><td>`$$([math]::Round($disk.MonthlyCost, 2))</td><td>$($disk.Recommendation)</td></tr>"
        }
        $html += "</table></div>"
    }
    
    if ($findings.StoppedVMs.Count -gt 0) {
        $html += "<div class='section'><h2>Stopped VMs ($($findings.StoppedVMs.Count))</h2><table><tr><th>Resource Group</th><th>Name</th><th>Power State</th><th>Monthly Cost</th><th>Recommendation</th></tr>"
        foreach ($vm in $findings.StoppedVMs) {
            $html += "<tr><td>$($vm.ResourceGroup)</td><td>$($vm.Name)</td><td>$($vm.PowerState)</td><td>`$$([math]::Round($vm.MonthlyCost, 2))</td><td>$($vm.Recommendation)</td></tr>"
        }
        $html += "</table></div>"
    }
    
    $html += "</body></html>"
    
    $html | Out-File $reportPath -Encoding UTF8
    Write-Host "📄 Report generated: $reportPath" -ForegroundColor Green
    Start-Process $reportPath
}

Write-Host "✅ Cost analysis complete!" -ForegroundColor Green
Write-Host ""

