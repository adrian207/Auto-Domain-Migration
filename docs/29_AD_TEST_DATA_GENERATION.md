# Active Directory Test Data Generation Strategy

**Date:** October 2025  
**Author:** Adrian Johnson  
**Purpose:** Generate realistic AD test data for migration demonstrations

---

## 🎯 Overview

To effectively demonstrate domain migration capabilities, we need realistic Active Directory test data including:

- **Users:** Varied departments, titles, attributes
- **OUs:** Hierarchical organizational structure
- **Computers:** Workstations and servers
- **Groups:** Security and distribution groups
- **Realistic Relationships:** Group memberships, manager hierarchies

---

## 📊 Test Data Scaling by Tier

### Tier 1 (Demo/POC)

```yaml
Scale: Small organization demo
Users: 50-100
Computers: 20-30
Groups: 10-15
OUs: 5-7 (2 levels deep)
Timeline: 5-10 minutes to generate

Purpose: Quick demos and learning
Complexity: Basic organizational structure
```

### Tier 2 (Production)

```yaml
Scale: Medium business simulation
Users: 500-1,000
Computers: 100-200
Groups: 50-75
OUs: 15-20 (3 levels deep)
Timeline: 30-45 minutes to generate

Purpose: Realistic production testing
Complexity: Multiple departments, locations
```

### Tier 3 (Enterprise)

```yaml
Scale: Large enterprise simulation
Users: 3,000-5,000
Computers: 800-1,200
Groups: 200-300
OUs: 30-50 (4 levels deep)
Timeline: 2-3 hours to generate

Purpose: Enterprise-scale validation
Complexity: Global structure, complex relationships
```

---

## 🏢 Organizational Structure

### OU Hierarchy

```
Domain Root (contoso.local)
│
├── Corporate/
│   ├── Users/
│   │   ├── Executives/
│   │   ├── Managers/
│   │   └── Employees/
│   │
│   ├── Computers/
│   │   ├── Workstations/
│   │   ├── Laptops/
│   │   └── Servers/
│   │
│   └── Groups/
│       ├── Security/
│       └── Distribution/
│
├── Departments/
│   ├── IT/
│   │   ├── Users/
│   │   └── Computers/
│   │
│   ├── HR/
│   │   ├── Users/
│   │   └── Computers/
│   │
│   ├── Finance/
│   │   ├── Users/
│   │   └── Computers/
│   │
│   ├── Engineering/
│   │   ├── Users/
│   │   └── Computers/
│   │
│   ├── Sales/
│   │   ├── Users/
│   │   └── Computers/
│   │
│   └── Marketing/
│       ├── Users/
│       └── Computers/
│
├── Locations/ (Tier 2+)
│   ├── HQ-NewYork/
│   ├── Office-LosAngeles/
│   ├── Office-Chicago/
│   └── Office-London/
│
└── Service-Accounts/
    ├── SQL-Services/
    ├── Web-Services/
    └── Monitoring/
```

---

## 👤 User Attributes

### Standard Attributes

```powershell
User Object Properties:
├── SamAccountName: firstname.lastname
├── UserPrincipalName: firstname.lastname@contoso.local
├── DisplayName: Firstname Lastname
├── GivenName: Firstname
├── Surname: Lastname
├── Description: Job title and department
├── EmailAddress: firstname.lastname@contoso.com
├── Title: Job title
├── Department: Department name
├── Company: Contoso Corporation
├── Office: Office location
├── OfficePhone: (555) xxx-xxxx
├── Mobile: (555) xxx-xxxx
├── StreetAddress: Office address
├── City: Office city
├── State: Office state
├── PostalCode: Office ZIP
├── Country: US/UK/etc
├── Manager: DN of manager
└── EmployeeID: 6-digit number
```

### Job Titles by Department

