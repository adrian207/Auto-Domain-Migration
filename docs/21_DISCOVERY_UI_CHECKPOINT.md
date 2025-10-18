# Discovery Results UI & Decision Checkpoint

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Date:** October 2025

**Purpose:** Provide an interactive dashboard to review discovery results, understand the migration landscape, make informed decisions about what to migrate, and identify potential issues before starting any migration work.

**Design Philosophy:** **"See before you leap"** – Full transparency of the source environment with actionable insights.

---

## 1) Discovery Workflow Overview

### 1.1 Discovery Process

```
┌─────────────────────────────────────────────────────────┐
│ 1. Run Discovery Playbooks                             │
│    - AD users, computers, groups                        │
│    - Services on servers                                │
│    - Database connections                               │
│    - DNS records                                        │
│    - Dependencies and relationships                     │
│    Duration: 30-60 minutes                              │
└─────────────────────────────────────────────────────────┘
                        ▼
┌─────────────────────────────────────────────────────────┐
│ 2. Process & Analyze Results                           │
│    - Categorize items                                   │
│    - Identify dependencies                              │
│    - Flag potential issues                              │
│    - Generate recommendations                           │
│    Duration: Automatic (5-10 minutes)                   │
└─────────────────────────────────────────────────────────┘
                        ▼
┌─────────────────────────────────────────────────────────┐
│ 3. CHECKPOINT: Review Discovery Results                │
│    - Interactive dashboard                              │
│    - Make inclusion/exclusion decisions                 │
│    - Resolve conflicts                                  │
│    - Approve migration scope                            │
│    Duration: Manual review (1-4 hours)                  │
└─────────────────────────────────────────────────────────┘
                        ▼
┌─────────────────────────────────────────────────────────┐
│ 4. Generate Migration Waves                            │
│    - Based on approved scope                            │
│    - Respecting dependencies                            │
│    - Optimized for minimal disruption                   │
│    Duration: Automatic (5 minutes)                      │
└─────────────────────────────────────────────────────────┘
```

---

## 2) Discovery Dashboard (Main View)

### 2.1 Dashboard Overview

