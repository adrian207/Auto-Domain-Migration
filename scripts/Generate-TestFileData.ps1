# Test File Data Generation Script
# Purpose: Create 1,000 test files (10KB-10MB) for file server migration demos
# Usage: .\Generate-TestFileData.ps1 -OutputPath "C:\TestShares" -FileCount 1000

param(
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "C:\TestShares",
    
    [Parameter(Mandatory=$false)]
    [int]$FileCount = 1000,
    
    [Parameter(Mandatory=$false)]
    [switch]$CreateShares,
    
    [Parameter(Mandatory=$false)]
    [switch]$SetPermissions
)

# File generation configuration
$shareConfig = @{
    "HR" = @{
        SubFolders = @("Policies", "Forms", "Reports", "Handbooks")
        FileTypes = @{
            ".pdf" = 40    # 40% PDFs
            ".docx" = 35   # 35% Word docs
            ".xlsx" = 25   # 25% Excel files
        }
        SizeRange = @(50KB, 5MB)
        FileCount = 250
        Permissions = @{
            "Domain Admins" = "FullControl"
            "HR-Staff" = "Modify"
            "Domain Users" = "ReadAndExecute"
        }
    }
    "Finance" = @{
        SubFolders = @("Budget", "Invoices", "Statements", "Reports", "Archive")
        FileTypes = @{
            ".xlsx" = 50   # 50% Excel
            ".pdf" = 40    # 40% PDF
            ".csv" = 10    # 10% CSV
        }
        SizeRange = @(500KB, 10MB)
        FileCount = 300
        Permissions = @{
            "Domain Admins" = "FullControl"
            "Finance-Team" = "Modify"
            "Managers" = "ReadAndExecute"
        }
    }
    "Engineering" = @{
        SubFolders = @("Docs", "Specs", "Diagrams", "CAD", "Projects")
        FileTypes = @{
            ".pdf" = 30    # 30% PDF
            ".docx" = 30   # 30% Word
            ".vsdx" = 20   # 20% Visio
            ".zip" = 20    # 20% Archives
        }
        SizeRange = @(100KB, 10MB)
        FileCount = 450
        Permissions = @{
            "Domain Admins" = "FullControl"
            "Engineering-Team" = "Modify"
            "Domain Users" = "Read"
        }
    }
}

# Function to generate random file content
function New-RandomFileContent {
    param(
        [int64]$SizeInBytes,
        [string]$FileExtension
    )
    
    $bytes = New-Object byte[] $SizeInBytes
    
    # Create pseudo-realistic content based on file type
    switch ($FileExtension) {
        ".pdf" {
            # PDF header and random binary
            $pdfHeader = [System.Text.Encoding]::ASCII.GetBytes("%PDF-1.4`n")
            [Array]::Copy($pdfHeader, 0, $bytes, 0, $pdfHeader.Length)
            (New-Object Random).NextBytes($bytes[$pdfHeader.Length..($bytes.Length-1)])
        }
        ".docx" {
            # ZIP-based Office format
            $zipHeader = [byte[]](0x50, 0x4B, 0x03, 0x04)
            [Array]::Copy($zipHeader, 0, $bytes, 0, $zipHeader.Length)
            (New-Object Random).NextBytes($bytes[$zipHeader.Length..($bytes.Length-1)])
        }
        ".xlsx" {
            # ZIP-based Office format
            $zipHeader = [byte[]](0x50, 0x4B, 0x03, 0x04)
            [Array]::Copy($zipHeader, 0, $bytes, 0, $zipHeader.Length)
            (New-Object Random).NextBytes($bytes[$zipHeader.Length..($bytes.Length-1)])
        }
        ".vsdx" {
            # ZIP-based Office format
            $zipHeader = [byte[]](0x50, 0x4B, 0x03, 0x04)
            [Array]::Copy($zipHeader, 0, $bytes, 0, $zipHeader.Length)
            (New-Object Random).NextBytes($bytes[$zipHeader.Length..($bytes.Length-1)])
        }
        ".zip" {
            # ZIP archive
            $zipHeader = [byte[]](0x50, 0x4B, 0x03, 0x04)
            [Array]::Copy($zipHeader, 0, $bytes, 0, $zipHeader.Length)
            (New-Object Random).NextBytes($bytes[$zipHeader.Length..($bytes.Length-1)])
        }
        ".csv" {
            # CSV with headers
            $csvHeader = "ID,Date,Amount,Description,Status`n"
            $csvBytes = [System.Text.Encoding]::UTF8.GetBytes($csvHeader)
            [Array]::Copy($csvBytes, 0, $bytes, 0, [Math]::Min($csvBytes.Length, $bytes.Length))
            # Fill rest with pseudo-CSV data
            for ($i = $csvBytes.Length; $i -lt $bytes.Length; $i += 50) {
                $line = "$i,$(Get-Date -Format 'yyyy-MM-dd'),`$$([random]::new().Next(100,10000)),Item $i,Active`n"
                $lineBytes = [System.Text.Encoding]::UTF8.GetBytes($line)
                [Array]::Copy($lineBytes, 0, $bytes, $i, [Math]::Min($lineBytes.Length, $bytes.Length - $i))
            }
        }
        default {
            # Random binary for unknown types
            (New-Object Random).NextBytes($bytes)
        }
    }
    
    return $bytes
}

