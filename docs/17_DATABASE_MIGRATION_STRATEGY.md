# Database Server Migration Strategy

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Date:** October 2025

**Purpose:** Comprehensive strategy for migrating database servers (SQL Server, PostgreSQL, MySQL, Oracle) with mixed authentication (Windows/domain + native database authentication), connection string updates, and application dependency management.

**Key Challenge:** Database servers often have **dual authentication** (Windows domain accounts + database-native accounts), complex dependencies, and zero-tolerance for downtime.

---

## 1) Database Migration Overview

### 1.1 Types of Database Migrations

| Migration Type | Description | Downtime | Complexity |
|----------------|-------------|----------|------------|
| **In-Place Domain Move** | Migrate DB server to new domain, keep data in place | 15-30 min | Medium |
| **Lift-and-Shift** | Migrate DB server + data to new infrastructure | 1-4 hours | High |
| **Side-by-Side** | Build new DB server, replicate data, cutover | Minutes (replication lag) | Very High |
| **Service-Only** | Migrate SQL/Postgres service account, keep server in source domain | <5 min | Low |

**Recommendation:** Start with **in-place domain move** for most servers, reserve side-by-side for mission-critical databases.

---

## 2) SQL Server Migration

### 2.1 Authentication Model Understanding

**SQL Server supports mixed authentication:**
1. **Windows Authentication** (domain accounts)
   - Server admin: `DOMAIN\SQLAdmins`
   - Application logins: `DOMAIN\AppUser`
   - Service account: `DOMAIN\svc_sql`
2. **SQL Authentication** (database-native)
   - SA account (built-in)
   - Application logins: `app_user` (password in database)

**Challenge:** Windows Authentication breaks when domain changes; SQL Authentication continues working.

---

### 2.2 Pre-Migration Discovery

**Playbook:** `playbooks/00h_discovery_sql_server.yml`

```yaml
---
- name: SQL Server Discovery
  hosts: sql_servers
  gather_facts: yes

  tasks:
    - name: Get SQL Server instances
      win_shell: |
        Get-Service | Where-Object {$_.Name -like "MSSQL*" -and $_.Status -eq "Running"} | 
          Select-Object Name, DisplayName, 
            @{N='ServiceAccount';E={(Get-WmiObject Win32_Service -Filter "Name='$($_.Name)'").StartName}} |
          ConvertTo-Json -Compress
      register: sql_instances

    - name: Get Windows Authentication logins
      win_shell: |
        sqlcmd -S localhost -Q "SELECT name, type_desc, create_date, is_disabled FROM sys.server_principals WHERE type IN ('U', 'G') AND name LIKE '{{ source_domain }}%' FOR JSON PATH" -h -1
      register: windows_logins

    - name: Get SQL Authentication logins
      win_shell: |
        sqlcmd -S localhost -Q "SELECT name, type_desc, create_date, is_disabled FROM sys.server_principals WHERE type = 'S' AND name NOT LIKE '##%' FOR JSON PATH" -h -1
      register: sql_logins

    - name: Get databases
      win_shell: |
        sqlcmd -S localhost -Q "SELECT name, database_id, create_date, state_desc, recovery_model_desc, (SELECT SUM(size) * 8 / 1024 FROM sys.master_files WHERE database_id = d.database_id) AS size_mb FROM sys.databases d FOR JSON PATH" -h -1
      register: databases

    - name: Get SQL Agent jobs with domain accounts
      win_shell: |
        sqlcmd -S localhost -d msdb -Q "SELECT j.name AS JobName, j.enabled, l.name AS OwnerLogin FROM dbo.sysjobs j INNER JOIN sys.server_principals l ON j.owner_sid = l.sid WHERE l.type IN ('U', 'G') AND l.name LIKE '{{ source_domain }}%' FOR JSON PATH" -h -1
      register: agent_jobs

    - name: Get linked servers
      win_shell: |
        sqlcmd -S localhost -Q "SELECT name, product, provider, data_source, catalog FROM sys.servers WHERE is_linked = 1 FOR JSON PATH" -h -1
      register: linked_servers

    - name: Enumerate application connections (via DMV)
      win_shell: |
        sqlcmd -S localhost -Q "SELECT login_name, host_name, program_name, COUNT(*) AS connection_count FROM sys.dm_exec_sessions WHERE is_user_process = 1 GROUP BY login_name, host_name, program_name ORDER BY connection_count DESC FOR JSON PATH" -h -1
      register: app_connections

    - name: Save SQL Server inventory
      copy:
        content: |
          {
            "hostname": "{{ inventory_hostname }}",
            "instances": {{ sql_instances.stdout | default('[]') }},
            "windows_logins": {{ windows_logins.stdout | default('[]') }},
            "sql_logins": {{ sql_logins.stdout | default('[]') }},
            "databases": {{ databases.stdout | default('[]') }},
            "agent_jobs": {{ agent_jobs.stdout | default('[]') }},
            "linked_servers": {{ linked_servers.stdout | default('[]') }},
            "app_connections": {{ app_connections.stdout | default('[]') }}
          }
        dest: "{{ artifacts_dir }}/databases/{{ inventory_hostname }}_sql.json"
      delegate_to: localhost
```

