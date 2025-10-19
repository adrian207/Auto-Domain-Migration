# Configure Source File Server for SMS Demo
# Purpose: Setup file server roles and test data

# Initialize data disk
$disk = Get-Disk | Where-Object { $_.PartitionStyle -eq 'RAW' } | Select-Object -First 1
if ($disk) {
    Initialize-Disk -Number $disk.Number -PartitionStyle GPT -PassThru |
        New-Partition -AssignDriveLetter -UseMaximumSize |
        Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data" -Confirm:$false
}

# Install File Server role
Install-WindowsFeature -Name FS-FileServer, FS-Resource-Manager -IncludeManagementTools

# Create shares directory
$sharePath = "D:\Shares"
New-Item -Path $sharePath -ItemType Directory -Force

# Create test shares
$shares = @("HR", "Finance", "Engineering")
foreach ($share in $shares) {
    $path = Join-Path $sharePath $share
    New-Item -Path $path -ItemType Directory -Force
    
    # Create SMB share
    New-SmbShare -Name $share `
        -Path $path `
        -FullAccess "Everyone" `
        -Description "Test share for migration demo"
}

# Enable WinRM for Ansible
Enable-PSRemoting -Force
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

# Configure firewall
Set-NetFirewallRule -Name "FPS-SMB-In-TCP" -Enabled True
Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing"
Enable-NetFirewallRule -DisplayGroup "Windows Remote Management"

Write-Host "Source File Server configured successfully"

