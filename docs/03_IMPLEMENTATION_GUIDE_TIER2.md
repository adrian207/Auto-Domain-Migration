# Implementation Guide – Tier 2 (Medium/Production)

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Date:** October 2025

**Target:** 500-3,000 users, production migrations with monitoring and rollback capability

**Timeline:** 10-14 weeks  
**Team:** 4-5 FTE  
**Budget:** $350k-440k

---

## Week 1-3: Infrastructure Deployment

### Day 1-3: Network & Prerequisites

**1. Network Planning**
```yaml
# Network segments (example)
Control Plane VLAN: 10.100.10.0/24
  - AWX Primary:    10.100.10.10
  - AWX Secondary:  10.100.10.11
  - Vault:          10.100.10.20
  - Postgres-01:    10.100.10.30
  - Postgres-02:    10.100.10.31
  - Prometheus:     10.100.10.40
  - Grafana:        10.100.10.41

State Store VLAN: 10.100.20.0/24
  - StateStore-East: 10.100.20.10
  - StateStore-West: 10.100.20.11
  - StateStore-Central: 10.100.20.12
```

**2. Firewall Rules**
```bash
# From AWX runners to targets
TCP/5986 (WinRM HTTPS) - to all Windows hosts
TCP/22 (SSH) - to all Linux hosts
TCP/389,636 (LDAP/LDAPS) - to DCs
TCP/88 (Kerberos) - to DCs
TCP/445 (SMB) - to state stores

# From runners to control plane
TCP/8200 (Vault API) - AWX to Vault
TCP/5432 (PostgreSQL) - AWX to Postgres
TCP/9090 (Prometheus) - Grafana to Prometheus

# From operators to control plane
TCP/443 (HTTPS) - Operators to AWX/Grafana/Nginx
TCP/8200 (Vault UI) - Operators to Vault (optional)
```

**3. DNS Records**
```
awx.migration.example.com       A    10.100.10.10
awx-ha.migration.example.com    A    10.100.10.10, 10.100.10.11
vault.migration.example.com     A    10.100.10.20
postgres.migration.example.com  A    10.100.10.30
postgres-ro.migration.example.com A  10.100.10.31
reports.migration.example.com   A    10.100.10.10
grafana.migration.example.com   A    10.100.10.41
```

---

### Day 4-7: Server Provisioning

**VM Specifications:**

| Server | vCPU | RAM | Disk | OS |
|--------|------|-----|------|----|
| AWX-01 | 8 | 32 GB | 500 GB | RHEL 8/Ubuntu 22.04 |
| AWX-02 | 8 | 32 GB | 500 GB | RHEL 8/Ubuntu 22.04 |
| Vault-01 | 4 | 8 GB | 100 GB | Ubuntu 22.04 |
| Postgres-01 | 8 | 32 GB | 1 TB SSD | Ubuntu 22.04 |
| Postgres-02 | 8 | 32 GB | 1 TB SSD | Ubuntu 22.04 |
| Prometheus-01 | 4 | 16 GB | 500 GB | Ubuntu 22.04 |
| Grafana-01 | 4 | 16 GB | 200 GB | Ubuntu 22.04 |

**Base OS Configuration (all servers):**
```bash
# Update packages
sudo apt update && sudo apt upgrade -y  # Ubuntu
sudo dnf update -y                       # RHEL

# Install common tools
sudo apt install -y vim curl git python3-pip chrony  # Ubuntu
sudo dnf install -y vim curl git python3-pip chrony  # RHEL

# Configure time sync (critical for Kerberos)
sudo systemctl enable --now chronyd
chronyc tracking  # Verify offset <0.1s

# Configure firewalld
sudo systemctl enable --now firewalld

# SELinux permissive (for testing; enforce after validation)
sudo setenforce 0
sudo sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config

# Create migration user
sudo useradd -m -s /bin/bash -G wheel migration  # RHEL
sudo useradd -m -s /bin/bash -G sudo migration   # Ubuntu
```

---

### Day 8-10: AWX Deployment

**Option A: Docker Compose (Simpler)**

