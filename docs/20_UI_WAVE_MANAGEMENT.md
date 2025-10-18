# Turn-Key UI & Wave Management System

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Date:** October 2025

**Purpose:** Provide a user-friendly web interface that hides Ansible complexity, enables self-service wave management with checkpoints, and allows operators to skip problematic items without blocking the entire wave.

**Design Philosophy:** **"Click to migrate, not code to migrate"** – Hide Ansible/AWX complexity behind an intuitive UI.

---

## 1) System Overview

### 1.1 User Experience Goals

✅ **Turn-Key:** One-click wave execution with pre-flight checks  
✅ **Self-Service:** Operators manage waves without Ansible knowledge  
✅ **Visual:** Real-time dashboards, progress bars, status indicators  
✅ **Flexible:** Skip problematic items, reschedule, rollback individual machines  
✅ **Safe:** Checkpoints require approval before proceeding  
✅ **Transparent:** Clear error messages, detailed logs, troubleshooting guidance  

---

### 1.2 Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                      Web Browser                             │
│  ┌────────────────────────────────────────────────────────┐  │
│  │     React/Vue.js Frontend (Migration Dashboard)        │  │
│  │  - Wave Builder                                        │  │
│  │  - Machine/User Selector (checkboxes)                  │  │
│  │  - Checkpoint Approvals                                │  │
│  │  - Real-time Progress                                  │  │
│  │  - Exception Management                                │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
                         │ HTTPS (REST API)
                         ▼
┌──────────────────────────────────────────────────────────────┐
│           Backend API (Python FastAPI / Flask)               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  - Wave Management API                                 │  │
│  │  - Checkpoint Logic                                    │  │
│  │  - Exception Handling                                  │  │
│  │  │  - AWX API Client                                   │  │
│  │  - PostgreSQL (state management)                       │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
                         │ AWX REST API
                         ▼
┌──────────────────────────────────────────────────────────────┐
│                  AWX (Ansible Tower)                         │
│  - Job Templates (pre-configured playbooks)                  │
│  - Inventories (machines, users)                             │
│  - Credentials (domain admin, Azure, etc.)                   │
│  - Job Execution                                             │
└──────────────────────────────────────────────────────────────┘
                         │ Ansible Playbooks
                         ▼
┌──────────────────────────────────────────────────────────────┐
│              Target Infrastructure                           │
│  - Source AD / Entra ID                                      │
│  - Target AD / Entra ID                                      │
│  - Workstations, Servers, Databases                          │
└──────────────────────────────────────────────────────────────┘
```

---

## 2) Wave Management Interface

### 2.1 Wave Builder (UI Mockup)

```
╔═══════════════════════════════════════════════════════════════╗
║  🏢 Migration Dashboard - Wave Builder                        ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Wave: Production - Wave 3                      [Edit Name]   ║
║  Scheduled: 2025-11-15 @ 6:00 PM EST          [Reschedule]   ║
║  Estimated Duration: 4 hours 30 minutes                       ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 📊 Wave Summary                                         │ ║
║  │                                                         │ ║
║  │  Total Items: 250                                       │ ║
║  │  ✅ Ready:    235  (checkmark = passed pre-flight)     │ ║
║  │  ⚠️  Warning:  10  (yellow = needs attention)          │ ║
║  │  ❌ Blocked:    5  (red = blocking issues)             │ ║
║  │                                                         │ ║
║  │  [View Pre-Flight Report]                               │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 🎯 Select Items to Migrate                              │ ║
║  │                                                         │ ║
║  │  Filter: [All] [Workstations] [Servers] [Users]        │ ║
║  │  Search: [____________]  Sort: [Status ▼]              │ ║
║  │                                                         │ ║
║  │  ┌────────────────────────────────────────────────┐    │ ║
║  │  │ ☑️ Select All (235 ready items)                │    │ ║
║  │  │ ☐ Include warnings (10 items - not recommended)│    │ ║
║  │  │ ☐ Force blocked (5 items - dangerous!)        │    │ ║
║  │  └────────────────────────────────────────────────┘    │ ║
║  │                                                         │ ║
║  │  ┌──────────────────────────────────────────────────┐  │ ║
║  │  │ Machine Name      │ Type │ User  │ Status │ ☑️  │  │ ║
║  │  ├──────────────────────────────────────────────────┤  │ ║
║  │  │ WKS-ACCT-001      │ Win11│ jdoe  │ ✅ Ready│ ☑  │  │ ║
║  │  │ WKS-ACCT-002      │ Win11│ asmith│ ✅ Ready│ ☑  │  │ ║
║  │  │ WKS-ACCT-003      │ Win10│ bjones│ ✅ Ready│ ☑  │  │ ║
║  │  │ WKS-ACCT-004      │ Win11│ mwill │ ⚠️ Warn │ ☐  │  │ ║
║  │  │   └─ Warning: Disk space low (15 GB)   [Details]   │ ║
║  │  │ WKS-ACCT-005      │ Win10│ tlee  │ ❌ Block│ ☐  │  │ ║
║  │  │   └─ Error: USMT scan failed [Troubleshoot]       │ ║
║  │  │ WKS-HR-001        │ Win11│ cwhite│ ✅ Ready│ ☑  │  │ ║
║  │  │ ...                                               │  │ ║
║  │  └──────────────────────────────────────────────────┘  │ ║
║  │                                                         │ ║
║  │  [Bulk Actions ▼]  [Export List]  [Import from CSV]    │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 🚦 Checkpoints (Approval Gates)                         │ ║
║  │                                                         │ ║
║  │  ☑️ Checkpoint 1: Pre-Flight Validation Complete       │ ║
║  │  ☐ Checkpoint 2: Backup State Stores (auto-approve)   │ ║
║  │  ☐ Checkpoint 3: USMT Capture Complete (manual)       │ ║
║  │  ☐ Checkpoint 4: Domain Move Complete (manual)        │ ║
║  │  ☐ Checkpoint 5: USMT Restore Complete (manual)       │ ║
║  │  ☐ Checkpoint 6: Final Validation (manual)            │ ║
║  │                                                         │ ║
║  │  [Configure Checkpoints]                                │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ ⚙️ Wave Options                                         │ ║
║  │                                                         │ ║
║  │  ☑️ Run pre-flight checks before starting              │ ║
║  │  ☑️ Create snapshots before migration                  │ ║
║  │  ☑️ Send email notifications on checkpoint             │ ║
║  │  ☑️ Pause on first error (for debugging)               │ ║
║  │  ☐ Skip errors and continue (production mode)          │ ║
║  │  ☐ Enable dry-run mode (simulate only)                 │ ║
║  │                                                         │ ║
║  │  Parallelism: [10] concurrent migrations               │ ║
║  │  Timeout: [120] minutes per machine                    │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  [← Back to Dashboard]     [💾 Save Wave]  [🚀 Start Wave]  ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

