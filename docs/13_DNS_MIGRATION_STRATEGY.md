# DNS Migration Strategy

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Date:** October 2025

**Purpose:** Ensure DNS records are properly migrated, updated, or re-created when machines change domains, and IP addresses are re-registered with correct DNS servers.

**Criticality:** HIGH – Incorrect DNS configuration will break application access, file shares, and service discovery

---

## 1) DNS Migration Scenarios

### Scenario A: Same IP Address, New Domain
**Example:** `APP01` moves from `source.example.com` to `target.example.com`, keeps IP `10.0.1.50`

**DNS Changes Required:**
- Old: `APP01.source.example.com` → `10.0.1.50` (remove from source DNS)
- New: `APP01.target.example.com` → `10.0.1.50` (add to target DNS)
- PTR: `50.1.0.10.in-addr.arpa` → update to point to `APP01.target.example.com`

---

### Scenario B: New IP Address, New Domain
**Example:** `WEB01` moves to new data center with new IP addressing

**DNS Changes Required:**
- Old: `WEB01.source.example.com` → `10.0.2.10` (remove)
- New: `WEB01.target.example.com` → `10.1.2.10` (add)
- PTR: Update both old and new reverse zones
- CNAME/Alias: Update any service aliases (e.g., `intranet.example.com` → `WEB01.target.example.com`)

---

### Scenario C: Service DNS Records
**Example:** SQL Server with DNS aliases, web apps with CNAMEs

**DNS Records to Migrate:**
- A records for primary hostname
- CNAME aliases (`sql.example.com` → `SQL01.target.example.com`)
- SRV records (for domain controllers, Kerberos, LDAP)
- TXT records (SPF, DKIM if mail servers)

---

## 2) DNS Record Discovery

### 2.1 Export Existing DNS Records

**Playbook:** `playbooks/00e_discovery_dns.yml`

```yaml
---
- name: DNS Discovery - Export Current Records
  hosts: source_dns_servers
  gather_facts: no

  tasks:
    - name: Get DNS zones
      win_shell: |
        Get-DnsServerZone | Where-Object {$_.IsAutoCreated -eq $false -and $_.ZoneName -notlike "TrustAnchors"} | 
          Select-Object ZoneName, ZoneType
      register: dns_zones

    - name: Export forward lookup zones
      win_shell: |
        $zone = "{{ item.ZoneName }}"
        Get-DnsServerResourceRecord -ZoneName $zone | 
          Select-Object HostName, RecordType, @{N='RecordData';E={$_.RecordData.IPv4Address -or $_.RecordData.HostNameAlias -or $_.RecordData.PtrDomainName}}, TimeToLive | 
          ConvertTo-Json -Compress
      loop: "{{ dns_zones.stdout | from_json }}"
      register: dns_records
      when: item.ZoneName is not search('in-addr.arpa')

    - name: Save DNS export to artifact
      copy:
        content: "{{ item.stdout }}"
        dest: "{{ artifacts_dir }}/dns/{{ item.item.ZoneName }}.json"
      loop: "{{ dns_records.results }}"
      delegate_to: localhost
      when: item.stdout is defined

    - name: Export reverse lookup zones
      win_shell: |
        $zone = "{{ item.ZoneName }}"
        Get-DnsServerResourceRecord -ZoneName $zone -RRType Ptr | 
          Select-Object HostName, @{N='PTRRecord';E={$_.RecordData.PtrDomainName}} | 
          ConvertTo-Json -Compress
      loop: "{{ dns_zones.stdout | from_json }}"
      register: ptr_records
      when: item.ZoneName is search('in-addr.arpa')

    - name: Save PTR export
      copy:
        content: "{{ item.stdout }}"
        dest: "{{ artifacts_dir }}/dns/ptr_{{ item.item.ZoneName }}.json"
      loop: "{{ ptr_records.results }}"
      delegate_to: localhost
      when: item.stdout is defined
```

**Output:** `artifacts/dns/<zonename>.json` with all A, CNAME, SRV, PTR records

---

### 2.2 Identify Service DNS Aliases

