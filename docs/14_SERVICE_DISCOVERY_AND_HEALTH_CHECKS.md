# Service Discovery & Domain Health Checks

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Date:** October 2025

**Purpose:** Comprehensive discovery of services, applications, and dependencies on servers, plus validation of domain/DNS health before migration waves.

**Criticality:** CRITICAL – These checks are **go/no-go gates**. Do not proceed with migration if critical issues are found.

---

## 1) Service Discovery on Servers

### 1.1 Windows Services Enumeration

**What to Discover:**
- All Windows Services (automatic startup)
- Service account principals (LocalSystem, NetworkService, domain accounts)
- Dependencies between services
- Service descriptions and display names
- Binary paths and command-line arguments

**Playbook:** `playbooks/00g_discovery_services.yml`

```yaml
---
- name: Service Discovery - Windows Services
  hosts: windows:&servers
  gather_facts: yes

  tasks:
    - name: Enumerate all services
      win_shell: |
        Get-Service | Where-Object {$_.StartType -ne "Disabled"} | 
          Select-Object Name, DisplayName, Status, StartType, 
            @{N='ServiceAccount';E={(Get-WmiObject Win32_Service -Filter "Name='$($_.Name)'").StartName}},
            @{N='BinaryPath';E={(Get-WmiObject Win32_Service -Filter "Name='$($_.Name)'").PathName}},
            @{N='Dependencies';E={$_.ServicesDependedOn.Name -join ','}} |
          ConvertTo-Json -Compress
      register: services_raw

    - name: Parse services
      set_fact:
        services: "{{ services_raw.stdout | from_json }}"

    - name: Identify domain service accounts
      set_fact:
        domain_service_accounts: "{{ services | selectattr('ServiceAccount', 'search', source_domain) | map(attribute='ServiceAccount') | unique | list }}"

    - name: Get service dependencies graph
      win_shell: |
        $services = Get-Service
        $graph = @{}
        foreach ($svc in $services) {
          $deps = $svc.ServicesDependedOn | Select-Object -ExpandProperty Name
          if ($deps) {
            $graph[$svc.Name] = $deps
          }
        }
        $graph | ConvertTo-Json -Compress
      register: dependency_graph

    - name: Save service inventory
      copy:
        content: |
          {
            "hostname": "{{ inventory_hostname }}",
            "services": {{ services_raw.stdout }},
            "domain_service_accounts": {{ domain_service_accounts | to_json }},
            "dependency_graph": {{ dependency_graph.stdout }},
            "discovered_at": "{{ ansible_date_time.iso8601 }}"
          }
        dest: "{{ artifacts_dir }}/services/{{ inventory_hostname }}_services.json"
      delegate_to: localhost

    - name: Flag critical services
      set_fact:
        critical_services: "{{ services | selectattr('Name', 'in', critical_service_list) | list }}"
      vars:
        critical_service_list:
          - 'MSSQLSERVER'
          - 'SQLSERVERAGENT'
          - 'W3SVC'  # IIS
          - 'WAS'    # IIS App Pool
          - 'NTDS'   # Active Directory
          - 'DNS'
          - 'DFS Replication'
          - 'Netlogon'

    - name: Warn if critical services using domain accounts
      debug:
        msg: "WARNING: Critical service {{ item.Name }} uses domain account {{ item.ServiceAccount }}"
      loop: "{{ critical_services }}"
      when: item.ServiceAccount is search(source_domain)
```

**Output:** `artifacts/services/<hostname>_services.json`

```json
{
  "hostname": "APP01",
  "services": [
    {
      "Name": "MyAppService",
      "DisplayName": "My Application Service",
      "Status": "Running",
      "StartType": "Automatic",
      "ServiceAccount": "DOMAIN\\svc_myapp",
      "BinaryPath": "C:\\Program Files\\MyApp\\service.exe",
      "Dependencies": "HTTP,RpcSs"
    }
  ],
  "domain_service_accounts": ["DOMAIN\\svc_myapp", "DOMAIN\\svc_sql"],
  "dependency_graph": {
    "MyAppService": ["HTTP", "RpcSs"],
    "W3SVC": ["HTTP"]
  }
}
```

---

### 1.2 Scheduled Tasks Discovery

**What to Discover:**
- All scheduled tasks
- Task principals (user accounts)
- Triggers (schedule, event-based)
- Actions (executables, scripts)
- Dependencies on other tasks

**Playbook snippet:**

```yaml
- name: Enumerate scheduled tasks
  win_shell: |
    Get-ScheduledTask | Where-Object {$_.State -ne "Disabled"} |
      Select-Object TaskName, TaskPath, State,
        @{N='Principal';E={$_.Principal.UserId}},
        @{N='Triggers';E={($_.Triggers | ForEach-Object {$_.ToString()}) -join ';'}},
        @{N='Actions';E={($_.Actions | ForEach-Object {$_.Execute + ' ' + $_.Arguments}) -join ';'}} |
      ConvertTo-Json -Compress
  register: scheduled_tasks

- name: Identify tasks with domain accounts
  set_fact:
    domain_tasks: "{{ (scheduled_tasks.stdout | from_json) | selectattr('Principal', 'search', source_domain) | list }}"

- name: Save scheduled tasks inventory
  copy:
    content: |
      {
        "hostname": "{{ inventory_hostname }}",
        "tasks": {{ scheduled_tasks.stdout }},
        "domain_tasks": {{ domain_tasks | to_json }}
      }
    dest: "{{ artifacts_dir }}/services/{{ inventory_hostname }}_tasks.json"
  delegate_to: localhost
```

