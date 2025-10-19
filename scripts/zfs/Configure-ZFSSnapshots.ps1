<#
.SYNOPSIS
    Configures ZFS snapshot schedules for file servers
.DESCRIPTION
    Creates automated ZFS snapshot schedules with retention policies:
    - Hourly snapshots (keep 24)
    - Daily snapshots (keep 7)
    - Weekly snapshots (keep 4)
    - Monthly snapshots (keep 12)
.PARAMETER FileServer
    FQDN of file server with ZFS
.PARAMETER DatasetName
    ZFS dataset name (e.g., "tank/data")
.PARAMETER EnableReplication
    Enable replication to secondary site
.EXAMPLE
    .\Configure-ZFSSnapshots.ps1 -FileServer "fs01.source.local" -DatasetName "tank/shares"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$FileServer,
    
    [Parameter(Mandatory=$true)]
    [string]$DatasetName,
    
    [Parameter()]
    [switch]$EnableReplication,
    
    [Parameter()]
    [string]$ReplicationTarget
)

Write-Host @"

╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║          📸 ZFS Snapshot Configuration                              ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  File Server: $FileServer" -ForegroundColor Gray
Write-Host "  Dataset: $DatasetName" -ForegroundColor Gray
Write-Host "  Replication: $(if ($EnableReplication) { 'Enabled' } else { 'Disabled' })" -ForegroundColor Gray
Write-Host ""

# ZFS snapshot script content
$snapshotScript = @'
#!/bin/bash
# ZFS Snapshot Management Script
# Manages automated snapshots with retention policies

DATASET="DATASET_NAME"
SNAPSHOT_PREFIX="auto"

# Function: Create snapshot
create_snapshot() {
    local freq=$1
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local snapshot_name="${DATASET}@${SNAPSHOT_PREFIX}-${freq}-${timestamp}"
    
    echo "Creating ${freq} snapshot: ${snapshot_name}"
    zfs snapshot "${snapshot_name}"
    
    if [ $? -eq 0 ]; then
        echo "✅ Snapshot created successfully"
        return 0
    else
        echo "❌ Failed to create snapshot"
        return 1
    fi
}

# Function: Clean old snapshots
cleanup_snapshots() {
    local freq=$1
    local keep=$2
    
    echo "Cleaning old ${freq} snapshots (keeping ${keep})"
    
    # Get list of snapshots for this frequency
    zfs list -t snapshot -o name -s creation | \
        grep "${DATASET}@${SNAPSHOT_PREFIX}-${freq}-" | \
        head -n -${keep} | \
        while read snapshot; do
            echo "  Removing: ${snapshot}"
            zfs destroy "${snapshot}"
        done
}

# Hourly snapshot (keep 24)
if [ "$1" == "hourly" ]; then
    create_snapshot "hourly"
    cleanup_snapshots "hourly" 24
fi

# Daily snapshot (keep 7)
if [ "$1" == "daily" ]; then
    create_snapshot "daily"
    cleanup_snapshots "daily" 7
fi

# Weekly snapshot (keep 4)
if [ "$1" == "weekly" ]; then
    create_snapshot "weekly"
    cleanup_snapshots "weekly" 4
fi

# Monthly snapshot (keep 12)
if [ "$1" == "monthly" ]; then
    create_snapshot "monthly"
    cleanup_snapshots "monthly" 12
fi

echo "Snapshot management complete"
'@

# Replace dataset name
$snapshotScript = $snapshotScript.Replace("DATASET_NAME", $DatasetName)

# Create cron schedule
$cronSchedule = @'
# ZFS Snapshot Schedule
# Managed by Configure-ZFSSnapshots.ps1

# Hourly snapshots (every hour)
0 * * * * /usr/local/bin/zfs-snapshot.sh hourly >> /var/log/zfs-snapshots.log 2>&1

# Daily snapshots (at 1:00 AM)
0 1 * * * /usr/local/bin/zfs-snapshot.sh daily >> /var/log/zfs-snapshots.log 2>&1

# Weekly snapshots (Sunday at 2:00 AM)
0 2 * * 0 /usr/local/bin/zfs-snapshot.sh weekly >> /var/log/zfs-snapshots.log 2>&1

# Monthly snapshots (1st of month at 3:00 AM)
0 3 1 * * /usr/local/bin/zfs-snapshot.sh monthly >> /var/log/zfs-snapshots.log 2>&1
'@

# Replication script (if enabled)
$replicationScript = @'
#!/bin/bash
# ZFS Replication Script
# Replicates snapshots to secondary site

SOURCE_DATASET="SOURCE_DATASET"
TARGET_HOST="TARGET_HOST"
TARGET_DATASET="TARGET_DATASET"

echo "Starting ZFS replication..."
echo "Source: ${SOURCE_DATASET}"
echo "Target: ${TARGET_HOST}:${TARGET_DATASET}"

# Get latest snapshot
LATEST_SNAPSHOT=$(zfs list -t snapshot -o name -s creation | \
                  grep "${SOURCE_DATASET}@${SNAPSHOT_PREFIX}-" | \
                  tail -n 1)