```bash
# On AWX-01
sudo dnf install -y docker docker-compose  # RHEL
sudo apt install -y docker.io docker-compose  # Ubuntu

sudo systemctl enable --now docker

# Clone AWX
git clone https://github.com/ansible/awx.git
cd awx/tools/docker-compose

# Edit inventory
cat > inventory <<EOF
localhost ansible_connection=local ansible_python_interpreter="/usr/bin/env python3"

[all:vars]
postgres_data_dir=/var/lib/pgdocker
host_port=80
host_port_ssl=443
docker_compose_dir=/var/lib/awx
pg_password=CHANGE_ME_STRONG_PASSWORD
broadcast_websocket_secret=CHANGE_ME_RANDOM_STRING
secret_key=CHANGE_ME_RANDOM_STRING
admin_password=CHANGE_ME_ADMIN_PASSWORD
EOF

# Build and launch
ansible-playbook -i inventory install.yml

# Verify
curl http://localhost/api/v2/ping/
```

**Option B: RPM/Deb Package (Production-Grade)**

```bash
# Add AWX repo
sudo dnf config-manager --add-repo https://rpm.releases.ansible.com/ansible-awx/

# Install AWX
sudo dnf install -y ansible-awx

# Configure external PostgreSQL (see Postgres section below)
sudo vim /etc/tower/conf.d/postgres.py
# DATABASES = {
#     'default': {
#         'ENGINE': 'django.db.backends.postgresql',
#         'NAME': 'awx',
#         'USER': 'awx',
#         'PASSWORD': 'FROM_VAULT',
#         'HOST': 'postgres.migration.example.com',
#         'PORT': 5432,
#     }
# }

# Initialize database
sudo awx-manage migrate

# Create admin user
sudo awx-manage createsuperuser

# Start services
sudo systemctl enable --now awx-web awx-task
```

**HA Configuration (Active/Standby):**
```bash
# Install HAProxy on both nodes
sudo apt install -y haproxy keepalived

# /etc/haproxy/haproxy.cfg
cat > /etc/haproxy/haproxy.cfg <<EOF
global
    log /dev/log local0
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s

defaults
    mode http
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

frontend awx_front
    bind *:443 ssl crt /etc/ssl/certs/awx.pem
    default_backend awx_back

backend awx_back
    balance roundrobin
    option httpchk GET /api/v2/ping/
    server awx01 10.100.10.10:80 check
    server awx02 10.100.10.11:80 check backup
EOF

sudo systemctl enable --now haproxy
```

---

### Day 11-13: HashiCorp Vault Deployment

```bash
# On Vault-01
wget https://releases.hashicorp.com/vault/1.15.0/vault_1.15.0_linux_amd64.zip
unzip vault_1.15.0_linux_amd64.zip
sudo mv vault /usr/local/bin/

# Create Vault user
sudo useradd -r -d /var/lib/vault -s /bin/false vault

# Create directories
sudo mkdir -p /etc/vault.d /var/lib/vault /var/log/vault
sudo chown -R vault:vault /etc/vault.d /var/lib/vault /var/log/vault

# Configure Vault
sudo tee /etc/vault.d/vault.hcl <<EOF
ui = true
api_addr = "https://vault.migration.example.com:8200"
cluster_addr = "https://10.100.10.20:8201"

storage "file" {
  path = "/var/lib/vault/data"
}

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_cert_file = "/etc/vault.d/tls/vault.crt"
  tls_key_file = "/etc/vault.d/tls/vault.key"
}
EOF

# Create TLS cert (self-signed for now)
sudo mkdir /etc/vault.d/tls
cd /etc/vault.d/tls
sudo openssl req -new -x509 -days 365 -nodes -text \
  -out vault.crt -keyout vault.key \
  -subj "/CN=vault.migration.example.com"
sudo chown vault:vault vault.*

# Systemd service
sudo tee /etc/systemd/system/vault.service <<EOF
[Unit]
Description=HashiCorp Vault
After=network.target

[Service]
User=vault
Group=vault
ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/vault.hcl
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now vault

# Initialize Vault (SAVE OUTPUT SECURELY!)
export VAULT_ADDR='https://vault.migration.example.com:8200'
export VAULT_SKIP_VERIFY=1  # Only for self-signed cert
vault operator init -key-shares=5 -key-threshold=3

# Unseal (use 3 of 5 keys from init output)
vault operator unseal <key1>
vault operator unseal <key2>
vault operator unseal <key3>

# Login with root token
vault login <root_token>
```

