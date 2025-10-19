# User Generation Script
# Purpose: Generate realistic test users with full attributes

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Tier1", "Tier2", "Tier3")]
    [string]$Tier,
    
    [Parameter(Mandatory=$true)]
    [string]$DomainDN,
    
    [Parameter(Mandatory=$true)]
    [SecureString]$DefaultPassword
)

# Import name data
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptPath\Data\NameData.ps1"

# User counts by tier and department
$userCounts = @{
    "Tier1" = @{
        IT = 10
        HR = 8
        Finance = 8
        Engineering = 20
        Sales = 15
        Marketing = 12
        Executives = 3
    }
    "Tier2" = @{
        IT = 50
        HR = 40
        Finance = 60
        Engineering = 200
        Sales = 150
        Marketing = 80
        Executives = 10
    }
    "Tier3" = @{
        IT = 200
        HR = 150
        Finance = 250
        Engineering = 1000
        Sales = 600
        Marketing = 300
        Executives = 25
    }
}

$counts = $userCounts[$Tier]
$createdUsers = @{}  # Track created SAMAccountNames
$totalCreated = 0
$totalFailed = 0

# Password is already SecureString
$securePassword = $DefaultPassword

# Extract domain name for email
$domainName = ($DomainDN -split ',DC=' | Select-Object -Skip 1) -join '.'

foreach ($dept in $counts.Keys) {
    Write-Host "`nGenerating $($counts[$dept]) users for $dept..." -ForegroundColor Yellow
    
    # Determine target OU
    if ($dept -eq "Executives") {
        $deptPath = "OU=Executives,OU=Users,OU=Corporate,$DomainDN"
    } else {
        $deptPath = "OU=Users,OU=$dept,OU=Departments,$DomainDN"
    }
    
    # Verify OU exists
    try {
        $null = Get-ADOrganizationalUnit -Identity $deptPath -ErrorAction Stop
    } catch {
        Write-Warning "  OU not found: $deptPath - Skipping $dept"
        continue
    }
    
    for ($i = 1; $i -le $counts[$dept]; $i++) {
        # Generate unique name
        $attempts = 0
        do {
            $firstName = Get-Random -InputObject $FirstNames
            $lastName = Get-Random -InputObject $LastNames
            $samAccountName = "$firstName.$lastName".ToLower()
            $attempts++
            
            if ($attempts -gt 50) {
                # Add number suffix if too many attempts
                $samAccountName = "$firstName.$lastName$(Get-Random -Minimum 1 -Maximum 999)".ToLower()
                break
            }
        } while ($createdUsers.ContainsKey($samAccountName))
        
        # Mark as used
        $createdUsers[$samAccountName] = $true
        
        # Select random attributes
        $title = Get-Random -InputObject $JobTitles[$dept]
        $location = Get-Random -InputObject $Locations.Keys
        $locInfo = $Locations[$location]
        
        # Generate IDs and phone
        $employeeID = Get-Random -Minimum 100000 -Maximum 999999
        $extension = "{0:D4}" -f (Get-Random -Minimum 1000 -Maximum 9999)
        $mobileExtension = "{0:D4}" -f (Get-Random -Minimum 1000 -Maximum 9999)
        
        # Build user parameters
        $userParams = @{
            Name = "$firstName $lastName"
            GivenName = $firstName
            Surname = $lastName
            SamAccountName = $samAccountName
            UserPrincipalName = "$samAccountName@$domainName"
            EmailAddress = "$samAccountName@$($domainName -replace '\.local$','.com')"
            DisplayName = "$firstName $lastName"
            Title = $title
            Department = $dept
            Company = "Contoso Corporation"
            Office = $location
            OfficePhone = "$($locInfo.Phone)$extension"
            MobilePhone = "$($locInfo.Phone)$mobileExtension"
            StreetAddress = $locInfo.Address
            City = $locInfo.City
            State = $locInfo.State
            PostalCode = $locInfo.ZIP
            Country = $locInfo.Country
            Description = "$title - $dept Department"
            Path = $deptPath
            AccountPassword = $securePassword
            Enabled = $true
            ChangePasswordAtLogon = $false
        }
        
        # Add employee ID if available (custom attribute)
        try {
            $userParams.Add("EmployeeID", $employeeID.ToString())
        } catch {}
        
        # Create the user
        try {
            New-ADUser @userParams -ErrorAction Stop
            $totalCreated++
            
            if ($i % 25 -eq 0) {
                Write-Host "  Created $i of $($counts[$dept])..." -ForegroundColor Gray
            }
            
        } catch {
            $totalFailed++
            if ($_.Exception.Message -notlike "*already exists*") {
                Write-Warning "  Failed to create $samAccountName`: $($_.Exception.Message)"
            }
        }
        
        # Progress bar
        if ($i % 10 -eq 0) {
            $percent = [math]::Round(($i / $counts[$dept]) * 100)
            Write-Progress -Activity "Creating $dept users" `
                -Status "$i of $($counts[$dept])" `
                -PercentComplete $percent
        }
    }
    
    Write-Progress -Activity "Creating $dept users" -Completed
    Write-Host "  ✓ Completed $dept department" -ForegroundColor Green
}

Write-Host "`n✓ User generation complete!" -ForegroundColor Green
Write-Host "  Total created: $totalCreated" -ForegroundColor Yellow
if ($totalFailed -gt 0) {
    Write-Host "  Total failed: $totalFailed" -ForegroundColor Red
}