**Query for CNAMEs pointing to migration targets:**

```powershell
# On source DNS server
$migrationHosts = @("APP01", "WEB01", "SQL01")  # From wave host list

$migrationHosts | ForEach-Object {
    $hostname = $_
    Get-DnsServerResourceRecord -ZoneName "source.example.com" -RRType CName | 
        Where-Object {$_.RecordData.HostNameAlias -like "$hostname*"} |
        Select-Object @{N='Alias';E={$_.HostName}}, @{N='Target';E={$_.RecordData.HostNameAlias}}
}
```

**Example Output:**
```
Alias           Target
-----           ------
intranet        APP01.source.example.com
sql             SQL01.source.example.com
fileserver      FILE01.source.example.com
```

**Action:** Document these aliases in `mappings/dns_aliases.yml` for re-creation in target DNS

---

### 2.3 Capture Current IP Addresses

**Add to discovery playbook:**

```yaml
# In roles/discovery_health/tasks/windows_health.yml
- name: Get current IP configuration
  win_shell: |
    Get-NetIPAddress -AddressFamily IPv4 -PrefixOrigin Manual,Dhcp | 
      Where-Object {$_.InterfaceAlias -notlike "*Loopback*"} |
      Select-Object IPAddress, InterfaceAlias, PrefixOrigin | 
      ConvertTo-Json -Compress
  register: ip_config

- name: Get DNS server configuration
  win_shell: |
    Get-DnsClientServerAddress -AddressFamily IPv4 | 
      Where-Object {$_.ServerAddresses -ne $null} |
      Select-Object InterfaceAlias, ServerAddresses | 
      ConvertTo-Json -Compress
  register: dns_servers

- name: Get DNS suffix configuration
  win_shell: |
    Get-DnsClient | Select-Object InterfaceAlias, ConnectionSpecificSuffix | 
      ConvertTo-Json -Compress
  register: dns_suffix

- name: Save network configuration
  copy:
    content: |
      {
        "hostname": "{{ inventory_hostname }}",
        "ip_config": {{ ip_config.stdout }},
        "dns_servers": {{ dns_servers.stdout }},
        "dns_suffix": {{ dns_suffix.stdout }}
      }
    dest: "{{ artifacts_dir }}/network/{{ inventory_hostname }}.json"
  delegate_to: localhost
```

---

## 3) DNS Migration Approaches

### Approach 1: Dynamic DNS Registration (Preferred for Workstations)

**How it works:**
- Windows clients automatically register their A and PTR records via Dynamic DNS (DDNS)
- When domain changes, old records are removed and new records are created
- Minimal manual intervention required

**Prerequisites:**
- Target DNS zones configured with "Allow secure dynamic updates"
- DHCP scopes configured with correct DNS suffix and servers
- Target domain computers have "Register this connection's addresses in DNS" enabled

**Configuration:**

```yaml
# In machine_move_usmt role, after domain join
- name: Verify DNS client settings
  win_shell: |
    Set-DnsClient -InterfaceAlias "{{ primary_interface }}" -RegisterThisConnectionsAddress $true
    
- name: Set DNS suffix
  win_shell: |
    Set-DnsClient -InterfaceAlias "{{ primary_interface }}" -ConnectionSpecificSuffix "{{ target_domain }}"

- name: Configure DNS servers
  win_shell: |
    Set-DnsClientServerAddress -InterfaceAlias "{{ primary_interface }}" -ServerAddresses @("{{ target_dns_primary }}", "{{ target_dns_secondary }}")

- name: Force DNS registration
  win_shell: |
    Register-DnsClient
    ipconfig /registerdns
  
- name: Wait for DNS propagation
  pause:
    seconds: 60

- name: Verify DNS registration
  win_shell: |
    Resolve-DnsName {{ inventory_hostname }}.{{ target_domain }} -Server {{ target_dns_primary }}
  register: dns_verify
  retries: 5
  delay: 30
  until: dns_verify is success
```

**Cleanup of old DNS records:**

