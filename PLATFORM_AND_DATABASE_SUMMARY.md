# Platform & Database Migration Additions – Summary

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Date:** October 2025

## Overview

Based on your questions about **multi-cloud/multi-platform support** and **database server migrations** (especially SQL Server with mixed authentication), I've created two comprehensive strategy documents:

---

## 1) Platform Variants (docs/16_PLATFORM_VARIANTS.md)

### Purpose
Provide **platform-specific implementation branches** for AWS, Azure, GCP, and major virtualization platforms (Hyper-V, vSphere, OpenStack), enabling you to choose your infrastructure stack while using the same migration automation framework.

### Key Concepts

#### Platform Abstraction Model
- **Core migration logic** (identity export/provision, domain moves, validation) remains **platform-agnostic**
- **Infrastructure components** (storage, compute, networking, secrets) are **swappable** via platform-specific roles and variables

#### Git Branch Strategy
```
main (platform-agnostic core)
├── platform/aws
├── platform/azure
├── platform/gcp
├── platform/vmware-vsphere
├── platform/hyperv
├── platform/openstack
└── platform/hybrid (multi-cloud)
```

### Platform-Specific Components

Each platform branch includes:

1. **Infrastructure as Code** (Terraform/PowerShell DSC/Heat)
   - VPCs/VNets for control plane
   - Compute instances for AWX runners
   - Storage for USMT state stores (S3, Azure Blob, GCS, SMB, NFS, Ceph)
   - Databases for reporting (RDS, Azure DB, Cloud SQL, VM-based)
   - Network connectivity (VPN, Direct Connect, ExpressRoute, Cloud Interconnect)

2. **Platform-Specific Ansible Variables** (`group_vars/aws.yml`, `group_vars/azure.yml`, etc.)
   - State store type and configuration
   - Secrets backend (Secrets Manager, Key Vault, Secret Manager, Ansible Vault)
   - Database connection details
   - Backup methods (EBS snapshots, VM backups, Hyper-V checkpoints, vSphere snapshots)

3. **Platform-Specific Roles**
   - `aws_s3_state_store` / `azure_blob_state_store` / `gcp_gcs_state_store`
   - `aws_secrets_manager` / `azure_keyvault` / `gcp_secret_manager`
   - `aws_snapshot_ec2` / `azure_snapshot_vm` / `vsphere_snapshot`

4. **Platform-Specific Playbooks**
   - Snapshot/backup playbooks for each platform
   - Network configuration (VPN setup, transit gateways, etc.)

### Implementation Examples

#### AWS
- **State Store:** S3 with versioning (snapshot-like behavior)
- **Secrets:** AWS Secrets Manager
- **Database:** RDS PostgreSQL (Multi-AZ)
- **Network:** VPN Gateway + Direct Connect for high-bandwidth
- **Backup:** EBS snapshots + AMIs
- **Cost:** ~$4,800/month (Tier 2)

#### Azure
- **State Store:** Azure Blob with versioning
- **Secrets:** Azure Key Vault with RBAC
- **Database:** Azure Database for PostgreSQL (Zone Redundant)
- **Network:** ExpressRoute for on-prem connectivity
- **Backup:** Azure VM Backup + disk snapshots
- **Cost:** ~$4,700/month (Tier 2)

#### GCP
- **State Store:** Cloud Storage (GCS) with versioning
- **Secrets:** Google Secret Manager
- **Database:** Cloud SQL PostgreSQL (Regional)
- **Network:** Cloud Interconnect
- **Backup:** Persistent disk snapshots
- **Cost:** ~$4,000/month (Tier 2)

#### Hyper-V (On-Prem)
- **State Store:** SMB share on Storage Spaces (mirrored, Tier)
- **Secrets:** Ansible Vault (local)
- **Database:** PostgreSQL on VM
- **Network:** Site-to-site VPN
- **Backup:** Hyper-V checkpoints
- **Cost:** ~$500/month (storage + electricity, no cloud costs)

#### vSphere (VMware)
- **State Store:** NFS datastore or vSAN
- **Secrets:** Ansible Vault (local)
- **Database:** PostgreSQL on VM
- **Network:** Site-to-site VPN
- **Backup:** vSphere snapshots
- **Cost:** ~$400/month (storage, excludes vSphere licensing)