**Configure Vault Engines:**

```bash
# Enable AD secrets engine
vault secrets enable ad
vault write ad/config \
  binddn="CN=VaultSvc,OU=ServiceAccounts,DC=target,DC=com" \
  bindpass="VAULT_SERVICE_PASSWORD" \
  url="ldaps://target-dc.target.com" \
  userdn="OU=ServiceAccounts,DC=target,DC=com"

# Create role for migration account
vault write ad/roles/migration-windows \
  service_account_name="MigrationSvc@target.com" \
  ttl=6h

# Enable database secrets engine
vault secrets enable database
vault write database/config/mig-postgres \
  plugin_name=postgresql-database-plugin \
  allowed_roles="mig-writer,mig-reader" \
  connection_url="postgresql://{{username}}:{{password}}@postgres.migration.example.com:5432/mig?sslmode=require" \
  username="vault" \
  password="POSTGRES_VAULT_PASSWORD"

vault write database/roles/mig-writer \
  db_name=mig-postgres \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
                       GRANT INSERT, UPDATE, DELETE, SELECT ON ALL TABLES IN SCHEMA mig TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"

vault write database/roles/mig-reader \
  db_name=mig-postgres \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
                       GRANT SELECT ON ALL TABLES IN SCHEMA mig TO \"{{name}}\";" \
  default_ttl="24h" \
  max_ttl="72h"

# Enable SSH CA
vault secrets enable -path=ssh-client-signer ssh
vault write ssh-client-signer/config/ca generate_signing_key=true

# Create role for Linux hosts
vault write ssh-client-signer/roles/linux-migration \
  allow_user_certificates=true \
  allowed_users="migration,root" \
  default_extensions_template=true \
  key_type=ca \
  default_user=migration \
  ttl=2h

# Enable KV for static secrets
vault secrets enable -version=2 -path=secret kv

# Create policies
vault policy write awx-discovery - <<EOF
path "ad/creds/migration-windows" {
  capabilities = ["read"]
}
path "secret/data/migration/*" {
  capabilities = ["read"]
}
EOF

vault policy write awx-migration - <<EOF
path "ad/creds/*" {
  capabilities = ["read"]
}
path "database/creds/mig-writer" {
  capabilities = ["read"]
}
path "ssh-client-signer/sign/linux-migration" {
  capabilities = ["create", "update"]
}
path "secret/data/migration/*" {
  capabilities = ["read", "create", "update"]
}
EOF

# Create AppRole for AWX
vault auth enable approle
vault write auth/approle/role/awx \
  policies=awx-migration \
  token_ttl=1h \
  token_max_ttl=4h

vault read auth/approle/role/awx/role-id
vault write -f auth/approle/role/awx/secret-id
# Save role-id and secret-id for AWX configuration
```

---

### Day 14-17: PostgreSQL HA Deployment

**On Postgres-01 (Primary):**