```yaml
# In machine_move_usmt role, after successful join to target
- name: Remove old DNS A record
  win_shell: |
    Remove-DnsServerResourceRecord -ZoneName "{{ source_domain }}" -Name "{{ inventory_hostname }}" -RRType A -Force
  delegate_to: "{{ source_dns_server }}"
  failed_when: false

- name: Remove old PTR record
  win_shell: |
    $oldIP = "{{ hostvars[inventory_hostname].old_ip_address }}"
    $octets = $oldIP -split '\.'
    $reverseName = "$($octets[3]).$($octets[2]).$($octets[1]).$($octets[0]).in-addr.arpa"
    $reverseZone = "$($octets[2]).$($octets[1]).$($octets[0]).in-addr.arpa"
    Remove-DnsServerResourceRecord -ZoneName $reverseZone -Name $octets[3] -RRType Ptr -Force
  delegate_to: "{{ source_dns_server }}"
  failed_when: false
```

---

### Approach 2: Static DNS Registration (Required for Servers)

**Why:** Servers often have static IPs and service aliases (CNAMEs) that must be preserved

**Process:**

**Step 1: Pre-Create DNS Records in Target**

```yaml
# Playbook: playbooks/11_dns_provision.yml
- name: Provision DNS Records in Target Zone
  hosts: target_dns_servers
  gather_facts: no

  tasks:
    - name: Load migration host list
      set_fact:
        migration_hosts: "{{ lookup('file', 'artifacts/{{ wave }}_hosts.json') | from_json }}"

    - name: Create A records for servers (pre-migration)
      win_shell: |
        Add-DnsServerResourceRecordA -ZoneName "{{ target_domain }}" -Name "{{ item.hostname }}" -IPv4Address "{{ item.ip_address }}" -CreatePtr
      loop: "{{ migration_hosts }}"
      when: item.type == 'server'
      failed_when: false  # May already exist

    - name: Create CNAME aliases
      win_shell: |
        Add-DnsServerResourceRecordCName -ZoneName "{{ target_domain }}" -Name "{{ item.alias }}" -HostNameAlias "{{ item.target }}.{{ target_domain }}"
      loop: "{{ dns_aliases }}"
      vars:
        dns_aliases: "{{ lookup('file', 'mappings/dns_aliases.yml') | from_yaml }}"
```

**Step 2: Validate DNS Resolution (Post-Migration)**

```yaml
# In server_rebind role, after domain join
- name: Validate forward DNS resolution
  win_shell: |
    $result = Resolve-DnsName {{ inventory_hostname }}.{{ target_domain }} -Server {{ target_dns_primary }}
    if ($result.IPAddress -ne "{{ ansible_ip_addresses[0] }}") {
      throw "DNS mismatch: Expected {{ ansible_ip_addresses[0] }}, got $($result.IPAddress)"
    }
  register: dns_forward_check
  retries: 10
  delay: 30
  until: dns_forward_check is success

- name: Validate reverse DNS resolution
  win_shell: |
    $result = Resolve-DnsName {{ ansible_ip_addresses[0] }} -Server {{ target_dns_primary }}
    if ($result.NameHost -ne "{{ inventory_hostname }}.{{ target_domain }}") {
      throw "PTR mismatch: Expected {{ inventory_hostname }}.{{ target_domain }}, got $($result.NameHost)"
    }
  register: dns_reverse_check
  retries: 10
  delay: 30
  until: dns_reverse_check is success
```

---

### Approach 3: IP Address Change + DNS Migration

**Scenario:** Moving to new data center or new IP subnet

**Step 1: Capture Old IP**

```yaml
# In preflight_validation role
- name: Record current IP address for rollback
  set_fact:
    old_ip_address: "{{ ansible_ip_addresses[0] }}"

- name: Save old IP to state
  copy:
    content: |
      {
        "hostname": "{{ inventory_hostname }}",
        "old_ip": "{{ old_ip_address }}",
        "old_domain": "{{ ansible_domain }}",
        "timestamp": "{{ ansible_date_time.iso8601 }}"
      }
    dest: "{{ state_dir }}/host/{{ inventory_hostname }}/network_backup.json"
  delegate_to: localhost
```

