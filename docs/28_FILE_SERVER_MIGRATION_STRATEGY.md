# File Server Migration Strategy - Storage Migration Service

**Date:** October 2025  
**Author:** Adrian Johnson  
**Purpose:** Integrate Microsoft Storage Migration Service for file server migrations

---

## 🎯 Overview

**Storage Migration Service (SMS)** is Microsoft's tool for migrating file servers to Windows Server or Azure. We're integrating SMS into all three tiers to provide complete file server migration alongside AD migration.

### Key Benefits

✅ **Agentless:** No software installation on source servers  
✅ **Automated:** Discovery, transfer, and cutover automation  
✅ **Zero-downtime:** Staged migration with minimal cutover window  
✅ **Share preservation:** Maintains permissions, shares, and ACLs  
✅ **Azure support:** Can migrate to Azure Files or Azure File Sync  

---

## 🏗️ Architecture by Tier

### Tier 1 (Free/Demo)

```
Source Environment:
├── Source DC (existing)
└── Source File Server (B1ms, 1TB Standard HDD)
    ├── Windows Server 2022 Standard
    ├── Test shares: HR, Finance, Engineering
    └── 1,000 test files (10KB-10MB)

Target Environment:
├── Target DC (B2s)
├── Target File Server (B1ms, 1TB Standard HDD)
│   └── Windows Server 2022 Standard
└── SMS Orchestrator (on Target DC)
    └── Storage Migration Service role

Cost: +$30/month (2x B1ms)
Total Tier 1: $50-130/month
```

### Tier 2 (Production)

```
Source Environment:
├── Source DC (existing)
└── Source File Server (existing or D4s_v5, 4TB Premium SSD)
    ├── Windows Server 2022 Standard
    ├── Production shares
    └── Real data

Target Environment:
├── Target DC (B2s)
├── Target File Server (D4s_v5, 4TB Premium SSD)
│   ├── Windows Server 2022 Standard
│   ├── Deduplication enabled
│   └── DFS Replication ready
└── SMS Orchestrator (dedicated VM - D2s_v5)
    ├── Storage Migration Service
    └── Centralized management

Alternative: Azure Files Premium
├── No target file server VM needed
├── Direct migration to Azure Files
└── Cost: ~$0.12/GB/month

Cost: +$210/month (VMs) OR +$500/month (Azure Files for 4TB)
Total Tier 2: $1,000-1,300/month
```

### Tier 3 (Enterprise)

```
Multi-Region Setup:
├── Source File Servers (existing, multiple)
└── Target Options:
    ├── Option A: Azure Files Premium + Azure File Sync
    │   ├── Global file namespace
    │   ├── Multi-region replication
    │   └── Cloud tiering
    │
    ├── Option B: Target File Servers (D8s_v5 pool)
    │   ├── 3+ servers with DFS-R
    │   ├── Load balanced
    │   └── Geo-redundant
    │
    └── SMS Orchestrator Cluster (3 VMs)
        ├── High availability
        └── Parallel migrations

Cost: +$800-1,500/month depending on option
Total Tier 3: $6,800-7,500/month
```

---

## 🔧 Storage Migration Service Components

### 1. SMS Orchestrator

**Purpose:** Central management server running SMS role

**Requirements:**
- Windows Server 2022 Standard
- Minimum: 2 vCPU, 4GB RAM
- Network access to source and target servers
- Domain membership (target domain)

**Installation:**
```powershell
# Install SMS role
Install-WindowsFeature -Name SMS-Service -IncludeManagementTools

# Start SMS service
Start-Service -Name "Storage Migration Service"

# Verify installation
Get-WindowsFeature -Name SMS-Service
```

### 2. Source File Server

**Purpose:** Existing file server with data to migrate

**Supported Sources:**
- Windows Server 2012 R2+
- Windows Server 2008 R2 (with updates)
- Linux/Samba servers (with SMB 2.0+)
- NetApp NAS devices

**Preparation:**
```powershell
# Enable WinRM on source
Enable-PSRemoting -Force

# Enable file and printer sharing
Set-NetFirewallRule -Name "FPS-SMB-In-TCP" -Enabled True

# Verify shares
Get-SmbShare | Where-Object { $_.Special -eq $false }
```

### 3. Target File Server

**Purpose:** Destination for migrated data

**Configuration:**
- Same or newer Windows Server version
- Equal or larger storage capacity
- Domain-joined to target domain
- File Server role installed