# Function to select file type based on distribution
function Get-RandomFileType {
    param($FileTypes)
    
    $random = Get-Random -Minimum 0 -Maximum 100
    $cumulative = 0
    
    foreach ($type in $FileTypes.Keys) {
        $cumulative += $FileTypes[$type]
        if ($random -lt $cumulative) {
            return $type
        }
    }
    
    return $FileTypes.Keys[0]
}

# Main generation logic
Write-Host "`n===========================================`n" -ForegroundColor Cyan
Write-Host "  Test File Data Generator v1.0" -ForegroundColor Cyan
Write-Host "===========================================`n" -ForegroundColor Cyan

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Output Path: $OutputPath"
Write-Host "  Total Files: $FileCount"
Write-Host "  Shares: $($shareConfig.Keys -join ', ')"
Write-Host ""

$totalFilesCreated = 0
$totalSizeBytes = 0

foreach ($shareName in $shareConfig.Keys) {
    $config = $shareConfig[$shareName]
    $sharePath = Join-Path $OutputPath $shareName
    
    Write-Host "Creating share: $shareName" -ForegroundColor Green
    Write-Host "  Subfolders: $($config.SubFolders.Count)"
    Write-Host "  Files: $($config.FileCount)"
    
    # Create share directory
    if (-not (Test-Path $sharePath)) {
        New-Item -Path $sharePath -ItemType Directory -Force | Out-Null
    }
    
    # Create subfolders
    foreach ($folder in $config.SubFolders) {
        $folderPath = Join-Path $sharePath $folder
        if (-not (Test-Path $folderPath)) {
            New-Item -Path $folderPath -ItemType Directory -Force | Out-Null
        }
    }
    
    # Generate files
    $filesPerFolder = [math]::Floor($config.FileCount / $config.SubFolders.Count)
    $filesCreated = 0
    
    foreach ($folder in $config.SubFolders) {
        $folderPath = Join-Path $sharePath $folder
        
        for ($i = 1; $i -le $filesPerFolder; $i++) {
            # Select file type based on distribution
            $ext = Get-RandomFileType -FileTypes $config.FileTypes
            
            # Generate filename
            $timestamp = Get-Date -Format "yyyyMMdd"
            $fileName = "Document_${timestamp}_$(Get-Random -Minimum 1000 -Maximum 9999)$ext"
            $filePath = Join-Path $folderPath $fileName
            
            # Calculate random file size
            $minSize = $config.SizeRange[0]
            $maxSize = $config.SizeRange[1]
            $fileSize = Get-Random -Minimum $minSize -Maximum $maxSize
            
            # Generate file content
            try {
                $content = New-RandomFileContent -SizeInBytes $fileSize -FileExtension $ext
                [IO.File]::WriteAllBytes($filePath, $content)
                
                # Set random modified date (within last year)
                $randomDays = Get-Random -Minimum 1 -Maximum 365
                $modifiedDate = (Get-Date).AddDays(-$randomDays)
                (Get-Item $filePath).LastWriteTime = $modifiedDate
                
                $filesCreated++
                $totalFilesCreated++
                $totalSizeBytes += $fileSize
                
            } catch {
                Write-Warning "Failed to create file: $filePath - $_"
            }
            
            # Progress update
            if ($filesCreated % 10 -eq 0) {
                Write-Progress -Activity "Generating files for $shareName\$folder" `
                    -Status "Created $filesCreated of $($config.FileCount) files" `
                    -PercentComplete (($filesCreated / $config.FileCount) * 100)
            }
        }
    }
    
    Write-Host "  ✓ Created $filesCreated files" -ForegroundColor Green
    Write-Host ""
}