### 2.2 Wave Execution (Real-Time Progress)

```
╔═══════════════════════════════════════════════════════════════╗
║  🚀 Wave 3 - In Progress                                      ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 📊 Overall Progress                                     │ ║
║  │                                                         │ ║
║  │  ████████████████░░░░░░░░ 67% (158/235 machines)       │ ║
║  │                                                         │ ║
║  │  ✅ Completed:     145                                  │ ║
║  │  🔄 In Progress:    13                                  │ ║
║  │  ⏸️  Queued:        67                                  │ ║
║  │  ⚠️  Warnings:       3  [View]                          │ ║
║  │  ❌ Failed:         10  [View]                          │ ║
║  │  ⏭️  Skipped:        5  [View]                          │ ║
║  │                                                         │ ║
║  │  Started: 6:00 PM EST                                   │ ║
║  │  Elapsed: 2h 15m                                        │ ║
║  │  ETA: 8:45 PM EST (30 minutes remaining)                │ ║
║  │                                                         │ ║
║  │  [Pause Wave]  [Emergency Stop]  [View Logs]            │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 🚦 Current Checkpoint: Domain Move Complete             │ ║
║  │                                                         │ ║
║  │  ⚠️ Manual Approval Required                            │ ║
║  │                                                         │ ║
║  │  Progress: 145/235 machines moved to target domain      │ ║
║  │  Success Rate: 93.5%                                    │ ║
║  │  Failures: 10 machines (see exception queue below)      │ ║
║  │                                                         │ ║
║  │  ⚠️ Review failures before proceeding to USMT restore   │ ║
║  │                                                         │ ║
║  │  [🛑 Reject & Rollback]  [➡️ Approve & Continue]       │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 🔄 Currently Migrating (13 in parallel)                │ ║
║  │                                                         │ ║
║  │  WKS-ACCT-045  │ Phase 4: Domain Join    │ ████░░ 65% │ ║
║  │  WKS-ACCT-046  │ Phase 3: Domain Disjoin │ █████░ 83% │ ║
║  │  WKS-ACCT-047  │ Phase 2: USMT Capture   │ ██░░░░ 40% │ ║
║  │  WKS-HR-012    │ Phase 5: USMT Restore   │ ██████ 95% │ ║
║  │  ... (9 more)                              [Show All]   │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ ❌ Exception Queue (10 items need attention)            │ ║
║  │                                                         │ ║
║  │  Machine       │ Error                     │ Action     │ ║
║  │  ─────────────────────────────────────────────────────  │ ║
║  │  WKS-ACCT-005  │ USMT capture failed      │ [Details]  │ ║
║  │    └─ Error: Access denied to C:\Users\tlee            │ ║
║  │    └─ Recommendation: Check file permissions           │ ║
║  │    └─ [Skip & Continue] [Retry Now] [Add to Remediate] │ ║
║  │                                                         │ ║
║  │  WKS-ACCT-015  │ Domain join timeout      │ [Details]  │ ║
║  │    └─ Error: Cannot reach target DC (timeout)          │ ║
║  │    └─ Recommendation: Verify network connectivity      │ ║
║  │    └─ [Skip & Continue] [Retry Now] [Add to Remediate] │ ║
║  │                                                         │ ║
║  │  WKS-ACCT-032  │ Secure channel failure   │ [Details]  │ ║
║  │    └─ Error: Trust relationship failed                 │ ║
║  │    └─ Recommendation: Run Test-ComputerSecureChannel   │ ║
║  │    └─ [Skip & Continue] [Retry Now] [Add to Remediate] │ ║
║  │                                                         │ ║
║  │  ... (7 more)                               [Show All]  │ ║
║  │                                                         │ ║
║  │  [Skip All] [Retry All] [Move to Remediation Wave]     │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  [Export Report]  [View Full Logs]  [Send Email Summary]     ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

## 3) Checkpoint System

### 3.1 Checkpoint Configuration

**Purpose:** Pause wave execution at critical points for manual review and approval.

**Checkpoint Types:**

| Checkpoint | Trigger | Approval Type | Can Skip? |
|------------|---------|---------------|-----------|
| **Pre-Flight** | Before wave starts | Auto (if all pass) | No |
| **Post-Backup** | After snapshots | Auto | Yes |
| **Post-USMT-Capture** | After user data backed up | Manual | No |
| **Post-Domain-Move** | After domain change | Manual | No |
| **Post-USMT-Restore** | After user data restored | Manual | No |
| **Final-Validation** | After all migrations | Manual | No |

**Checkpoint Data Model:**

```yaml
# checkpoints.yml
checkpoints:
  - id: pre_flight
    name: "Pre-Flight Validation"
    phase: before_wave
    approval_type: auto
    auto_approve_threshold: 100  # % of machines that must pass
    can_skip: false
    
  - id: post_usmt_capture
    name: "USMT Capture Complete"
    phase: after_phase_2
    approval_type: manual
    reviewers:
      - ops-team@company.com
      - migration-lead@company.com
    can_skip: false
    notification:
      email: true
      slack: true
      teams: true
    
  - id: post_domain_move
    name: "Domain Move Complete"
    phase: after_phase_4
    approval_type: manual
    reviewers:
      - ops-team@company.com
    can_skip: false
    validation_checks:
      - verify_domain_membership
      - verify_ad_computer_object
      - verify_secure_channel
    success_threshold: 95  # % of machines that must succeed