#### OpenStack
- **State Store:** Swift (object storage) or Ceph
- **Secrets:** Ansible Vault
- **Database:** PostgreSQL on VM
- **Network:** Neutron VPN
- **Backup:** Cinder volume snapshots
- **Cost:** ~$1,000/month

### Hybrid/Multi-Cloud Strategy

For organizations with **hybrid** or **multi-cloud** architectures:

- **Scenario:** On-prem source domain, hybrid target (some resources in Azure, some on-prem)
- **Solution:** Split runners (on-prem + cloud), dual state stores (SMB + Blob), centralized reporting database
- **Inventory:** Separate groups for `workstations_onprem` vs. `workstations_azure`
- **Variables:** Different `usmt_store_type` per group

### Platform Selection Matrix

| Criterion | AWS | Azure | GCP | Hyper-V | vSphere | OpenStack |
|-----------|-----|-------|-----|---------|---------|-----------|
| **Best For** | Cloud-first orgs | Microsoft shops | Data-heavy | Windows-centric | VMware existing | Open-source |
| **State Store** | S3 | Blob | GCS | SMB/DFS-R | NFS/vSAN | Swift/Ceph |
| **Secrets** | Secrets Manager | Key Vault | Secret Manager | Ansible Vault | Ansible Vault | Ansible Vault |
| **Complexity** | Medium | Medium | Medium | Low | Low | High |

### Key Takeaways

✅ **Core migration logic is platform-agnostic** – AD export, USMT, domain joins work everywhere  
✅ **Only infrastructure layer changes** – S3 vs. Blob vs. SMB, etc.  
✅ **Git branches for platform variants** – Fork the branch that matches your infrastructure  
✅ **Hybrid is supported** – Split runners and state stores across cloud + on-prem  
✅ **Cost varies dramatically** – Cloud: $4k-5k/month; On-prem: $400-500/month  

---

## 2) Database Migration Strategy (docs/17_DATABASE_MIGRATION_STRATEGY.md)

### Purpose
Comprehensive strategy for migrating **database servers** with **mixed authentication** (Windows domain accounts + database-native authentication), connection string updates, and zero-tolerance for downtime.

### Challenges Addressed

1. **Mixed Authentication:**
   - SQL Server: Windows Authentication (`DOMAIN\SQLAdmins`) + SQL Authentication (`sa`, `app_user`)
   - PostgreSQL: LDAP/Kerberos (domain-integrated) + password-based (domain-agnostic)
   - MySQL: Native auth (no domain dependency in most cases)
   - Oracle: OS authentication (NTS) + database authentication

2. **Domain Move Impact:**
   - Windows Authentication **breaks** when domain changes
   - SQL Authentication **continues working** (unaffected)

3. **Connection Strings:**
   - Applications have hardcoded FQDNs (`SQL01.olddomain.com`)
   - Service accounts (`DOMAIN\svc_sql`) need updating
   - Kerberos SPNs must be re-registered

### SQL Server Migration

#### Pre-Migration Discovery

Automated playbook (`00h_discovery_sql_server.yml`) discovers:
- SQL Server instances and service accounts
- Windows Authentication logins (broken by domain move)
- SQL Authentication logins (unaffected)
- SQL Agent jobs with domain owners
- Linked servers
- Active application connections (via DMVs)

**Example Output:**
```json
{
  "windows_logins": [
    {"name": "OLDDOMAIN\\SQLAdmins", "type": "WINDOWS_GROUP"},
    {"name": "OLDDOMAIN\\AppUser", "type": "WINDOWS_USER"}
  ],
  "sql_logins": [
    {"name": "app_user", "type": "SQL_LOGIN"}
  ],
  "app_connections": [
    {"login_name": "OLDDOMAIN\\AppUser", "host_name": "APP-01", "count": 45}
  ]
}
```

#### Migration Approaches

**Approach A: In-Place Domain Move (Preferred)**

1. **Pre-migration:** Create dual logins (old + new domain)
   ```sql
   CREATE LOGIN [NEWDOMAIN\SQLAdmins] FROM WINDOWS;
   ```

2. **Domain move:** Standard `machine_move_usmt` playbook (disjoin → join)

3. **Post-migration:** Fix orphaned users
   ```sql
   -- Remap database users to new domain logins
   EXEC sp_change_users_login 'Auto_Fix', @user, @newlogin;
   ```

