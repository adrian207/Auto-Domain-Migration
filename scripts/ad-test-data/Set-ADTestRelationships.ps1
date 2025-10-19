# Relationship Creation Script
# Purpose: Set group memberships and manager hierarchies

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Tier1", "Tier2", "Tier3")]
    [string]$Tier,
    
    [Parameter(Mandatory=$true)]
    [string]$DomainDN
)

Write-Host "Creating relationships..." -ForegroundColor Yellow

$departments = @("IT", "HR", "Finance", "Engineering", "Sales", "Marketing")
$membershipsAdded = 0
$managersSet = 0

# Step 1: Add users to department groups
Write-Host "`nAdding users to department security groups..." -ForegroundColor Cyan

foreach ($dept in $departments) {
    try {
        $deptGroup = Get-ADGroup -Filter "Name -eq 'G-$dept-Team'" -ErrorAction Stop
        $deptOUPath = "OU=Users,OU=$dept,OU=Departments,$DomainDN"
        
        $users = Get-ADUser -Filter * -SearchBase $deptOUPath -ErrorAction SilentlyContinue
        
        if ($users) {
            foreach ($user in $users) {
                try {
                    Add-ADGroupMember -Identity $deptGroup -Members $user -ErrorAction SilentlyContinue
                    $membershipsAdded++
                } catch {
                    # Ignore already member errors
                }
            }
            Write-Host "  ✓ Added $($users.Count) users to G-$dept-Team" -ForegroundColor Green
        }
    } catch {
        Write-Warning "  Failed to process $dept`: $_"
    }
}

# Step 2: Add users to distribution lists
Write-Host "`nAdding users to distribution lists..." -ForegroundColor Cyan

# Add all users to DL-All-Employees
try {
    $allEmployeesDL = Get-ADGroup -Filter "Name -eq 'DL-All-Employees'" -ErrorAction Stop
    $allUsers = Get-ADUser -Filter * -SearchBase "OU=Departments,$DomainDN"
    
    foreach ($user in $allUsers) {
        try {
            Add-ADGroupMember -Identity $allEmployeesDL -Members $user -ErrorAction SilentlyContinue
            $membershipsAdded++
        } catch {}
    }
    
    Write-Host "  ✓ Added all users to DL-All-Employees" -ForegroundColor Green
} catch {
    Write-Warning "  Failed to add users to DL-All-Employees"
}

# Add users to department distribution lists
foreach ($dept in $departments) {
    try {
        $deptDL = Get-ADGroup -Filter "Name -eq 'DL-$dept-Department'" -ErrorAction Stop
        $deptOUPath = "OU=Users,OU=$dept,OU=Departments,$DomainDN"
        
        $users = Get-ADUser -Filter * -SearchBase $deptOUPath -ErrorAction SilentlyContinue
        
        if ($users) {
            foreach ($user in $users) {
                try {
                    Add-ADGroupMember -Identity $deptDL -Members $user -ErrorAction SilentlyContinue
                    $membershipsAdded++
                } catch {}
            }
            Write-Host "  ✓ Added users to DL-$dept-Department" -ForegroundColor Green
        }
    } catch {
        Write-Warning "  Failed to process DL-$dept-Department"
    }
}

# Step 3: Assign managers (10% of each department as managers)
Write-Host "`nAssigning manager relationships..." -ForegroundColor Cyan