**Step 2: Change IP Address During Migration**

```yaml
# In machine_move_usmt role, after domain join
- name: Configure new IP address
  win_shell: |
    $adapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up" -and $_.InterfaceDescription -notlike "*Loopback*"} | Select-Object -First 1
    New-NetIPAddress -InterfaceAlias $adapter.Name -IPAddress "{{ new_ip_address }}" -PrefixLength {{ subnet_prefix }} -DefaultGateway "{{ default_gateway }}"
    Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses @("{{ target_dns_primary }}", "{{ target_dns_secondary }}")
  when: new_ip_address is defined and new_ip_address != old_ip_address

- name: Reboot to apply network changes
  win_reboot:
    reboot_timeout: 600
  when: new_ip_address is defined
```

**Step 3: Update DNS with New IP**

```yaml
- name: Update DNS A record with new IP
  win_shell: |
    Remove-DnsServerResourceRecord -ZoneName "{{ target_domain }}" -Name "{{ inventory_hostname }}" -RRType A -Force -ErrorAction SilentlyContinue
    Add-DnsServerResourceRecordA -ZoneName "{{ target_domain }}" -Name "{{ inventory_hostname }}" -IPv4Address "{{ new_ip_address }}" -CreatePtr
  delegate_to: "{{ target_dns_server }}"
```

---

## 4) Service-Specific DNS Handling

### 4.1 SQL Server

**DNS Requirements:**
- A record for server name
- CNAME alias for service name (e.g., `sql.example.com` → `SQL01.target.example.com`)
- SPN registration matches DNS name

**Migration Steps:**

```yaml
- name: Create SQL DNS alias in target
  win_shell: |
    Add-DnsServerResourceRecordCName -ZoneName "{{ target_domain }}" -Name "sql" -HostNameAlias "{{ inventory_hostname }}.{{ target_domain }}"
  delegate_to: "{{ target_dns_server }}"

- name: Validate SQL connection via alias
  win_shell: |
    sqlcmd -S sql.{{ target_domain }} -Q "SELECT @@SERVERNAME"
  register: sql_test
  failed_when: sql_test.stdout is not search(inventory_hostname)
```

---

### 4.2 Web Applications (IIS)

**DNS Requirements:**
- A record for server
- CNAME for friendly URL (e.g., `intranet.example.com` → `WEB01.target.example.com`)
- SSL certificate must match DNS name

**Migration Steps:**

```yaml
- name: Create web app DNS alias
  win_shell: |
    Add-DnsServerResourceRecordCName -ZoneName "{{ target_domain }}" -Name "intranet" -HostNameAlias "{{ inventory_hostname }}.{{ target_domain }}"
  delegate_to: "{{ target_dns_server }}"

- name: Update IIS binding if hostname changes
  win_shell: |
    Import-Module WebAdministration
    Get-WebBinding -Name "Default Web Site" | Where-Object {$_.protocol -eq "https"} | ForEach-Object {
      Set-WebBinding -Name "Default Web Site" -BindingInformation $_.bindingInformation -PropertyName HostHeader -Value "intranet.{{ target_domain }}"
    }
  when: update_iis_bindings | default(false)
```

---

### 4.3 File Servers

**DNS Requirements:**
- A record for server
- DFS namespace may need DNS updates if root servers change

**Migration Steps:**

```yaml
- name: Validate file share access via DNS name
  win_shell: |
    Test-Path \\{{ inventory_hostname }}.{{ target_domain }}\Share1
  register: share_test
  delegate_to: "{{ test_client }}"

- name: Update DFS root target (if applicable)
  win_shell: |
    Remove-DfsnRootTarget -Path "\\{{ source_domain }}\DFSRoot" -TargetPath "\\{{ inventory_hostname }}.{{ source_domain }}\DFSRoot"
    New-DfsnRootTarget -Path "\\{{ target_domain }}\DFSRoot" -TargetPath "\\{{ inventory_hostname }}.{{ target_domain }}\DFSRoot"
  when: is_dfs_root_server | default(false)
```