**Output Analysis:**

```json
{
  "windows_logins": [
    {"name": "OLDDOMAIN\\SQLAdmins", "type_desc": "WINDOWS_GROUP"},
    {"name": "OLDDOMAIN\\AppUser", "type_desc": "WINDOWS_USER"}
  ],
  "sql_logins": [
    {"name": "sa", "type_desc": "SQL_LOGIN", "is_disabled": true},
    {"name": "app_user", "type_desc": "SQL_LOGIN"}
  ],
  "app_connections": [
    {"login_name": "OLDDOMAIN\\AppUser", "host_name": "APP-SERVER-01", "program_name": ".Net SqlClient", "connection_count": 45},
    {"login_name": "app_user", "host_name": "WEB-SERVER-01", "program_name": "Tomcat", "connection_count": 12}
  ]
}
```

**Key Insights:**
- `OLDDOMAIN\\AppUser` has 45 active connections → **requires login translation**
- `app_user` (SQL auth) has 12 connections → **unaffected by domain move**
- `OLDDOMAIN\\SQLAdmins` needs mapping to `NEWDOMAIN\SQLAdmins`

---

### 2.3 Migration Approaches

#### Approach A: In-Place Domain Move (Preferred)

**Steps:**

1. **Pre-Migration Backup**
```sql
-- Full backup before migration
BACKUP DATABASE [MyAppDB] TO DISK = 'D:\Backup\MyAppDB_PRE_MIGRATION.bak' WITH INIT, COMPRESSION;
GO
```

2. **Create Dual Logins (Transition Period)**
```yaml
# Before domain move
- name: Create logins in new domain (pre-migration)
  win_shell: |
    sqlcmd -S localhost -Q "CREATE LOGIN [{{ target_domain }}\SQLAdmins] FROM WINDOWS; ALTER SERVER ROLE sysadmin ADD MEMBER [{{ target_domain }}\SQLAdmins];"
  delegate_to: "{{ sql_server }}"
```

3. **Domain Move** (Standard `machine_move_usmt` playbook)
```yaml
# Executes domain disjoin → join
# SQL Server service remains stopped during reboots
```

4. **Post-Migration: Fix Orphaned Users**
```yaml
- name: Fix orphaned SQL users after domain move
  win_shell: |
    sqlcmd -S localhost -Q @"
    -- Drop old domain logins
    USE [master];
    GO
    
    -- Drop old domain logins (now invalid)
    DECLARE @login NVARCHAR(128);
    DECLARE login_cursor CURSOR FOR 
      SELECT name FROM sys.server_principals 
      WHERE type IN ('U', 'G') AND name LIKE '{{ source_domain }}%';
    OPEN login_cursor;
    FETCH NEXT FROM login_cursor INTO @login;
    WHILE @@FETCH_STATUS = 0
    BEGIN
      EXEC('DROP LOGIN [' + @login + ']');
      FETCH NEXT FROM login_cursor INTO @login;
    END;
    CLOSE login_cursor;
    DEALLOCATE login_cursor;
    
    -- Remap database users to new domain logins
    EXEC sp_MSforeachdb '
    USE [?];
    IF DB_ID(''?'') > 4  -- Skip system databases
    BEGIN
      DECLARE @user NVARCHAR(128);
      DECLARE @newlogin NVARCHAR(128);
      DECLARE user_cursor CURSOR FOR 
        SELECT name FROM sys.database_principals 
        WHERE type IN (''U'', ''G'') AND name LIKE ''{{ source_domain }}%'';
      OPEN user_cursor;
      FETCH NEXT FROM user_cursor INTO @user;
      WHILE @@FETCH_STATUS = 0
      BEGIN
        SET @newlogin = REPLACE(@user, ''{{ source_domain }}'', ''{{ target_domain }}'');
        EXEC sp_change_users_login ''Auto_Fix'', @user, NULL, NULL, @newlogin;
        FETCH NEXT FROM user_cursor INTO @user;
      END;
      CLOSE user_cursor;
      DEALLOCATE user_cursor;
    END';
    "@
```