```yaml
IT Department:
  - Chief Technology Officer
  - IT Director
  - Systems Administrator
  - Network Engineer
  - Security Analyst
  - Help Desk Technician
  - Database Administrator

HR Department:
  - Chief Human Resources Officer
  - HR Director
  - HR Manager
  - Recruiter
  - HR Coordinator
  - Benefits Administrator
  - Payroll Specialist

Finance Department:
  - Chief Financial Officer
  - Finance Director
  - Accountant
  - Financial Analyst
  - Accounts Payable Clerk
  - Accounts Receivable Clerk
  - Budget Analyst

Engineering Department:
  - Chief Engineering Officer
  - Engineering Director
  - Senior Engineer
  - Software Engineer
  - QA Engineer
  - DevOps Engineer
  - Product Manager

Sales Department:
  - Chief Sales Officer
  - Sales Director
  - Sales Manager
  - Account Executive
  - Sales Representative
  - Sales Engineer
  - Business Development Manager

Marketing Department:
  - Chief Marketing Officer
  - Marketing Director
  - Marketing Manager
  - Content Manager
  - Social Media Manager
  - Marketing Coordinator
  - Graphic Designer
```

---

## 💻 Computer Naming Convention

### Workstation Names

```
Format: {Location}{Type}{Department}{Number}
Examples:
  - NYC-WS-IT-001
  - NYC-WS-HR-015
  - LAX-WS-FIN-008
  - CHI-LT-ENG-042  (LT = Laptop)
  - LON-WS-MKT-003
```

### Server Names

```
Format: {Location}{Role}{Number}
Examples:
  - NYC-DC-01        (Domain Controller)
  - NYC-FS-01        (File Server)
  - NYC-SQL-01       (SQL Server)
  - NYC-WEB-01       (Web Server)
  - NYC-APP-01       (Application Server)
  - LAX-DC-01
  - LON-DC-01
```

---

## 👥 Group Types and Membership

### Security Groups

```yaml
Global Groups:
  - G-IT-Admins (10% of IT dept)
  - G-HR-Staff (all HR users)
  - G-Finance-Team (all Finance users)
  - G-Engineering-Team (all Engineering users)
  - G-Sales-Team (all Sales users)
  - G-Marketing-Team (all Marketing users)
  - G-Managers (all users with Manager title)
  - G-Executives (C-level users)

Resource Groups:
  - R-IT-Server-Access
  - R-Finance-Share-RW
  - R-HR-Share-RO
  - R-VPN-Users
  - R-Remote-Desktop-Users
```

### Distribution Groups

```yaml
Distribution Lists:
  - DL-All-Employees
  - DL-IT-Department
  - DL-HR-Department
  - DL-Finance-Department
  - DL-Engineering-Department
  - DL-Sales-Department
  - DL-Marketing-Department
  - DL-Company-Announcements
```

---

## 🔢 Realistic Data Sources

### Name Lists

```powershell
# First Names (100 common names)
$FirstNames = @(
    "James", "Mary", "John", "Patricia", "Robert", "Jennifer", "Michael", "Linda",
    "William", "Barbara", "David", "Elizabeth", "Richard", "Susan", "Joseph", "Jessica",
    "Thomas", "Sarah", "Charles", "Karen", "Christopher", "Nancy", "Daniel", "Lisa",
    "Matthew", "Betty", "Anthony", "Margaret", "Mark", "Sandra", "Donald", "Ashley",
    "Steven", "Kimberly", "Paul", "Emily", "Andrew", "Donna", "Joshua", "Michelle",
    "Kenneth", "Dorothy", "Kevin", "Carol", "Brian", "Amanda", "George", "Melissa",
    "Edward", "Deborah", "Ronald", "Stephanie", "Timothy", "Rebecca", "Jason", "Sharon",
    "Jeffrey", "Laura", "Ryan", "Cynthia", "Jacob", "Kathleen", "Gary", "Amy",
    "Nicholas", "Shirley", "Eric", "Angela", "Jonathan", "Helen", "Stephen", "Anna",
    "Larry", "Brenda", "Justin", "Pamela", "Scott", "Nicole", "Brandon", "Emma",
    "Benjamin", "Samantha", "Samuel", "Katherine", "Raymond", "Christine", "Gregory", "Debra",
    "Frank", "Rachel", "Alexander", "Catherine", "Patrick", "Carolyn", "Raymond", "Janet"
)

# Last Names (100 common surnames)
$LastNames = @(
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
    "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson", "Thomas",
    "Taylor", "Moore", "Jackson", "Martin", "Lee", "Perez", "Thompson", "White",
    "Harris", "Sanchez", "Clark", "Ramirez", "Lewis", "Robinson", "Walker", "Young",
    "Allen", "King", "Wright", "Scott", "Torres", "Nguyen", "Hill", "Flores",
    "Green", "Adams", "Nelson", "Baker", "Hall", "Rivera", "Campbell", "Mitchell",
    "Carter", "Roberts", "Gomez", "Phillips", "Evans", "Turner", "Diaz", "Parker",
    "Cruz", "Edwards", "Collins", "Reyes", "Stewart", "Morris", "Morales", "Murphy",
    "Cook", "Rogers", "Gutierrez", "Ortiz", "Morgan", "Cooper", "Peterson", "Bailey",
    "Reed", "Kelly", "Howard", "Ramos", "Kim", "Cox", "Ward", "Richardson",
    "Watson", "Brooks", "Chavez", "Wood", "James", "Bennett", "Gray", "Mendoza",
    "Ruiz", "Hughes", "Price", "Alvarez", "Castillo", "Sanders", "Patel", "Myers"
)

# Office Locations
$Locations = @{
    "NewYork" = @{
        Code = "NYC"
        Address = "123 Manhattan Ave"
        City = "New York"
        State = "NY"
        ZIP = "10001"
        Phone = "(212) 555-"
    }
    "LosAngeles" = @{
        Code = "LAX"
        Address = "456 Hollywood Blvd"
        City = "Los Angeles"
        State = "CA"
        ZIP = "90001"
        Phone = "(323) 555-"
    }
    "Chicago" = @{
        Code = "CHI"
        Address = "789 Michigan Ave"
        City = "Chicago"
        State = "IL"
        ZIP = "60601"
        Phone = "(312) 555-"
    }
    "London" = @{
        Code = "LON"
        Address = "101 Oxford Street"
        City = "London"
        State = "England"
        ZIP = "SW1A 1AA"
        Phone = "+44 20 7946 "
    }
}
```