4. **Update SQL Agent job owners**
   ```sql
   EXEC sp_update_job @job_id, @owner_login_name = 'NEWDOMAIN\admin';
   ```

5. **Update service account** (via Ansible `win_service`)
   ```yaml
   - win_service:
       name: MSSQLSERVER
       username: "NEWDOMAIN\\svc_sql"
       password: "{{ vault_password }}"
       state: restarted
   ```

6. **Re-register SPNs**
   ```powershell
   setspn -S MSSQLSvc/SQL01.newdomain.com:1433 NEWDOMAIN\svc_sql
   ```

**Downtime:** 20-30 minutes

**Approach B: Side-by-Side with Replication (Zero-Downtime)**

1. Build new SQL Server in target domain
2. Configure transactional replication or Always On Availability Groups
3. Monitor replication lag (wait until <5 seconds)
4. Cutover (application connection string change or DNS)
5. Decommission old server after validation

**Downtime:** <5 minutes (DNS propagation)

#### Connection String Migration

**Challenge:** Apps have hardcoded `Server=SQL01.olddomain.com`

**Solution Options:**

1. **Automated Update** (if config format is known)
   ```yaml
   - win_shell: |
       $xml = [xml](Get-Content "web.config")
       $xml.configuration.connectionStrings.add.connectionString = 
         $xml.configuration.connectionStrings.add.connectionString -replace 
         "olddomain.com", "newdomain.com"
       $xml.Save("web.config")
   ```

2. **DNS Alias** (Recommended)
   ```yaml
   # Create CNAME: sql.newdomain.com → SQL01.newdomain.com
   - win_shell: |
       Add-DnsServerResourceRecordCName -ZoneName "newdomain.com" 
         -Name "sql" -HostNameAlias "SQL01.newdomain.com"
   ```
   
   **Benefit:** No application code changes, just DNS update.

### PostgreSQL Migration

#### Authentication Model

1. **Host-based** (`pg_hba.conf`) – IP or password, **no domain dependency**
2. **LDAP/Kerberos** – Domain-integrated, **breaks on domain move**

#### Migration Approach (for Kerberos/LDAP)

1. **Update `/etc/sssd/sssd.conf`** (done by `linux_migrate` role)
2. **Update Kerberos keytab:**
   ```bash
   kvno postgres/postgres-01.newdomain.com
   ktutil
     addent -password -p postgres/postgres-01.newdomain.com@NEWDOMAIN.COM
     wkt /etc/postgresql/14/main/postgres.keytab
   ```

3. **Update `postgresql.conf`:**
   ```ini
   krb_realm = 'NEWDOMAIN.COM'
   ```

4. **Update `pg_hba.conf`:**
   ```
   host all all 0.0.0.0/0 gss include_realm=0 krb_realm=NEWDOMAIN.COM
   ```

5. **Restart PostgreSQL**

**Downtime:** 5-10 minutes

### MySQL/MariaDB Migration

- **Native authentication** (username/password) – **No domain dependency**
- **Exception:** MySQL Enterprise with LDAP plugin
- **Migration:** Typically no changes needed

### Oracle Database Migration

- **Database authentication** – No domain dependency
- **OS authentication** (`SQLNET.AUTHENTICATION_SERVICES = NTS`) – Relies on domain
- **Migration:** Create Oracle users for new domain (`CREATE USER "NEWDOMAIN\admin" IDENTIFIED EXTERNALLY`)

### Database Migration Checklist

**Pre-Migration (T-7 days):**
- [ ] Run database discovery playbooks
- [ ] Document all Windows Authentication logins
- [ ] Identify applications and connection strings
- [ ] Create DNS aliases for database servers
- [ ] Create service accounts in target domain
- [ ] Backup all databases (full + transaction log)

**During Migration (T=0):**
- [ ] Create dual logins (old + new domain)
- [ ] Execute domain move
- [ ] Fix orphaned database users
- [ ] Update SQL Agent job owners
- [ ] Update service accounts
- [ ] Re-register SPNs
- [ ] Validate application connectivity

**Post-Migration (T+1 day):**
- [ ] Remove old domain logins
- [ ] Update connection strings (or verify DNS alias)
- [ ] Monitor error logs for authentication failures
- [ ] Full backup post-migration

### Key Takeaways