---

### 4.4 Domain Controllers (Special Case)

**DNS Requirements:**
- A record for DC name
- Multiple SRV records for domain services
- Kerberos, LDAP, GC, Kpasswd SRV records

**Handling:**
- **DO NOT** manually migrate DC DNS records
- Use `dcpromo` / `Install-ADDSDomainController` which auto-registers SRV records
- Validate with `dcdiag /test:dns`

---

## 5) DNS Scavenging and Cleanup

### 5.1 Enable Scavenging on Source DNS

**Purpose:** Automatically remove stale records from source domain after machines migrate

**Configuration:**

```powershell
# On source DNS server
# Enable scavenging on zone
Set-DnsServerZoneAging -Name "source.example.com" -Aging $true -ScavengeServers "DNS01.source.example.com"

# Set no-refresh interval: 7 days
# Set refresh interval: 7 days
# (Records older than 14 days will be scavenged)
Set-DnsServerZoneAging -Name "source.example.com" -NoRefreshInterval 7.00:00:00 -RefreshInterval 7.00:00:00

# Enable scavenging on server
Set-DnsServerScavenging -ScavengingState $true -ScavengingInterval 7.00:00:00 -ApplyOnAllZones
```

**Result:** Old DNS records will auto-delete 14 days after migration

---

### 5.2 Manual Cleanup (Immediate)

**Playbook:** `playbooks/12_dns_cleanup.yml`

```yaml
---
- name: DNS Cleanup - Remove Migrated Host Records from Source
  hosts: source_dns_servers
  gather_facts: no

  tasks:
    - name: Load migrated hosts list
      set_fact:
        migrated_hosts: "{{ lookup('file', 'state/wave/{{ wave }}/migrated_hosts.json') | from_json }}"

    - name: Remove A records from source zone
      win_shell: |
        Remove-DnsServerResourceRecord -ZoneName "{{ source_domain }}" -Name "{{ item.hostname }}" -RRType A -Force
      loop: "{{ migrated_hosts }}"
      failed_when: false

    - name: Remove PTR records from source reverse zone
      win_shell: |
        $ip = "{{ item.old_ip }}"
        $octets = $ip -split '\.'
        $reverseZone = "$($octets[2]).$($octets[1]).$($octets[0]).in-addr.arpa"
        Remove-DnsServerResourceRecord -ZoneName $reverseZone -Name $octets[3] -RRType Ptr -Force
      loop: "{{ migrated_hosts }}"
      failed_when: false

    - name: Remove CNAME aliases
      win_shell: |
        Remove-DnsServerResourceRecord -ZoneName "{{ source_domain }}" -Name "{{ item.alias }}" -RRType CName -Force
      loop: "{{ dns_aliases }}"
      when: item.migrated | default(false)
      failed_when: false
```

---

## 6) DNS Validation and Testing

### 6.1 Pre-Migration DNS Health Check

**Playbook:** `playbooks/00f_validate_dns.yml`

```yaml
---
- name: DNS Validation - Pre-Migration
  hosts: all
  gather_facts: no

  tasks:
    - name: Check forward DNS resolution
      win_shell: |
        Resolve-DnsName {{ inventory_hostname }}.{{ ansible_domain }} -Server {{ ansible_dns_servers[0] }}
      register: dns_forward
      failed_when: false

    - name: Check reverse DNS resolution
      win_shell: |
        Resolve-DnsName {{ ansible_ip_addresses[0] }} -Server {{ ansible_dns_servers[0] }}
      register: dns_reverse
      failed_when: false

    - name: Check DNS suffix
      win_shell: |
        (Get-DnsClient).ConnectionSpecificSuffix
      register: dns_suffix_check

    - name: Report DNS health
      set_fact:
        dns_health:
          forward_ok: "{{ dns_forward is success }}"
          reverse_ok: "{{ dns_reverse is success }}"
          suffix: "{{ dns_suffix_check.stdout | trim }}"
          issues: "{{ [] if (dns_forward is success and dns_reverse is success) else ['DNS resolution issues detected'] }}"
```

---