```bash
sudo apt install -y postgresql-14 postgresql-contrib

# Configure PostgreSQL
sudo tee -a /etc/postgresql/14/main/postgresql.conf <<EOF
listen_addresses = '*'
wal_level = replica
max_wal_senders = 3
wal_keep_size = 1GB
hot_standby = on
EOF

# Configure authentication
sudo tee -a /etc/postgresql/14/main/pg_hba.conf <<EOF
host    replication     replicator      10.100.10.31/32    md5
host    awx             awx             10.100.10.0/24     md5
host    mig             vault           10.100.10.20/32    md5
host    mig             all             10.100.10.0/24     md5
EOF

sudo systemctl restart postgresql

# Create users and databases
sudo -u postgres psql <<EOF
-- AWX database
CREATE DATABASE awx;
CREATE USER awx WITH PASSWORD 'AWX_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE awx TO awx;

-- Migration database
CREATE DATABASE mig;
CREATE USER vault WITH PASSWORD 'VAULT_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE mig TO vault;

-- Replication user
CREATE USER replicator WITH REPLICATION LOGIN PASSWORD 'REPLICATION_PASSWORD';
EOF

# Create migration schema
sudo -u postgres psql -d mig <<EOF
CREATE SCHEMA mig;

CREATE TABLE mig.run (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  started_at timestamptz NOT NULL DEFAULT now(),
  finished_at timestamptz,
  wave text,
  kind text,  -- discovery, provision, machine_move, etc.
  status text,  -- running, success, failed, cancelled
  total_hosts int DEFAULT 0,
  successful_hosts int DEFAULT 0,
  failed_hosts int DEFAULT 0
);

CREATE TABLE mig.host (
  id bigserial PRIMARY KEY,
  name text UNIQUE NOT NULL,
  os_family text,
  site text,
  is_linux boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE mig.check_result (
  id bigserial PRIMARY KEY,
  run_id uuid REFERENCES mig.run(id) ON DELETE CASCADE,
  host_id bigint REFERENCES mig.host(id) ON DELETE CASCADE,
  check_name text,
  pass boolean,
  details jsonb,
  recorded_at timestamptz DEFAULT now()
);

CREATE TABLE mig.migration_event (
  id bigserial PRIMARY KEY,
  run_id uuid REFERENCES mig.run(id) ON DELETE CASCADE,
  host_id bigint REFERENCES mig.host(id) ON DELETE CASCADE,
  phase text,  -- captured, disjoined, joined, restored, rolled_back
  status text,  -- success, failed, in_progress
  details jsonb,
  timestamp timestamptz DEFAULT now()
);

CREATE INDEX idx_check_result_run ON mig.check_result(run_id);
CREATE INDEX idx_check_result_host ON mig.check_result(host_id);
CREATE INDEX idx_migration_event_run ON mig.migration_event(run_id);
CREATE INDEX idx_migration_event_host ON mig.migration_event(host_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA mig TO vault;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA mig TO vault;
EOF
```

**On Postgres-02 (Replica):**

```bash
sudo apt install -y postgresql-14

# Stop PostgreSQL
sudo systemctl stop postgresql

# Remove default data directory
sudo rm -rf /var/lib/postgresql/14/main

# Create base backup from primary
sudo -u postgres pg_basebackup -h 10.100.10.30 -D /var/lib/postgresql/14/main -U replicator -P -v -R -X stream

# Start replica
sudo systemctl start postgresql

# Verify replication
sudo -u postgres psql -c "SELECT * FROM pg_stat_replication;"
```

**Setup Read-Only DNS for Replica:**
```bash
# Add DNS A record
# postgres-ro.migration.example.com -> 10.100.10.31
```

---

### Day 18-21: State Store Setup

**Deploy DFS-R for Regional State Stores (Windows):**

```powershell
# On StateStore-East (10.100.20.10)
# Install DFS role
Install-WindowsFeature -Name FS-DFS-Replication -IncludeManagementTools

# Create state store share
New-Item -Path C:\StateStore -ItemType Directory
New-SmbShare -Name "StateStore$" -Path C:\StateStore -FullAccess "DOMAIN\MigrationSvc","DOMAIN\Domain Admins"

# Create DFS namespace
New-DfsnRoot -TargetPath "\\statestore-east.example.com\StateStore$" -Path "\\example.com\StateStore" -Type DomainV2

# Add other regional targets
New-DfsnFolderTarget -Path "\\example.com\StateStore" -TargetPath "\\statestore-west.example.com\StateStore$"
New-DfsnFolderTarget -Path "\\example.com\StateStore" -TargetPath "\\statestore-central.example.com\StateStore$"

# Configure replication group
New-DfsReplicationGroup -GroupName "StateStoreReplication"
Add-DfsrMember -GroupName "StateStoreReplication" -ComputerName "statestore-east","statestore-west","statestore-central"
Add-DfsrConnection -GroupName "StateStoreReplication" -SourceComputerName "statestore-east" -DestinationComputerName "statestore-west"
Add-DfsrConnection -GroupName "StateStoreReplication" -SourceComputerName "statestore-west" -DestinationComputerName "statestore-central"
Add-DfsrConnection -GroupName "StateStoreReplication" -SourceComputerName "statestore-central" -DestinationComputerName "statestore-east"

# Set replication folder
New-DfsReplicatedFolder -GroupName "StateStoreReplication" -FolderName "StateStore"
Set-DfsrMembership -GroupName "StateStoreReplication" -FolderName "StateStore" -ComputerName "statestore-east" -ContentPath "C:\StateStore" -PrimaryMember $true
Set-DfsrMembership -GroupName "StateStoreReplication" -FolderName "StateStore" -ComputerName "statestore-west" -ContentPath "C:\StateStore"
Set-DfsrMembership -GroupName "StateStoreReplication" -FolderName "StateStore" -ComputerName "statestore-central" -ContentPath "C:\StateStore"
```