---

### 1.3 IIS Configuration Discovery

**What to Discover:**
- Web sites and application pools
- Bindings (hostname, port, SSL certificate)
- App pool identities (domain accounts)
- Virtual directories and physical paths
- Authentication methods

**Playbook snippet:**

```yaml
- name: Check if IIS installed
  win_service_info:
    name: W3SVC
  register: iis_check

- name: Enumerate IIS sites
  win_shell: |
    Import-Module WebAdministration
    Get-Website | Select-Object Name, State, PhysicalPath,
      @{N='Bindings';E={($_.Bindings.Collection | ForEach-Object {$_.protocol + '://' + $_.bindingInformation}) -join ';'}},
      @{N='AppPool';E={$_.applicationPool}} |
      ConvertTo-Json -Compress
  register: iis_sites
  when: iis_check.services[0].state == 'running'

- name: Enumerate IIS app pools
  win_shell: |
    Import-Module WebAdministration
    Get-IISAppPool | Select-Object Name, State,
      @{N='Identity';E={$_.processModel.userName}},
      @{N='IdentityType';E={$_.processModel.identityType}} |
      ConvertTo-Json -Compress
  register: iis_apppools
  when: iis_check.services[0].state == 'running'

- name: Enumerate SSL certificates
  win_shell: |
    Get-ChildItem Cert:\LocalMachine\My | 
      Where-Object {$_.HasPrivateKey -eq $true} |
      Select-Object Subject, Thumbprint, NotBefore, NotAfter,
        @{N='DaysToExpiry';E={($_.NotAfter - (Get-Date)).Days}} |
      ConvertTo-Json -Compress
  register: ssl_certs
  when: iis_check.services[0].state == 'running'

- name: Save IIS inventory
  copy:
    content: |
      {
        "hostname": "{{ inventory_hostname }}",
        "sites": {{ iis_sites.stdout | default('[]') }},
        "app_pools": {{ iis_apppools.stdout | default('[]') }},
        "ssl_certs": {{ ssl_certs.stdout | default('[]') }}
      }
    dest: "{{ artifacts_dir }}/services/{{ inventory_hostname }}_iis.json"
  delegate_to: localhost
  when: iis_check.services[0].state == 'running'
```

---

### 1.4 SQL Server Discovery

**What to Discover:**
- SQL Server instances
- Database names and sizes
- SQL Agent jobs
- Linked servers (cross-server dependencies)
- Service accounts
- SQL logins (Windows auth vs. SQL auth)

**Playbook snippet:**

```yaml
- name: Check if SQL Server installed
  win_service_info:
    name: MSSQLSERVER
  register: sql_check

- name: Enumerate SQL instances
  win_shell: |
    Get-Service | Where-Object {$_.Name -like "MSSQL*" -and $_.Status -eq "Running"} |
      Select-Object Name, DisplayName, 
        @{N='ServiceAccount';E={(Get-WmiObject Win32_Service -Filter "Name='$($_.Name)'").StartName}} |
      ConvertTo-Json -Compress
  register: sql_instances
  when: sql_check.services | length > 0

- name: Get SQL databases (via sqlcmd)
  win_shell: |
    sqlcmd -S localhost -Q "SELECT name, database_id, create_date, (SUM(size) * 8 / 1024) AS size_mb FROM sys.databases d JOIN sys.master_files f ON d.database_id = f.database_id GROUP BY name, d.database_id, create_date FOR JSON PATH" -h -1
  register: sql_databases
  when: sql_check.services[0].state == 'running'
  failed_when: false

- name: Get SQL Agent jobs
  win_shell: |
    sqlcmd -S localhost -Q "SELECT job_id, name, enabled, date_created, date_modified FROM msdb.dbo.sysjobs FOR JSON PATH" -h -1
  register: sql_jobs
  when: sql_check.services[0].state == 'running'
  failed_when: false

- name: Get linked servers
  win_shell: |
    sqlcmd -S localhost -Q "SELECT name, product, provider, data_source FROM sys.servers WHERE is_linked = 1 FOR JSON PATH" -h -1
  register: sql_linked_servers
  when: sql_check.services[0].state == 'running'
  failed_when: false

- name: Get SQL logins with domain accounts
  win_shell: |
    sqlcmd -S localhost -Q "SELECT name, type_desc, create_date, is_disabled FROM sys.server_principals WHERE type IN ('U', 'G') AND name LIKE '{{ source_domain }}%' FOR JSON PATH" -h -1
  register: sql_logins
  when: sql_check.services[0].state == 'running'
  failed_when: false

- name: Save SQL inventory
  copy:
    content: |
      {
        "hostname": "{{ inventory_hostname }}",
        "instances": {{ sql_instances.stdout | default('[]') }},
        "databases": {{ sql_databases.stdout | default('[]') }},
        "jobs": {{ sql_jobs.stdout | default('[]') }},
        "linked_servers": {{ sql_linked_servers.stdout | default('[]') }},
        "domain_logins": {{ sql_logins.stdout | default('[]') }}
      }
    dest: "{{ artifacts_dir }}/services/{{ inventory_hostname }}_sql.json"
  delegate_to: localhost
  when: sql_check.services | length > 0
```