### 6.2 Post-Migration DNS Validation

**Add to validation playbook (`playbooks/40_validate.yml`):**

```yaml
- name: Validate DNS in target domain
  hosts: "{{ target_hosts }}"
  gather_facts: yes

  tasks:
    - name: Check forward DNS resolution
      win_shell: |
        $result = Resolve-DnsName {{ inventory_hostname }}.{{ target_domain }} -Server {{ target_dns_primary }}
        if ($result.IPAddress -ne "{{ ansible_ip_addresses[0] }}") {
          throw "DNS mismatch"
        }
      register: dns_forward_validate
      retries: 5
      delay: 30
      until: dns_forward_validate is success

    - name: Check reverse DNS resolution
      win_shell: |
        $result = Resolve-DnsName {{ ansible_ip_addresses[0] }} -Server {{ target_dns_primary }}
        if ($result.NameHost -ne "{{ inventory_hostname }}.{{ target_domain }}") {
          throw "PTR mismatch"
        }
      register: dns_reverse_validate
      retries: 5
      delay: 30
      until: dns_reverse_validate is success

    - name: Validate DNS suffix
      win_shell: |
        $suffix = (Get-DnsClient | Where-Object {$_.InterfaceAlias -notlike "*Loopback*"}).ConnectionSpecificSuffix | Select-Object -First 1
        if ($suffix -ne "{{ target_domain }}") {
          throw "DNS suffix mismatch: Expected {{ target_domain }}, got $suffix"
        }

    - name: Validate CNAME aliases (for servers)
      win_shell: |
        Resolve-DnsName {{ item.alias }}.{{ target_domain }} -Server {{ target_dns_primary }}
      loop: "{{ dns_aliases }}"
      when: inventory_hostname == item.target
      register: alias_validate

    - name: Test application access via DNS name
      win_shell: |
        Test-NetConnection {{ inventory_hostname }}.{{ target_domain }} -Port {{ item.port }}
      loop:
        - { port: 3389 }   # RDP
        - { port: 445 }    # SMB
        - { port: 5985 }   # WinRM
      register: app_access_test
```

---

## 7) Rollback DNS Changes

**Scenario:** Wave rolled back, hosts rejoined source domain

**Playbook:** `playbooks/99_rollback_dns.yml`

```yaml
---
- name: Rollback DNS - Restore Source Records
  hosts: "{{ rollback_hosts }}"
  gather_facts: no

  tasks:
    - name: Load network backup
      slurp:
        src: "{{ state_dir }}/host/{{ inventory_hostname }}/network_backup.json"
      register: network_backup_raw
      delegate_to: localhost

    - name: Parse network backup
      set_fact:
        network_backup: "{{ network_backup_raw.content | b64decode | from_json }}"

    - name: Re-create A record in source DNS
      win_shell: |
        Add-DnsServerResourceRecordA -ZoneName "{{ source_domain }}" -Name "{{ inventory_hostname }}" -IPv4Address "{{ network_backup.old_ip }}" -CreatePtr
      delegate_to: "{{ source_dns_server }}"

    - name: Remove record from target DNS
      win_shell: |
        Remove-DnsServerResourceRecord -ZoneName "{{ target_domain }}" -Name "{{ inventory_hostname }}" -RRType A -Force
      delegate_to: "{{ target_dns_server }}"
      failed_when: false

    - name: Force DNS registration to source
      win_shell: |
        Register-DnsClient
        ipconfig /registerdns
```

---

## 8) DNS Migration Checklist

**Pre-Wave (T-24 hours):**
- [ ] DNS discovery completed (`00e_discovery_dns.yml`)
- [ ] DNS aliases documented in `mappings/dns_aliases.yml`
- [ ] Target DNS zones configured (forward and reverse)
- [ ] DNS scavenging configured on source DNS
- [ ] DHCP scopes updated with target DNS servers (if applicable)
- [ ] Split-brain DNS tested (source and target can coexist)