```

---

### 3.2 Checkpoint Approval UI

```
╔═══════════════════════════════════════════════════════════════╗
║  🚦 Checkpoint Approval Required                              ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Wave: Production - Wave 3                                    ║
║  Checkpoint: Post-Domain-Move (Phase 4 Complete)              ║
║  Timestamp: 2025-11-15 8:15 PM EST                            ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 📊 Checkpoint Summary                                   │ ║
║  │                                                         │ ║
║  │  Total Machines: 235                                    │ ║
║  │  ✅ Successful:   220 (93.6%)                           │ ║
║  │  ❌ Failed:        10 (4.3%)                            │ ║
║  │  ⏭️ Skipped:        5 (2.1%)                            │ ║
║  │                                                         │ ║
║  │  Success Rate: 93.6%  (Threshold: 95%) ⚠️              │ ║
║  │                                                         │ ║
║  │  ⚠️ Below success threshold - review recommended       │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 🔍 Validation Checks                                    │ ║
║  │                                                         │ ║
║  │  ✅ Domain membership verified (220/220)                │ ║
║  │  ✅ AD computer objects created (220/220)               │ ║
║  │  ✅ Secure channel established (215/220)                │ ║
║  │     └─ ⚠️ 5 machines have weak secure channel         │ ║
║  │  ✅ DNS registration successful (218/220)               │ ║
║  │     └─ ⚠️ 2 machines have stale DNS records           │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ ❌ Failed Machines (10)                                 │ ║
║  │                                                         │ ║
║  │  1. WKS-ACCT-005 - Domain join timeout                 │ ║
║  │  2. WKS-ACCT-015 - Cannot reach target DC              │ ║
║  │  3. WKS-ACCT-032 - Secure channel failure              │ ║
║  │  ... (7 more)                            [View Details] │ ║
║  │                                                         │ ║
║  │  [Move to Remediation Wave]  [View Full Report]        │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 📝 Approval Decision                                    │ ║
║  │                                                         │ ║
║  │  ◉ Approve & Continue                                  │ ║
║  │     Continue to Phase 5 (USMT Restore) with 220        │ ║
║  │     successful machines. Move 10 failed machines to    │ ║
║  │     remediation queue.                                 │ ║
║  │                                                         │ ║
║  │  ○ Reject & Pause                                      │ ║
║  │     Pause wave for troubleshooting. Do not proceed.    │ ║
║  │                                                         │ ║
║  │  ○ Reject & Rollback                                   │ ║
║  │     Rollback all 220 successful machines to source     │ ║
║  │     domain. Abort wave.                                │ ║
║  │                                                         │ ║
║  │  Notes: [___________________________________________]   │ ║
║  │         [___________________________________________]   │ ║
║  │                                                         │ ║
║  │  Approver: ops-lead@company.com (required)             │ ║
║  │                                                         │ ║
║  │  [Submit Approval]                                      │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

## 4) Exception Handling Workflow

### 4.1 Exception Queue Logic

**When a machine fails:**