foreach ($dept in $departments) {
    try {
        $deptOUPath = "OU=Users,OU=$dept,OU=Departments,$DomainDN"
        $users = Get-ADUser -Filter * -SearchBase $deptOUPath -ErrorAction SilentlyContinue
        
        if ($users -and $users.Count -gt 5) {
            # Select 10% as managers (minimum 1, maximum 20)
            $managerCount = [math]::Max(1, [math]::Min(20, [math]::Floor($users.Count * 0.10)))
            $managers = $users | Get-Random -Count $managerCount
            
            # Get manager group
            $managerGroup = Get-ADGroup -Filter "Name -eq 'G-$dept-Managers'" -ErrorAction SilentlyContinue
            $allManagersGroup = Get-ADGroup -Filter "Name -eq 'G-Managers'" -ErrorAction SilentlyContinue
            
            foreach ($manager in $managers) {
                # Update job title to include "Manager"
                if ($manager.Title -notlike "*Manager*" -and $manager.Title -notlike "*Director*") {
                    try {
                        $newTitle = $manager.Title -replace "^Senior ", "Manager - "
                        if ($newTitle -eq $manager.Title) {
                            $newTitle = "Manager - $($manager.Title)"
                        }
                        Set-ADUser -Identity $manager -Title $newTitle -ErrorAction SilentlyContinue
                    } catch {}
                }
                
                # Add to manager groups
                if ($managerGroup) {
                    try {
                        Add-ADGroupMember -Identity $managerGroup -Members $manager -ErrorAction SilentlyContinue
                    } catch {}
                }
                
                if ($allManagersGroup) {
                    try {
                        Add-ADGroupMember -Identity $allManagersGroup -Members $manager -ErrorAction SilentlyContinue
                    } catch {}
                }
                
                # Assign 3-8 direct reports to this manager
                $reportCount = Get-Random -Minimum 3 -Maximum 8
                $directReports = $users | Where-Object { $_.DistinguishedName -ne $manager.DistinguishedName } | Get-Random -Count $reportCount
                
                foreach ($report in $directReports) {
                    try {
                        Set-ADUser -Identity $report -Manager $manager -ErrorAction SilentlyContinue
                        $managersSet++
                    } catch {}
                }
            }
            
            Write-Host "  ✓ Assigned $managerCount managers in $dept with direct reports" -ForegroundColor Green
        }
    } catch {
        Write-Warning "  Failed to assign managers for $dept`: $_"
    }
}

# Step 4: Add executives to executive group
Write-Host "`nConfiguring executive relationships..." -ForegroundColor Cyan

try {
    $execGroup = Get-ADGroup -Filter "Name -eq 'G-Executives'" -ErrorAction Stop
    $execOUPath = "OU=Executives,OU=Users,OU=Corporate,$DomainDN"
    
    $execs = Get-ADUser -Filter * -SearchBase $execOUPath -ErrorAction SilentlyContinue
    
    if ($execs) {
        foreach ($exec in $execs) {
            try {
                Add-ADGroupMember -Identity $execGroup -Members $exec -ErrorAction SilentlyContinue
                $membershipsAdded++
            } catch {}
        }
        Write-Host "  ✓ Added executives to G-Executives group" -ForegroundColor Green
    }
} catch {
    Write-Warning "  Failed to configure executive group"
}

# Step 5: Add IT admins to admin groups
Write-Host "`nConfiguring IT admin relationships..." -ForegroundColor Cyan

try {
    $itAdminGroup = Get-ADGroup -Filter "Name -eq 'G-IT-Admins'" -ErrorAction Stop
    $itOUPath = "OU=Users,OU=IT,OU=Departments,$DomainDN"
    
    $itUsers = Get-ADUser -Filter * -SearchBase $itOUPath -ErrorAction SilentlyContinue
    
    if ($itUsers) {
        # Select 20% of IT staff as admins
        $adminCount = [math]::Max(2, [math]::Floor($itUsers.Count * 0.20))
        $admins = $itUsers | Where-Object { $_.Title -like "*Admin*" -or $_.Title -like "*Manager*" -or $_.Title -like "*Director*" } | 
            Select-Object -First $adminCount
        
        if (-not $admins) {
            $admins = $itUsers | Get-Random -Count $adminCount
        }
        
        foreach ($admin in $admins) {
            try {
                Add-ADGroupMember -Identity $itAdminGroup -Members $admin -ErrorAction SilentlyContinue
                $membershipsAdded++
            } catch {}
        }
        
        Write-Host "  ✓ Added $($admins.Count) IT staff to G-IT-Admins" -ForegroundColor Green
    }
} catch {
    Write-Warning "  Failed to configure IT admin group"
}

Write-Host "`n✓ Relationship creation complete!" -ForegroundColor Green
Write-Host "  Group memberships added: $membershipsAdded" -ForegroundColor Yellow
Write-Host "  Manager relationships set: $managersSet" -ForegroundColor Yellow

