# Group Generation Script
# Purpose: Generate security and distribution groups

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Tier1", "Tier2", "Tier3")]
    [string]$Tier,
    
    [Parameter(Mandatory=$true)]
    [string]$DomainDN
)

Write-Host "Creating groups..." -ForegroundColor Yellow

$created = 0
$skipped = 0

# Base paths
$securityGroupPath = "OU=Security,OU=Groups,OU=Corporate,$DomainDN"
$distributionGroupPath = "OU=Distribution,OU=Groups,OU=Corporate,$DomainDN"

# Verify OUs exist
foreach ($path in @($securityGroupPath, $distributionGroupPath)) {
    try {
        $null = Get-ADOrganizationalUnit -Identity $path -ErrorAction Stop
    } catch {
        Write-Warning "OU not found: $path - Some groups may not be created"
    }
}

# Define groups
$departments = @("IT", "HR", "Finance", "Engineering", "Sales", "Marketing")

# Security Groups
Write-Host "`nCreating Security Groups..." -ForegroundColor Cyan

$securityGroups = @(
    @{Name="G-Domain-Admins"; Desc="Domain Administrators"; Scope="Global"},
    @{Name="G-IT-Admins"; Desc="IT Department Administrators"; Scope="Global"},
    @{Name="G-Server-Admins"; Desc="Server Administrators"; Scope="Global"},
    @{Name="G-Help-Desk"; Desc="Help Desk Support Team"; Scope="Global"},
    @{Name="G-Managers"; Desc="All Managers"; Scope="Global"},
    @{Name="G-Executives"; Desc="Executive Leadership Team"; Scope="Global"},
    @{Name="R-VPN-Users"; Desc="VPN Access"; Scope="DomainLocal"},
    @{Name="R-Remote-Desktop-Users"; Desc="Remote Desktop Access"; Scope="DomainLocal"},
    @{Name="R-File-Server-Access"; Desc="File Server Access"; Scope="DomainLocal"}
)

# Add department security groups
foreach ($dept in $departments) {
    $securityGroups += @{
        Name = "G-$dept-Team"
        Desc = "$dept Department Team Members"
        Scope = "Global"
    }
    
    $securityGroups += @{
        Name = "G-$dept-Managers"
        Desc = "$dept Department Managers"
        Scope = "Global"
    }
}

# Add resource groups if Tier 2+
if ($Tier -ne "Tier1") {
    $securityGroups += @(
        @{Name="R-Finance-Share-RW"; Desc="Finance Share - Read/Write"; Scope="DomainLocal"},
        @{Name="R-Finance-Share-RO"; Desc="Finance Share - Read Only"; Scope="DomainLocal"},
        @{Name="R-HR-Share-RW"; Desc="HR Share - Read/Write"; Scope="DomainLocal"},
        @{Name="R-HR-Share-RO"; Desc="HR Share - Read Only"; Scope="DomainLocal"},
        @{Name="R-Engineering-Share-RW"; Desc="Engineering Share - Read/Write"; Scope="DomainLocal"},
        @{Name="R-SQL-Server-Access"; Desc="SQL Server Access"; Scope="DomainLocal"},
        @{Name="R-Application-Server-Access"; Desc="Application Server Access"; Scope="DomainLocal"}
    )
}

foreach ($group in $securityGroups) {
    try {
        $existing = Get-ADGroup -Filter "Name -eq '$($group.Name)'" -ErrorAction SilentlyContinue
        
        if (-not $existing) {
            New-ADGroup -Name $group.Name `
                -GroupScope $group.Scope `
                -GroupCategory Security `
                -Description $group.Desc `
                -Path $securityGroupPath `
                -ErrorAction Stop
            
            Write-Host "  ✓ Created: $($group.Name)" -ForegroundColor Green
            $created++
        } else {
            Write-Host "  ○ Exists: $($group.Name)" -ForegroundColor DarkGray
            $skipped++
        }
    } catch {
        Write-Warning "  ✗ Failed: $($group.Name) - $_"
    }
}

# Distribution Groups
Write-Host "`nCreating Distribution Groups..." -ForegroundColor Cyan

$distributionGroups = @(
    @{Name="DL-All-Employees"; Desc="All Company Employees"},
    @{Name="DL-Company-Announcements"; Desc="Company-Wide Announcements"},
    @{Name="DL-Emergency-Notifications"; Desc="Emergency Notifications"},
    @{Name="DL-Managers"; Desc="All Managers"},
    @{Name="DL-Executives"; Desc="Executive Team"}
)

# Add department distribution lists
foreach ($dept in $departments) {
    $distributionGroups += @{
        Name = "DL-$dept-Department"
        Desc = "$dept Department Distribution List"
    }
    
    $distributionGroups += @{
        Name = "DL-$dept-Team"
        Desc = "$dept Team Communications"
    }
}

# Add location-based DLs for Tier 2+
if ($Tier -ne "Tier1") {
    $locations = @("NewYork", "LosAngeles", "Chicago")
    
    if ($Tier -eq "Tier3") {
        $locations += @("London", "Tokyo", "Sydney")
    }
    
    foreach ($loc in $locations) {
        $distributionGroups += @{
            Name = "DL-Office-$loc"
            Desc = "$loc Office Communications"
        }
    }
}

foreach ($group in $distributionGroups) {
    try {
        $existing = Get-ADGroup -Filter "Name -eq '$($group.Name)'" -ErrorAction SilentlyContinue
        
        if (-not $existing) {
            New-ADGroup -Name $group.Name `
                -GroupScope Universal `
                -GroupCategory Distribution `
                -Description $group.Desc `
                -Path $distributionGroupPath `
                -ErrorAction Stop
            
            Write-Host "  ✓ Created: $($group.Name)" -ForegroundColor Green
            $created++
        } else {
            Write-Host "  ○ Exists: $($group.Name)" -ForegroundColor DarkGray
            $skipped++
        }
    } catch {
        Write-Warning "  ✗ Failed: $($group.Name) - $_"
    }
}

Write-Host "`n✓ Group generation complete!" -ForegroundColor Green
Write-Host "  Total created: $created" -ForegroundColor Yellow
Write-Host "  Already existed: $skipped" -ForegroundColor DarkGray