**Alternative: MinIO Single-Node (Linux):**

```bash
# On StateStore-01
wget https://dl.min.io/server/minio/release/linux-amd64/minio
chmod +x minio
sudo mv minio /usr/local/bin/

# Create minio user
sudo useradd -r -s /bin/false minio

# Create data directory
sudo mkdir -p /data/minio
sudo chown minio:minio /data/minio

# Systemd service
sudo tee /etc/systemd/system/minio.service <<EOF
[Unit]
Description=MinIO
After=network.target

[Service]
User=minio
Group=minio
Environment="MINIO_ROOT_USER=admin"
Environment="MINIO_ROOT_PASSWORD=CHANGE_ME_STRONG_PASSWORD"
ExecStart=/usr/local/bin/minio server /data/minio --console-address ":9001"
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now minio

# Create bucket for state stores
mc alias set local http://localhost:9000 admin CHANGE_ME_STRONG_PASSWORD
mc mb local/usmt-states
mc policy set download local/usmt-states
```

---

### Day 22-24: Observability Stack

**Prometheus:**

```bash
# On Prometheus-01
wget https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz
tar xvf prometheus-2.45.0.linux-amd64.tar.gz
sudo mv prometheus-2.45.0.linux-amd64 /opt/prometheus
sudo useradd -r -s /bin/false prometheus

# Create config
sudo mkdir /etc/prometheus
sudo tee /etc/prometheus/prometheus.yml <<EOF
global:
  scrape_interval: 30s
  evaluation_interval: 30s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets:
        - 'awx-01.migration.example.com:9100'
        - 'awx-02.migration.example.com:9100'
        - 'postgres-01.migration.example.com:9100'
        - 'postgres-02.migration.example.com:9100'
        - 'vault-01.migration.example.com:9100'

  - job_name: 'windows_exporter'
    static_configs:
      - targets:
        - 'statestore-east.example.com:9182'
        - 'statestore-west.example.com:9182'

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-01.migration.example.com:9187']

  - job_name: 'vault'
    metrics_path: '/v1/sys/metrics'
    params:
      format: ['prometheus']
    bearer_token: 'VAULT_PROMETHEUS_TOKEN'
    static_configs:
      - targets: ['vault.migration.example.com:8200']

  - job_name: 'blackbox_winrm'
    metrics_path: /probe
    params:
      module: [tcp_connect]
    static_configs:
      - targets:
        - 'dc01.example.com:5986'
        - 'dc02.example.com:5986'
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: localhost:9115

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']

rule_files:
  - '/etc/prometheus/rules/*.yml'
EOF

# Create systemd service
sudo tee /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus
After=network.target

[Service]
User=prometheus
ExecStart=/opt/prometheus/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/var/lib/prometheus
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now prometheus
```

**Grafana:**

```bash
# On Grafana-01
sudo apt install -y grafana

# Configure Grafana
sudo tee /etc/grafana/grafana.ini <<EOF
[server]
http_addr = 0.0.0.0
http_port = 3000
domain = grafana.migration.example.com
root_url = https://grafana.migration.example.com/

[security]
admin_user = admin
admin_password = CHANGE_ME_ADMIN_PASSWORD

[database]
type = postgres
host = postgres-ro.migration.example.com:5432
name = grafana
user = grafana
password = GRAFANA_DB_PASSWORD
EOF

# Create Grafana database
sudo -u postgres psql -h postgres.migration.example.com <<EOF
CREATE DATABASE grafana;
CREATE USER grafana WITH PASSWORD 'GRAFANA_DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE grafana TO grafana;
EOF

sudo systemctl enable --now grafana-server
```

---

## Week 4-5: Ansible Development

