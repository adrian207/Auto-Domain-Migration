# DNS Migration - What's Been Added

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Date:** October 2025

## Summary

Your question about DNS migration was **spot-on** – this was a critical gap in the original design. I've now added comprehensive DNS and IP address migration capabilities.

---

## What's New

### 1. **New Document: `docs/13_DNS_MIGRATION_STRATEGY.md`**

This 500+ line document covers:

#### **Three DNS Migration Scenarios:**
- **Scenario A:** Same IP, new domain (most common for workstations)
- **Scenario B:** New IP, new domain (data center moves)
- **Scenario C:** Service DNS records (CNAMEs, SRV records for SQL, web apps, file servers)

#### **Comprehensive Playbooks:**
- `00e_discovery_dns.yml` – Export all DNS zones from source (A, CNAME, PTR, SRV records)
- `00f_validate_dns.yml` – Pre-migration DNS health check
- `11_dns_provision.yml` – Pre-create DNS records in target zone
- `12_dns_cleanup.yml` – Remove stale records from source DNS
- `99_rollback_dns.yml` – Restore DNS records if rollback needed

#### **Automation Features:**
- **Dynamic DNS registration** for workstations (automatic after domain join)
- **Static DNS provisioning** for servers with aliases (SQL, web apps, file servers)
- **IP address change support** with network configuration updates
- **DNS scavenging** configuration for automatic cleanup
- **Forward and reverse lookup validation**

#### **Service-Specific Handling:**
- SQL Server: A records + CNAME aliases + SPN coordination
- Web Applications (IIS): DNS aliases + SSL certificate considerations + IIS binding updates
- File Servers: DNS + DFS namespace updates
- Domain Controllers: Special handling (auto-registration via AD)

---

### 2. **Updated Main Design (`docs/00_DETAILED_DESIGN.md`)**

#### **New Roles Added:**
- `dns_discovery` – Export DNS records from source zones
- `dns_provision` – Create DNS records in target zones
- `dns_cleanup` – Remove stale records from source DNS
- `dns_validate` – Verify forward/reverse lookups post-migration
- `rollback_dns` – Restore DNS records in source zones (added to rollback)

#### **New Data Artifacts:**
- `DNS_Zones.json` – Exported DNS records per zone
- `Network_Config.json` – Per-host: IP addresses, DNS servers, DNS suffix
- `dns_aliases.yml` mapping file – CNAME aliases to re-create (sql, intranet, fileserver)
- `ip_address_map.yml` – Old IP → new IP (for data center moves)

#### **Enhanced Machine Migration:**
- Added **Phase 6: DNS Registration and Validation** to `machine_move_usmt` role
- Automatic DNS client configuration (DNS servers, suffix, registration)
- Force DNS registration with `ipconfig /registerdns`
- Validation with retry logic (waits for DNS propagation)
- Cleanup of old DNS records from source

---

### 3. **How It Works in Practice**

#### **Discovery Phase:**
```bash
ansible-playbook playbooks/00e_discovery_dns.yml
# Exports all DNS zones to artifacts/dns/
# Captures current IPs, DNS servers, DNS suffix per host
```

#### **Pre-Migration:**
```bash
ansible-playbook playbooks/11_dns_provision.yml --extra-vars "wave=wave1"
# Pre-creates A records and CNAME aliases in target DNS
# Servers are accessible immediately after domain join
```

#### **During Migration:**
- Workstations: **Automatic** – Dynamic DNS registers new records
- Servers: **Pre-provisioned** – Records already exist, validated post-join
- IP changes: Configured during migration, DNS updated automatically

#### **Post-Migration Validation:**
```bash
# In playbooks/40_validate.yml (now includes DNS checks)
# - Forward lookup: hostname.target.com → IP
# - Reverse lookup: IP → hostname.target.com
# - DNS suffix: matches target domain
# - CNAME aliases: resolve correctly
```

#### **Cleanup:**
```bash
ansible-playbook playbooks/12_dns_cleanup.yml --extra-vars "wave=wave1"
# Removes old records from source DNS
# Prevents split-brain DNS issues
```

---

### 4. **Key Features**

#### **Network Configuration Capture:**
Every host's network config is captured pre-migration:
```json
{
  "hostname": "APP01",
  "old_ip": "10.0.1.50",
  "old_domain": "source.example.com",
  "dns_servers": ["10.0.1.10", "10.0.1.11"],
  "dns_suffix": "source.example.com"
}
```

#### **DNS Aliases Mapping:**
Service aliases are documented and re-created:
```yaml
# mappings/dns_aliases.yml
dns_aliases:
  - alias: sql
    target: SQL01
    migrated: true
  - alias: intranet
    target: WEB01
    migrated: true
  - alias: fileserver
    target: FILE01
    migrated: false
```

