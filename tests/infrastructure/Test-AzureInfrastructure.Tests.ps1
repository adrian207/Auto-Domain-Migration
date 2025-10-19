#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.0.0" }
#Requires -Modules Az.Accounts, Az.Resources, Az.Network, Az.Compute

<#
.SYNOPSIS
    Integration tests for Azure infrastructure deployment
.DESCRIPTION
    Validates that Azure infrastructure is deployed correctly across all tiers
#>

BeforeAll {
    # Import required modules
    Import-Module Az.Accounts -ErrorAction Stop
    Import-Module Az.Resources -ErrorAction Stop
    Import-Module Az.Network -ErrorAction Stop
    Import-Module Az.Compute -ErrorAction Stop
    
    # Test configuration
    $script:TestConfig = @{
        Tier1ResourceGroup = "admt-tier1-rg"
        Tier2ResourceGroup = "admt-tier2-rg"
        Tier3ResourceGroup = "admt-tier3-rg"
        Location = "eastus"
    }
    
    # Check if authenticated
    $context = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $context) {
        Write-Warning "Not authenticated to Azure. Tests will be skipped."
        $script:SkipTests = $true
    } else {
        Write-Host "Authenticated as: $($context.Account.Id)" -ForegroundColor Green
        $script:SkipTests = $false
    }
}

Describe "Azure Authentication" {
    It "Should have valid Azure context" {
        $context = Get-AzContext
        $context | Should -Not -BeNullOrEmpty
        $context.Account | Should -Not -BeNullOrEmpty
        $context.Subscription | Should -Not -BeNullOrEmpty
    }
    
    It "Should have required permissions" {
        $context = Get-AzContext
        $subscription = Get-AzSubscription -SubscriptionId $context.Subscription.Id
        $subscription.State | Should -Be "Enabled"
    }
}

Describe "Tier 1 Infrastructure - Free Tier" -Tag "Tier1", "Infrastructure" {
    BeforeAll {
        if ($script:SkipTests) { Set-ItResult -Skipped -Because "Not authenticated to Azure" }
    }
    
    Context "Resource Group" {
        It "Should have Tier 1 resource group" {
            $rg = Get-AzResourceGroup -Name $TestConfig.Tier1ResourceGroup -ErrorAction SilentlyContinue
            $rg | Should -Not -BeNullOrEmpty
            $rg.Location | Should -Be $TestConfig.Location
            $rg.ProvisioningState | Should -Be "Succeeded"
        }
        
        It "Should have correct tags" {
            $rg = Get-AzResourceGroup -Name $TestConfig.Tier1ResourceGroup
            $rg.Tags | Should -Not -BeNullOrEmpty
            $rg.Tags["Environment"] | Should -BeIn @("Demo", "Tier1", "Development")
        }
    }
    
    Context "Domain Controllers" {
        It "Should have source domain controller VM" {
            $vm = Get-AzVM -ResourceGroupName $TestConfig.Tier1ResourceGroup | 
                  Where-Object { $_.Name -like "*source*dc*" -or $_.Name -like "*dc*source*" }
            $vm | Should -Not -BeNullOrEmpty
            $vm.ProvisioningState | Should -Be "Succeeded"
        }
        
        It "Should have target domain controller VM" {
            $vm = Get-AzVM -ResourceGroupName $TestConfig.Tier1ResourceGroup | 
                  Where-Object { $_.Name -like "*target*dc*" -or $_.Name -like "*dc*target*" }
            $vm | Should -Not -BeNullOrEmpty
            $vm.ProvisioningState | Should -Be "Succeeded"
        }
        
        It "Domain controllers should have appropriate VM size" {
            $vms = Get-AzVM -ResourceGroupName $TestConfig.Tier1ResourceGroup | 
                   Where-Object { $_.Name -like "*dc*" }
            foreach ($vm in $vms) {
                # Free tier typically uses B-series
                $vm.HardwareProfile.VmSize | Should -Match "^(Standard_B|Standard_D)"
            }
        }
    }
    
    Context "File Servers" {
        It "Should have source file server" {
            $vm = Get-AzVM -ResourceGroupName $TestConfig.Tier1ResourceGroup | 
                  Where-Object { $_.Name -like "*source*file*" -or $_.Name -like "*fs*source*" }
            $vm | Should -Not -BeNullOrEmpty
        }
        
        It "Should have target file server" {
            $vm = Get-AzVM -ResourceGroupName $TestConfig.Tier1ResourceGroup | 
                  Where-Object { $_.Name -like "*target*file*" -or $_.Name -like "*fs*target*" }
            $vm | Should -Not -BeNullOrEmpty
        }
        
        It "File servers should have data disks" {
            $vms = Get-AzVM -ResourceGroupName $TestConfig.Tier1ResourceGroup | 
                   Where-Object { $_.Name -like "*file*" -or $_.Name -like "*fs*" }
            foreach ($vm in $vms) {
                $vm.StorageProfile.DataDisks.Count | Should -BeGreaterThan 0
            }
        }
    }
    
    Context "Networking" {
        It "Should have virtual network" {
            $vnet = Get-AzVirtualNetwork -ResourceGroupName $TestConfig.Tier1ResourceGroup
            $vnet | Should -Not -BeNullOrEmpty
            $vnet.ProvisioningState | Should -Be "Succeeded"
        }
        
        It "Should have required subnets" {
            $vnet = Get-AzVirtualNetwork -ResourceGroupName $TestConfig.Tier1ResourceGroup
            $subnetNames = $vnet.Subnets.Name
            $subnetNames | Should -Contain "source-subnet"
            $subnetNames | Should -Contain "target-subnet"
        }
        
        It "Should have network security groups" {
            $nsgs = Get-AzNetworkSecurityGroup -ResourceGroupName $TestConfig.Tier1ResourceGroup
            $nsgs.Count | Should -BeGreaterThan 0
        }
        
        It "NSGs should have security rules" {
            $nsgs = Get-AzNetworkSecurityGroup -ResourceGroupName $TestConfig.Tier1ResourceGroup
            foreach ($nsg in $nsgs) {
                $nsg.SecurityRules.Count | Should -BeGreaterThan 0
            }
        }
    }
    
    Context "Storage" {
        It "Should have storage account" {
            $storage = Get-AzStorageAccount -ResourceGroupName $TestConfig.Tier1ResourceGroup
            $storage | Should -Not -BeNullOrEmpty
        }
        
        It "Storage should have correct configuration" {
            $storage = Get-AzStorageAccount -ResourceGroupName $TestConfig.Tier1ResourceGroup | Select-Object -First 1
            $storage.EnableHttpsTrafficOnly | Should -Be $true
            $storage.Sku.Name | Should -BeIn @("Standard_LRS", "Standard_GRS")
        }
    }
}