---

### 1.5 Network Port Listeners

**What to Discover:**
- Active TCP/UDP listeners
- Process owning each port
- Inbound connections from other servers (dependencies)

**Playbook snippet:**

```yaml
- name: Get active TCP listeners
  win_shell: |
    Get-NetTCPConnection -State Listen | 
      Select-Object LocalAddress, LocalPort, State,
        @{N='Process';E={(Get-Process -Id $_.OwningProcess).ProcessName}},
        @{N='ProcessPath';E={(Get-Process -Id $_.OwningProcess).Path}} |
      ConvertTo-Json -Compress
  register: tcp_listeners

- name: Get established connections (to detect dependencies)
  win_shell: |
    Get-NetTCPConnection -State Established | 
      Where-Object {$_.RemoteAddress -notlike "127.*" -and $_.RemoteAddress -ne "::1"} |
      Group-Object RemoteAddress | 
      Select-Object @{N='RemoteServer';E={$_.Name}}, @{N='ConnectionCount';E={$_.Count}} |
      Sort-Object ConnectionCount -Descending |
      Select-Object -First 20 |
      ConvertTo-Json -Compress
  register: remote_connections

- name: Save network inventory
  copy:
    content: |
      {
        "hostname": "{{ inventory_hostname }}",
        "tcp_listeners": {{ tcp_listeners.stdout }},
        "remote_connections": {{ remote_connections.stdout }},
        "discovery_note": "Remote connections show servers this host depends on"
      }
    dest: "{{ artifacts_dir }}/services/{{ inventory_hostname }}_network.json"
  delegate_to: localhost
```

---

### 1.6 Application-Specific Discovery

**Custom application configurations:**

```yaml
- name: Scan for custom config files
  win_find:
    paths:
      - 'C:\Program Files'
      - 'C:\inetpub'
      - 'D:\Apps'
    patterns:
      - '*.config'
      - 'appsettings.json'
      - 'web.config'
      - 'app.config'
    recurse: yes
    depth: 3
  register: config_files

- name: Search configs for domain references
  win_shell: |
    Select-String -Path "{{ item.path }}" -Pattern "{{ source_domain }}" -CaseSensitive:$false
  loop: "{{ config_files.files }}"
  register: domain_references
  failed_when: false

- name: Save config file inventory
  copy:
    content: |
      {
        "hostname": "{{ inventory_hostname }}",
        "config_files": {{ config_files.files | to_json }},
        "domain_references": {{ domain_references.results | selectattr('stdout', 'defined') | map(attribute='item.path') | list | to_json }}
      }
    dest: "{{ artifacts_dir }}/services/{{ inventory_hostname }}_configs.json"
  delegate_to: localhost
```

---

### 1.7 Service Principal Names (SPNs)

**What to Discover:**
- All SPNs registered for server computer account
- All SPNs registered for service accounts
- Duplicate SPNs (will cause authentication failures)

**Playbook snippet:**

```yaml
- name: Get SPNs for computer account
  win_shell: |
    setspn -L {{ inventory_hostname }}
  register: computer_spns

- name: Get SPNs for service accounts
  win_shell: |
    setspn -L {{ item }}
  loop: "{{ domain_service_accounts }}"
  register: service_account_spns
  delegate_to: "{{ source_dc }}"
  failed_when: false

- name: Check for duplicate SPNs
  win_shell: |
    setspn -X -F
  register: duplicate_spns
  delegate_to: "{{ source_dc }}"

- name: Save SPN inventory
  copy:
    content: |
      {
        "hostname": "{{ inventory_hostname }}",
        "computer_spns": {{ computer_spns.stdout_lines | to_json }},
        "service_account_spns": {{ service_account_spns.results | map(attribute='stdout_lines') | list | to_json }},
        "duplicate_spns": {{ duplicate_spns.stdout_lines | to_json }}
      }
    dest: "{{ artifacts_dir }}/services/{{ inventory_hostname }}_spns.json"
  delegate_to: localhost
```

---

## 2) Domain Health Checks

### 2.1 Domain Controller Health (dcdiag)

**What to Check:**
- Connectivity to all DCs
- Replication status
- DNS registration
- FSMO role holders
- Active Directory database integrity

**Playbook:** `playbooks/00c_discovery_domain_core.yml`