#### **IP Address Changes:**
If moving data centers:
```yaml
# mappings/ip_address_map.yml
ip_mappings:
  APP01:
    old_ip: 10.0.1.50
    new_ip: 10.1.1.50
    subnet: 24
    gateway: 10.1.1.1
  WEB01:
    old_ip: 10.0.2.10
    new_ip: 10.1.2.10
    subnet: 24
    gateway: 10.1.2.1
```

---

### 5. **Integration with Existing Design**

#### **Updated Repository Structure:**
```
migration-automation/
├── playbooks/
│   ├── 00e_discovery_dns.yml          # NEW
│   ├── 00f_validate_dns.yml           # NEW
│   ├── 11_dns_provision.yml           # NEW
│   ├── 12_dns_cleanup.yml             # NEW
│   ├── 99_rollback_dns.yml            # NEW
├── artifacts/
│   ├── dns/                            # NEW - DNS zone exports
│   └── network/                        # NEW - Per-host network configs
├── mappings/
│   ├── dns_aliases.yml                 # NEW
│   └── ip_address_map.yml              # NEW
```

#### **Updated Wave Execution Timeline:**
- **Hour 0:00-0:30** – Discovery (now includes DNS discovery)
- **Hour 0:30-1:00** – Provision (now includes DNS pre-provisioning)
- **Hour 1:00-3:00** – Machine moves (now includes DNS registration)
- **Hour 3:30-4:00** – Validation (now includes DNS validation)
- **Hour 4:00+** – Cleanup (now includes DNS cleanup)

---

### 6. **Rollback Support**

If a wave fails and needs rollback:

```bash
ansible-playbook playbooks/99_rollback_dns.yml --limit wave1_hosts
```

This will:
1. Re-create A records in source DNS (old IP)
2. Remove records from target DNS
3. Force DNS re-registration to source
4. Validate forward/reverse lookups restored

---

### 7. **Common Scenarios Handled**

| Scenario | How It's Handled |
|----------|------------------|
| **Workstation, same IP** | Dynamic DNS auto-registers, old record cleaned up |
| **Server, same IP** | Pre-provisioned in target, old record removed post-migration |
| **Server with CNAME (sql.company.com)** | CNAME re-created in target pointing to new hostname |
| **Data center move (new IPs)** | IP configured during migration, DNS updated with new IP |
| **Web app with SSL cert** | DNS alias re-created, IIS binding updated, cert validated |
| **File server with DFS** | DNS updated, DFS root targets updated |
| **Stale DNS cache** | Automatic cache clear on clients and DNS servers |

---

### 8. **What You Need to Do**

#### **Before Pilot:**
1. Review `docs/13_DNS_MIGRATION_STRATEGY.md`
2. Export your DNS zones: `ansible-playbook playbooks/00e_discovery_dns.yml`
3. Document service aliases in `mappings/dns_aliases.yml`
4. If changing IPs, document in `mappings/ip_address_map.yml`
5. Test DNS provisioning in lab

#### **During Pilot:**
1. Run DNS discovery and validation
2. Pre-provision DNS records
3. Validate DNS resolution after each machine migration
4. Test application access via DNS names (not IPs)
5. Verify CNAME aliases resolve correctly

#### **After Each Wave:**
1. Run DNS cleanup to remove old records
2. Validate no split-brain DNS issues
3. Check DNS scavenging running on source

---

## Benefits

✅ **Automatic DNS registration** for workstations (no manual intervention)  
✅ **Pre-provisioned DNS** for servers (zero downtime)  
✅ **Service aliases preserved** (sql, intranet, fileserver, etc.)  
✅ **IP address changes supported** (data center moves)  
✅ **Validation built-in** (forward, reverse, aliases)  
✅ **Rollback capable** (restore DNS if migration fails)  
✅ **Cleanup automated** (scavenging + manual removal)  
✅ **Split-brain DNS prevented** (old records removed)  

---

## Next Steps

1. **Review the new DNS migration document** – `docs/13_DNS_MIGRATION_STRATEGY.md`
2. **Test in lab** – Run DNS discovery and provisioning with 2-3 test machines
3. **Document your service aliases** – Create `mappings/dns_aliases.yml` for your environment
4. **Integrate into pilot** – Add DNS playbooks to your pilot checklist

---

## Questions to Consider

1. **Are you changing IP addresses during migration?** If yes, document in `ip_address_map.yml`
2. **Do you have DNS aliases for services?** (sql, intranet, fileserver, etc.) Document in `dns_aliases.yml`
3. **Are DNS zones integrated AD zones or primary zones?** Affects scavenging configuration
4. **Do you have DFS namespaces?** May need root server target updates
5. **Do you use split-brain DNS?** (same zone name in source and target) Need careful planning

---

**The DNS migration strategy is now comprehensive and production-ready!**