Describe "Tier 2 Infrastructure - Production" -Tag "Tier2", "Infrastructure" {
    BeforeAll {
        if ($script:SkipTests) { Set-ItResult -Skipped -Because "Not authenticated to Azure" }
    }
    
    Context "Resource Group" {
        It "Should have Tier 2 resource group" {
            $rg = Get-AzResourceGroup -Name $TestConfig.Tier2ResourceGroup -ErrorAction SilentlyContinue
            if (-not $rg) { Set-ItResult -Skipped -Because "Tier 2 not deployed" }
            $rg.ProvisioningState | Should -Be "Succeeded"
        }
    }
    
    Context "High Availability" {
        It "Should have availability sets or zones" {
            $rg = Get-AzResourceGroup -Name $TestConfig.Tier2ResourceGroup -ErrorAction SilentlyContinue
            if (-not $rg) { Set-ItResult -Skipped -Because "Tier 2 not deployed" }
            
            $availSets = Get-AzAvailabilitySet -ResourceGroupName $TestConfig.Tier2ResourceGroup -ErrorAction SilentlyContinue
            $vms = Get-AzVM -ResourceGroupName $TestConfig.Tier2ResourceGroup
            
            # Should have either availability sets or VMs in zones
            ($availSets.Count -gt 0) -or ($vms | Where-Object { $_.Zones }) | Should -Be $true
        }
    }
    
    Context "Database" {
        It "Should have PostgreSQL database" {
            $rg = Get-AzResourceGroup -Name $TestConfig.Tier2ResourceGroup -ErrorAction SilentlyContinue
            if (-not $rg) { Set-ItResult -Skipped -Because "Tier 2 not deployed" }
            
            # Check for PostgreSQL flexible server
            $db = Get-AzResource -ResourceGroupName $TestConfig.Tier2ResourceGroup -ResourceType "Microsoft.DBforPostgreSQL/flexibleServers"
            $db | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Monitoring" {
        It "Should have Log Analytics workspace" {
            $rg = Get-AzResourceGroup -Name $TestConfig.Tier2ResourceGroup -ErrorAction SilentlyContinue
            if (-not $rg) { Set-ItResult -Skipped -Because "Tier 2 not deployed" }
            
            $workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $TestConfig.Tier2ResourceGroup
            $workspace | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Tier 3 Infrastructure - Enterprise" -Tag "Tier3", "Infrastructure", "AKS" {
    BeforeAll {
        if ($script:SkipTests) { Set-ItResult -Skipped -Because "Not authenticated to Azure" }
    }
    
    Context "Resource Group" {
        It "Should have Tier 3 resource group" {
            $rg = Get-AzResourceGroup -Name $TestConfig.Tier3ResourceGroup -ErrorAction SilentlyContinue
            if (-not $rg) { Set-ItResult -Skipped -Because "Tier 3 not deployed" }
            $rg.ProvisioningState | Should -Be "Succeeded"
        }
    }
    
    Context "AKS Cluster" {
        It "Should have AKS cluster" {
            $rg = Get-AzResourceGroup -Name $TestConfig.Tier3ResourceGroup -ErrorAction SilentlyContinue
            if (-not $rg) { Set-ItResult -Skipped -Because "Tier 3 not deployed" }
            
            $aks = Get-AzAksCluster -ResourceGroupName $TestConfig.Tier3ResourceGroup
            $aks | Should -Not -BeNullOrEmpty
            $aks.ProvisioningState | Should -Be "Succeeded"
        }
        
        It "AKS should have multiple node pools" {
            $rg = Get-AzResourceGroup -Name $TestConfig.Tier3ResourceGroup -ErrorAction SilentlyContinue
            if (-not $rg) { Set-ItResult -Skipped -Because "Tier 3 not deployed" }
            
            $aks = Get-AzAksCluster -ResourceGroupName $TestConfig.Tier3ResourceGroup
            $aks.AgentPoolProfiles.Count | Should -BeGreaterThan 1
        }
        
        It "AKS should have Azure AD integration enabled" {
            $rg = Get-AzResourceGroup -Name $TestConfig.Tier3ResourceGroup -ErrorAction SilentlyContinue
            if (-not $rg) { Set-ItResult -Skipped -Because "Tier 3 not deployed" }
            
            $aks = Get-AzAksCluster -ResourceGroupName $TestConfig.Tier3ResourceGroup
            $aks.AadProfile | Should -Not -BeNullOrEmpty
            $aks.AadProfile.Managed | Should -Be $true
        }
    }
    
    Context "Key Vault" {
        It "Should have Key Vault" {
            $rg = Get-AzResourceGroup -Name $TestConfig.Tier3ResourceGroup -ErrorAction SilentlyContinue
            if (-not $rg) { Set-ItResult -Skipped -Because "Tier 3 not deployed" }
            
            $kv = Get-AzKeyVault -ResourceGroupName $TestConfig.Tier3ResourceGroup
            $kv | Should -Not -BeNullOrEmpty
        }
        
        It "Key Vault should have soft delete enabled" {
            $rg = Get-AzResourceGroup -Name $TestConfig.Tier3ResourceGroup -ErrorAction SilentlyContinue
            if (-not $rg) { Set-ItResult -Skipped -Because "Tier 3 not deployed" }
            
            $kv = Get-AzKeyVault -ResourceGroupName $TestConfig.Tier3ResourceGroup
            $kv.EnableSoftDelete | Should -Be $true
        }
    }
}

Describe "Cost Analysis" -Tag "Cost", "Validation" {
    It "Should track resource costs with tags" {
        if ($script:SkipTests) { Set-ItResult -Skipped -Because "Not authenticated to Azure" }
        
        $allResources = Get-AzResource | Where-Object { $_.ResourceGroupName -like "admt-*" }
        $taggedResources = $allResources | Where-Object { $_.Tags.Count -gt 0 }
        
        # At least 80% of resources should be tagged
        $tagPercentage = ($taggedResources.Count / $allResources.Count) * 100
        $tagPercentage | Should -BeGreaterOrEqual 80
    }
}

Describe "Security Validation" -Tag "Security", "Compliance" {
    Context "Network Security" {
        It "All NSGs should block unnecessary inbound traffic" {
            if ($script:SkipTests) { Set-ItResult -Skipped -Because "Not authenticated to Azure" }
            
            $allNsgs = Get-AzNetworkSecurityGroup | Where-Object { $_.ResourceGroupName -like "admt-*" }
            
            foreach ($nsg in $allNsgs) {
                # Check for overly permissive rules (allow * from Internet)
                $dangerousRules = $nsg.SecurityRules | Where-Object {
                    $_.Direction -eq "Inbound" -and
                    $_.Access -eq "Allow" -and
                    $_.SourceAddressPrefix -eq "*" -and
                    $_.DestinationPortRange -eq "*"
                }
                
                $dangerousRules.Count | Should -Be 0
            }
        }
    }
    
    Context "Storage Security" {
        It "All storage accounts should enforce HTTPS" {
            if ($script:SkipTests) { Set-ItResult -Skipped -Because "Not authenticated to Azure" }
            
            $storageAccounts = Get-AzStorageAccount | Where-Object { $_.ResourceGroupName -like "admt-*" }
            
            foreach ($storage in $storageAccounts) {
                $storage.EnableHttpsTrafficOnly | Should -Be $true
            }
        }
        
        It "Storage accounts should have minimum TLS version" {
            if ($script:SkipTests) { Set-ItResult -Skipped -Because "Not authenticated to Azure" }
            
            $storageAccounts = Get-AzStorageAccount | Where-Object { $_.ResourceGroupName -like "admt-*" }
            
            foreach ($storage in $storageAccounts) {
                $storage.MinimumTlsVersion | Should -BeIn @("TLS1_2", "TLS1_3")
            }
        }
    }
}

AfterAll {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  Infrastructure Validation Complete" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