---

## 🚀 Generation Scripts

### Script 1: OU Structure Creation

```powershell
# New-ADOUStructure.ps1
# Purpose: Create hierarchical OU structure

param(
    [ValidateSet("Tier1", "Tier2", "Tier3")]
    [string]$Tier = "Tier1",
    
    [string]$DomainDN = "DC=contoso,DC=local"
)

function New-OUIfNotExists {
    param($Name, $Path)
    
    try {
        $ou = Get-ADOrganizationalUnit -Filter "Name -eq '$Name'" -SearchBase $Path -ErrorAction SilentlyContinue
        if (-not $ou) {
            New-ADOrganizationalUnit -Name $Name -Path $Path
            Write-Host "✓ Created OU: $Name" -ForegroundColor Green
        } else {
            Write-Host "○ OU exists: $Name" -ForegroundColor DarkGray
        }
    } catch {
        Write-Warning "Failed to create OU $Name`: $_"
    }
}

# Base OUs
$baseOUs = @("Corporate", "Departments", "Service-Accounts")
if ($Tier -ne "Tier1") {
    $baseOUs += "Locations"
}

foreach ($ou in $baseOUs) {
    New-OUIfNotExists -Name $ou -Path $DomainDN
}

# Corporate sub-OUs
$corporatePath = "OU=Corporate,$DomainDN"
@("Users", "Computers", "Groups") | ForEach-Object {
    New-OUIfNotExists -Name $_ -Path $corporatePath
}

# Department OUs
$deptPath = "OU=Departments,$DomainDN"
$departments = @("IT", "HR", "Finance", "Engineering", "Sales", "Marketing")
foreach ($dept in $departments) {
    New-OUIfNotExists -Name $dept -Path $deptPath
    
    $deptOUPath = "OU=$dept,$deptPath"
    @("Users", "Computers") | ForEach-Object {
        New-OUIfNotExists -Name $_ -Path $deptOUPath
    }
}

# Location OUs (Tier 2+)
if ($Tier -ne "Tier1") {
    $locPath = "OU=Locations,$DomainDN"
    $locations = @("HQ-NewYork", "Office-LosAngeles", "Office-Chicago")
    
    if ($Tier -eq "Tier3") {
        $locations += @("Office-London", "Office-Tokyo", "Office-Sydney")
    }
    
    foreach ($loc in $locations) {
        New-OUIfNotExists -Name $loc -Path $locPath
    }
}

Write-Host "`n✓ OU structure creation complete!" -ForegroundColor Cyan
```

### Script 2: User Generation

```powershell
# New-ADTestUsers.ps1
# Purpose: Generate realistic test users

