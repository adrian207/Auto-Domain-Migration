# Configure Target File Server for SMS Demo  
# Purpose: Setup file server roles and SMS

# Initialize data disk
$disk = Get-Disk | Where-Object { $_.PartitionStyle -eq 'RAW' } | Select-Object -First 1
if ($disk) {
    Initialize-Disk -Number $disk.Number -PartitionStyle GPT -PassThru |
        New-Partition -AssignDriveLetter -UseMaximumSize |
        Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data" -Confirm:$false
}

# Install File Server role
Install-WindowsFeature -Name FS-FileServer, FS-Resource-Manager, FS-Data-Deduplication -IncludeManagementTools

# Install Storage Migration Service
Install-WindowsFeature -Name SMS-Service -IncludeManagementTools

# Create shares directory
$sharePath = "D:\Shares"
New-Item -Path $sharePath -ItemType Directory -Force

# Enable WinRM for Ansible
Enable-PSRemoting -Force
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

# Configure firewall
Set-NetFirewallRule -Name "FPS-SMB-In-TCP" -Enabled True
Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing"
Enable-NetFirewallRule -DisplayGroup "Windows Remote Management"

# Start SMS service
Start-Service -Name "Storage Migration Service"

Write-Host "Target File Server with SMS configured successfully"