if [ -z "$LATEST_SNAPSHOT" ]; then
    echo "❌ No snapshots found to replicate"
    exit 1
fi

echo "Replicating: ${LATEST_SNAPSHOT}"

# Send incremental or full replication
# Check if target has any snapshots
ssh ${TARGET_HOST} "zfs list -t snapshot ${TARGET_DATASET}" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    # Incremental replication
    LAST_COMMON=$(ssh ${TARGET_HOST} "zfs list -t snapshot -o name ${TARGET_DATASET}" | \
                  tail -n 1)
    
    echo "Incremental replication from: ${LAST_COMMON}"
    zfs send -i ${LAST_COMMON} ${LATEST_SNAPSHOT} | \
        ssh ${TARGET_HOST} "zfs receive -F ${TARGET_DATASET}"
else
    # Full replication
    echo "Full replication"
    zfs send ${LATEST_SNAPSHOT} | \
        ssh ${TARGET_HOST} "zfs receive ${TARGET_DATASET}"
fi

if [ $? -eq 0 ]; then
    echo "✅ Replication completed successfully"
else
    echo "❌ Replication failed"
    exit 1
fi
'@

if ($EnableReplication) {
    $replicationScript = $replicationScript.Replace("SOURCE_DATASET", $DatasetName)
    $replicationScript = $replicationScript.Replace("TARGET_HOST", $ReplicationTarget)
    $replicationScript = $replicationScript.Replace("TARGET_DATASET", $DatasetName)
}

# Save scripts locally
$scriptPath = Join-Path $PSScriptRoot "zfs-snapshot.sh"
$snapshotScript | Out-File $scriptPath -Encoding UTF8

$cronPath = Join-Path $PSScriptRoot "zfs-crontab"
$cronSchedule | Out-File $cronPath -Encoding UTF8

if ($EnableReplication) {
    $replPath = Join-Path $PSScriptRoot "zfs-replication.sh"
    $replicationScript | Out-File $replPath -Encoding UTF8
}

Write-Host "📝 Scripts generated:" -ForegroundColor Green
Write-Host "   $scriptPath" -ForegroundColor Gray
Write-Host "   $cronPath" -ForegroundColor Gray
if ($EnableReplication) {
    Write-Host "   $replPath" -ForegroundColor Gray
}
Write-Host ""

# Deployment instructions
Write-Host "📋 Deployment Instructions:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Copy scripts to file server:" -ForegroundColor Yellow
Write-Host "   scp zfs-snapshot.sh root@${FileServer}:/usr/local/bin/" -ForegroundColor Gray
Write-Host "   scp zfs-crontab root@${FileServer}:/tmp/" -ForegroundColor Gray
if ($EnableReplication) {
    Write-Host "   scp zfs-replication.sh root@${FileServer}:/usr/local/bin/" -ForegroundColor Gray
}
Write-Host ""

Write-Host "2. On file server, make scripts executable:" -ForegroundColor Yellow
Write-Host "   ssh root@${FileServer}" -ForegroundColor Gray
Write-Host "   chmod +x /usr/local/bin/zfs-snapshot.sh" -ForegroundColor Gray
if ($EnableReplication) {
    Write-Host "   chmod +x /usr/local/bin/zfs-replication.sh" -ForegroundColor Gray
}
Write-Host ""

Write-Host "3. Install cron schedule:" -ForegroundColor Yellow
Write-Host "   crontab /tmp/zfs-crontab" -ForegroundColor Gray
Write-Host "   crontab -l  # Verify" -ForegroundColor Gray
Write-Host ""

Write-Host "4. Test snapshot creation:" -ForegroundColor Yellow
Write-Host "   /usr/local/bin/zfs-snapshot.sh hourly" -ForegroundColor Gray
Write-Host "   zfs list -t snapshot | grep $DatasetName" -ForegroundColor Gray
Write-Host ""

if ($EnableReplication) {
    Write-Host "5. Configure SSH key for replication:" -ForegroundColor Yellow
    Write-Host "   ssh-keygen -t rsa -b 4096" -ForegroundColor Gray
    Write-Host "   ssh-copy-id root@$ReplicationTarget" -ForegroundColor Gray
    Write-Host "   Test: ssh root@$ReplicationTarget 'zfs list'" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "6. Test replication:" -ForegroundColor Yellow
    Write-Host "   /usr/local/bin/zfs-replication.sh" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "📊 Snapshot Schedule:" -ForegroundColor Cyan
Write-Host "   Hourly:  Every hour (keep 24)" -ForegroundColor Gray
Write-Host "   Daily:   1:00 AM (keep 7)" -ForegroundColor Gray
Write-Host "   Weekly:  Sunday 2:00 AM (keep 4)" -ForegroundColor Gray
Write-Host "   Monthly: 1st at 3:00 AM (keep 12)" -ForegroundColor Gray
Write-Host ""

Write-Host "✅ ZFS snapshot configuration complete!" -ForegroundColor Green
Write-Host ""