**Setup:**
```powershell
# Install File Server role
Install-WindowsFeature -Name FS-FileServer -IncludeManagementTools

# Enable deduplication (optional)
Install-WindowsFeature -Name FS-Data-Deduplication

# Enable DFS (for Tier 2/3)
Install-WindowsFeature -Name FS-DFS-Namespace, FS-DFS-Replication
```

---

## 📊 Migration Process

### Phase 1: Discovery (1-2 hours)

```yaml
SMS Discovery:
  1. Add source servers to SMS
  2. Scan file system inventory
  3. Detect shares and permissions
  4. Analyze data size and structure
  5. Generate migration plan

Automated by Ansible:
  - ansible-playbook playbooks/sms/01_discovery.yml
```

### Phase 2: Transfer (Hours to Days)

```yaml
Data Transfer:
  1. Initial copy (full dataset)
  2. Incremental syncs (deltas)
  3. Validation and verification
  4. Pre-cutover testing

Stages:
  - Initial Transfer: 80-90% of time
  - Sync 1: 10% of changes
  - Sync 2: 5% of changes
  - Final Sync: <1% (during cutover)

Performance:
  - Tier 1: ~100 MB/s
  - Tier 2: ~500 MB/s (Premium SSD)
  - Tier 3: ~1 GB/s (multiple servers)
```

### Phase 3: Cutover (30-60 minutes)

```yaml
Cutover Steps:
  1. Stop source file shares
  2. Final incremental sync
  3. Transfer share definitions
  4. Set NTFS permissions
  5. Configure DFS namespace (if used)
  6. Enable target shares
  7. Update DNS/DFS pointers
  8. Test access from clients

Rollback Option:
  - Re-enable source shares
  - Revert DNS/DFS changes
  - No data loss
```

---

## 💾 Test Data Generation

### Demo File Structure

```
Test Shares:
├── HR\ (250 files, ~500 MB)
│   ├── Policies\ (50 PDFs, 1-5 MB each)
│   ├── Forms\ (100 DOCs, 50-200 KB each)
│   └── Reports\ (100 XLS, 100-500 KB each)
│
├── Finance\ (300 files, ~1.2 GB)
│   ├── Budget\ (50 XLS, 5-10 MB each)
│   ├── Invoices\ (200 PDFs, 500 KB-2 MB each)
│   └── Statements\ (50 PDFs, 1-5 MB each)
│
└── Engineering\ (450 files, ~2.8 GB)
    ├── Docs\ (150 PDFs, 1-10 MB each)
    ├── Specs\ (200 DOCs, 100 KB-5 MB each)
    └── Diagrams\ (100 VSD, 500 KB-10 MB each)

Total: 1,000 files, ~4.5 GB
```

### Generation Script

```powershell
# Create test data generation script
# Location: scripts/Generate-TestFileData.ps1

param(
    [int]$FileCount = 1000,
    [string]$OutputPath = "C:\TestShares"
)

$shares = @{
    "HR" = @{
        SubFolders = @("Policies", "Forms", "Reports")
        FileTypes = @(".pdf", ".docx", ".xlsx")
        SizeRange = @(50KB, 5MB)
        Count = 250
    }
    "Finance" = @{
        SubFolders = @("Budget", "Invoices", "Statements")
        FileTypes = @(".xlsx", ".pdf")
        SizeRange = @(500KB, 10MB)
        Count = 300
    }
    "Engineering" = @{
        SubFolders = @("Docs", "Specs", "Diagrams")
        FileTypes = @(".pdf", ".docx", ".vsdx")
        SizeRange = @(100KB, 10MB)
        Count = 450
    }
}

foreach ($share in $shares.Keys) {
    $sharePath = Join-Path $OutputPath $share
    New-Item -Path $sharePath -ItemType Directory -Force
    
    foreach ($folder in $shares[$share].SubFolders) {
        $folderPath = Join-Path $sharePath $folder
        New-Item -Path $folderPath -ItemType Directory -Force
        
        $filesPerFolder = [math]::Floor($shares[$share].Count / $shares[$share].SubFolders.Count)
        
        for ($i = 1; $i -le $filesPerFolder; $i++) {
            $ext = Get-Random -InputObject $shares[$share].FileTypes
            $fileName = "TestFile_$($i.ToString('D4'))$ext"
            $filePath = Join-Path $folderPath $fileName
            
            $minSize = $shares[$share].SizeRange[0]
            $maxSize = $shares[$share].SizeRange[1]
            $size = Get-Random -Minimum $minSize -Maximum $maxSize
            
            # Generate random binary data
            $bytes = New-Object byte[] $size
            (New-Object Random).NextBytes($bytes)
            [IO.File]::WriteAllBytes($filePath, $bytes)
            
            Write-Progress -Activity "Generating test files" `
                -Status "$share\$folder" `
                -PercentComplete (($i / $filesPerFolder) * 100)
        }
    }
    
    Write-Host "Created $($shares[$share].Count) files in $share share" -ForegroundColor Green
}

Write-Host "`nTest data generation complete!" -ForegroundColor Cyan
Write-Host "Total files: $(Get-ChildItem -Path $OutputPath -Recurse -File | Measure-Object).Count"
Write-Host "Total size: $([math]::Round((Get-ChildItem -Path $OutputPath -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1GB, 2)) GB"
```

---

## 🔄 Ansible Automation

### Playbook Structure

```yaml
ansible/playbooks/sms/
├── 00_install_sms.yml          # Install SMS on orchestrator
├── 01_discovery.yml            # Discover source servers
├── 02_prepare_target.yml       # Setup target file server
├── 03_generate_test_data.yml   # Create demo files
├── 04_transfer_data.yml        # Execute data migration
├── 05_validate_transfer.yml    # Verify migration
├── 06_cutover.yml              # Final cutover
└── 99_rollback_cutover.yml     # Revert if needed