```yaml
---
- name: Domain Health - Core Checks
  hosts: source_dcs
  gather_facts: no

  tasks:
    - name: Run dcdiag comprehensive test
      win_shell: |
        dcdiag /v /c /skip:SystemLog | Out-String
      register: dcdiag_output
      changed_when: false

    - name: Parse dcdiag for failures
      set_fact:
        dcdiag_failed: "{{ dcdiag_output.stdout is search('failed test') }}"
        dcdiag_warnings: "{{ dcdiag_output.stdout | regex_findall('Warning:.*') }}"

    - name: Fail if critical tests failed
      fail:
        msg: "CRITICAL: dcdiag failed on {{ inventory_hostname }}. Review: {{ artifacts_dir }}/domain/dcdiag_{{ inventory_hostname }}.txt"
      when: dcdiag_failed

    - name: Save dcdiag output
      copy:
        content: "{{ dcdiag_output.stdout }}"
        dest: "{{ artifacts_dir }}/domain/dcdiag_{{ inventory_hostname }}.txt"
      delegate_to: localhost

    - name: Run specific critical tests
      win_shell: |
        $tests = @{
          'Connectivity' = (dcdiag /test:Connectivity)
          'Replications' = (dcdiag /test:Replications)
          'NCSecDesc' = (dcdiag /test:NCSecDesc)
          'NetLogons' = (dcdiag /test:NetLogons)
          'DNS' = (dcdiag /test:DNS /DnsBasic)
        }
        $results = @{}
        foreach ($test in $tests.Keys) {
          $output = $tests[$test] -join "`n"
          $results[$test] = @{
            'passed' = ($output -notmatch 'failed test')
            'output' = $output
          }
        }
        $results | ConvertTo-Json -Depth 3
      register: critical_tests

    - name: Parse critical test results
      set_fact:
        domain_health: "{{ critical_tests.stdout | from_json }}"

    - name: Report domain health
      debug:
        msg: "Domain health on {{ inventory_hostname }}: {{ domain_health | dict2items | selectattr('value.passed', 'equalto', false) | map(attribute='key') | list }}"
```

---

### 2.2 Active Directory Replication

**What to Check:**
- Replication topology
- Last replication success time
- Replication failures/pending changes
- Replication queue depth

**Playbook snippet:**

```yaml
- name: Check AD replication status
  win_shell: |
    repadmin /showrepl /csv | ConvertFrom-Csv | 
      Select-Object "Source DSA", "Naming Context", "Last Success", "Failures" |
      ConvertTo-Json -Compress
  register: replication_status
  delegate_to: "{{ source_dc }}"

- name: Parse replication status
  set_fact:
    replication_data: "{{ replication_status.stdout | from_json }}"

- name: Identify replication failures
  set_fact:
    replication_failures: "{{ replication_data | selectattr('Failures', '!=', '0') | list }}"

- name: Fail if replication broken
  fail:
    msg: "CRITICAL: AD replication failures detected: {{ replication_failures | map(attribute='Source DSA') | list }}"
  when: replication_failures | length > 0

- name: Check replication lag
  win_shell: |
    repadmin /showrepl /csv | ConvertFrom-Csv | 
      Select-Object "Source DSA", "Last Success" |
      ForEach-Object {
        $lastSync = [datetime]::Parse($_.'Last Success')
        $age = (Get-Date) - $lastSync
        [PSCustomObject]@{
          'Source' = $_.'Source DSA'
          'LastSync' = $lastSync
          'AgeMinutes' = $age.TotalMinutes
        }
      } | ConvertTo-Json -Compress
  register: replication_lag

- name: Warn if replication lag >15 minutes
  debug:
    msg: "WARNING: Replication lag from {{ item.Source }}: {{ item.AgeMinutes }} minutes"
  loop: "{{ replication_lag.stdout | from_json }}"
  when: item.AgeMinutes | float > 15

- name: Check replication queue
  win_shell: |
    repadmin /queue
  register: replication_queue

- name: Fail if replication queue >1000
  fail:
    msg: "CRITICAL: Replication queue has >1000 pending changes. Wait for convergence before migration."
  when: replication_queue.stdout is search('Queue contains [0-9]{4,} item')
```

---

### 2.3 FSMO Role Holders

**What to Check:**
- Identify which DC holds each FSMO role
- Verify FSMO roles are reachable
- Check for seized vs. transferred roles

**Playbook snippet:**

```yaml
- name: Get FSMO role holders
  win_shell: |
    netdom query fsmo
  register: fsmo_roles
  delegate_to: "{{ source_dc }}"

- name: Parse FSMO roles
  set_fact:
    fsmo_holders: "{{ fsmo_roles.stdout_lines | select('search', 'master') | list }}"

- name: Verify FSMO role holder is online
  win_ping:
  delegate_to: "{{ item | regex_search('([A-Za-z0-9-]+)\\.', '\\1') | first }}"
  loop: "{{ fsmo_holders }}"
  register: fsmo_ping
  failed_when: false

- name: Fail if any FSMO holder offline
  fail:
    msg: "CRITICAL: FSMO role holder {{ item.item }} is unreachable"
  loop: "{{ fsmo_ping.results }}"
  when: item.ping is not defined or item.failed