5. **Update SQL Agent Job Owners**
```sql
USE msdb;
GO

-- Update job owners to new domain accounts
DECLARE @job_id UNIQUEIDENTIFIER;
DECLARE @newowner NVARCHAR(128);
DECLARE job_cursor CURSOR FOR 
  SELECT j.job_id, REPLACE(l.name, '{{ source_domain }}', '{{ target_domain }}') AS newowner
  FROM dbo.sysjobs j
  INNER JOIN sys.server_principals l ON j.owner_sid = l.sid
  WHERE l.name LIKE '{{ source_domain }}%';

OPEN job_cursor;
FETCH NEXT FROM job_cursor INTO @job_id, @newowner;
WHILE @@FETCH_STATUS = 0
BEGIN
  EXEC sp_update_job @job_id = @job_id, @owner_login_name = @newowner;
  FETCH NEXT FROM job_cursor INTO @job_id, @newowner;
END;
CLOSE job_cursor;
DEALLOCATE job_cursor;
```

6. **Validate Connectivity**
```yaml
- name: Test SQL connections with new domain account
  win_shell: |
    sqlcmd -S localhost -E -Q "SELECT SUSER_NAME();"
  register: sql_auth_test
  failed_when: not (sql_auth_test.stdout is search(target_domain))
```

**Downtime:** 20-30 minutes (domain move + SQL restart + login fixes)

---

#### Approach B: Side-by-Side with Replication (Zero-Downtime)

**Steps:**

1. **Build New SQL Server in Target Domain**
```yaml
- name: Deploy new SQL Server in target domain
  # Standard Windows VM deployment
  # Join to target domain during build
```

2. **Configure Replication (or Always On Availability Groups)**
```sql
-- On source server (publisher)
USE master;
GO
EXEC sp_replicationdboption @dbname = 'MyAppDB', @optname = 'publish', @value = 'true';
GO

-- Setup transactional replication to target
EXEC sp_addpublication @publication = 'MyAppDB_Pub', @description = 'Migration Replication', 
  @sync_method = 'concurrent', @repl_freq = 'continuous';
GO

-- Add subscriber (target server)
EXEC sp_addsubscription @publication = 'MyAppDB_Pub', @subscriber = 'NEWSQL.newdomain.com', 
  @destination_db = 'MyAppDB', @subscription_type = 'Push';
GO
```

3. **Monitor Replication Lag**
```yaml
- name: Check replication lag
  win_shell: |
    sqlcmd -S localhost -d MyAppDB -Q "SELECT DATEDIFF(SECOND, last_commit_time, GETDATE()) AS lag_seconds FROM sys.dm_hadr_database_replica_states WHERE is_local = 0;" -h -1
  register: replication_lag
  until: replication_lag.stdout | int < 5
  retries: 60
  delay: 10
```

4. **Cutover** (application connection string change)
```yaml
# Update application config files, DNS CNAME, or load balancer
# See §2.5 for connection string migration
```

5. **Decommission Old Server** (after validation period)

**Downtime:** <5 minutes (DNS/connection string propagation)

---

### 2.4 SQL Server Service Account Migration

**Challenge:** SQL Server service runs as `OLDDOMAIN\svc_sql` → must change to `NEWDOMAIN\svc_sql`

**Steps:**

1. **Create New Service Account in Target Domain**
```powershell
# On target DC
New-ADUser -Name "svc_sql" -SamAccountName "svc_sql" -UserPrincipalName "svc_sql@newdomain.com" `
  -AccountPassword (ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force) -Enabled $true