ansible/roles/sms/
├── sms_orchestrator/
│   ├── tasks/
│   │   ├── main.yml            # Install SMS
│   │   └── configure.yml       # Setup SMS
│   └── defaults/main.yml
│
├── sms_discovery/
│   ├── tasks/
│   │   ├── main.yml            # Run discovery
│   │   └── inventory.yml       # Create inventory
│   └── templates/
│       └── inventory.json.j2
│
└── sms_migration/
    ├── tasks/
    │   ├── main.yml            # Execute migration
    │   ├── transfer.yml        # Data transfer
    │   └── cutover.yml         # Final cutover
    └── defaults/main.yml
```

### Example Playbook

```yaml
# ansible/playbooks/sms/04_transfer_data.yml

---
- name: SMS Data Transfer
  hosts: sms_orchestrator
  gather_facts: yes
  
  vars:
    source_server: "source-fs.source.local"
    target_server: "target-fs.target.local"
    shares:
      - name: "HR"
        path: "C:\\Shares\\HR"
      - name: "Finance"
        path: "C:\\Shares\\Finance"
      - name: "Engineering"
        path: "C:\\Shares\\Engineering"
  
  tasks:
    - name: Start SMS migration job
      win_shell: |
        Import-Module StorageMigrationService
        
        $job = New-SmsJob -Name "Migration_{{ ansible_date_time.epoch }}"
        
        Add-SmsSource -JobName $job.Name `
          -ComputerName "{{ source_server }}" `
          -Credential (Get-StoredCredential -Target "SourceAdmin")
        
        Add-SmsTarget -JobName $job.Name `
          -ComputerName "{{ target_server }}" `
          -Credential (Get-StoredCredential -Target "TargetAdmin")
        
        Start-SmsInventory -JobName $job.Name
        Start-SmsTransfer -JobName $job.Name
        
        Write-Output $job.Name
      register: migration_job
    
    - name: Monitor transfer progress
      win_shell: |
        Import-Module StorageMigrationService
        
        do {
          $status = Get-SmsTransferStatus -JobName "{{ migration_job.stdout | trim }}"
          
          Write-Host "Progress: $($status.PercentComplete)%"
          Write-Host "Transferred: $($status.BytesTransferred / 1GB) GB"
          Write-Host "Remaining: $($status.BytesRemaining / 1GB) GB"
          
          Start-Sleep -Seconds 60
        } while ($status.State -eq "Running")
        
        return $status
      register: transfer_status
      
    - name: Display transfer results
      debug:
        msg: |
          Transfer completed!
          Status: {{ transfer_status.stdout }}
          Files transferred: {{ (transfer_status.stdout | from_json).FilesTransferred }}
          Total size: {{ (transfer_status.stdout | from_json).BytesTransferred / 1GB }} GB
```

---

## 💰 Cost Analysis

### Tier 1 (Free/Demo)

```yaml
File Servers:
├── Source File Server (B1ms): $15/month
├── Target File Server (B1ms): $15/month
└── Storage (2x 1TB Standard HDD): $40/month