### Role Structure

```bash
cd ~/migration-automation
mkdir -p roles/{ad_export,ad_provision,machine_move_usmt,server_rebind,linux_migrate,discovery_health,preflight_validation,gate_on_health,reporting_render,reporting_etl,rollback_machine}/{tasks,templates,defaults,vars,handlers}
```

### Example Role: `discovery_health`

**roles/discovery_health/tasks/main.yml:**
```yaml
---
- name: Check if Windows host
  set_fact:
    is_windows: "{{ ansible_os_family == 'Windows' }}"

- include_tasks: windows_health.yml
  when: is_windows

- include_tasks: linux_health.yml
  when: not is_windows
```

**roles/discovery_health/tasks/windows_health.yml:**
```yaml
---
- name: Check WinRM connectivity
  win_ping:
  register: winrm_check
  failed_when: false

- name: Check secure channel
  win_powershell:
    script: |
      Test-ComputerSecureChannel
  register: secure_channel
  failed_when: false

- name: Check time sync
  win_powershell:
    script: |
      $timesync = w32tm /query /status
      if ($timesync -match "Last Successful Sync Time") {
        $offset = w32tm /stripchart /computer:{{ domain_dc }} /samples:1 /dataonly 2>&1
        if ($offset -match "[\+\-](\d+\.\d+)") {
          [Math]::Abs([decimal]$matches[1])
        } else {0}
      } else {999}
  register: time_offset

- name: Check AD site
  win_powershell:
    script: |
      (Get-ADDomainController -Discover).Site
  register: ad_site
  failed_when: false

- name: Set discovery facts
  set_fact:
    discovery_result:
      host: "{{ inventory_hostname }}"
      winrm_ok: "{{ winrm_check is success }}"
      secure_channel_ok: "{{ secure_channel.output[0] | default(false) }}"
      time_offset_sec: "{{ time_offset.output[0] | default(999) | float }}"
      ad_site: "{{ ad_site.output[0] | default('UNKNOWN') }}"
      checks_passed: "{{ winrm_check is success and secure_channel.output[0] | default(false) and (time_offset.output[0] | default(999) | float < 5) }}"
```

**roles/discovery_health/tasks/linux_health.yml:**
```yaml
---
- name: Check SSH connectivity
  ping:
  register: ssh_check

- name: Check if domain-joined
  command: realm list
  register: realm_check
  failed_when: false

- name: Check sssd service
  service_facts:

- name: Check Kerberos ticket
  command: klist -s
  register: krb_check
  failed_when: false
  when: realm_check.rc == 0

- name: Check time sync
  command: chronyc tracking
  register: chrony_check

- name: Parse time offset
  set_fact:
    time_offset_linux: "{{ chrony_check.stdout | regex_search('System time\\s+:\\s+([-\\d.]+)', '\\1') | first | default(999) | float }}"

- name: Set discovery facts
  set_fact:
    discovery_result:
      host: "{{ inventory_hostname }}"
      ssh_ok: "{{ ssh_check is success }}"
      domain_joined: "{{ realm_check.rc == 0 }}"
      sssd_running: "{{ ansible_facts.services['sssd.service'].state == 'running' if 'sssd.service' in ansible_facts.services else false }}"
      krb_ok: "{{ krb_check.rc == 0 if realm_check.rc == 0 else false }}"
      time_offset_sec: "{{ time_offset_linux | abs }}"
      checks_passed: "{{ ssh_check is success and (time_offset_linux | abs < 5) }}"
```

---

### Playbook: Discovery

**playbooks/00_discovery_health.yml:**
```yaml
---
- name: Discovery - Health Checks
  hosts: all
  gather_facts: yes
  vars:
    run_id: "{{ lookup('pipe', 'uuidgen') }}"

  tasks:
    - name: Run health checks
      include_role:
        name: discovery_health

    - name: Save results locally
      copy:
        content: "{{ discovery_result | to_json }}"
        dest: "{{ artifacts_dir }}/discovery/{{ inventory_hostname }}.json"
      delegate_to: localhost

    - name: Insert to database (Tier 2)
      include_role:
        name: reporting_etl
      vars:
        etl_action: discovery
        etl_data: "{{ discovery_result }}"
```