```
╔═══════════════════════════════════════════════════════════════╗
║  🔍 Discovery Results - Project "NYC Office Migration"        ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Discovery Started:  2025-11-10 9:00 AM EST                   ║
║  Discovery Completed: 2025-11-10 10:15 AM EST                 ║
║  Duration: 1h 15m                                             ║
║  Status: ⚠️ Requires Review                                   ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 📊 Discovery Summary                                    │ ║
║  │                                                         │ ║
║  │  Source Domain: olddomain.corp.com                      │ ║
║  │  Discovery Scope: NYC Office OU                         │ ║
║  │                                                         │ ║
║  │  ┌──────────────────┬──────────┬──────────┬──────────┐ │ ║
║  │  │ Category         │ Total    │ Selected │ Excluded │ │ ║
║  │  ├──────────────────┼──────────┼──────────┼──────────┤ │ ║
║  │  │ 👥 Users          │  1,247   │    0     │    0     │ │ ║
║  │  │ 💻 Workstations   │    856   │    0     │    0     │ │ ║
║  │  │ 🖥️  Servers        │     43   │    0     │    0     │ │ ║
║  │  │ 👪 Groups         │    189   │    0     │    0     │ │ ║
║  │  │ 🔌 Services       │    327   │    0     │    0     │ │ ║
║  │  │ 🗄️  Databases      │     12   │    0     │    0     │ │ ║
║  │  │ 🌐 DNS Records    │  2,143   │    0     │    0     │ │ ║
║  │  └──────────────────┴──────────┴──────────┴──────────┘ │ ║
║  │                                                         │ ║
║  │  ⚠️  Issues Found: 87  [View Details]                   │ ║
║  │  💡 Recommendations: 23  [View All]                     │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 🚨 Critical Issues (Blockers)                           │ ║
║  │                                                         │ ║
║  │  ❌ 3 servers with unknown OS version                   │ ║
║  │     └─ Cannot determine migration compatibility        │ ║
║  │     └─ [View] [Tag for Manual Review]                  │ ║
║  │                                                         │ ║
║  │  ❌ 12 workstations offline for >30 days               │ ║
║  │     └─ Cannot validate current state                   │ ║
║  │     └─ [View] [Exclude from Migration]                 │ ║
║  │                                                         │ ║
║  │  ❌ 5 service accounts with circular dependencies       │ ║
║  │     └─ May cause migration failures                    │ ║
║  │     └─ [View Dependency Graph] [Resolve]               │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ ⚠️ Warnings (Need Attention)                            │ ║
║  │                                                         │ ║
║  │  ⚠️ 34 machines with low disk space (<20 GB)           │ ║
║  │  ⚠️ 8 users with profiles >50 GB (slow migration)      │ ║
║  │  ⚠️ 15 machines missing USMT prerequisites             │ ║
║  │  ⚠️ 23 DNS records with invalid IP addresses           │ ║
║  │                                                         │ ║
║  │  [View All Warnings]                                    │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 📑 Quick Actions                                        │ ║
║  │                                                         │ ║
║  │  [Review Users]      [Review Computers]                 │ ║
║  │  [Review Services]   [Review Dependencies]              │ ║
║  │  [Export Report]     [Generate Wave Plan]               │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 🚦 Discovery Checkpoint Status                          │ ║
║  │                                                         │ ║
║  │  Status: ⏸️ Pending Review                              │ ║
║  │  Required Actions:                                      │ ║
║  │  ☐ Review all critical issues                          │ ║
║  │  ☐ Make inclusion/exclusion decisions                  │ ║
║  │  ☐ Resolve conflicts                                   │ ║
║  │  ☐ Approve migration scope                             │ ║
║  │                                                         │ ║
║  │  Once complete, you can proceed to wave planning.      │ ║
║  │                                                         │ ║
║  │  [Start Review Process]                                 │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

## 3) User Discovery Results

### 3.1 User Review Interface

```
╔═══════════════════════════════════════════════════════════════╗
║  👥 User Discovery Results (1,247 users)                      ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 📊 User Statistics                                      │ ║
║  │                                                         │ ║
║  │  Total Users: 1,247                                     │ ║
║  │  ✅ Active: 1,089 (87.3%)                               │ ║
║  │  ⏸️ Disabled: 94 (7.5%)                                 │ ║
║  │  ⚠️ Inactive >90 days: 64 (5.1%)                        │ ║
║  │                                                         │ ║
║  │  By Type:                                               │ ║
║  │  - Regular Users: 1,143 (91.7%)                         │ ║
║  │  - Service Accounts: 89 (7.1%)                          │ ║
║  │  - Admin Accounts: 15 (1.2%)                            │ ║
║  │                                                         │ ║
║  │  Profile Sizes:                                         │ ║
║  │  - <10 GB: 823 users                                    │ ║
║  │  - 10-50 GB: 416 users                                  │ ║
║  │  - >50 GB: 8 users ⚠️                                   │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 🔍 Filters & Search                                     │ ║
║  │                                                         │ ║
║  │  Search: [___________________]  🔎                      │ ║
║  │                                                         │ ║
║  │  Status: [All ▼] [Active] [Disabled] [Inactive]        │ ║
║  │  Type: [All ▼] [Users] [Service Accts] [Admins]        │ ║
║  │  Department: [All ▼] [Sales] [IT] [HR] [Finance]       │ ║
║  │  Issues: [All ▼] [Has Issues] [No Issues]              │ ║
║  │                                                         │ ║
║  │  Sort: [Last Logon ▼] [Name] [Department] [Profile]    │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 📋 User List                                            │ ║
║  │                                                         │ ║
║  │  ☑️ Select All (1,247) | ☐ Select Active Only (1,089)  │ ║
║  │  ☐ Select by Department | ☐ Advanced Selection         │ ║
║  │                                                         │ ║
║  │  ┌──────────────────────────────────────────────────┐  │ ║
║  │  │ ☑ │ Username  │ Name      │ Dept  │ Status│ ⚠️ │  │ ║
║  │  ├──────────────────────────────────────────────────┤  │ ║
║  │  │ ☑ │ jdoe      │ John Doe  │ Sales │ ✅ Act│   │  │ ║
║  │  │   │ Last Logon: 2025-11-09 │ Profile: 12 GB  │   │  │ ║
║  │  │   │ Groups: 5 │ Computers: 1 │ [Details]      │   │  │ ║
║  │  │                                                    │  │ ║
║  │  │ ☑ │ asmith    │ Alice Smith│ IT   │ ✅ Act│   │  │ ║
║  │  │   │ Last Logon: 2025-11-10 │ Profile: 8 GB   │   │  │ ║
║  │  │   │ Groups: 12 │ Computers: 2 │ [Details]     │   │  │ ║
║  │  │                                                    │  │ ║
║  │  │ ☐ │ bjones    │ Bob Jones │ Sales │ ⏸️ Dis│   │  │ ║
║  │  │   │ Disabled: 2025-08-15 │ Profile: 5 GB     │   │  │ ║
║  │  │   │ Reason: Terminated │ [Exclude] [Details] │   │  │ ║
║  │  │                                                    │  │ ║
║  │  │ ☑ │ mwilliams │ Mary Will │ HR    │ ✅ Act│ ⚠️│  │ ║
║  │  │   │ Last Logon: 2025-11-08 │ Profile: 67 GB ⚠️│   │  │ ║
║  │  │   │ ⚠️ Large profile - migration may be slow     │   │  │ ║
║  │  │   │ Recommendation: Clean up before migration  │   │  │ ║
║  │  │   │ [Details] [View Profile Contents]          │   │  │ ║
║  │  │                                                    │  │ ║
║  │  │ ☐ │ svc_sql   │ SQL Svc   │ IT    │ ✅ Act│ ⚠️│  │ ║
║  │  │   │ Type: Service Account │ Password: Never Exp │  │ ║
║  │  │   │ ⚠️ Used by 12 servers - needs special handling│ │ ║
║  │  │   │ Dependencies: [View Graph] [Details]       │   │  │ ║
║  │  │                                                    │  │ ║
║  │  │ ☐ │ tlee      │ Tom Lee   │ Sales │ ⚠️ Ina│ ⚠️│  │ ║
║  │  │   │ Last Logon: 2025-07-12 (121 days ago)     │   │  │ ║
║  │  │   │ ⚠️ Inactive >90 days - verify before migrating││ │ ║
║  │  │   │ [Contact User] [Exclude] [Details]         │   │  │ ║
║  │  │                                                    │  │ ║
║  │  │ ... (1,241 more users)               [Show More]│  │ ║
║  │  └──────────────────────────────────────────────────┘  │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 💡 Bulk Actions                                         │ ║
║  │                                                         │ ║
║  │  With Selected (1,089 users):                           │ ║
║  │  [✅ Include in Migration]  [❌ Exclude from Migration] │ ║
║  │  [🏷️ Tag as VIP]  [📧 Send Email]  [📊 Export List]   │ ║
║  │                                                         │ ║
║  │  Special Actions:                                       │ ║
║  │  [Auto-Exclude Disabled]  [Auto-Exclude Inactive >90d] │ ║
║  │  [Auto-Flag Large Profiles]  [Auto-Flag Service Accts] │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 📈 Analysis & Recommendations                           │ ║
║  │                                                         │ ║
║  │  💡 Recommendation: Exclude 94 disabled accounts        │ ║
║  │     Reason: No longer active in organization           │ ║
║  │     Impact: Reduces migration scope by 7.5%            │ ║
║  │     [Apply Recommendation]                              │ ║
║  │                                                         │ ║
║  │  💡 Recommendation: Cleanup 8 large profiles first      │ ║
║  │     Reason: Profiles >50 GB slow down migration        │ ║
║  │     Impact: Could save 3-4 hours per profile           │ ║
║  │     [Send Cleanup Request to Users]                     │ ║
║  │                                                         │ ║
║  │  💡 Recommendation: Verify 64 inactive accounts         │ ║
║  │     Reason: Not logged in >90 days                     │ ║
║  │     Action: Contact managers to verify status          │ ║
║  │     [Generate Contact List]                             │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  [← Back to Discovery]  [Save Selections]  [Continue →]      ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