# Grant "Log on as a service" right
# (Done via GPO or local security policy)
```

2. **Grant SQL Server Permissions to New Account**
```powershell
# File system permissions
icacls "C:\Program Files\Microsoft SQL Server" /grant "NEWDOMAIN\svc_sql:(OI)(CI)F" /T
icacls "D:\SQLData" /grant "NEWDOMAIN\svc_sql:(OI)(CI)F" /T
icacls "E:\SQLLog" /grant "NEWDOMAIN\svc_sql:(OI)(CI)F" /T

# Registry permissions (automated via Ansible)
```

3. **Change SQL Server Service Account**
```yaml
- name: Update SQL Server service account
  win_service:
    name: MSSQLSERVER
    username: "{{ target_domain }}\\svc_sql"
    password: "{{ vault_sql_service_password }}"
    state: restarted
  register: sql_service_change

- name: Update SQL Server Agent service account
  win_service:
    name: SQLSERVERAGENT
    username: "{{ target_domain }}\\svc_sql"
    password: "{{ vault_sql_service_password }}"
    state: restarted
```

4. **Re-register SPNs**
```powershell
# Remove old SPNs
setspn -D MSSQLSvc/SQL01.olddomain.com:1433 OLDDOMAIN\svc_sql
setspn -D MSSQLSvc/SQL01:1433 OLDDOMAIN\svc_sql

# Register new SPNs
setspn -S MSSQLSvc/SQL01.newdomain.com:1433 NEWDOMAIN\svc_sql
setspn -S MSSQLSvc/SQL01:1433 NEWDOMAIN\svc_sql
```

5. **Validate**
```yaml
- name: Test SQL Server Kerberos authentication
  win_shell: |
    sqlcmd -S SQL01.newdomain.com -E -Q "SELECT auth_scheme FROM sys.dm_exec_connections WHERE session_id = @@SPID;"
  register: auth_test
  failed_when: not (auth_test.stdout is search('KERBEROS'))
```

---

### 2.5 Application Connection String Migration

**Challenge:** Applications have hardcoded connection strings with old domain references.

#### **Discovery:**

```yaml
- name: Scan for SQL connection strings
  win_find:
    paths:
      - 'C:\inetpub\wwwroot'
      - 'C:\Program Files\MyApp'
    patterns:
      - '*.config'
      - 'appsettings.json'
      - 'web.config'
    recurse: yes
  register: config_files

- name: Search for old domain in connection strings
  win_shell: |
    Select-String -Path "{{ item.path }}" -Pattern "{{ source_domain }}" -CaseSensitive:$false
  loop: "{{ config_files.files }}"
  register: old_domain_refs
```

#### **Update Connection Strings:**

**Option A: Automated (if config format is known)**

```yaml
- name: Update connection strings in web.config
  win_shell: |
    $config = "{{ item.path }}"
    $xml = [xml](Get-Content $config)
    $connStrings = $xml.configuration.connectionStrings.add
    foreach ($conn in $connStrings) {
      $conn.connectionString = $conn.connectionString -replace "{{ source_domain }}", "{{ target_domain }}"
    }
    $xml.Save($config)
  loop: "{{ config_files.files }}"
```

**Option B: Manual (complex formats)**

```yaml
- name: Generate connection string update report
  copy:
    content: |
      # Connection String Update Required
      
      {% for file in old_domain_refs.results %}
      File: {{ file.item.path }}
      Line: {{ file.stdout }}
      
      Action: Update OLDDOMAIN references to NEWDOMAIN
      {% endfor %}
    dest: "{{ artifacts_dir }}/conn_string_updates_{{ inventory_hostname }}.md"
  delegate_to: localhost
```

#### **DNS Alias Approach (Recommended)**

**Instead of updating connection strings, use DNS CNAME:**

```yaml
# Create DNS CNAME for SQL server
- name: Create SQL DNS alias
  win_shell: |
    Add-DnsServerResourceRecordCName -ZoneName "newdomain.com" -Name "sql" -HostNameAlias "SQL01.newdomain.com"
  delegate_to: "{{ target_dns_server }}"
