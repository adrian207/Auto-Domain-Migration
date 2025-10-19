# Master AD Test Data Generator
# Purpose: Generate complete AD test environment with users, computers, groups, and OUs
# Usage: .\Generate-ADTestData.ps1 -Tier Tier1 -SourceDomain

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Tier1", "Tier2", "Tier3")]
    [string]$Tier,
    
    [Parameter(Mandatory=$false)]
    [string]$DomainDN,
    
    [Parameter(Mandatory=$false)]
    [SecureString]$DefaultPassword,
    
    [switch]$SkipOUs,
    [switch]$SkipUsers,
    [switch]$SkipComputers,
    [switch]$SkipGroups,
    [switch]$SkipRelationships
)

$ErrorActionPreference = "Continue"
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  AD Test Data Generator v1.0" -ForegroundColor Cyan
Write-Host "  Tier: $Tier" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Auto-detect domain if not specified
if (-not $DomainDN) {
    try {
        $DomainDN = (Get-ADDomain).DistinguishedName
        Write-Host "✓ Auto-detected domain: $DomainDN" -ForegroundColor Green
    } catch {
        Write-Error "Failed to auto-detect domain. Please specify -DomainDN parameter."
        exit 1
    }
}

# Verify AD module is available
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "ActiveDirectory PowerShell module not found. Please install RSAT tools."
    exit 1
}

Import-Module ActiveDirectory

# Set default password if not provided
if (-not $DefaultPassword) {
    $DefaultPassword = ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force
}

$startTime = Get-Date

# Step 1: Create OU structure
if (-not $SkipOUs) {
    Write-Host "`n[1/5] Creating OU structure..." -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor DarkGray
    
    try {
        & "$scriptPath\New-ADOUStructure.ps1" -Tier $Tier -DomainDN $DomainDN
        Write-Host "✓ OU structure created successfully" -ForegroundColor Green
    } catch {
        Write-Warning "OU creation encountered errors: $_"
    }
}

# Step 2: Create users
if (-not $SkipUsers) {
    Write-Host "`n[2/5] Creating users..." -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor DarkGray
    
    try {
        & "$scriptPath\New-ADTestUsers.ps1" -Tier $Tier -DomainDN $DomainDN -DefaultPassword $DefaultPassword
        Write-Host "✓ Users created successfully" -ForegroundColor Green
    } catch {
        Write-Warning "User creation encountered errors: $_"
    }
}

# Step 3: Create computers
if (-not $SkipComputers) {
    Write-Host "`n[3/5] Creating computers..." -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor DarkGray
    
    try {
        & "$scriptPath\New-ADTestComputers.ps1" -Tier $Tier -DomainDN $DomainDN
        Write-Host "✓ Computers created successfully" -ForegroundColor Green
    } catch {
        Write-Warning "Computer creation encountered errors: $_"
    }
}

# Step 4: Create groups
if (-not $SkipGroups) {
    Write-Host "`n[4/5] Creating groups..." -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor DarkGray
    
    try {
        & "$scriptPath\New-ADTestGroups.ps1" -Tier $Tier -DomainDN $DomainDN
        Write-Host "✓ Groups created successfully" -ForegroundColor Green
    } catch {
        Write-Warning "Group creation encountered errors: $_"
    }
}

# Step 5: Create relationships (group memberships, manager hierarchy)
if (-not $SkipRelationships) {
    Write-Host "`n[5/5] Creating relationships..." -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor DarkGray
    
    try {
        & "$scriptPath\Set-ADTestRelationships.ps1" -Tier $Tier -DomainDN $DomainDN
        Write-Host "✓ Relationships created successfully" -ForegroundColor Green
    } catch {
        Write-Warning "Relationship creation encountered errors: $_"
    }
}

$duration = (Get-Date) - $startTime

# Generate summary report
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Generation Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

try {
    $users = (Get-ADUser -Filter * -SearchBase "OU=Departments,$DomainDN").Count
    $computers = (Get-ADComputer -Filter * -SearchBase "OU=Departments,$DomainDN").Count
    $groups = (Get-ADGroup -Filter "Name -like 'G-*' -or Name -like 'DL-*'" -SearchBase $DomainDN).Count
    $ous = (Get-ADOrganizationalUnit -Filter * -SearchBase "OU=Departments,$DomainDN").Count
    
    Write-Host "Summary:" -ForegroundColor Yellow
    Write-Host "  Domain: $(($DomainDN -split ',DC=')[1..(($DomainDN -split ',DC=').Count-1)] -join '.')" 
    Write-Host "  Tier: $Tier"
    Write-Host ""
    Write-Host "  OUs created: $ous"
    Write-Host "  Users created: $users"
    Write-Host "  Computers created: $computers"
    Write-Host "  Groups created: $groups"
    Write-Host ""
    Write-Host "  Duration: $($duration.TotalMinutes.ToString('F1')) minutes"
    Write-Host "  Objects/minute: $(([math]::Round(($users + $computers + $groups) / $duration.TotalMinutes, 0)))"
    Write-Host ""
    Write-Host "Credentials:" -ForegroundColor Yellow
    Write-Host "  Default Password: [SecureString]"
    Write-Host "  Sample User: john.smith@$(($DomainDN -split ',DC=')[1..(($DomainDN -split ',DC=').Count-1)] -join '.')"
    Write-Host ""
    
    # Export summary
    $summary = @{
        Tier = $Tier
        Domain = $DomainDN
        Generated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Duration = $duration.TotalMinutes
        OUs = $ous
        Users = $users
        Computers = $computers
        Groups = $groups
    }
    
    $reportPath = "$scriptPath\generation-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $summary | ConvertTo-Json | Out-File $reportPath
    
    Write-Host "Report saved to: $reportPath" -ForegroundColor Green
    Write-Host ""
    Write-Host "✓ Ready for migration testing!" -ForegroundColor Green
    Write-Host ""
    
} catch {
    Write-Warning "Failed to generate summary: $_"
}

