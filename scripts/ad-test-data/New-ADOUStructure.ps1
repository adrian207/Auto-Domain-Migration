# OU Structure Creation Script
# Purpose: Create hierarchical OU structure for test environment

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Tier1", "Tier2", "Tier3")]
    [string]$Tier,
    
    [Parameter(Mandatory=$true)]
    [string]$DomainDN
)

function New-OUIfNotExists {
    param(
        [string]$Name,
        [string]$Path,
        [string]$Description = ""
    )
    
    try {
        $ouDN = "OU=$Name,$Path"
        $existingOU = Get-ADOrganizationalUnit -Identity $ouDN -ErrorAction SilentlyContinue
        
        if (-not $existingOU) {
            $params = @{
                Name = $Name
                Path = $Path
            }
            
            if ($Description) {
                $params.Description = $Description
            }
            
            New-ADOrganizationalUnit @params -ProtectedFromAccidentalDeletion $false
            Write-Host "  ✓ Created: $Name" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  ○ Exists: $Name" -ForegroundColor DarkGray
            return $false
        }
    } catch {
        Write-Warning "  ✗ Failed: $Name - $_"
        return $false
    }
}

Write-Host "`nCreating OU structure for $Tier..." -ForegroundColor Yellow

$created = 0

# Step 1: Base OUs
Write-Host "`n Base OUs:" -ForegroundColor Cyan
$baseOUs = @(
    @{Name="Corporate"; Desc="Corporate organizational units"},
    @{Name="Departments"; Desc="Department organizational units"},
    @{Name="Service-Accounts"; Desc="Service accounts"}
)

if ($Tier -ne "Tier1") {
    $baseOUs += @{Name="Locations"; Desc="Geographic locations"}
}

foreach ($ou in $baseOUs) {
    if (New-OUIfNotExists -Name $ou.Name -Path $DomainDN -Description $ou.Desc) {
        $created++
    }
}

# Step 2: Corporate sub-OUs
Write-Host "`n Corporate sub-OUs:" -ForegroundColor Cyan
$corporatePath = "OU=Corporate,$DomainDN"
$corpOUs = @(
    @{Name="Users"; Desc="Corporate user accounts"},
    @{Name="Computers"; Desc="Corporate computers"},
    @{Name="Groups"; Desc="Corporate groups"}
)

foreach ($ou in $corpOUs) {
    if (New-OUIfNotExists -Name $ou.Name -Path $corporatePath -Description $ou.Desc) {
        $created++
    }
}

# Corporate Users sub-OUs
$corpUsersPath = "OU=Users,$corporatePath"
@("Executives", "Managers", "Employees") | ForEach-Object {
    if (New-OUIfNotExists -Name $_ -Path $corpUsersPath) {
        $created++
    }
}

# Corporate Computers sub-OUs
$corpComputersPath = "OU=Computers,$corporatePath"
@("Workstations", "Laptops", "Servers") | ForEach-Object {
    if (New-OUIfNotExists -Name $_ -Path $corpComputersPath) {
        $created++
    }
}

# Corporate Groups sub-OUs
$corpGroupsPath = "OU=Groups,$corporatePath"
@("Security", "Distribution") | ForEach-Object {
    if (New-OUIfNotExists -Name $_ -Path $corpGroupsPath) {
        $created++
    }
}

# Step 3: Department OUs
Write-Host "`n Department OUs:" -ForegroundColor Cyan
$deptPath = "OU=Departments,$DomainDN"
$departments = @(
    @{Name="IT"; Desc="Information Technology"},
    @{Name="HR"; Desc="Human Resources"},
    @{Name="Finance"; Desc="Finance and Accounting"},
    @{Name="Engineering"; Desc="Engineering and Development"},
    @{Name="Sales"; Desc="Sales and Business Development"},
    @{Name="Marketing"; Desc="Marketing and Communications"}
)

foreach ($dept in $departments) {
    if (New-OUIfNotExists -Name $dept.Name -Path $deptPath -Description $dept.Desc) {
        $created++
    }
    
    $deptOUPath = "OU=$($dept.Name),$deptPath"
    
    # Create Users and Computers sub-OUs for each department
    @("Users", "Computers") | ForEach-Object {
        if (New-OUIfNotExists -Name $_ -Path $deptOUPath) {
            $created++
        }
    }
}

# Step 4: Location OUs (Tier 2+)
if ($Tier -ne "Tier1") {
    Write-Host "`n Location OUs:" -ForegroundColor Cyan
    $locPath = "OU=Locations,$DomainDN"
    
    $locations = @(
        @{Name="HQ-NewYork"; Desc="Headquarters - New York"},
        @{Name="Office-LosAngeles"; Desc="West Coast Office - Los Angeles"},
        @{Name="Office-Chicago"; Desc="Central Office - Chicago"}
    )
    
    if ($Tier -eq "Tier3") {
        $locations += @(
            @{Name="Office-London"; Desc="EMEA Office - London"},
            @{Name="Office-Tokyo"; Desc="APAC Office - Tokyo"},
            @{Name="Office-Sydney"; Desc="APAC Office - Sydney"}
        )
    }
    
    foreach ($loc in $locations) {
        if (New-OUIfNotExists -Name $loc.Name -Path $locPath -Description $loc.Desc) {
            $created++
        }
    }
}

# Step 5: Service Account OUs
Write-Host "`n Service Account OUs:" -ForegroundColor Cyan
$svcPath = "OU=Service-Accounts,$DomainDN"
$serviceOUs = @(
    @{Name="SQL-Services"; Desc="SQL Server service accounts"},
    @{Name="Web-Services"; Desc="Web application service accounts"},
    @{Name="Monitoring"; Desc="Monitoring service accounts"}
)

if ($Tier -ne "Tier1") {
    $serviceOUs += @{Name="Backup-Services"; Desc="Backup service accounts"}
}

foreach ($svc in $serviceOUs) {
    if (New-OUIfNotExists -Name $svc.Name -Path $svcPath -Description $svc.Desc) {
        $created++
    }
}

Write-Host "`n✓ OU structure creation complete!" -ForegroundColor Green
Write-Host "  Total OUs created: $created" -ForegroundColor Yellow