- name: Save FSMO inventory
  copy:
    content: |
      {
        "fsmo_roles": {{ fsmo_holders | to_json }},
        "checked_at": "{{ ansible_date_time.iso8601 }}"
      }
    dest: "{{ artifacts_dir }}/domain/fsmo_roles.json"
  delegate_to: localhost
```

---

### 2.4 Trust Relationships

**What to Check:**
- All trust relationships (incoming, outgoing, two-way)
- Trust health and status
- Required for ADMT if using SIDHistory

**Playbook snippet:**

```yaml
- name: Get domain trusts
  win_shell: |
    Get-ADTrust -Filter * | 
      Select-Object Name, Direction, TrustType, Created, Modified |
      ConvertTo-Json -Compress
  register: domain_trusts
  delegate_to: "{{ source_dc }}"

- name: Test trust relationships
  win_shell: |
    nltest /sc_query:{{ item.Name }}
  loop: "{{ domain_trusts.stdout | from_json }}"
  register: trust_tests
  failed_when: false

- name: Parse trust test results
  set_fact:
    broken_trusts: "{{ trust_tests.results | selectattr('rc', 'ne', 0) | map(attribute='item.Name') | list }}"

- name: Warn if trusts broken
  debug:
    msg: "WARNING: Trust to {{ item }} is broken or unreachable"
  loop: "{{ broken_trusts }}"
  when: broken_trusts | length > 0
```

---

### 2.5 SYSVOL and NETLOGON Replication

**What to Check:**
- SYSVOL shares accessible on all DCs
- DFSR replication healthy (for Server 2008 R2+)
- Group Policy replication

**Playbook snippet:**

```yaml
- name: Check SYSVOL share
  win_shell: |
    Test-Path "\\{{ inventory_hostname }}\SYSVOL"
  register: sysvol_check

- name: Fail if SYSVOL missing
  fail:
    msg: "CRITICAL: SYSVOL share not accessible on {{ inventory_hostname }}"
  when: not (sysvol_check.stdout | bool)

- name: Check DFSR replication for SYSVOL
  win_shell: |
    Get-DfsrBacklog -GroupName "Domain System Volume" -FolderName "SYSVOL Share" -SourceComputerName {{ inventory_hostname }} -DestinationComputerName {{ item }}
  loop: "{{ other_dcs }}"
  register: sysvol_backlog
  failed_when: false

- name: Warn if SYSVOL backlog >100
  debug:
    msg: "WARNING: SYSVOL backlog to {{ item.item }}: {{ item.stdout_lines | length }} files"
  loop: "{{ sysvol_backlog.results }}"
  when: item.stdout_lines | length > 100

- name: Check NETLOGON share
  win_shell: |
    Test-Path "\\{{ inventory_hostname }}\NETLOGON"
  register: netlogon_check

- name: Fail if NETLOGON missing
  fail:
    msg: "CRITICAL: NETLOGON share not accessible on {{ inventory_hostname }}"
  when: not (netlogon_check.stdout | bool)
```

---

## 3) DNS Health Checks

### 3.1 DNS Zone Health

**What to Check:**
- All DNS zones are loaded
- Zone transfer working between DNS servers
- Dynamic update enabled (for DDNS)
- Scavenging configuration

**Playbook:** `playbooks/00f_validate_dns.yml`

```yaml
---
- name: DNS Health Checks
  hosts: source_dns_servers
  gather_facts: no

  tasks:
    - name: Get DNS zones
      win_shell: |
        Get-DnsServerZone | 
          Select-Object ZoneName, ZoneType, IsDsIntegrated, DynamicUpdate, IsAutoCreated, IsPaused |
          ConvertTo-Json -Compress
      register: dns_zones

    - name: Parse DNS zones
      set_fact:
        zones: "{{ dns_zones.stdout | from_json }}"

    - name: Check for paused zones
      set_fact:
        paused_zones: "{{ zones | selectattr('IsPaused', 'equalto', true) | map(attribute='ZoneName') | list }}"

    - name: Fail if critical zones paused
      fail:
        msg: "CRITICAL: DNS zone {{ item }} is paused on {{ inventory_hostname }}"
      loop: "{{ paused_zones }}"
      when: item == source_domain or item is search('in-addr.arpa')

    - name: Check dynamic update status
      set_fact:
        zones_without_ddns: "{{ zones | selectattr('DynamicUpdate', 'equalto', 'None') | selectattr('IsAutoCreated', 'equalto', false) | map(attribute='ZoneName') | list }}"

    - name: Warn if dynamic update disabled
      debug:
        msg: "WARNING: Dynamic update disabled on zone {{ item }}. Workstations will not auto-register."
      loop: "{{ zones_without_ddns }}"
      when: zones_without_ddns | length > 0

    - name: Check zone transfer settings
      win_shell: |
        Get-DnsServerZone -Name {{ source_domain }} | 
          Select-Object ZoneName, SecondaryServers, NotifyServers |
          ConvertTo-Json -Compress
      register: zone_transfer

    - name: Verify zone transfer working
      win_shell: |
        nslookup -type=SOA {{ source_domain }} {{ item }}
      loop: "{{ secondary_dns_servers }}"
      register: soa_checks
      failed_when: false

    - name: Fail if zone transfer broken
      fail:
        msg: "CRITICAL: Zone transfer from {{ inventory_hostname }} to {{ item.item }} is broken"
      loop: "{{ soa_checks.results }}"
      when: item.rc != 0