param(
    [ValidateSet("Tier1", "Tier2", "Tier3")]
    [string]$Tier = "Tier1",
    
    [string]$DomainDN = "DC=contoso,DC=local",
    
    [string]$DefaultPassword = "P@ssw0rd123!"
)

# Import name data (from above)
. ".\Data\NameData.ps1"

# Determine user count based on tier
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
$createdUsers = @()

foreach ($dept in $counts.Keys) {
    Write-Host "`nGenerating $($counts[$dept]) users for $dept..." -ForegroundColor Yellow
    
    $deptPath = "OU=Users,OU=$dept,OU=Departments,$DomainDN"
    
    for ($i = 1; $i -le $counts[$dept]; $i++) {
        # Generate unique name
        do {
            $firstName = Get-Random -InputObject $FirstNames
            $lastName = Get-Random -InputObject $LastNames
            $samAccountName = "$firstName.$lastName".ToLower()
        } while ($createdUsers -contains $samAccountName)
        
        $createdUsers += $samAccountName
        
        # Select random title for department
        $title = Get-Random -InputObject $JobTitles[$dept]
        
        # Select random location
        $location = Get-Random -InputObject $Locations.Keys
        $locInfo = $Locations[$location]
        
        # Generate employee ID
        $employeeID = Get-Random -Minimum 100000 -Maximum 999999
        
        # Generate phone extension
        $extension = "{0:D4}" -f (Get-Random -Minimum 1000 -Maximum 9999)
        
        try {
            New-ADUser -Name "$firstName $lastName" `
                -GivenName $firstName `
                -Surname $lastName `
                -SamAccountName $samAccountName `
                -UserPrincipalName "$samAccountName@contoso.local" `
                -EmailAddress "$samAccountName@contoso.com" `
                -DisplayName "$firstName $lastName" `
                -Title $title `
                -Department $dept `
                -Company "Contoso Corporation" `
                -Office $location `
                -OfficePhone "$($locInfo.Phone)$extension" `
                -StreetAddress $locInfo.Address `
                -City $locInfo.City `
                -State $locInfo.State `
                -PostalCode $locInfo.ZIP `
                -EmployeeID $employeeID `
                -Description "$title - $dept Department" `
                -Path $deptPath `
                -AccountPassword (ConvertTo-SecureString $DefaultPassword -AsPlainText -Force) `
                -Enabled $true `
                -ChangePasswordAtLogon $false
            
            Write-Host "  ✓ Created: $samAccountName ($title)" -ForegroundColor Green
            
        } catch {
            Write-Warning "  Failed to create $samAccountName`: $_"
        }
        
        # Progress
        if ($i % 50 -eq 0) {
            Write-Progress -Activity "Creating $dept users" -Status "$i of $($counts[$dept])" -PercentComplete (($i / $counts[$dept]) * 100)
        }
    }
}

Write-Host "`n✓ User generation complete! Total users: $(($counts.Values | Measure-Object -Sum).Sum)" -ForegroundColor Cyan
```

### Script 3: Computer Generation

```powershell
# New-ADTestComputers.ps1
# Purpose: Generate computer accounts

param(
    [ValidateSet("Tier1", "Tier2", "Tier3")]
    [string]$Tier = "Tier1",
    
    [string]$DomainDN = "DC=contoso,DC=local"
)

# Computer counts by tier
$computerCounts = @{
    "Tier1" = 30
    "Tier2" = 200
    "Tier3" = 1200
}

$count = $computerCounts[$Tier]
$departments = @("IT", "HR", "Finance", "Engineering", "Sales", "Marketing")
$locations = @("NYC", "LAX", "CHI")

Write-Host "Generating $count computer accounts..." -ForegroundColor Yellow

for ($i = 1; $i -le $count; $i++) {
    # Random attributes
    $location = Get-Random -InputObject $locations
    $dept = Get-Random -InputObject $departments
    $type = if ((Get-Random -Minimum 0 -Maximum 100) -lt 80) { "WS" } else { "LT" }
    
    # Generate computer name
    $number = "{0:D3}" -f (Get-Random -Minimum 1 -Maximum 999)
    $computerName = "$location-$type-$dept-$number"
    
    $deptPath = "OU=Computers,OU=$dept,OU=Departments,$DomainDN"
    
    try {
        New-ADComputer -Name $computerName `
            -SAMAccountName $computerName `
            -Path $deptPath `
            -Description "Test $type for $dept department in $location" `
            -Enabled $true
        
        if ($i % 50 -eq 0) {
            Write-Host "  Created $i computers..." -ForegroundColor Gray
        }
        
    } catch {
        # Likely duplicate name, skip
    }
}