Write-Progress -Activity "Generating files" -Completed

# Summary
Write-Host "`n===========================================`n" -ForegroundColor Cyan
Write-Host "Generation Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  Total Files Created: $totalFilesCreated"
Write-Host "  Total Size: $([math]::Round($totalSizeBytes / 1GB, 2)) GB ($([math]::Round($totalSizeBytes / 1MB, 0)) MB)"
Write-Host "  Output Location: $OutputPath"
Write-Host ""

# Create SMB shares if requested
if ($CreateShares) {
    Write-Host "Creating SMB shares..." -ForegroundColor Yellow
    
    foreach ($shareName in $shareConfig.Keys) {
        $sharePath = Join-Path $OutputPath $shareName
        
        try {
            # Check if share already exists
            $existingShare = Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue
            
            if ($existingShare) {
                Write-Host "  Share '$shareName' already exists" -ForegroundColor DarkYellow
            } else {
                New-SmbShare -Name $shareName `
                    -Path $sharePath `
                    -FullAccess "Everyone" `
                    -Description "Test share for migration demo" | Out-Null
                
                Write-Host "  ✓ Created share: \\$env:COMPUTERNAME\$shareName" -ForegroundColor Green
            }
        } catch {
            Write-Warning "Failed to create share '$shareName': $_"
        }
    }
    
    Write-Host ""
}

# Set NTFS permissions if requested
if ($SetPermissions) {
    Write-Host "Setting NTFS permissions..." -ForegroundColor Yellow
    
    foreach ($shareName in $shareConfig.Keys) {
        $sharePath = Join-Path $OutputPath $shareName
        $permissions = $shareConfig[$shareName].Permissions
        
        try {
            $acl = Get-Acl $sharePath
            
            # Disable inheritance
            $acl.SetAccessRuleProtection($true, $false)
            
            # Add permissions
            foreach ($identity in $permissions.Keys) {
                $rights = $permissions[$identity]
                $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                    $identity,
                    $rights,
                    "ContainerInherit,ObjectInherit",
                    "None",
                    "Allow"
                )
                $acl.AddAccessRule($rule)
            }
            
            Set-Acl -Path $sharePath -AclObject $acl
            Write-Host "  ✓ Set permissions for: $shareName" -ForegroundColor Green
            
        } catch {
            Write-Warning "Failed to set permissions for '$shareName': $_"
        }
    }
    
    Write-Host ""
}

# Display file statistics
Write-Host "File Statistics:" -ForegroundColor Yellow
foreach ($shareName in $shareConfig.Keys) {
    $sharePath = Join-Path $OutputPath $shareName
    $fileCount = (Get-ChildItem -Path $sharePath -Recurse -File | Measure-Object).Count
    $totalSize = (Get-ChildItem -Path $sharePath -Recurse -File | Measure-Object -Property Length -Sum).Sum
    
    Write-Host "  $shareName`:"
    Write-Host "    Files: $fileCount"
    Write-Host "    Size: $([math]::Round($totalSize / 1MB, 0)) MB"
}

Write-Host "`n===========================================`n" -ForegroundColor Cyan
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Review generated files in: $OutputPath"
Write-Host "  2. Test SMS discovery and transfer"
Write-Host "  3. Validate file integrity post-migration"
Write-Host ""

# Export generation report
$report = @{
    GeneratedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    TotalFiles = $totalFilesCreated
    TotalSizeBytes = $totalSizeBytes
    TotalSizeGB = [math]::Round($totalSizeBytes / 1GB, 2)
    OutputPath = $OutputPath
    Shares = @{}
}

foreach ($shareName in $shareConfig.Keys) {
    $sharePath = Join-Path $OutputPath $shareName
    $fileCount = (Get-ChildItem -Path $sharePath -Recurse -File | Measure-Object).Count
    $totalSize = (Get-ChildItem -Path $sharePath -Recurse -File | Measure-Object -Property Length -Sum).Sum
    
    $report.Shares[$shareName] = @{
        FileCount = $fileCount
        TotalSize = $totalSize
        Path = $sharePath
    }
}

$reportPath = Join-Path $OutputPath "generation-report.json"
$report | ConvertTo-Json -Depth 5 | Out-File $reportPath

Write-Host "Report saved to: $reportPath" -ForegroundColor Green
Write-Host ""