```

**Application connection string:**
```
Before: Server=SQL01.olddomain.com;Database=MyAppDB;Integrated Security=SSPI;
After:  Server=sql.newdomain.com;Database=MyAppDB;Integrated Security=SSPI;
```

**Benefit:** No application code changes, just DNS update.

---

## 3) PostgreSQL Migration

### 3.1 Authentication Model

**PostgreSQL supports:**
1. **Host-based (pg_hba.conf)**
   - `host all all 10.0.0.0/8 trust` (IP-based, no domain dependency)
   - `host all all 0.0.0.0/0 md5` (password-based)
2. **LDAP/Kerberos** (domain-integrated)
   - `host all all 0.0.0.0/0 gss` (Kerberos)
3. **Certificate-based** (SSL client certs)

**Challenge:** If using Kerberos/SSSD, domain move breaks authentication.

---

### 3.2 Pre-Migration Discovery

```yaml
- name: PostgreSQL Discovery
  hosts: postgres_servers
  become: yes

  tasks:
    - name: Get PostgreSQL version
      command: psql --version
      register: pg_version

    - name: Get database list
      postgresql_query:
        db: postgres
        login_host: localhost
        login_user: postgres
        query: "SELECT datname, pg_database_size(datname) AS size_bytes FROM pg_database WHERE datistemplate = false;"
      register: databases

    - name: Get roles
      postgresql_query:
        db: postgres
        query: "SELECT rolname, rolsuper, rolinherit, rolcreaterole, rolcreatedb FROM pg_roles;"
      register: roles

    - name: Check pg_hba.conf for domain references
      slurp:
        src: /var/lib/pgsql/14/data/pg_hba.conf
      register: pg_hba

    - name: Parse pg_hba for LDAP/Kerberos
      set_fact:
        uses_domain_auth: "{{ (pg_hba.content | b64decode) is search('gss|ldap') }}"

    - name: Get active connections
      postgresql_query:
        db: postgres
        query: "SELECT datname, usename, client_addr, application_name, COUNT(*) FROM pg_stat_activity WHERE state = 'active' GROUP BY datname, usename, client_addr, application_name;"
      register: connections

    - name: Save inventory
      copy:
        content: |
          {
            "hostname": "{{ inventory_hostname }}",
            "version": "{{ pg_version.stdout }}",
            "databases": {{ databases.query_result | to_json }},
            "roles": {{ roles.query_result | to_json }},
            "uses_domain_auth": {{ uses_domain_auth }},
            "connections": {{ connections.query_result | to_json }}
          }
        dest: "{{ artifacts_dir }}/databases/{{ inventory_hostname }}_postgres.json"
      delegate_to: localhost
```

---

### 3.3 Migration Approach

**For IP/password-based auth:** No changes needed (domain-agnostic)

**For Kerberos/LDAP auth:**

1. **Update `/etc/sssd/sssd.conf` to target domain** (done by `linux_migrate` role)

2. **Update Kerberos keytab**
```bash
# On PostgreSQL server after domain join
kinit admin@NEWDOMAIN.COM
kvno postgres/postgres-01.newdomain.com
ktutil
  addent -password -p postgres/postgres-01.newdomain.com@NEWDOMAIN.COM -k 1 -e aes256-cts-hmac-sha1-96
  wkt /etc/postgresql/14/main/postgres.keytab
  quit
chown postgres:postgres /etc/postgresql/14/main/postgres.keytab
chmod 600 /etc/postgresql/14/main/postgres.keytab
```

3. **Update `postgresql.conf`**
```ini
krb_server_keyfile = '/etc/postgresql/14/main/postgres.keytab'
krb_realm = 'NEWDOMAIN.COM'
```

4. **Update `pg_hba.conf`**
```
# Old
host all all 0.0.0.0/0 gss include_realm=0 krb_realm=OLDDOMAIN.COM

