# Computer Generation Script
# Purpose: Generate realistic computer accounts

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Tier1", "Tier2", "Tier3")]
    [string]$Tier,
    
    [Parameter(Mandatory=$true)]
    [string]$DomainDN
)

# Import name data
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptPath\Data\NameData.ps1"

# Computer counts by tier
$computerCounts = @{
    "Tier1" = 30
    "Tier2" = 200
    "Tier3" = 1200
}

$count = $computerCounts[$Tier]
$departments = @("IT", "HR", "Finance", "Engineering", "Sales", "Marketing")
$locations = @("NYC", "LAX", "CHI")

if ($Tier -eq "Tier3") {
    $locations += @("LON", "TYO", "SYD")
}

Write-Host "Generating $count computer accounts..." -ForegroundColor Yellow

$created = 0
$failed = 0
$createdNames = @{}

for ($i = 1; $i -le $count; $i++) {
    # Generate unique computer name
    $attempts = 0
    do {
        # Random attributes
        $location = Get-Random -InputObject $locations
        $dept = Get-Random -InputObject $departments
        $deptCode = $DepartmentCodes[$dept]
        
        # 80% workstations, 20% laptops
        $type = if ((Get-Random -Minimum 0 -Maximum 100) -lt 80) { "WS" } else { "LT" }
        
        # Generate number
        $number = "{0:D3}" -f (Get-Random -Minimum 1 -Maximum 999)
        $computerName = "$location-$type-$deptCode-$number"
        $attempts++
        
        if ($attempts -gt 50) {
            # Add extra digit if too many collisions
            $number = "{0:D4}" -f (Get-Random -Minimum 1000 -Maximum 9999)
            $computerName = "$location-$type-$deptCode-$number"
            break
        }
    } while ($createdNames.ContainsKey($computerName))
    
    $createdNames[$computerName] = $true
    
    # Determine target OU
    $deptPath = "OU=Computers,OU=$dept,OU=Departments,$DomainDN"
    
    # Verify OU exists
    try {
        $null = Get-ADOrganizationalUnit -Identity $deptPath -ErrorAction Stop
    } catch {
        Write-Warning "  OU not found: $deptPath"
        $failed++
        continue
    }
    
    # Create computer
    try {
        $description = "Test $type for $dept department in $location office"
        
        New-ADComputer -Name $computerName `
            -SAMAccountName $computerName `
            -Path $deptPath `
            -Description $description `
            -Enabled $true `
            -ErrorAction Stop
        
        $created++
        
    } catch {
        if ($_.Exception.Message -notlike "*already exists*") {
            Write-Warning "  Failed to create $computerName`: $($_.Exception.Message)"
        }
        $failed++
    }
    
    # Progress updates
    if ($i % 50 -eq 0) {
        Write-Host "  Created $i of $count..." -ForegroundColor Gray
    }
    
    if ($i % 10 -eq 0) {
        $percent = [math]::Round(($i / $count) * 100)
        Write-Progress -Activity "Creating computers" `
            -Status "$i of $count" `
            -PercentComplete $percent
    }
}

Write-Progress -Activity "Creating computers" -Completed

Write-Host "✓ Computer generation complete!" -ForegroundColor Green
Write-Host "  Total created: $created" -ForegroundColor Yellow
if ($failed -gt 0) {
    Write-Host "  Total failed: $failed" -ForegroundColor Red
}