## 4) Computer Discovery Results

### 4.1 Computer Review Interface

```
╔═══════════════════════════════════════════════════════════════╗
║  💻 Computer Discovery Results (899 computers)                ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 📊 Computer Statistics                                  │ ║
║  │                                                         │ ║
║  │  Total Computers: 899                                   │ ║
║  │  - Workstations: 856 (95.2%)                            │ ║
║  │  - Servers: 43 (4.8%)                                   │ ║
║  │                                                         │ ║
║  │  Status:                                                │ ║
║  │  ✅ Online: 783 (87.1%)                                 │ ║
║  │  ⚠️ Offline <7 days: 74 (8.2%)                          │ ║
║  │  ❌ Offline >30 days: 42 (4.7%)                         │ ║
║  │                                                         │ ║
║  │  Operating Systems:                                     │ ║
║  │  - Windows 11: 432 (50.5%)                              │ ║
║  │  - Windows 10: 412 (48.1%)                              │ ║
║  │  - Windows Server 2019: 28 (3.3%)                       │ ║
║  │  - Windows Server 2022: 15 (1.8%)                       │ ║
║  │  - Unknown/Linux: 12 (1.4%)                             │ ║
║  │                                                         │ ║
║  │  Health:                                                │ ║
║  │  ✅ Healthy: 802 (89.2%)                                │ ║
║  │  ⚠️ Warnings: 55 (6.1%)                                 │ ║
║  │  ❌ Issues: 42 (4.7%)                                   │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 🗺️ Computer Visualization                               │ ║
║  │                                                         │ ║
║  │  View: [List] [Grid] [🗺️ Map] [📊 Chart]               │ ║
║  │                                                         │ ║
║  │  ┌─────────────────────────────────────────────────┐   │ ║
║  │  │  OS Distribution                                │   │ ║
║  │  │                                                 │   │ ║
║  │  │  ████████████ Windows 11 (50.5%)               │   │ ║
║  │  │  ███████████ Windows 10 (48.1%)                │   │ ║
║  │  │  █ Server 2019 (3.3%)                          │   │ ║
║  │  │  █ Other (1.8%)                                │   │ ║
║  │  └─────────────────────────────────────────────────┘   │ ║
║  │                                                         │ ║
║  │  ┌─────────────────────────────────────────────────┐   │ ║
║  │  │  By Location                                    │   │ ║
║  │  │                                                 │   │ ║
║  │  │  NYC Office: 523 computers                      │   │ ║
║  │  │  ├─ Floor 5: 187                                │   │ ║
║  │  │  ├─ Floor 6: 156                                │   │ ║
║  │  │  ├─ Floor 7: 123                                │   │ ║
║  │  │  └─ Server Room: 57                             │   │ ║
║  │  │                                                 │   │ ║
║  │  │  Remote/VPN: 376 computers                      │   │ ║
║  │  └─────────────────────────────────────────────────┘   │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 💻 Computer List (showing workstations)                 │ ║
║  │                                                         │ ║
║  │  Filter: [All] [✅ Workstations] [Servers] [Problematic]│ ║
║  │  Search: [___________________]  🔎                      │ ║
║  │                                                         │ ║
║  │  ┌──────────────────────────────────────────────────┐  │ ║
║  │  │☑│ Hostname    │ OS      │ User    │ Status│ ⚠️ │  │ ║
║  │  ├──────────────────────────────────────────────────┤  │ ║
║  │  │☑│ WKS-NYC-001 │ Win11   │ jdoe    │ ✅    │   │  │ ║
║  │  │ │ Last Seen: 2025-11-10 14:23                    │  │ ║
║  │  │ │ IP: 10.10.5.45 │ Disk: 85 GB free │ RAM: 16GB │  │ ║
║  │  │ │ Installed Software: 47 apps │ [Details]       │  │ ║
║  │  │                                                    │  │ ║
║  │  │☑│ WKS-NYC-002 │ Win10   │ asmith  │ ✅    │   │  │ ║
║  │  │ │ Last Seen: 2025-11-10 15:12                    │  │ ║
║  │  │ │ IP: 10.10.5.46 │ Disk: 120 GB free│ RAM: 8GB  │  │ ║
║  │  │ │ Installed Software: 32 apps │ [Details]       │  │ ║
║  │  │                                                    │  │ ║
║  │  │☑│ WKS-NYC-003 │ Win11   │ mwill   │ ✅    │ ⚠️│  │ ║
║  │  │ │ Last Seen: 2025-11-10 11:34                    │  │ ║
║  │  │ │ IP: 10.10.5.47 │ Disk: 15 GB free ⚠️│RAM: 16GB│  │ ║
║  │  │ │ ⚠️ Low disk space - may fail USMT capture     │  │ ║
║  │  │ │ Recommendation: Free up space before migration│  │ ║
║  │  │ │ [Run Disk Cleanup] [Details]                  │  │ ║
║  │  │                                                    │  │ ║
║  │  │☐│ WKS-NYC-087 │ Win10   │ tlee    │ ❌    │ ⚠️│  │ ║
║  │  │ │ Last Seen: 2025-08-05 (97 days ago)           │  │ ║
║  │  │ │ Status: Offline │ Cannot reach for validation │  │ ║
║  │  │ │ ⚠️ Recommend: Exclude from migration          │  │ ║
║  │  │ │ [Exclude] [Try to Ping] [Details]             │  │ ║
║  │  │                                                    │  │ ║
║  │  │☑│ WKS-REMOTE-15│ Win11  │ bjones  │ ✅    │ 🌐│  │ ║
║  │  │ │ Last Seen: 2025-11-09 22:15 (VPN)             │  │ ║
║  │  │ │ Location: Remote/Home │ Connection: VPN       │  │ ║
║  │  │ │ 🌐 Special handling: Coordinate with user     │  │ ║
║  │  │ │ [Schedule Migration Window] [Details]         │  │ ║
║  │  │                                                    │  │ ║
║  │  │ ... (851 more computers)             [Show More]│  │ ║
║  │  └──────────────────────────────────────────────────┘  │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 🖥️ Server Deep Dive (43 servers)                        │ ║
║  │                                                         │ ║
║  │  Filter: [All] [File Servers] [DB Servers] [App Servers]│ ║
║  │                                                         │ ║
║  │  ┌──────────────────────────────────────────────────┐  │ ║
║  │  │☑│ Hostname    │ Role        │ Services │ ⚠️     │  │ ║
║  │  ├──────────────────────────────────────────────────┤  │ ║
║  │  │☑│ SVR-SQL-01  │ DB Server   │ 12       │ ⚠️    │  │ ║
║  │  │ │ OS: Server 2019 │ SQL Server 2019 Enterprise  │  │ ║
║  │  │ │ Services: SQL Server, SQL Agent, SSRS, SSAS   │  │ ║
║  │  │ │ ⚠️ Mixed auth: Windows + SQL logins           │  │ ║
║  │  │ │ ⚠️ 23 dependent applications                   │  │ ║
║  │  │ │ [View Services] [View Dependencies] [Details] │  │ ║
║  │  │                                                    │  │ ║
║  │  │☑│ SVR-FILE-01 │ File Server │ 8        │       │  │ ║
║  │  │ │ OS: Server 2022 │ File & Storage Services     │  │ ║
║  │  │ │ Shares: 47 │ Total Size: 12.4 TB              │  │ ║
║  │  │ │ Services: SMB, DFS, FSRM                       │  │ ║
║  │  │ │ [View Shares] [View ACLs] [Details]           │  │ ║
║  │  │                                                    │  │ ║
║  │  │☑│ SVR-APP-05  │ App Server  │ 15       │ ⚠️    │  │ ║
║  │  │ │ OS: Server 2019 │ IIS 10, .NET 4.8            │  │ ║
║  │  │ │ Websites: 8 │ App Pools: 12                   │  │ ║
║  │  │ │ ⚠️ Custom service accounts: 5                  │  │ ║
║  │  │ │ ⚠️ Scheduled tasks: 18                         │  │ ║
║  │  │ │ [View Services] [View Tasks] [Details]        │  │ ║
║  │  │                                                    │  │ ║
║  │  │ ... (40 more servers)                [Show More]│  │ ║
║  │  └──────────────────────────────────────────────────┘  │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  [← Back to Discovery]  [Save Selections]  [Continue →]      ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

## 5) Service & Dependency Discovery

### 5.1 Service Discovery Results

```
╔═══════════════════════════════════════════════════════════════╗
║  🔌 Service Discovery Results (327 services)                  ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 📊 Service Statistics                                   │ ║
║  │                                                         │ ║
║  │  Total Services: 327 (on 43 servers)                    │ ║
║  │                                                         │ ║
║  │  By Type:                                               │ ║
║  │  - Windows Services: 189                                │ ║
║  │  - IIS Websites/Apps: 78                                │ ║
║  │  - SQL Server Instances: 18                             │ ║
║  │  - Scheduled Tasks: 42                                  │ ║
║  │                                                         │ ║
║  │  Authentication:                                        │ ║
║  │  - LocalSystem: 98 (30.0%)                              │ ║
║  │  - NetworkService: 76 (23.2%)                           │ ║
║  │  - Domain Accounts: 153 (46.8%) ⚠️                      │ ║
║  │                                                         │ ║
║  │  ⚠️ 153 services use domain accounts - require updates │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 🔍 Service List                                         │ ║
║  │                                                         │ ║
║  │  Filter: [All] [Domain Account] [Critical] [Issues]    │ ║
║  │  Group By: [Server] [Service Type] [Account]           │ ║
║  │                                                         │ ║
║  │  ┌──────────────────────────────────────────────────┐  │ ║
║  │  │ Server: SVR-SQL-01                               │  │ ║
║  │  │                                                    │  │ ║
║  │  │ ☑ │ Service Name       │ Account      │ Status  │  │ ║
║  │  │ ├─────────────────────────────────────────────── │  │ ║
║  │  │ ☑ │ MSSQLSERVER        │ DOMAIN\      │ ⚠️     │  │ ║
║  │  │   │                    │ svc_sql      │ Running │  │ ║
║  │  │   │ Type: SQL Server Database Engine              │  │ ║
║  │  │   │ ⚠️ Service account needs domain update       │  │ ║
║  │  │   │ ⚠️ SPNs registered: MSSQLSvc/SVR-SQL-01:1433 │  │ ║
║  │  │   │ Action Required: Re-register SPNs post-move  │  │ ║
║  │  │   │ [View Details] [Plan Update]                 │  │ ║
║  │  │                                                    │  │ ║
║  │  │ ☑ │ SQLSERVERAGENT     │ DOMAIN\      │ ⚠️     │  │ ║
║  │  │   │                    │ svc_sql      │ Running │  │ ║
║  │  │   │ Type: SQL Server Agent                        │  │ ║
║  │  │   │ ⚠️ Same account as MSSQLSERVER - update both │  │ ║
║  │  │   │ Jobs: 23 (some may reference domain accounts)│  │ ║
║  │  │   │ [View Jobs] [Plan Update]                    │  │ ║
║  │  │                                                    │  │ ║
║  │  │ ☑ │ ReportServer       │ DOMAIN\      │ ⚠️     │  │ ║
║  │  │   │                    │ svc_ssrs     │ Running │  │ ║
║  │  │   │ Type: SQL Server Reporting Services           │  │ ║
║  │  │   │ ⚠️ Different service account                  │  │ ║
║  │  │   │ Reports: 34 │ Subscriptions: 12              │  │ ║
║  │  │   │ [View Details] [Plan Update]                 │  │ ║
║  │  └──────────────────────────────────────────────────┘  │ ║
║  │                                                         │ ║
║  │  ┌──────────────────────────────────────────────────┐  │ ║
║  │  │ Server: SVR-APP-05                               │  │ ║
║  │  │                                                    │  │ ║
║  │  │ ☑ │ W3SVC (IIS)        │ LocalSystem  │ ✅     │  │ ║
║  │  │   │ Type: World Wide Web Publishing Service       │  │ ║
║  │  │   │ ✅ No domain dependency                       │  │ ║
║  │  │   │ Application Pools: 12 (8 use domain accounts)│  │ ║
║  │  │   │ [View App Pools] [Details]                   │  │ ║
║  │  │                                                    │  │ ║
║  │  │ ☑ │ AppPool: MainApp   │ DOMAIN\      │ ⚠️     │  │ ║
║  │  │   │                    │ svc_webapp   │ Running │  │ ║
║  │  │   │ Type: IIS Application Pool                    │  │ ║
║  │  │   │ Websites: 3 │ Virtual Dirs: 7                │  │ ║
║  │  │   │ ⚠️ Identity: Domain account                   │  │ ║
║  │  │   │ ⚠️ Connection strings may reference domain   │  │ ║
║  │  │   │ [View Websites] [View Config] [Plan Update]  │  │ ║
║  │  │                                                    │  │ ║
║  │  │ ☑ │ MyCustomService    │ DOMAIN\      │ ⚠️     │  │ ║
║  │  │   │                    │ svc_custom   │ Running │  │ ║
║  │  │   │ Type: Windows Service (custom)                │  │ ║
║  │  │   │ ⚠️ Unknown purpose - requires investigation  │  │ ║
║  │  │   │ ⚠️ Config may contain domain references      │  │ ║
║  │  │   │ [View Logs] [Stop Test] [Details]            │  │ ║
║  │  └──────────────────────────────────────────────────┘  │ ║
║  │                                                         │ ║
║  │  ... (41 more servers)                   [Show More]   │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 🗺️ Service Account Dependency Map                       │ ║
║  │                                                         │ ║
║  │  Click an account to see all dependent services:       │ ║
║  │                                                         │ ║
║  │  ┌──────────────────────────────────────────────────┐  │ ║
║  │  │  [DOMAIN\svc_sql] ──┬── SVR-SQL-01: MSSQLSERVER  │  │ ║
║  │  │                     ├── SVR-SQL-01: SQLSERVERAGENT│  │ ║
║  │  │                     ├── SVR-SQL-02: MSSQLSERVER  │  │ ║
║  │  │                     └── SVR-SQL-03: MSSQLSERVER  │  │ ║
║  │  │                                                    │  │ ║
║  │  │  [DOMAIN\svc_webapp] ─┬─ SVR-APP-05: AppPool1    │  │ ║
║  │  │                       ├─ SVR-APP-05: AppPool2    │  │ ║
║  │  │                       ├─ SVR-APP-06: AppPool1    │  │ ║
║  │  │                       └─ SVR-APP-07: MainApp     │  │ ║
║  │  │                                                    │  │ ║
║  │  │  [DOMAIN\svc_backup] ──┬── SVR-FILE-01: BackupSvc│  │ ║
║  │  │                        ├── SVR-FILE-02: BackupSvc│  │ ║
║  │  │                        └── SVR-APP-*: BackupAgnt │  │ ║
║  │  │                                                    │  │ ║
║  │  │  [View Full Graph] [Export Map]                   │  │ ║
║  │  └──────────────────────────────────────────────────┘  │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 💡 Recommendations                                      │ ║
║  │                                                         │ ║
║  │  1. Update 153 service accounts                         │ ║
║  │     - Create accounts in target domain                  │ ║
║  │     - Update service configuration                      │ ║
║  │     - Re-register SPNs                                  │ ║
║  │     [Generate Runbook]                                  │ ║
║  │                                                         │ ║
║  │  2. Test 42 scheduled tasks                             │ ║
║  │     - Many run as domain accounts                       │ ║
║  │     - May break if accounts not updated                 │ ║
║  │     [Export Task List]                                  │ ║
║  │                                                         │ ║
║  │  3. Document 8 IIS app pools                            │ ║
║  │     - Review web.config for connection strings          │ ║
║  │     - Check for integrated auth settings                │ ║
║  │     [Generate Checklist]                                │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  [← Back to Discovery]  [Save Selections]  [Continue →]      ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