# New
host all all 0.0.0.0/0 gss include_realm=0 krb_realm=NEWDOMAIN.COM
```

5. **Restart PostgreSQL**
```bash
systemctl restart postgresql-14
```

**Downtime:** 5-10 minutes (PostgreSQL restart)

---

## 4) MySQL/MariaDB Migration

### 4.1 Authentication

**MySQL uses native authentication by default:**
- `user@host` with password hash
- **No domain dependency** in most deployments

**Exception:** MySQL Enterprise with LDAP plugin

**Migration:** Typically no changes needed unless using LDAP plugin.

---

## 5) Oracle Database Migration

### 5.1 Authentication

**Oracle supports:**
1. **Database authentication** (username/password)
2. **OS authentication** (SQLNET.AUTHENTICATION_SERVICES = NTS for Windows)
3. **Kerberos** (rare)

**Challenge:** OS authentication (`SQLNET.AUTHENTICATION_SERVICES = NTS`) relies on domain.

---

### 5.2 Migration Approach

**If using OS authentication:**

1. **Update `sqlnet.ora`**
```
# Old
SQLNET.AUTHENTICATION_SERVICES=(NTS)
NAMES.DIRECTORY_PATH=(TNSNAMES, HOSTNAME)

# Add users in new domain
```

2. **Create Oracle users for new domain**
```sql
-- On Oracle DB
CREATE USER "NEWDOMAIN\oracle_admin" IDENTIFIED EXTERNALLY;
GRANT DBA TO "NEWDOMAIN\oracle_admin";
```

3. **Update application to use new domain account**

**Downtime:** None (dual authentication during transition)

---

## 6) Database Migration Checklist

### Pre-Migration (T-7 days)
- [ ] Run database discovery playbooks
- [ ] Document all Windows Authentication logins
- [ ] Document all SQL Agent jobs with domain owners
- [ ] Identify applications and their connection strings
- [ ] Create DNS aliases for database servers
- [ ] Test connectivity from apps to DNS alias
- [ ] Create service accounts in target domain
- [ ] Backup all databases (full + transaction log)

### During Migration (T=0)
- [ ] Create dual logins (old + new domain)
- [ ] Execute domain move (standard `machine_move_usmt`)
- [ ] Fix orphaned database users (sp_change_users_login)
- [ ] Update SQL Agent job owners
- [ ] Update service accounts
- [ ] Re-register SPNs
- [ ] Test Windows Authentication with new domain account
- [ ] Test SQL Authentication (should be unaffected)
- [ ] Validate application connectivity

### Post-Migration (T+1 day)
- [ ] Remove old domain logins
- [ ] Update connection strings (or verify DNS alias working)
- [ ] Monitor error logs for authentication failures
- [ ] Verify linked servers still working
- [ ] Verify SQL Agent jobs running successfully
- [ ] Full backup post-migration

---

## 7) Connection String Patterns

### SQL Server

**Windows Authentication:**
```
Before: Server=SQL01.olddomain.com;Database=MyAppDB;Integrated Security=SSPI;
After:  Server=sql.newdomain.com;Database=MyAppDB;Integrated Security=SSPI;
```

**SQL Authentication (no change needed):**
```
Server=SQL01.olddomain.com;Database=MyAppDB;User Id=app_user;Password=SecurePass123;
```

### PostgreSQL

**Host-based (no change needed):**
```
host=postgres-01 port=5432 dbname=myapp user=app_user password=pass
```

**Kerberos:**
```
Before: host=postgres-01.olddomain.com port=5432 dbname=myapp gssencmode=require
After:  host=postgres-01.newdomain.com port=5432 dbname=myapp gssencmode=require
```

### MySQL (typically no change)

```
server=mysql-01;database=myapp;uid=app_user;pwd=pass;
```

---

## 8) Summary

**Key Takeaways:**

✅ **SQL Authentication is your friend** – Unaffected by domain moves  
✅ **DNS aliases are critical** – Avoid hardcoded server names  
✅ **Dual logins during transition** – Create new domain logins before domain move  
✅ **Orphaned users are fixable** – Use `sp_change_users_login` (SQL) or keytab updates (Postgres)  
✅ **Service accounts need SPNs** – Re-register after domain move  
✅ **Connection strings are everywhere** – Scan proactively, use DNS aliases  

**Recommended Strategy:**
1. **In-place domain move** for 80% of database servers
2. **Side-by-side replication** for mission-critical (zero-downtime)
3. **DNS aliases** to decouple apps from server FQDNs
4. **Dual authentication** (Windows + SQL) during transition period

**Downtime Estimates:**
- SQL Server (in-place): 20-30 minutes
- PostgreSQL (in-place): 5-10 minutes
- SQL Server (side-by-side): <5 minutes
- MySQL: 0 minutes (typically no domain dependency)

---

**END OF DOCUMENT**