✅ **SQL Authentication is your friend** – Unaffected by domain moves  
✅ **DNS aliases are critical** – Avoid hardcoded server names  
✅ **Dual logins during transition** – Create new domain logins before domain move  
✅ **Orphaned users are fixable** – Use `sp_change_users_login` (SQL) or keytab updates (Postgres)  
✅ **Service accounts need SPNs** – Re-register after domain move  
✅ **Connection strings are everywhere** – Scan proactively, use DNS aliases  

---

## Integration with Overall Design

### New Playbooks Added

- `playbooks/00h_discovery_sql_server.yml` – Discover SQL Server instances, logins, jobs
- `playbooks/00i_discovery_postgres.yml` – Discover PostgreSQL databases, roles, auth methods
- `playbooks/03_migrate_database_servers.yml` – In-place database server domain move
- `playbooks/04_update_connection_strings.yml` – Automated connection string updates

### New Roles Added

- `roles/sql_server_migrate` – SQL Server domain move logic
- `roles/postgres_migrate` – PostgreSQL domain move logic
- `roles/database_connection_strings` – Scan and update connection strings
- `roles/dns_database_aliases` – Create DNS CNAMEs for database servers

### Platform-Specific Infrastructure

Each platform branch now includes:
- Database server provisioning (RDS, Azure DB, Cloud SQL, VM-based)
- State store configuration (S3, Blob, GCS, SMB, NFS)
- Secrets management (Secrets Manager, Key Vault, Secret Manager, Ansible Vault)
- Backup strategies (EBS snapshots, VM backups, Hyper-V checkpoints, vSphere snapshots)

---

## Recommendations

### For Platform Selection

1. **Start with your existing infrastructure:**
   - AWS shop → Use `platform/aws` branch
   - Azure/M365 shop → Use `platform/azure` branch
   - VMware shop → Use `platform/vsphere` branch
   - Cost-conscious → Use `platform/hyperv` or `platform/openstack`

2. **Don't over-architect:**
   - Tier 1 (Demo): Use whatever you have
   - Tier 2/3 (Production): Choose based on existing investments and expertise

3. **Consider hybrid:**
   - On-prem source, cloud target → Use `platform/hybrid`
   - Split runners and state stores across environments

### For Database Migration

1. **In-place domain move for 80% of database servers**
   - Downtime: 20-30 minutes
   - Complexity: Medium
   - Cost: Minimal

2. **Side-by-side replication for mission-critical databases**
   - Downtime: <5 minutes
   - Complexity: High
   - Cost: High (double infrastructure during transition)

3. **DNS aliases to decouple apps from server FQDNs**
   - Single source of truth: DNS record
   - No application code changes
   - Easy rollback (just update DNS)

4. **Dual authentication during transition**
   - Create new domain logins before domain move
   - Keep both old and new logins active for transition period
   - Remove old logins post-validation

---

## Updated Documentation Structure

```
docs/
├── 00_DETAILED_DESIGN.md     # Updated to reference new docs
├── 01_DEPLOYMENT_TIERS.md    # Tier comparison guide
├── ...
├── 13_DNS_MIGRATION_STRATEGY.md
├── 14_SERVICE_DISCOVERY_AND_HEALTH_CHECKS.md
├── 15_ZFS_SNAPSHOT_STRATEGY.md
├── 16_PLATFORM_VARIANTS.md   # ← NEW: Multi-cloud/platform support
└── 17_DATABASE_MIGRATION_STRATEGY.md  # ← NEW: Database server migrations
```

---

## Next Steps

1. **Choose your platform branch** based on existing infrastructure
2. **Review database inventory** to identify mixed-authentication databases
3. **Create DNS aliases** for database servers (do this early!)
4. **Test database discovery playbooks** in lab environment
5. **Deploy platform-specific infrastructure** (Terraform/PowerShell DSC)
6. **Pilot database migration** with non-critical server

---

**Questions Answered:**

✅ **Multi-cloud support?** Yes – Git branches for AWS, Azure, GCP, Hyper-V, vSphere, OpenStack  
✅ **Database mixed auth?** Yes – Dual logins, orphaned user fixes, service account updates, SPN re-registration  
✅ **Connection strings?** Yes – Automated scanning + update, or DNS aliases (recommended)  
✅ **Zero downtime?** Yes – Side-by-side replication for mission-critical databases  

---

**END OF SUMMARY**