**During Wave:**
- [ ] DNS records provisioned in target (`11_dns_provision.yml`)
- [ ] Dynamic DNS registration validated post-join
- [ ] Forward and reverse lookups tested
- [ ] CNAME aliases re-created for services
- [ ] Application access tested via DNS name

**Post-Wave (T+24 hours):**
- [ ] DNS cleanup of source records (`12_dns_cleanup.yml`)
- [ ] No orphaned DNS entries in source
- [ ] DNS scavenging running on source
- [ ] All service aliases resolving correctly
- [ ] No DNS-related incidents reported

---

## 9) Common DNS Issues and Fixes

### Issue: DNS Record Not Registering in Target

**Symptoms:** `nslookup <hostname>` returns "Name does not exist"

**Diagnosis:**
```powershell
# On migrated host
ipconfig /all
# Check DNS suffix and DNS servers

Get-DnsClient | Select InterfaceAlias, ConnectionSpecificSuffix
```

**Fix:**
```powershell
# Force DNS registration
ipconfig /registerdns
Register-DnsClient

# Wait 2 minutes
Start-Sleep 120

# Verify on DNS server
Resolve-DnsName <hostname>.target.example.com -Server target-dns.target.example.com
```

---

### Issue: Stale DNS Cache Causing Old IP Resolution

**Symptoms:** Applications connecting to old IP address even after migration

**Fix:**
```powershell
# Clear DNS cache on client
ipconfig /flushdns

# Clear DNS cache on DNS server
Clear-DnsServerCache -Force
```

---

### Issue: PTR Record Mismatch

**Symptoms:** Reverse DNS lookup returns wrong hostname or fails

**Diagnosis:**
```powershell
Resolve-DnsName 10.0.1.50 -Server target-dns.target.example.com
# Expected: hostname.target.example.com
# Actual: hostname.source.example.com OR "Name does not exist"
```

**Fix:**
```powershell
# Remove old PTR
$ip = "10.0.1.50"
$octets = $ip -split '\.'
$reverseZone = "$($octets[2]).$($octets[1]).$($octets[0]).in-addr.arpa"
Remove-DnsServerResourceRecord -ZoneName $reverseZone -Name $octets[3] -RRType Ptr -Force

# Add new PTR
Add-DnsServerResourceRecordPtr -ZoneName $reverseZone -Name $octets[3] -PtrDomainName "hostname.target.example.com"
```

---

## 10) DNS Migration Timeline

| Phase | Task | Duration | Who |
|-------|------|----------|-----|
| **T-7 days** | DNS discovery and export | 1 hour | Migration team |
| **T-3 days** | Document DNS aliases and service records | 2 hours | App owners + migration team |
| **T-1 day** | Provision target DNS zones and records | 1 hour | DNS admin |
| **T-1 day** | Configure DHCP with target DNS servers | 30 min | Network team |
| **T=0 (cutover)** | Machines re-register DNS via DDNS | Automatic | N/A |
| **T+1 hour** | Validate DNS resolution for all hosts | 30 min | Migration team |
| **T+4 hours** | Create CNAME aliases for services | 1 hour | DNS admin |
| **T+1 day** | Clean up source DNS records | 30 min | DNS admin |
| **T+14 days** | DNS scavenging removes remaining stale records | Automatic | N/A |

---

## 11) Summary

**Key Takeaways:**
1. **Dynamic DNS (DDNS)** handles most workstation records automatically
2. **Servers require manual DNS provisioning** due to static IPs and aliases
3. **Capture old IPs** before migration for rollback capability
4. **Validate DNS resolution** before declaring wave successful
5. **Clean up source DNS** within 24 hours to avoid confusion
6. **Enable DNS scavenging** for long-term hygiene
7. **Test CNAME aliases** for all service endpoints

**Integration Points:**
- Add `00e_discovery_dns.yml` to discovery phase
- Add `11_dns_provision.yml` before machine migration
- Add DNS validation to `40_validate.yml`
- Add `12_dns_cleanup.yml` to post-wave cleanup

---

**For network-level considerations (DHCP, routing), see `docs/14_NETWORK_MIGRATION_STRATEGY.md` (to be created).**

---

**END OF DOCUMENT**