---

## Week 6-7: Pilot Execution

### Pilot Scope
- 50 users
- 10 workstations (5 East, 5 West to test regional state stores)
- 5 servers (2 web, 2 app, 1 SQL)

### Pilot Checklist

**Pre-Pilot (1 week before):**
- [ ] CAB approval obtained
- [ ] Pilot host list finalized
- [ ] Backups confirmed for all pilot hosts
- [ ] State stores tested (write 10 GB, read 10 GB)
- [ ] Vault dynamic credentials tested
- [ ] PostgreSQL replication lag <1 second
- [ ] Monitoring dashboards configured
- [ ] Break-glass account tested
- [ ] Rollback procedures documented and reviewed

**Pilot Day (Saturday, 8 AM - 6 PM):**

**Hour 0-1: Discovery**
```bash
cd ~/migration-automation
ansible-playbook -i inventories/tier2_medium/hosts.ini playbooks/00_discovery_health.yml --limit pilot

# Review report
firefox http://reports.migration.example.com/reports/discovery_pilot.html
```

**Hour 1-2: Pre-Flight Validation**
```bash
ansible-playbook -i inventories/tier2_medium/hosts.ini playbooks/00a_preflight_validation.yml --limit pilot

# Fix any blockers (app dependencies, insufficient disk space)
```

**Hour 2-3: Identity Provision**
```bash
ansible-playbook -i inventories/tier2_medium/hosts.ini playbooks/10_provision.yml --extra-vars "wave=pilot"

# Verify in target AD
Get-ADUser -Filter {employeeID -eq "12345"} -Properties *
```

**Hour 3-7: Machine Migration (Workstations)**
```bash
ansible-playbook -i inventories/tier2_medium/hosts.ini playbooks/20_machine_move.yml --limit pilot_workstations --forks 10

# Monitor in Grafana
firefox http://grafana.migration.example.com/d/migration-overview
```

**Hour 7-10: Server Migration + Rebind**
```bash
ansible-playbook -i inventories/tier2_medium/hosts.ini playbooks/20_machine_move.yml --limit pilot_servers --forks 5
ansible-playbook -i inventories/tier2_medium/hosts.ini playbooks/30_server_rebind.yml --limit pilot_servers
```

**Hour 10: Validation**
```bash
ansible-playbook -i inventories/tier2_medium/hosts.ini playbooks/40_validate.yml --limit pilot

# Manual checks:
# - User login test
# - App access test
# - Service status verification
```

**Post-Pilot (Week after):**
- [ ] Lessons learned session
- [ ] Update runbooks based on issues
- [ ] Tune concurrency (if runner CPU >80%)
- [ ] Adjust USMT switches (if files missing)
- [ ] Update group mappings (if unmapped groups found)
- [ ] Present metrics to CAB for production approval

---

## Week 8-12: Production Waves

### Wave Planning

**Wave Template (batches/wave1.yml):**
```yaml
wave_id: wave1
wave_label: "Production Wave 1 - Finance Department"
scheduled_date: "2025-11-15"
scheduled_time: "20:00"  # 8 PM
expected_duration: "4 hours"
blackout_dates:
  - "2025-11-24"  # Thanksgiving
  - "2025-12-25"  # Christmas

hosts:
  users:
    - filter: "department -eq 'Finance'"
    - count: 150
  workstations:
    - pattern: "FIN-WS-*"
    - count: 75
  servers:
    - pattern: "FINSQL*,FINAPP*"
    - count: 10

concurrency:
  users: 100
  workstations: 50
  servers: 10

safety:
  max_failure_percent: 5
  pause_on_threshold: true
  require_approval_after_failure: true

notifications:
  slack_channel: "#migration-ops"
  email_list: "migration-team@example.com"
```

### Production Wave Execution (Automated)

**AWX Workflow Template: "Production Wave Execution"**

Nodes:
1. **Discovery** (`00_discovery_health.yml`)
2. **Gate Check** (`02_gate_on_health.yml`) → Approval node if >5% failures
3. **Provision** (`10_provision.yml`)
4. **Machine Move - Workstations** (`20_machine_move.yml`, limit: workstations, forks: 50)
5. **Machine Move - Servers** (`20_machine_move.yml`, limit: servers, forks: 10)
6. **Server Rebind** (`30_server_rebind.yml`, limit: servers)
7. **Validation** (`40_validate.yml`)
8. **Reporting** (`09_render_report.yml` → `reporting_publish`)
9. **Database ETL** (`reporting_etl`)