1. **Immediate Actions:**
   - Pause that machine's migration
   - Add to exception queue
   - Continue other machines (don't block wave)
   - Send notification

2. **Operator Options:**
   - **Skip & Continue:** Exclude from wave, add to remediation list
   - **Retry Now:** Re-run migration for this machine
   - **Troubleshoot:** View logs, run diagnostics
   - **Rollback Single:** Rollback just this machine
   - **Mark for Review:** Flag for later investigation

3. **Wave Behavior:**
   - **Dev/POC:** Pause on first error (for debugging)
   - **Production:** Continue on error, collect exceptions

---

### 4.2 Exception Detail View

```
╔═══════════════════════════════════════════════════════════════╗
║  ❌ Exception Details - WKS-ACCT-005                          ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 📋 Machine Information                                  │ ║
║  │                                                         │ ║
║  │  Hostname: WKS-ACCT-005                                 │ ║
║  │  IP: 10.200.2.45                                        │ ║
║  │  OS: Windows 11 Pro 23H2                                │ ║
║  │  Primary User: tlee@olddomain.com                       │ ║
║  │  Department: Accounting                                 │ ║
║  │  Location: New York Office                              │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ ❌ Error Summary                                        │ ║
║  │                                                         │ ║
║  │  Phase: Phase 2 - USMT Capture                          │ ║
║  │  Error Code: USMT-0003                                  │ ║
║  │  Error Message: Access denied to C:\Users\tlee          │ ║
║  │  Timestamp: 2025-11-15 7:23 PM EST                      │ ║
║  │  Retry Count: 2                                         │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 🔍 Root Cause Analysis                                  │ ║
║  │                                                         │ ║
║  │  Detected Issue: File/folder permissions              │ ║
║  │                                                         │ ║
║  │  Details:                                               │ ║
║  │  - USMT scanstate.exe cannot access user profile       │ ║
║  │  - Folder: C:\Users\tlee\AppData\Local\Temp            │ ║
║  │  - Current permissions: BUILTIN\Administrators (deny)   │ ║
║  │  - Required: SYSTEM (full control)                      │ ║
║  │                                                         │ ║
║  │  Similar Issues:                                        │ ║  │  - 3 other machines in this wave had same error         │ ║
║  │  - Common in machines with third-party encryption       │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 💡 Recommended Actions                                  │ ║
║  │                                                         │ ║
║  │  1. [Auto-Fix] Reset folder permissions                │ ║
║  │     Run: icacls "C:\Users\tlee\AppData" /reset /T      │ ║
║  │     Estimated time: 2 minutes                           │ ║
║  │     Success rate: 95%                                   │ ║
║  │     [Run Now]                                           │ ║
║  │                                                         │ ║
║  │  2. [Manual Fix] Remote into machine via Guacamole     │ ║
║  │     Fix permissions manually                            │ ║
║  │     [Open Remote Session]                               │ ║
║  │                                                         │ ║
║  │  3. [Workaround] Skip encrypted folders                │ ║
║  │     Modify USMT config to exclude Temp folder           │ ║
║  │     [Apply & Retry]                                     │ ║
║  │                                                         │ ║
║  │  4. [Escalate] Contact user to unlock                  │ ║
║  │     Send email to tlee@company.com                      │ ║
║  │     [Send Email]                                        │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 📜 Full Error Log                                       │ ║
║  │                                                         │ ║
║  │  [2025-11-15 19:23:12] INFO: Starting USMT capture     │ ║
║  │  [2025-11-15 19:23:14] INFO: Scanning user profile...  │ ║
║  │  [2025-11-15 19:23:18] WARN: Access denied to temp dir │ ║
║  │  [2025-11-15 19:23:20] ERROR: USMT scanstate failed    │ ║
║  │  [2025-11-15 19:23:20] ERROR: Exit code: 27            │ ║
║  │  [2025-11-15 19:23:21] INFO: Attempting retry (1/3)    │ ║
║  │  ...                                  [View Full Log]   │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 🛠️ Remediation Actions                                  │ ║
║  │                                                         │ ║
║  │  [🔄 Retry Migration]  [🔧 Run Diagnostics]            │ ║
║  │  [⏭️ Skip & Continue]  [🔙 Rollback Machine]           │ ║
║  │  [📋 Add to Remediation Wave]                           │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  [← Back to Exception Queue]              [Export Report]    ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

## 5) Pre-Flight Check Interface

### 5.1 Pre-Flight Dashboard

```
╔═══════════════════════════════════════════════════════════════╗
║  ✈️ Pre-Flight Checks - Wave 3                                ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Status: ⚠️ In Progress (187/235 complete)                    ║
║  Started: 2025-11-15 5:30 PM EST                              ║
║  ETA: 6:00 PM EST (30 minutes remaining)                      ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 📊 Check Summary                                        │ ║
║  │                                                         │ ║
║  │  ✅ Passed:     180 machines (76.6%)                    │ ║
║  │  ⚠️  Warnings:    7 machines (3.0%)                     │ ║
║  │  ❌ Failed:      48 machines (20.4%)                    │ ║
║  │  🔄 Running:    48 machines                             │ ║
║  │                                                         │ ║
║  │  Wave Readiness: ⚠️ 76.6% (Recommended: >90%)          │ ║
║  │                                                         │ ║
║  │  [View Full Report]  [Export to Excel]                  │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 🔍 Check Categories                                     │ ║
║  │                                                         │ ║
║  │  ✅ Network Connectivity (235/235)             100%     │ ║
║  │  ✅ WinRM Access (235/235)                     100%     │ ║
║  │  ✅ Domain Membership (235/235)                100%     │ ║
║  │  ⚠️  Disk Space (227/235)                      96.6%    │ ║
║  │     └─ 8 machines below 20 GB free             [View]   │ ║
║  │  ❌ USMT Prerequisites (187/235)               79.6%    │ ║
║  │     └─ 48 machines missing USMT files          [View]   │ ║
║  │  ✅ Software Inventory (235/235)               100%     │ ║
║  │  ✅ User Profile Size (233/235)                99.1%    │ ║
║  │     └─ 2 profiles >50 GB                       [View]   │ ║
║  │  ✅ Antivirus Status (235/235)                 100%     │ ║
║  │  ✅ Pending Reboots (230/235)                  97.9%    │ ║
║  │     └─ 5 machines need reboot                  [View]   │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ ❌ Failed Checks (48 machines)                          │ ║
║  │                                                         │ ║
║  │  Issue: Missing USMT files (48 machines)                │ ║
║  │  Severity: High                                         │ ║
║  │  Impact: Cannot migrate without USMT                    │ ║
║  │                                                         │ ║
║  │  Machines: WKS-ACCT-010, WKS-ACCT-012, ... [View All]   │ ║
║  │                                                         │ ║
║  │  Recommended Action:                                    │ ║
║  │  [Bulk Install USMT]  Run playbook to deploy USMT      │ ║
║  │                       to all 48 machines                │ ║
║  │                       Estimated time: 15 minutes        │ ║
║  │                       [Run Now]                         │ ║
║  │                                                         │ ║
║  │  Alternative:                                           │ ║
║  │  [Exclude from Wave]  Remove 48 machines from wave     │ ║
║  │                       Migrate in later wave             │ ║
║  │                       [Apply]                           │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ ⚠️  Warnings (7 machines)                               │ ║
║  │                                                         │ ║
║  │  Issue: Low disk space (7 machines)                     │ ║
║  │  Severity: Medium                                       │ ║
║  │  Impact: May fail during USMT capture                   │ ║
║  │                                                         │ ║
║  │  WKS-ACCT-004: 15 GB free (needs 20 GB)                │ ║
║  │  WKS-HR-008:   18 GB free (needs 20 GB)                │ ║
║  │  ... (5 more)                            [View All]     │ ║
║  │                                                         │ ║
║  │  Recommended Action:                                    │ ║
║  │  [Cleanup Disk Space]  Run disk cleanup tool           │ ║
║  │                        Delete temp files, old logs      │ ║
║  │                        [Run Now]                        │ ║
║  │                                                         │ ║
║  │  Alternative:                                           │ ║
║  │  [Proceed with Warning]  Risk: Possible failure        │ ║
║  │                          during migration               │ ║
║  │                          [Accept Risk & Continue]       │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  [← Back to Wave Builder]   [Fix All Issues]  [Start Wave]   ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

## 6) Remediation Wave Management

### 6.1 Remediation Queue

```
╔═══════════════════════════════════════════════════════════════╗
║  🔧 Remediation Queue                                         ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 📊 Summary                                              │ ║
║  │                                                         │ ║
║  │  Total Items: 53                                        │ ║
║  │  From Wave 1: 12                                        │ ║
║  │  From Wave 2:  8                                        │ ║
║  │  From Wave 3: 33                                        │ ║
║  │                                                         │ ║
║  │  ✅ Fixed & Ready: 18  [Move to Next Wave]             │ ║
║  │  🔄 In Progress:   10  [View Status]                    │ ║
║  │  ⏸️  Pending:       25  [Start Troubleshooting]         │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 📋 Remediation Items                                    │ ║
║  │                                                         │ ║
║  │  Filter: [All] [By Wave] [By Error Type]               │ ║
║  │  Sort: [Priority ▼]                                     │ ║
║  │                                                         │ ║
║  │  Machine      │ Original Wave │ Error        │ Status  │ ║
║  │  ──────────────────────────────────────────────────────│ ║
║  │  WKS-ACCT-005 │ Wave 3        │ USMT Capture │ ⏸️ Pend │ ║
║  │    └─ Priority: High  Assigned: jdoe@company.com       │ ║
║  │    └─ Notes: User locked files, waiting for unlock     │ ║
║  │    └─ [Start Troubleshooting] [Reassign] [Update]     │ ║
║  │                                                         │ ║
║  │  WKS-ACCT-015 │ Wave 3        │ Domain Join  │ 🔄 Work │ ║
║  │    └─ Priority: High  Assigned: ops-team               │ ║
║  │    └─ Notes: Network config fixed, retrying now        │ ║
║  │    └─ [View Progress] [View Logs]                      │ ║
║  │                                                         │ ║
║  │  WKS-HR-042   │ Wave 2        │ Profile Size │ ✅ Fix  │ ║
║  │    └─ Priority: Medium  Assigned: ops-team             │ ║
║  │    └─ Notes: Cleaned up profile, now 12 GB             │ ║
║  │    └─ [Re-test Pre-Flight] [Add to Next Wave]         │ ║
║  │                                                         │ ║
║  │  ... (50 more)                             [Show All]  │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 🎯 Quick Actions                                        │ ║
║  │                                                         │ ║
║  │  [Create Remediation Wave]  Bundle fixed items into    │ ║
║  │                             new migration wave          │ ║
║  │                             [Create Wave]               │ ║
║  │                                                         │ ║
║  │  [Bulk Retry]               Retry all failed items     │ ║
║  │                             with fixes applied          │ ║
║  │                             [Start Bulk Retry]          │ ║
║  │                                                         │ ║
║  │  [Export to CSV]            Download for offline work  │ ║
║  │                             [Export]                    │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

## 7) Implementation - Backend API

### 7.1 FastAPI Backend Structure

```python
# backend/app/main.py
from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Optional
import asyncio

app = FastAPI(title="Migration Dashboard API")

# CORS for frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],  # React dev server
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─────────────────────────────────────────────────────────
# Wave Management API
# ─────────────────────────────────────────────────────────

@app.get("/api/waves")
async def list_waves():
    """Get all migration waves"""
    # Query PostgreSQL for waves
    waves = await db.fetch_all("SELECT * FROM waves ORDER BY scheduled_time")
    return waves

@app.post("/api/waves")
async def create_wave(wave: WaveCreate):
    """Create new migration wave"""
    wave_id = await db.insert_wave(wave)
    return {"wave_id": wave_id, "status": "created"}

@app.get("/api/waves/{wave_id}/machines")
async def get_wave_machines(wave_id: int, status: Optional[str] = None):
    """Get machines in wave with optional status filter"""
    query = """
        SELECT m.*, wm.status, wm.error_message 
        FROM machines m
        JOIN wave_machines wm ON m.id = wm.machine_id
        WHERE wm.wave_id = :wave_id
    """
    if status:
        query += " AND wm.status = :status"
    
    machines = await db.fetch_all(query, {"wave_id": wave_id, "status": status})
    return machines

@app.post("/api/waves/{wave_id}/machines/toggle")
async def toggle_machines(wave_id: int, machine_ids: List[int], include: bool):
    """Add or remove machines from wave"""
    if include:
        await db.add_machines_to_wave(wave_id, machine_ids)
    else:
        await db.remove_machines_from_wave(wave_id, machine_ids)
    return {"status": "updated", "count": len(machine_ids)}

@app.post("/api/waves/{wave_id}/start")
async def start_wave(wave_id: int):
    """Start wave execution via AWX"""
    # 1. Run pre-flight checks
    preflight_job = await awx_client.launch_job_template(
        template_id="pre_flight_checks",
        extra_vars={"wave_id": wave_id}
    )
    
    # 2. Wait for pre-flight completion
    await awx_client.wait_for_job(preflight_job.id)
    
    # 3. Evaluate pre-flight results
    results = await evaluate_preflight(wave_id)
    
    if results["pass_rate"] < 0.90:
        raise HTTPException(
            status_code=400,
            detail=f"Pre-flight pass rate {results['pass_rate']} below threshold"
        )
    
    # 4. Launch main migration job
    migration_job = await awx_client.launch_job_template(
        template_id="wave_migration",
        extra_vars={"wave_id": wave_id}
    )
    
    # 5. Update wave status
    await db.update_wave_status(wave_id, "in_progress", migration_job.id)
    
    return {
        "status": "started",
        "job_id": migration_job.id,
        "preflight_results": results
    }

# ─────────────────────────────────────────────────────────
# Checkpoint API
# ─────────────────────────────────────────────────────────

@app.get("/api/waves/{wave_id}/checkpoints")
async def get_checkpoints(wave_id: int):
    """Get checkpoints for wave"""
    checkpoints = await db.fetch_all("""
        SELECT * FROM checkpoints 
        WHERE wave_id = :wave_id 
        ORDER BY sequence
    """, {"wave_id": wave_id})
    return checkpoints

@app.post("/api/checkpoints/{checkpoint_id}/approve")
async def approve_checkpoint(checkpoint_id: int, approval: CheckpointApproval):
    """Approve or reject checkpoint"""
    # 1. Validate approver
    if not await validate_approver(checkpoint_id, approval.approver_email):
        raise HTTPException(status_code=403, detail="Not authorized to approve")
    
    # 2. Update checkpoint status
    await db.update_checkpoint_status(
        checkpoint_id,
        "approved" if approval.approved else "rejected",
        approval.notes
    )
    
    # 3. If approved, resume wave
    if approval.approved:
        wave_id = await db.get_wave_id_for_checkpoint(checkpoint_id)
        await resume_wave(wave_id)
    else:
        # If rejected, pause or rollback based on decision
        if approval.action == "rollback":
            await initiate_rollback(wave_id)
    
    return {"status": "processed"}

# ─────────────────────────────────────────────────────────
# Exception Handling API
# ─────────────────────────────────────────────────────────

@app.get("/api/waves/{wave_id}/exceptions")
async def get_exceptions(wave_id: int):
    """Get exception queue for wave"""
    exceptions = await db.fetch_all("""
        SELECT m.hostname, m.ip_address, e.error_code, e.error_message, 
               e.phase, e.timestamp, e.retry_count, e.status
        FROM exceptions e
        JOIN machines m ON e.machine_id = m.id
        WHERE e.wave_id = :wave_id AND e.status != 'resolved'
        ORDER BY e.timestamp DESC
    """, {"wave_id": wave_id})
    
    # Enrich with recommendations
    for exception in exceptions:
        exception["recommendations"] = await get_recommendations(
            exception["error_code"]
        )
    
    return exceptions

@app.post("/api/exceptions/{exception_id}/action")
async def handle_exception(exception_id: int, action: ExceptionAction):
    """Handle exception with specified action"""
    exception = await db.get_exception(exception_id)
    
    if action.action == "retry":
        # Retry migration for this machine
        job = await awx_client.launch_job_template(
            template_id="single_machine_migration",
            extra_vars={
                "machine_id": exception["machine_id"],
                "wave_id": exception["wave_id"]
            }
        )
        await db.update_exception_status(exception_id, "retrying", job_id=job.id)
        
    elif action.action == "skip":
        # Skip this machine, continue wave
        await db.update_exception_status(exception_id, "skipped")
        await db.update_machine_status(exception["machine_id"], "skipped")
        
    elif action.action == "remediate":
        # Add to remediation queue
        await db.add_to_remediation_queue(
            exception["machine_id"],
            exception["wave_id"],
            exception["error_code"],
            action.notes
        )
        await db.update_exception_status(exception_id, "remediation")
        
    elif action.action == "rollback":
        # Rollback single machine
        job = await awx_client.launch_job_template(
            template_id="rollback_single_machine",
            extra_vars={"machine_id": exception["machine_id"]}
        )
        await db.update_exception_status(exception_id, "rolling_back", job_id=job.id)
    
    return {"status": "action_initiated", "action": action.action}

# ─────────────────────────────────────────────────────────
# Pre-Flight Checks API
# ─────────────────────────────────────────────────────────

@app.post("/api/waves/{wave_id}/preflight")
async def run_preflight_checks(wave_id: int):
    """Run pre-flight checks for wave"""
    # Launch AWX job for pre-flight checks
    job = await awx_client.launch_job_template(
        template_id="pre_flight_checks",
        extra_vars={"wave_id": wave_id}
    )
    
    return {
        "status": "running",
        "job_id": job.id,
        "estimated_time": "15 minutes"
    }

@app.get("/api/waves/{wave_id}/preflight/results")
async def get_preflight_results(wave_id: int):
    """Get pre-flight check results"""
    results = await db.fetch_all("""
        SELECT m.hostname, c.check_name, c.status, c.message, c.severity
        FROM preflight_checks c
        JOIN machines m ON c.machine_id = m.id
        WHERE c.wave_id = :wave_id
        ORDER BY c.severity DESC, m.hostname
    """, {"wave_id": wave_id})
    
    # Aggregate statistics
    stats = {
        "total": len(set([r["hostname"] for r in results])),
        "passed": len([r for r in results if r["status"] == "pass"]),
        "warnings": len([r for r in results if r["status"] == "warning"]),
        "failed": len([r for r in results if r["status"] == "fail"])
    }
    
    return {"stats": stats, "details": results}

# ─────────────────────────────────────────────────────────
# Real-Time Progress API (WebSocket)
# ─────────────────────────────────────────────────────────

@app.websocket("/ws/waves/{wave_id}/progress")
async def wave_progress_websocket(websocket: WebSocket, wave_id: int):
    """WebSocket for real-time wave progress updates"""
    await websocket.accept()
    
    try:
        while True:
            # Query current progress
            progress = await db.fetch_one("""
                SELECT 
                    COUNT(*) FILTER (WHERE status = 'completed') as completed,
                    COUNT(*) FILTER (WHERE status = 'in_progress') as in_progress,
                    COUNT(*) FILTER (WHERE status = 'queued') as queued,
                    COUNT(*) FILTER (WHERE status = 'failed') as failed,
                    COUNT(*) FILTER (WHERE status = 'skipped') as skipped
                FROM wave_machines
                WHERE wave_id = :wave_id
            """, {"wave_id": wave_id})
            
            # Send update
            await websocket.send_json(progress)
            
            # Wait before next update
            await asyncio.sleep(5)
            
    except WebSocketDisconnect:
        print(f"Client disconnected from wave {wave_id} progress")
```

---

### 7.2 Data Models

```python
# backend/app/models.py
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from enum import Enum

class MachineStatus(str, Enum):
    READY = "ready"
    WARNING = "warning"
    BLOCKED = "blocked"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    FAILED = "failed"
    SKIPPED = "skipped"

class Machine(BaseModel):
    id: int
    hostname: str
    ip_address: str
    os_type: str
    os_version: str
    primary_user: Optional[str]
    department: Optional[str]
    location: Optional[str]
    status: MachineStatus
    preflight_passed: bool
    last_seen: datetime

class WaveCreate(BaseModel):
    name: str
    scheduled_time: datetime
    parallelism: int = 10
    timeout_minutes: int = 120
    enable_preflight: bool = True
    enable_snapshots: bool = True
    pause_on_error: bool = False
    send_notifications: bool = True

class Wave(BaseModel):
    id: int
    name: str
    scheduled_time: datetime
    status: str  # draft, scheduled, in_progress, paused, completed, failed
    created_at: datetime
    created_by: str
    machine_count: int
    completed_count: int
    failed_count: int

class Checkpoint(BaseModel):
    id: int
    wave_id: int
    name: str
    phase: str
    approval_type: str  # auto, manual
    status: str  # pending, approved, rejected
    required_approvers: List[str]
    approved_by: Optional[str]
    approved_at: Optional[datetime]
    notes: Optional[str]

class Exception(BaseModel):
    id: int
    wave_id: int
    machine_id: int
    error_code: str
    error_message: str
    phase: str
    timestamp: datetime
    retry_count: int
    status: str  # active, retrying, skipped, remediation, resolved
    recommendations: List[str]

class CheckpointApproval(BaseModel):
    checkpoint_id: int
    approved: bool
    action: str  # continue, pause, rollback
    approver_email: str
    notes: Optional[str]

class ExceptionAction(BaseModel):
    exception_id: int
    action: str  # retry, skip, remediate, rollback
    notes: Optional[str]
```

---

## 8) Implementation - Frontend (React)

### 8.1 Frontend Structure

```
frontend/
├── src/
│   ├── components/
│   │   ├── WaveBuilder/
│   │   │   ├── WaveBuilder.tsx          # Main wave builder UI
│   │   │   ├── MachineSelector.tsx      # Machine selection with checkboxes
│   │   │   ├── CheckpointConfig.tsx     # Checkpoint configuration
│   │   │   └── WaveOptions.tsx          # Wave settings
│   │   │
│   │   ├── WaveExecution/
│   │   │   ├── WaveProgress.tsx         # Real-time progress dashboard
│   │   │   ├── CheckpointApproval.tsx   # Checkpoint approval UI
│   │   │   ├── ExceptionQueue.tsx       # Exception queue display
│   │   │   └── ExceptionDetail.tsx      # Exception detail view
│   │   │
│   │   ├── PreFlight/
│   │   │   ├── PreFlightDashboard.tsx   # Pre-flight checks UI
│   │   │   └── PreFlightResults.tsx     # Pre-flight results
│   │   │
│   │   ├── Remediation/
│   │   │   └── RemediationQueue.tsx     # Remediation management
│   │   │
│   │   └── Common/
│   │       ├── StatusBadge.tsx          # Status indicator component
│   │       ├── ProgressBar.tsx          # Progress bar component
│   │       └── DataTable.tsx            # Reusable data table
│   │
│   ├── services/
│   │   ├── api.ts                       # API client
│   │   └── websocket.ts                 # WebSocket client
│   │
│   ├── hooks/
│   │   ├── useWaveProgress.ts           # Real-time progress hook
│   │   └── useCheckpoints.ts            # Checkpoint management hook
│   │
│   └── App.tsx
```

---

### 8.2 Machine Selector Component (React)

```typescript
// frontend/src/components/WaveBuilder/MachineSelector.tsx
import React, { useState, useEffect } from 'react';
import { Checkbox, Table, Badge, Button, Input, Select } from '@/components/ui';
import { api } from '@/services/api';

interface Machine {
  id: number;
  hostname: string;
  type: string;
  primary_user: string;
  status: 'ready' | 'warning' | 'blocked';
  error_message?: string;
}

export const MachineSelector: React.FC<{ waveId: number }> = ({ waveId }) => {
  const [machines, setMachines] = useState<Machine[]>([]);
  const [selected, setSelected] = useState<Set<number>>(new Set());
  const [filter, setFilter] = useState<string>('all');
  const [search, setSearch] = useState<string>('');

  useEffect(() => {
    loadMachines();
  }, [waveId]);

  const loadMachines = async () => {
    const data = await api.get(`/api/waves/${waveId}/machines`);
    setMachines(data);
    
    // Auto-select all "ready" machines
    const readyIds = data
      .filter((m: Machine) => m.status === 'ready')
      .map((m: Machine) => m.id);
    setSelected(new Set(readyIds));
  };

  const toggleSelection = (id: number) => {
    const newSelected = new Set(selected);
    if (newSelected.has(id)) {
      newSelected.delete(id);
    } else {
      newSelected.add(id);
    }
    setSelected(newSelected);
  };

  const toggleAll = (includeWarnings: boolean = false) => {
    const statuses = includeWarnings ? ['ready', 'warning'] : ['ready'];
    const ids = machines
      .filter(m => statuses.includes(m.status))
      .map(m => m.id);
    setSelected(new Set(ids));
  };

  const saveSelection = async () => {
    await api.post(`/api/waves/${waveId}/machines/toggle`, {
      machine_ids: Array.from(selected),
      include: true
    });
    
    // Unselect machines not in selection
    const unselected = machines
      .filter(m => !selected.has(m.id))
      .map(m => m.id);
    
    if (unselected.length > 0) {
      await api.post(`/api/waves/${waveId}/machines/toggle`, {
        machine_ids: unselected,
        include: false
      });
    }
  };

  const getStatusBadge = (status: string) => {
    const variants = {
      ready: { color: 'green', label: '✅ Ready' },
      warning: { color: 'yellow', label: '⚠️ Warning' },
      blocked: { color: 'red', label: '❌ Blocked' }
    };
    const variant = variants[status as keyof typeof variants];
    return <Badge color={variant.color}>{variant.label}</Badge>;
  };

  const filteredMachines = machines.filter(m => {
    if (filter !== 'all' && m.status !== filter) return false;
    if (search && !m.hostname.toLowerCase().includes(search.toLowerCase())) return false;
    return true;
  });

  return (
    <div className="machine-selector">
      {/* Filter Controls */}
      <div className="flex gap-4 mb-4">
        <Input
          placeholder="Search machines..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="w-64"
        />
        <Select value={filter} onChange={setFilter}>
          <option value="all">All Statuses</option>
          <option value="ready">Ready Only</option>
          <option value="warning">Warnings Only</option>
          <option value="blocked">Blocked Only</option>
        </Select>
      </div>

      {/* Bulk Selection */}
      <div className="flex gap-2 mb-4">
        <Button onClick={() => toggleAll(false)}>
          Select All Ready ({machines.filter(m => m.status === 'ready').length})
        </Button>
        <Button variant="secondary" onClick={() => toggleAll(true)}>
          Include Warnings (+{machines.filter(m => m.status === 'warning').length})
        </Button>
        <Button variant="outline" onClick={() => setSelected(new Set())}>
          Deselect All
        </Button>
      </div>

      {/* Summary */}
      <div className="bg-blue-50 p-4 rounded mb-4">
        <p className="font-semibold">Selected: {selected.size} machines</p>
        <p className="text-sm text-gray-600">
          {machines.filter(m => selected.has(m.id) && m.status === 'ready').length} ready, 
          {machines.filter(m => selected.has(m.id) && m.status === 'warning').length} warnings, 
          {machines.filter(m => selected.has(m.id) && m.status === 'blocked').length} blocked
        </p>
      </div>

      {/* Machine Table */}
      <Table>
        <thead>
          <tr>
            <th></th>
            <th>Machine Name</th>
            <th>Type</th>
            <th>Primary User</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          {filteredMachines.map(machine => (
            <React.Fragment key={machine.id}>
              <tr className={selected.has(machine.id) ? 'bg-blue-50' : ''}>
                <td>
                  <Checkbox
                    checked={selected.has(machine.id)}
                    onChange={() => toggleSelection(machine.id)}
                    disabled={machine.status === 'blocked'}
                  />
                </td>
                <td>{machine.hostname}</td>
                <td>{machine.type}</td>
                <td>{machine.primary_user}</td>
                <td>{getStatusBadge(machine.status)}</td>
              </tr>
              {machine.error_message && (
                <tr className="text-sm text-gray-600">
                  <td></td>
                  <td colSpan={4}>
                    └─ {machine.error_message} 
                    <Button variant="link" size="sm">Details</Button>
                  </td>
                </tr>
              )}
            </React.Fragment>
          ))}
        </tbody>
      </Table>

      {/* Save Button */}
      <div className="mt-4 flex justify-end">
        <Button onClick={saveSelection} variant="primary">
          Save Selection ({selected.size} machines)
        </Button>
      </div>
    </div>
  );
};
```

---

## 9) Deployment

### 9.1 Docker Compose (Complete Stack)

```yaml
# docker-compose.yml
version: '3.8'

services:
  # PostgreSQL Database
  postgres:
    image: postgres:14
    environment:
      POSTGRES_DB: migration
      POSTGRES_USER: migration
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backend/db/schema.sql:/docker-entrypoint-initdb.d/schema.sql
    ports:
      - "5432:5432"

  # Backend API
  backend:
    build: ./backend
    environment:
      DATABASE_URL: postgresql://migration:${POSTGRES_PASSWORD}@postgres:5432/migration
      AWX_URL: ${AWX_URL}
      AWX_TOKEN: ${AWX_TOKEN}
    ports:
      - "8000:8000"
    depends_on:
      - postgres

  # Frontend
  frontend:
    build: ./frontend
    ports:
      - "3000:3000"
    environment:
      REACT_APP_API_URL: http://localhost:8000
    depends_on:
      - backend

  # Nginx (reverse proxy)
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - frontend
      - backend

volumes:
  postgres_data:
```

---

## 10) Summary

### What You Get

✅ **Turn-Key UI:** Click-based wave management, no Ansible knowledge required  
✅ **Flexible Selection:** Checkbox selection for machines/users, bulk actions  
✅ **Checkpoint System:** Approval gates at critical phases, prevent runaway failures  
✅ **Exception Handling:** Skip problematic items, don't block entire wave  
✅ **Real-Time Progress:** WebSocket-based live updates, ETA calculation  
✅ **Remediation Queue:** Track failed items, fix and retry  
✅ **Pre-Flight Checks:** Validate before starting, auto-fix common issues  
✅ **Visual Dashboards:** Progress bars, status badges, color coding  

### Complexity Hidden

❌ Ansible playbooks  
❌ AWX job templates  
❌ Inventory management  
❌ Variable files  
❌ Command-line tools  

### User Experience

**Before Migration:**
1. Select machines (checkboxes)
2. Run pre-flight checks (one button)
3. Fix any issues (guided recommendations)
4. Click "Start Wave"

**During Migration:**
1. Watch real-time progress
2. Approve checkpoints (if needed)
3. Handle exceptions (skip, retry, or troubleshoot)
4. Don't wait - problematic items move to remediation queue

**After Migration:**
1. Review summary report
2. Fix remediation queue items
3. Schedule remediation wave

**Total Complexity Seen by User:** Nearly zero!

---

**END OF DOCUMENT**