```

---

### 3.2 DNS SRV Records (Domain Services)

**What to Check:**
- Kerberos SRV records (_kerberos._tcp, _kerberos._udp)
- LDAP SRV records (_ldap._tcp)
- Global Catalog SRV records (_gc._tcp)
- All DCs registered correctly

**Playbook snippet:**

```yaml
- name: Check critical SRV records
  win_shell: |
    $srvRecords = @(
      "_kerberos._tcp.{{ source_domain }}",
      "_ldap._tcp.{{ source_domain }}",
      "_gc._tcp.{{ source_domain }}",
      "_kerberos._tcp.dc._msdcs.{{ source_domain }}",
      "_ldap._tcp.dc._msdcs.{{ source_domain }}"
    )
    $results = @{}
    foreach ($srv in $srvRecords) {
      $result = nslookup -type=SRV $srv 2>&1
      $results[$srv] = ($result -match 'svr hostname')
    }
    $results | ConvertTo-Json -Compress
  register: srv_records

- name: Parse SRV record results
  set_fact:
    srv_status: "{{ srv_records.stdout | from_json }}"

- name: Fail if critical SRV records missing
  fail:
    msg: "CRITICAL: SRV record {{ item.key }} not found in DNS"
  loop: "{{ srv_status | dict2items }}"
  when: not item.value

- name: Verify DC count matches SRV records
  win_shell: |
    (nslookup -type=SRV _ldap._tcp.dc._msdcs.{{ source_domain }} | Select-String 'svr hostname').Count
  register: srv_dc_count

- name: Get actual DC count
  win_shell: |
    (Get-ADDomainController -Filter *).Count
  register: actual_dc_count
  delegate_to: "{{ source_dc }}"

- name: Warn if DC count mismatch
  debug:
    msg: "WARNING: SRV records show {{ srv_dc_count.stdout | trim }} DCs but AD has {{ actual_dc_count.stdout | trim }} DCs"
  when: srv_dc_count.stdout | trim != actual_dc_count.stdout | trim
```

---

### 3.3 Time Synchronization

**What to Check:**
- All DCs in sync with PDC emulator
- All servers in sync with DCs
- Time offset <5 seconds (critical for Kerberos)

**Playbook snippet:**

```yaml
- name: Check time source
  win_shell: |
    w32tm /query /source
  register: time_source

- name: Check time sync status
  win_shell: |
    w32tm /query /status
  register: time_status

- name: Parse time offset
  set_fact:
    time_offset: "{{ time_status.stdout | regex_search('Last Successful Sync Time.*\\nPhase Offset: ([-\\d.]+)s', '\\1') | first | default(999) | float }}"

- name: Fail if time offset >5 seconds
  fail:
    msg: "CRITICAL: Time offset {{ time_offset }}s exceeds 5-second Kerberos tolerance on {{ inventory_hostname }}"
  when: time_offset | abs > 5

- name: Check time sync with PDC
  win_shell: |
    $pdc = (Get-ADDomain).PDCEmulator
    w32tm /stripchart /computer:$pdc /samples:3 /dataonly
  register: pdc_time_check

- name: Parse PDC time offset
  set_fact:
    pdc_offset: "{{ pdc_time_check.stdout | regex_search('([-\\d.]+)s', '\\1') | last | default(999) | float }}"

- name: Warn if PDC offset >1 second
  debug:
    msg: "WARNING: Time offset from PDC: {{ pdc_offset }}s on {{ inventory_hostname }}"
  when: pdc_offset | abs > 1