**Survey Variables:**
- `wave_file`: Path to wave YAML (e.g., `batches/wave1.yml`)
- `dry_run`: Boolean (default: false)
- `force_proceed`: Boolean to skip gate on failures (default: false)

---

## Week 13-14: Cleanup & Handoff

**1. Decommission Source Resources (after 30-day soak)**
```bash
# Disable source AD users
Get-ADUser -Filter {extensionAttribute1 -eq "MIGRATED"} | Disable-ADAccount

# Remove from source groups
# ... (scripted based on group_map.yml)
```

**2. Archive Artifacts**
```bash
cd ~/migration-automation
tar -czf migration-artifacts-$(date +%F).tar.gz artifacts/ state/ backups/
aws s3 cp migration-artifacts-*.tar.gz s3://migration-archive/
```

**3. Training for Operations Team**
- 2-day workshop on AWX, Vault, playbooks
- Hands-on: Execute test wave in lab
- Review troubleshooting runbook
- Shadow on-call rotation (1 week)

**4. Documentation Handoff**
- Architecture diagrams
- Runbooks (operations, troubleshooting, rollback)
- Credential inventory (Vault paths)
- Contact list (vendors, escalation)

**5. Retrospective**
- What went well
- What didn't go well
- Metrics achieved (success rate, timeline, cost)
- Improvements for next migration

---

## Troubleshooting Guide

### Issue: WinRM Connection Failures

**Symptoms:** `winrm: [Errno 104] Connection reset by peer`

**Diagnosis:**
```bash
# From AWX runner
telnet <target_host> 5986
openssl s_client -connect <target_host>:5986 | openssl x509 -noout -text
```

**Fix:**
```powershell
# On target Windows host
Enable-PSRemoting -Force
winrm quickconfig -force
winrm set winrm/config/service '@{AllowUnencrypted="false"}'
winrm set winrm/config/service/auth '@{Kerberos="true"}'
Restart-Service WinRM
```

---

### Issue: Vault Sealed

**Symptoms:** `Error making API request. URL: GET https://vault:8200/v1/ad/creds/migration-windows ... 503 Service Unavailable`

**Diagnosis:**
```bash
vault status
# Sealed: true
```

**Fix:**
```bash
vault operator unseal <key1>
vault operator unseal <key2>
vault operator unseal <key3>
# Repeat until unsealed
```

---

### Issue: PostgreSQL Replication Lag

**Symptoms:** Reports show stale data, Grafana query: `pg_replication_lag_seconds > 30`

**Diagnosis:**
```sql
-- On primary
SELECT * FROM pg_stat_replication;
-- Check replay_lag column
```

**Fix:**
```bash
# Increase wal_keep_size
sudo -u postgres psql -c "ALTER SYSTEM SET wal_keep_size = '2GB';"
sudo systemctl reload postgresql

# If replication broken, rebuild replica
# (see Day 14-17 section above)
```

---

## Summary

This guide provides a **step-by-step implementation path for Tier 2** deployments. Key takeaways:

- **Infrastructure takes 3 weeks** to deploy properly (don't rush)
- **Ansible development takes 2 weeks** with thorough testing
- **Pilot is critical** to validate assumptions and tune parameters
- **Production waves should be 200-400 hosts** max to limit blast radius
- **Monitoring is not optional** – you cannot manage what you don't measure

**Next Steps:**
1. Secure budget approval ($350k-440k)
2. Assemble team (4-5 FTE)
3. Provision infrastructure (Week 1-3)
4. Begin Ansible development in parallel (Week 2-5)
5. Execute pilot (Week 6-7)

For questions or assistance, refer to:
- `docs/05_RUNBOOK_OPERATIONS.md` – Day-to-day operations
- `docs/06_RUNBOOK_TROUBLESHOOTING.md` – Common issues
- `docs/07_ROLLBACK_PROCEDURES.md` – Emergency rollback

---

**END OF GUIDE**