Total Addition: $70/month
New Tier 1 Total: $120-200/month
```

### Tier 2 (Production)

```yaml
Option A: VMs
├── Source File Server (existing): $0
├── Target File Server (D4s_v5): $140/month
├── SMS Orchestrator (D2s_v5): $70/month
└── Storage (4TB Premium SSD): $600/month

Total: $810/month

Option B: Azure Files Premium
├── Source File Server (existing): $0
├── Azure Files (4TB): $480/month
└── SMS Orchestrator (D2s_v5): $70/month

Total: $550/month (cheaper!)

Recommended: Option B
New Tier 2 Total: $1,342/month
```

### Tier 3 (Enterprise)

```yaml
Option A: Azure File Sync (Hybrid)
├── Azure Files Premium (10TB): $1,200/month
├── File Sync Service: $100/month
├── SMS Orchestrator Cluster (3x D2s_v5): $210/month
└── Bandwidth: $200/month

Total: $1,710/month

Option B: VM Pool
├── Target File Servers (3x D8s_v5): $1,400/month
├── Storage (30TB Premium): $4,500/month
├── SMS Orchestrator Cluster: $210/month

Total: $6,110/month

Recommended: Option A (Hybrid)
New Tier 3 Total: $7,671/month
```

---

## 🎯 Migration Scenarios

### Scenario 1: Small Office (Tier 1)

```
Source: 
├── Windows Server 2012 R2
├── 500 GB data
├── 3 shares (HR, Finance, IT)
└── 10 users

Target:
├── Windows Server 2022
├── 1 TB storage
└── Azure Files backup (optional)

Timeline:
├── Discovery: 30 minutes
├── Transfer: 4-6 hours
├── Cutover: 30 minutes
└── Total: 1 business day

Cost: $120/month (demo), $0 after migration complete
```

### Scenario 2: Medium Business (Tier 2)

```
Source:
├── Multiple Windows Server 2016+ servers
├── 5-10 TB data
├── 20-50 shares
└── 500 users

Target:
├── Azure Files Premium
├── Azure File Sync for on-prem cache
└── Global namespace

Timeline:
├── Discovery: 2-4 hours
├── Transfer: 2-3 days (staged)
├── Cutover: 1-2 hours
└── Total: 1 week

Cost: $1,342/month ongoing
```

### Scenario 3: Enterprise (Tier 3)

```
Source:
├── 10+ file servers
├── 50-100+ TB data
├── Hundreds of shares
└── 3,000+ users across regions

Target:
├── Azure Files Premium (multi-region)
├── Azure File Sync (global)
├── DFS Namespace integration
└── Tiered storage

Timeline:
├── Discovery: 1 day
├── Transfer: 1-2 weeks (parallel)
├── Cutover: 4-8 hours (staged)
└── Total: 3-4 weeks

Cost: $7,671/month ongoing
```

---

## 📚 Best Practices

### 1. Pre-Migration

- Run disk cleanup on source
- Remove old/temp files
- Consolidate duplicate data
- Document share permissions
- Test with small dataset first

### 2. During Migration

- Use incremental syncs
- Monitor network bandwidth
- Schedule transfers off-hours
- Keep source online (staged migration)
- Validate data integrity

### 3. Post-Migration

- Keep source read-only for 30 days
- Monitor target server performance
- Verify all permissions
- Update documentation
- Train users on any changes

### 4. Performance Tuning

```powershell
# Increase SMS transfer threads
Set-SmsTransferConfiguration -ThreadCount 16

# Enable compression for slow links
Set-SmsTransferConfiguration -Compression $true

# Optimize network buffer
Set-SmsTransferConfiguration -NetworkBufferSize 4MB

# Enable deduplication on target
Enable-DedupVolume -Volume "D:" -UsageType Default
```

---

## 🔒 Security Considerations

### Access Control

- SMS orchestrator needs admin on source and target
- Use dedicated service account
- Store credentials in Key Vault
- Enable audit logging

### Data Protection

- Encryption in transit (SMB 3.0+)
- Encryption at rest (BitLocker/Azure encryption)
- Maintain ACLs during migration
- Preserve file attributes

### Compliance

- Log all migration activities
- Maintain chain of custody
- Validate data integrity
- Document all changes

---

## 📋 Next Steps

1. ✅ Review architecture document
2. ⬜ Deploy file servers in all tiers
3. ⬜ Generate test data
4. ⬜ Create Ansible playbooks
5. ⬜ Test migration workflow
6. ⬜ Document procedures

---

**Status:** Architecture complete  
**Next:** Implement Terraform for file servers across all tiers 🚀