```

---

## 4) Health Check Workflow Integration

### 4.1 Pre-Wave Go/No-Go Gate

**Playbook:** `playbooks/02_gate_on_health.yml`

```yaml
---
- name: Health Gate - Go/No-Go Decision
  hosts: localhost
  gather_facts: no

  tasks:
    - name: Load discovery results
      set_fact:
        discovery_results: "{{ lookup('file', artifacts_dir + '/discovery/' + wave + '_summary.json') | from_json }}"

    - name: Check domain health
      set_fact:
        domain_health_pass: "{{ discovery_results.domain.dcdiag_passed and discovery_results.domain.replication_healthy }}"

    - name: Check DNS health
      set_fact:
        dns_health_pass: "{{ discovery_results.dns.zones_loaded and discovery_results.dns.srv_records_ok }}"

    - name: Check time sync
      set_fact:
        time_sync_pass: "{{ discovery_results.hosts | selectattr('time_offset_sec', '>', 5) | list | length == 0 }}"

    - name: Check WinRM reachability
      set_fact:
        winrm_pass_rate: "{{ (discovery_results.hosts | selectattr('winrm_ok', 'equalto', true) | list | length) / (discovery_results.hosts | length) }}"

    - name: Calculate overall health score
      set_fact:
        health_score: "{{ (domain_health_pass | ternary(25,0)) + (dns_health_pass | ternary(25,0)) + (time_sync_pass | ternary(25,0)) + (winrm_pass_rate * 25) }}"

    - name: Display health report
      debug:
        msg: |
          ===========================================
          MIGRATION HEALTH CHECK - {{ wave }}
          ===========================================
          Domain Health:    {{ domain_health_pass | ternary('✓ PASS', '✗ FAIL') }}
          DNS Health:       {{ dns_health_pass | ternary('✓ PASS', '✗ FAIL') }}
          Time Sync:        {{ time_sync_pass | ternary('✓ PASS', '✗ FAIL') }}
          WinRM Reachability: {{ '%.1f' | format(winrm_pass_rate * 100) }}%
          
          Overall Health Score: {{ health_score }}/100
          ===========================================

    - name: FAIL if health score <90
      fail:
        msg: |
          CRITICAL: Health score {{ health_score }}/100 is below threshold (90).
          DO NOT PROCEED with migration until issues resolved.
          Review detailed reports in {{ artifacts_dir }}/domain/
      when: health_score | float < 90 and not force_proceed | default(false)

    - name: WARN if health score 90-95
      debug:
        msg: |
          WARNING: Health score {{ health_score }}/100 is acceptable but not optimal.
          Consider fixing warnings before proceeding.
      when: health_score | float >= 90 and health_score | float < 95

    - name: PASS if health score >=95
      debug:
        msg: |
          ✓ PASS: Health score {{ health_score }}/100 - Safe to proceed with migration.
      when: health_score | float >= 95
```

---

### 4.2 Consolidated Discovery Playbook

**Playbook:** `playbooks/00_discovery_all.yml`

```yaml
---
- name: Consolidated Discovery - All Checks
  hosts: localhost
  gather_facts: no

  tasks:
    - name: Run domain health checks
      include_tasks: 00c_discovery_domain_core.yml

    - name: Run DNS health checks
      include_tasks: 00f_validate_dns.yml

    - name: Run host health checks
      include_tasks: 00_discovery_health.yml

    - name: Run service discovery
      include_tasks: 00g_discovery_services.yml

    - name: Run DNS record discovery
      include_tasks: 00e_discovery_dns.yml

    - name: Generate consolidated report
      include_tasks: 09_render_report.yml
      vars:
        report_type: consolidated_discovery

    - name: Run health gate
      include_tasks: 02_gate_on_health.yml