Write-Host "✓ Computer generation complete! Total: $count" -ForegroundColor Cyan
```

---

## 📦 Master Generation Script

```powershell
# Generate-ADTestData.ps1
# Purpose: Master script to generate complete AD test environment

param(
    [Parameter(Mandatory)]
    [ValidateSet("Tier1", "Tier2", "Tier3")]
    [string]$Tier,
    
    [string]$DomainDN,
    
    [string]$DefaultPassword = "P@ssw0rd123!",
    
    [switch]$SkipOUs,
    [switch]$SkipUsers,
    [switch]$SkipComputers,
    [switch]$SkipGroups
)

$ErrorActionPreference = "Continue"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  AD Test Data Generator - $Tier" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Auto-detect domain if not specified
if (-not $DomainDN) {
    $DomainDN = (Get-ADDomain).DistinguishedName
    Write-Host "Auto-detected domain: $DomainDN`n" -ForegroundColor Yellow
}

$startTime = Get-Date

# Step 1: Create OU structure
if (-not $SkipOUs) {
    Write-Host "[1/4] Creating OU structure..." -ForegroundColor Cyan
    & ".\New-ADOUStructure.ps1" -Tier $Tier -DomainDN $DomainDN
}

# Step 2: Create users
if (-not $SkipUsers) {
    Write-Host "`n[2/4] Creating users..." -ForegroundColor Cyan
    & ".\New-ADTestUsers.ps1" -Tier $Tier -DomainDN $DomainDN -DefaultPassword $DefaultPassword
}

# Step 3: Create computers
if (-not $SkipComputers) {
    Write-Host "`n[3/4] Creating computers..." -ForegroundColor Cyan
    & ".\New-ADTestComputers.ps1" -Tier $Tier -DomainDN $DomainDN
}

# Step 4: Create groups and memberships
if (-not $SkipGroups) {
    Write-Host "`n[4/4] Creating groups..." -ForegroundColor Cyan
    & ".\New-ADTestGroups.ps1" -Tier $Tier -DomainDN $DomainDN
}

$duration = (Get-Date) - $startTime

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Generation Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

$users = (Get-ADUser -Filter * -SearchBase "OU=Departments,$DomainDN").Count
$computers = (Get-ADComputer -Filter * -SearchBase "OU=Departments,$DomainDN").Count
$groups = (Get-ADGroup -Filter * -SearchBase "OU=Departments,$DomainDN").Count

Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  Users created: $users"
Write-Host "  Computers created: $computers"
Write-Host "  Groups created: $groups"
Write-Host "  Duration: $($duration.TotalMinutes.ToString('F1')) minutes"
Write-Host ""
Write-Host "Default Password: $DefaultPassword" -ForegroundColor Yellow
Write-Host ""
Write-Host "Ready for migration testing!" -ForegroundColor Green
Write-Host ""
```

---

## 🎯 Usage Examples

### Tier 1 (Quick Demo)

```powershell
# Generate small test environment
.\Generate-ADTestData.ps1 -Tier Tier1

# Result: ~75 users, ~30 computers, ~15 groups
# Time: ~5-10 minutes
```

### Tier 2 (Production Testing)

```powershell
# Generate medium test environment
.\Generate-ADTestData.ps1 -Tier Tier2 -DefaultPassword "MySecureP@ss123!"

# Result: ~580 users, ~200 computers, ~60 groups
# Time: ~30-45 minutes
```

### Tier 3 (Enterprise Scale)

```powershell
# Generate large test environment
.\Generate-ADTestData.ps1 -Tier Tier3

# Result: ~2,525 users, ~1,200 computers, ~250 groups
# Time: ~2-3 hours
```

---

## 📚 Next Steps

1. ✅ Review this architecture document
2. ⬜ Create generation scripts
3. ⬜ Test on Tier 1 environment
4. ⬜ Integrate with Ansible
5. ⬜ Add to deployment workflows

---

**Status:** Architecture complete  
**Next:** Implement generation scripts 🚀