## 6) Dependency Visualization

### 6.1 Interactive Dependency Graph

```
╔═══════════════════════════════════════════════════════════════╗
║  🕸️ Dependency Graph                                          ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 🔍 Controls                                             │ ║
║  │                                                         │ ║
║  │  Focus: [All] [Users] [Computers] [Services] [Groups]  │ ║
║  │  Layout: [Hierarchical] [Force-Directed] [Circular]    │ ║
║  │  Filter: Show only items with >5 dependencies          │ ║
║  │  Highlight: [Domain Accounts] [Critical Services]      │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │                  Dependency Visualization               │ ║
║  │                                                         │ ║
║  │                    [svc_sql]                            │ ║
║  │                        │                                │ ║
║  │           ┌────────────┼────────────┐                   │ ║
║  │           ▼            ▼            ▼                   │ ║
║  │      [SVR-SQL-01] [SVR-SQL-02] [SVR-SQL-03]            │ ║
║  │           │            │            │                   │ ║
║  │           │            └────┬───────┘                   │ ║
║  │           ▼                 ▼                           │ ║
║  │      [MainApp]        [ReportApp]                       │ ║
║  │           │                 │                           │ ║
║  │           └────────┬────────┘                           │ ║
║  │                    ▼                                    │ ║
║  │              [500 Users]                                │ ║
║  │                                                         │ ║
║  │  Legend:                                                │ ║
║  │  🟢 Users  🔵 Computers  🟡 Services  🔴 Critical       │ ║
║  │                                                         │ ║
║  │  Click any node to see details and options.            │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 📋 Selected: svc_sql (Service Account)                  │ ║
║  │                                                         │ ║
║  │  Direct Dependencies: 12                                │ ║
║  │  - 3 SQL Server instances                               │ ║
║  │  - 2 SQL Agent services                                 │ ║
║  │  - 4 SSRS instances                                     │ ║
║  │  - 3 custom services                                    │ ║
║  │                                                         │ ║
║  │  Indirect Dependencies: 523                             │ ║
║  │  - 8 applications use these SQL servers                 │ ║
║  │  - 515 users access these applications                  │ ║
║  │                                                         │ ║
║  │  Impact if migration fails:                             │ ║
║  │  🔴 Critical: 515 users cannot access apps              │ ║
║  │                                                         │ ║
║  │  Recommendation:                                        │ ║  │  ⚠️ Migrate this account carefully                      │ ║
║  │  ⚠️ Test all SQL connections post-migration             │ ║
║  │  ⚠️ Have rollback plan ready                            │ ║
║  │                                                         │ ║
║  │  [View Full Details] [Add to Critical List]             │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 🔗 Circular Dependencies Detected (5)                   │ ║
║  │                                                         │ ║
║  │  ⚠️ svc_app1 ──► SVR-APP-01 ──► svc_app2 ──► SVR-APP-02│ ║
║  │     └────────────────────────────────┘                  │ ║
║  │                                                         │ ║
║  │  These need special handling during migration:         │ ║
║  │  [View Details] [Generate Migration Plan]              │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  [Export Graph] [Generate Report] [← Back to Discovery]      ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

## 7) Discovery Checkpoint Approval

### 7.1 Final Review & Approval

```
╔═══════════════════════════════════════════════════════════════╗
║  🚦 Discovery Checkpoint - Final Review                       ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ ✅ Review Checklist                                      │ ║
║  │                                                         │ ║
║  │  ☑️ Reviewed all critical issues (3 items)              │ ║
║  │  ☑️ Made inclusion/exclusion decisions                  │ ║
║  │     - 1,089 users included                              │ ║
║  │     - 158 users excluded (disabled/inactive)            │ ║
║  │     - 783 computers included                            │ ║
║  │     - 116 computers excluded (offline/problematic)      │ ║
║  │  ☑️ Reviewed service dependencies                       │ ║
║  │  ☑️ Identified critical services (23 items)             │ ║
║  │  ☐ Resolved circular dependencies (5 remaining)        │ ║
║  │  ☑️ Reviewed large profiles (8 users)                   │ ║
║  │  ☑️ Contacted affected users (12 sent emails)           │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 📊 Migration Scope Summary                              │ ║
║  │                                                         │ ║
║  │  Approved for Migration:                                │ ║
║  │  - 👥 Users: 1,089 (87.3% of total)                     │ ║
║  │  - 💻 Workstations: 783 (91.5% of total)                │ ║
║  │  - 🖥️ Servers: 38 (88.4% of total)                      │ ║
║  │  - 👪 Groups: 167 (88.4% of total)                      │ ║
║  │  - 🔌 Services: 289 (88.4% of total)                    │ ║
║  │                                                         │ ║
║  │  Excluded from Migration:                               │ ║
║  │  - 94 disabled user accounts                            │ ║
║  │  - 64 inactive users (>90 days)                         │ ║
║  │  - 42 offline workstations (>30 days)                   │ ║
║  │  - 74 workstations (offline <7 days, migrate later)     │ ║
║  │  - 5 servers (unknown OS, needs investigation)          │ ║
║  │                                                         │ ║
║  │  Tagged for Special Handling:                           │ ║
║  │  - 8 users with large profiles                          │ ║
║  │  - 23 critical services                                 │ ║
║  │  - 12 servers with complex dependencies                 │ ║
║  │  - 5 circular dependencies (needs manual resolution)    │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ ⚠️ Outstanding Issues                                    │ ║
║  │                                                         │ ║
║  │  5 circular dependencies unresolved                     │ ║
║  │  └─ These must be resolved before proceeding           │ ║
║  │  └─ [Resolve Now] [Create Manual Task]                 │ ║
║  │                                                         │ ║
║  │  8 large user profiles (>50 GB)                         │ ║
║  │  └─ Users notified to clean up                         │ ║
║  │  └─ Can proceed, but migration will be slower          │ ║
║  │  └─ [Accept Risk] [Delay These Users]                  │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 📅 Estimated Timeline                                   │ ║
║  │                                                         │ ║
║  │  Based on approved scope:                               │ ║
║  │  - Wave Planning: 1 day                                 │ ║
║  │  - Pilot Wave (10% ≈ 110 machines): 1 week             │ ║
║  │  - Production Waves: 6-8 weeks                          │ ║
║  │  - Remediation: 2 weeks                                 │ ║
║  │  - Total Project Duration: ~10 weeks                    │ ║
║  │                                                         │ ║
║  │  Estimated Effort:                                      │ ║
║  │  - Migration hours: ~1,200 hours (includes automation) │ ║
║  │  - Manual effort: ~80 hours (exception handling, etc.) │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │ 💼 Approval Decision                                    │ ║
║  │                                                         │ ║
║  │  I have reviewed the discovery results and:            │ ║
║  │                                                         │ ║
║  │  ◉ Approve migration scope                             │ ║
║  │     Proceed to wave planning with approved items       │ ║
║  │                                                         │ ║
║  │  ○ Approve with conditions                             │ ║
║  │     Proceed, but resolve outstanding issues first      │ ║
║  │     Conditions: [________________________________]      │ ║
║  │                                                         │ ║
║  │  ○ Reject and re-discover                              │ ║
║  │     Run discovery again with different parameters      │ ║
║  │     Reason: [____________________________________]      │ ║
║  │                                                         │ ║
║  │  Approver: migration-lead@company.com                   │ ║
║  │  Notes: [_________________________________________]     │ ║
║  │         [_________________________________________]     │ ║
║  │                                                         │ ║
║  │  [Cancel] [Save Draft] [✅ Approve & Continue]         │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