```

---

## 5) Reporting

### 5.1 Service Discovery Report (HTML)

**Template:** `roles/reporting_render/templates/service_discovery_report.html.j2`

```html
<!DOCTYPE html>
<html>
<head>
    <title>Service Discovery Report - {{ wave }}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th { background: #333; color: white; padding: 10px; text-align: left; }
        td { border: 1px solid #ddd; padding: 8px; }
        tr:hover { background: #f5f5f5; }
        .critical { background: #ffcccc; }
        .warning { background: #ffffcc; }
        .good { background: #ccffcc; }
    </style>
</head>
<body>
    <h1>Service Discovery Report</h1>
    <p>Wave: <strong>{{ wave }}</strong></p>
    <p>Generated: {{ ansible_date_time.iso8601 }}</p>

    <h2>Services Using Domain Accounts</h2>
    <table>
        <tr>
            <th>Hostname</th>
            <th>Service Name</th>
            <th>Display Name</th>
            <th>Service Account</th>
            <th>Status</th>
        </tr>
        {% for host in services_data %}
        {% for service in host.services | selectattr('ServiceAccount', 'search', source_domain) %}
        <tr class="{{ 'critical' if service.Name in critical_services else '' }}">
            <td>{{ host.hostname }}</td>
            <td>{{ service.Name }}</td>
            <td>{{ service.DisplayName }}</td>
            <td>{{ service.ServiceAccount }}</td>
            <td>{{ service.Status }}</td>
        </tr>
        {% endfor %}
        {% endfor %}
    </table>

    <h2>Scheduled Tasks Using Domain Accounts</h2>
    <table>
        <tr>
            <th>Hostname</th>
            <th>Task Name</th>
            <th>Principal</th>
            <th>State</th>
        </tr>
        {% for host in tasks_data %}
        {% for task in host.tasks | selectattr('Principal', 'search', source_domain) %}
        <tr>
            <td>{{ host.hostname }}</td>
            <td>{{ task.TaskName }}</td>
            <td>{{ task.Principal }}</td>
            <td>{{ task.State }}</td>
        </tr>
        {% endfor %}
        {% endfor %}
    </table>

    <h2>SPNs to Migrate</h2>
    <table>
        <tr>
            <th>Hostname</th>
            <th>SPN</th>
            <th>Type</th>
        </tr>
        {% for host in spn_data %}
        {% for spn in host.computer_spns %}
        <tr>
            <td>{{ host.hostname }}</td>
            <td>{{ spn }}</td>
            <td>Computer Account</td>
        </tr>
        {% endfor %}
        {% endfor %}
    </table>

    <h2>Server Dependencies (Top 10)</h2>
    <table>
        <tr>
            <th>Source Server</th>
            <th>Remote Server (Dependency)</th>
            <th>Connection Count</th>
        </tr>
        {% for host in network_data %}
        {% for conn in host.remote_connections | sort(attribute='ConnectionCount', reverse=true) | slice(10) %}
        <tr>
            <td>{{ host.hostname }}</td>
            <td>{{ conn.RemoteServer }}</td>
            <td>{{ conn.ConnectionCount }}</td>
        </tr>
        {% endfor %}
        {% endfor %}
    </table>
</body>
</html>
```

---

### 5.2 Domain Health Report (HTML)

**Template:** `roles/reporting_render/templates/domain_health_report.html.j2`

```html
<!DOCTYPE html>
<html>
<head>
    <title>Domain Health Report</title>
    <style>
        /* Same CSS as above */
        .pass { color: green; font-weight: bold; }
        .fail { color: red; font-weight: bold; }
    </style>
</head>
<body>
    <h1>Domain Health Report - {{ source_domain }}</h1>
    <p>Checked: {{ ansible_date_time.iso8601 }}</p>

    <h2>Summary</h2>
    <table>
        <tr><th>Check</th><th>Status</th><th>Details</th></tr>
        <tr>
            <td>DC Connectivity</td>
            <td class="{{ 'pass' if domain_health.Connectivity.passed else 'fail' }}">
                {{ '✓ PASS' if domain_health.Connectivity.passed else '✗ FAIL' }}
            </td>
            <td>All {{ dc_count }} DCs reachable</td>
        </tr>
        <tr>
            <td>AD Replication</td>
            <td class="{{ 'pass' if replication_healthy else 'fail' }}">
                {{ '✓ PASS' if replication_healthy else '✗ FAIL' }}
            </td>
            <td>{{ replication_failures | length }} failures detected</td>
        </tr>
        <tr>
            <td>DNS Health</td>
            <td class="{{ 'pass' if dns_health.zones_loaded else 'fail' }}">
                {{ '✓ PASS' if dns_health.zones_loaded else '✗ FAIL' }}
            </td>
            <td>{{ dns_zones | length }} zones loaded</td>
        </tr>
        <tr>
            <td>Time Sync</td>
            <td class="{{ 'pass' if time_sync_ok else 'fail' }}">
                {{ '✓ PASS' if time_sync_ok else '✗ FAIL' }}
            </td>
            <td>Max offset: {{ max_time_offset }}s</td>
        </tr>
    </table>

    <h2>FSMO Role Holders</h2>
    <table>
        <tr><th>Role</th><th>Holder</th><th>Status</th></tr>
        {% for role in fsmo_roles %}
        <tr>
            <td>{{ role.split(':')[0] }}</td>
            <td>{{ role.split(':')[1] }}</td>
            <td class="pass">✓ Online</td>
        </tr>
        {% endfor %}
    </table>

    <h2>Replication Status by DC</h2>
    <table>
        <tr><th>Source DC</th><th>Destination DC</th><th>Last Success</th><th>Lag (min)</th><th>Failures</th></tr>
        {% for repl in replication_status %}
        <tr class="{{ 'warning' if repl.AgeMinutes > 15 else '' }}">
            <td>{{ repl['Source DSA'] }}</td>
            <td>{{ inventory_hostname }}</td>
            <td>{{ repl['Last Success'] }}</td>
            <td>{{ repl.AgeMinutes }}</td>
            <td>{{ repl.Failures }}</td>
        </tr>
        {% endfor %}
    </table>
</body>
</html>
```

---

## 6) Summary Checklist

**Before Each Wave:**

### Domain Health:
- [ ] All DCs pass dcdiag tests
- [ ] AD replication lag <15 minutes
- [ ] No replication failures
- [ ] FSMO role holders online
- [ ] SYSVOL replication healthy
- [ ] Trust relationships working (if using ADMT)

### DNS Health:
- [ ] All zones loaded and not paused
- [ ] Dynamic update enabled on target zones
- [ ] SRV records present for all domain services
- [ ] Zone transfer working between DNS servers
- [ ] No stale DNS records (scavenging enabled)

### Service Discovery:
- [ ] All services inventoried with service accounts documented
- [ ] Scheduled tasks with domain accounts identified
- [ ] SPNs inventoried and duplicates resolved
- [ ] IIS/SQL configurations exported
- [ ] Application dependencies mapped
- [ ] Network port listeners documented

### Time Sync:
- [ ] All DCs within 5 seconds of PDC
- [ ] All servers within 5 seconds of DCs
- [ ] NTP source configured correctly

### Host Health:
- [ ] WinRM reachability >95%
- [ ] Secure channel tests pass
- [ ] Disk space sufficient for USMT (>20 GB free)
- [ ] No pending reboots

---

**This is your GO/NO-GO gate. Do not proceed if any CRITICAL checks fail.**

---

**END OF DOCUMENT**