## 8) Backend API for Discovery

### 8.1 Discovery Results API

```python
# backend/app/discovery_api.py
from fastapi import APIRouter, HTTPException
from typing import List, Optional

router = APIRouter(prefix="/api/discovery")

@router.post("/run")
async def run_discovery(scope: DiscoveryScope):
    """Initiate discovery playbooks"""
    # Launch AWX discovery job template
    job = await awx_client.launch_job_template(
        template_id="discovery_full",
        extra_vars={
            "source_domain": scope.domain,
            "search_base": scope.ou,
            "include_offline": scope.include_offline,
            "deep_scan": scope.deep_scan
        }
    )
    
    # Create discovery session in database
    session_id = await db.create_discovery_session(
        job_id=job.id,
        scope=scope.dict(),
        status="running"
    )
    
    return {
        "session_id": session_id,
        "job_id": job.id,
        "status": "running",
        "estimated_duration": "30-60 minutes"
    }

@router.get("/sessions/{session_id}")
async def get_discovery_session(session_id: int):
    """Get discovery session details"""
    session = await db.get_discovery_session(session_id)
    
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    # Get AWX job status
    if session["job_id"]:
        job_status = await awx_client.get_job_status(session["job_id"])
        session["job_status"] = job_status
    
    return session

@router.get("/sessions/{session_id}/results")
async def get_discovery_results(session_id: int):
    """Get comprehensive discovery results"""
    
    # Fetch all discovery data
    users = await db.fetch_all("""
        SELECT * FROM discovered_users 
        WHERE discovery_session_id = :session_id
    """, {"session_id": session_id})
    
    computers = await db.fetch_all("""
        SELECT * FROM discovered_computers 
        WHERE discovery_session_id = :session_id
    """, {"session_id": session_id})
    
    services = await db.fetch_all("""
        SELECT * FROM discovered_services 
        WHERE discovery_session_id = :session_id
    """, {"session_id": session_id})
    
    groups = await db.fetch_all("""
        SELECT * FROM discovered_groups 
        WHERE discovery_session_id = :session_id
    """, {"session_id": session_id})
    
    # Generate statistics
    stats = {
        "users": {
            "total": len(users),
            "active": len([u for u in users if u["enabled"]]),
            "disabled": len([u for u in users if not u["enabled"]]),
            "service_accounts": len([u for u in users if u["is_service_account"]])
        },
        "computers": {
            "total": len(computers),
            "online": len([c for c in computers if c["is_online"]]),
            "offline": len([c for c in computers if not c["is_online"]]),
            "workstations": len([c for c in computers if c["type"] == "workstation"]),
            "servers": len([c for c in computers if c["type"] == "server"])
        },
        "services": {
            "total": len(services),
            "domain_account": len([s for s in services if s["uses_domain_account"]])
        },
        "groups": {
            "total": len(groups)
        }
    }
    
    # Identify issues
    issues = await identify_issues(session_id)
    
    return {
        "session_id": session_id,
        "statistics": stats,
        "users": users,
        "computers": computers,
        "services": services,
        "groups": groups,
        "issues": issues
    }

@router.get("/sessions/{session_id}/issues")
async def get_discovery_issues(session_id: int):
    """Get issues found during discovery"""
    issues = await db.fetch_all("""
        SELECT * FROM discovery_issues 
        WHERE discovery_session_id = :session_id
        ORDER BY severity DESC, category
    """, {"session_id": session_id})
    
    return issues

@router.post("/sessions/{session_id}/decisions")
async def save_discovery_decisions(session_id: int, decisions: DiscoveryDecisions):
    """Save user's inclusion/exclusion decisions"""
    
    # Update users
    for user_id in decisions.included_users:
        await db.execute("""
            UPDATE discovered_users 
            SET include_in_migration = true
            WHERE id = :user_id AND discovery_session_id = :session_id
        """, {"user_id": user_id, "session_id": session_id})
    
    for user_id in decisions.excluded_users:
        await db.execute("""
            UPDATE discovered_users 
            SET include_in_migration = false, exclusion_reason = :reason
            WHERE id = :user_id AND discovery_session_id = :session_id
        """, {"user_id": user_id, "session_id": session_id, "reason": decisions.exclusion_reason})
    
    # Similar for computers, services, etc.
    
    return {"status": "saved", "session_id": session_id}

@router.post("/sessions/{session_id}/approve")
async def approve_discovery(session_id: int, approval: DiscoveryApproval):
    """Approve discovery results and proceed to wave planning"""
    
    # Validate all critical issues resolved
    critical_issues = await db.fetch_all("""
        SELECT * FROM discovery_issues 
        WHERE discovery_session_id = :session_id 
          AND severity = 'critical' 
          AND status != 'resolved'
    """, {"session_id": session_id})
    
    if critical_issues and not approval.force_approve:
        raise HTTPException(
            status_code=400,
            detail=f"{len(critical_issues)} critical issues unresolved"
        )
    
    # Update discovery session
    await db.execute("""
        UPDATE discovery_sessions
        SET status = 'approved',
            approved_by = :approver,
            approved_at = NOW(),
            approval_notes = :notes
        WHERE id = :session_id
    """, {
        "session_id": session_id,
        "approver": approval.approver_email,
        "notes": approval.notes
    })
    
    # Generate migration waves automatically
    if approval.auto_generate_waves:
        wave_count = await generate_migration_waves(session_id)
        return {
            "status": "approved",
            "waves_generated": wave_count,
            "next_step": "review_waves"
        }
    
    return {
        "status": "approved",
        "next_step": "manual_wave_planning"
    }

@router.get("/sessions/{session_id}/dependencies")
async def get_dependencies(session_id: int):
    """Get dependency graph for visualization"""
    
    # Fetch all dependencies
    dependencies = await db.fetch_all("""
        SELECT source_type, source_id, target_type, target_id, dependency_type
        FROM dependencies
        WHERE discovery_session_id = :session_id
    """, {"session_id": session_id})
    
    # Build graph structure
    graph = {
        "nodes": [],
        "edges": []
    }
    
    # Add nodes (users, computers, services)
    users = await db.fetch_all("""
        SELECT id, username, type FROM discovered_users
        WHERE discovery_session_id = :session_id
    """, {"session_id": session_id})
    
    for user in users:
        graph["nodes"].append({
            "id": f"user_{user['id']}",
            "label": user["username"],
            "type": "user",
            "category": user["type"]
        })
    
    # Add edges (dependencies)
    for dep in dependencies:
        graph["edges"].append({
            "source": f"{dep['source_type']}_{dep['source_id']}",
            "target": f"{dep['target_type']}_{dep['target_id']}",
            "type": dep["dependency_type"]
        })
    
    return graph

@router.get("/sessions/{session_id}/export")
async def export_discovery_results(session_id: int, format: str = "xlsx"):
    """Export discovery results to Excel/CSV"""
    
    # Generate report
    if format == "xlsx":
        workbook = await generate_excel_report(session_id)
        return FileResponse(
            workbook,
            media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            filename=f"discovery_{session_id}.xlsx"
        )
    elif format == "csv":
        csv_zip = await generate_csv_reports(session_id)
        return FileResponse(
            csv_zip,
            media_type="application/zip",
            filename=f"discovery_{session_id}.zip"
        )
```

---

## 9) Summary

### What You Get

✅ **Complete Visibility** – See everything discovered before making decisions  
✅ **Interactive Review** – Checkboxes, filters, search, bulk actions  
✅ **Issue Identification** – Automatic detection of problems with recommendations  
✅ **Dependency Mapping** – Visual graph of relationships and dependencies  
✅ **Inclusion/Exclusion** – Granular control over what to migrate  
✅ **Approval Checkpoint** – Formal sign-off before proceeding to wave planning  
✅ **Export Capabilities** – Excel, CSV, PDF reports for stakeholders  
✅ **Decision Tracking** – Record who approved what and why  

### User Experience

**Discovery Phase:**
1. Click "Run Discovery" (one button)
2. Wait 30-60 minutes (automatic)
3. Review results in interactive UI
4. Make decisions (include, exclude, tag)
5. Resolve issues (guided recommendations)
6. Approve and proceed to wave planning

**No Manual Data Collection Required!**

---

**END OF DOCUMENT**

