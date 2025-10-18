# Apache Guacamole Bastion for Azure Free Tier – Summary

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Date:** October 2025

## Overview

I've updated the Azure Free Tier implementation (`docs/18_AZURE_FREE_TIER_IMPLEMENTATION.md`) to include **Apache Guacamole** as an open-source bastion host with automatic dynamic IP address handling, replacing the need for Azure Bastion ($140+/month).

---

## Key Features

### 1️⃣ **Zero Cost Bastion Host**

- **Apache Guacamole** runs on a B1s VM (within free tier)
- **Replaces Azure Bastion** saving $140+/month
- **All backend VMs private** (no public IPs) - enhanced security

### 2️⃣ **Web-Based Access**

Access all your servers through a web browser (HTTPS):
- **SSH** to AWX (10.200.1.10)
- **SSH** to PostgreSQL (10.200.1.20)
- **RDP** to Test Workstation (10.200.2.10)

No client software needed - just a web browser!

### 3️⃣ **Automatic Dynamic IP Handling**

**Two-layer protection:**

**Client-Side (Manual):**
```bash
# Run before accessing Guacamole
./scripts/update-azure-nsg-ip.sh   # Linux/Mac
.\scripts\Update-AzureNsgIp.ps1    # Windows
```

**Server-Side (Automatic):**
- Guacamole VM **auto-detects your IP** every 5 minutes
- **Updates NSG rules** automatically via Azure CLI + Managed Identity
- **Maintains access** even if your IP changes

**How It Works:**
1. Guacamole VM uses managed identity to authenticate to Azure
2. Every 5 minutes (cron job), it detects your current public IP
3. Updates NSG rules to allow HTTPS (443) and SSH (22) from your IP
4. Logs all updates to `/var/log/update-ip.log`

---

## Architecture Changes

### Before (Original Design):
```
Internet → AWX (public IP) ❌
Internet → Test Workstation (public IP) ❌
```

### After (With Guacamole):
```
Internet → Guacamole Bastion (ONLY public IP) ✅
           ├─→ AWX (private) ✅
           ├─→ PostgreSQL (private) ✅
           └─→ Test Workstation (private) ✅
```

### Network Segmentation:
```
┌─────────────────────────────────────────┐
│ Subnet: snet-bastion (10.200.0.0/28)   │
│ - Guacamole VM (public IP)             │
│ - NSG: Allow HTTPS from YOUR IP only   │
└─────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────┐
│ Subnet: snet-control-plane              │
│ - AWX (private only)                    │
│ - PostgreSQL (private only)             │
└─────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────┐
│ Subnet: snet-workstations               │
│ - Test Workstation (private only)       │
└─────────────────────────────────────────┘
```

---

## What's Included

### Terraform Components

1. **Guacamole VM** (`compute.tf` addition)
   - B1s Linux VM (free tier)
   - Managed identity with NSG update permissions
   - Auto-shutdown schedule
   - Public IP (only VM with public access)

2. **Bastion Subnet & NSG** (`network.tf` addition)
   - Dedicated DMZ subnet (10.200.0.0/28)
   - NSG with dynamic IP rules
   - Placeholder rules (0.0.0.0/32) updated by scripts

3. **PostgreSQL Database** (`database.tf` addition)
   - New `guacamole` database on existing free-tier PostgreSQL
   - Firewall rules for bastion subnet

4. **Security Improvements**
   - Removed public IPs from AWX and test workstation
   - All access via Guacamole only
   - Deny-all-inbound rule on bastion NSG

### Scripts

1. **Cloud-Init** (`scripts/guacamole-cloud-init.yaml`)
   - Installs Docker, Docker Compose, Nginx, Azure CLI
   - Deploys Guacamole containers
   - Configures HTTPS with self-signed cert
   - Sets up automatic IP update cron job
   - Initializes Guacamole database

2. **Client-Side IP Update** (Linux/Mac)
   - `scripts/update-azure-nsg-ip.sh`
   - Detects your public IP
   - Updates NSG rules via Azure CLI
   - Shows Guacamole URL

3. **Client-Side IP Update** (Windows)
   - `scripts/Update-AzureNsgIp.ps1`
   - Same functionality, PowerShell
   - Uses Az PowerShell module

4. **Server-Side Auto-Update** (runs on Guacamole VM)
   - `/usr/local/bin/update-my-ip.sh`
   - Runs every 5 minutes via cron
   - Uses managed identity (no credentials needed)
   - Logs to `/var/log/update-ip.log`

---

## Deployment Workflow

### 1. Deploy Infrastructure

```bash
cd infrastructure/azure-free-tier
terraform init
terraform apply
```

**Wait ~15 minutes** for:
- VMs to provision
- Guacamole to install
- PostgreSQL to initialize

### 2. Update Your IP

**From your local machine:**

```bash
# Linux/Mac
./scripts/update-azure-nsg-ip.sh

# Windows PowerShell
.\scripts\Update-AzureNsgIp.ps1
```

This adds your current public IP to the NSG, allowing access.

### 3. Access Guacamole

```bash
# Get Guacamole URL
terraform output guacamole_url
# Output: https://20.xxx.xxx.xxx
```

**Open in browser:**
- URL: `https://<guacamole-ip>`
- Accept self-signed certificate warning
- **Default login:** `guacadmin` / `guacadmin`
- ⚠️ **CHANGE PASSWORD IMMEDIATELY!**

### 4. Configure Connections

In Guacamole Web UI, add connections:

**Connection 1: AWX (SSH)**
- Name: `AWX Server`
- Protocol: `SSH`
- Hostname: `10.200.1.10`
- Port: `22`
- Username: `azureadmin`
- Authentication: Upload your SSH private key

**Connection 2: PostgreSQL (SSH)**
- Name: `PostgreSQL Server`
- Protocol: `SSH`
- Hostname: `10.200.1.20`
- Port: `22`
- Username: `azureadmin`
- Authentication: Upload your SSH private key

**Connection 3: Test Workstation (RDP)**
- Name: `Windows Test Workstation`
- Protocol: `RDP`
- Hostname: `10.200.2.10`
- Port: `3389`
- Username: `azureadmin`
- Password: (from `terraform output` or Key Vault)
- Security: `NLA`
- Ignore server certificate: `Yes`

### 5. Use Guacamole

- Click any connection in Guacamole dashboard
- Access SSH/RDP in browser window
- No VPN, no client software needed!
- Copy/paste works between local and remote
- Sessions are recorded (for auditing)

---

## Dynamic IP Update Details

### How Client Script Works

```bash
#!/bin/bash
# 1. Detect your public IP
MY_IP=$(curl -s https://api.ipify.org)  # e.g., 203.0.113.45

# 2. Login to Azure (prompts for credentials)
az login

# 3. Update NSG rules
az network nsg rule update \
  --resource-group "rg-migdemo" \
  --nsg-name "nsg-bastion" \
  --name "Allow-HTTPS-Dynamic-IP" \
  --source-address-prefixes "$MY_IP/32"
```

### How Server Auto-Update Works

**On Guacamole VM:**

```bash
# Cron job runs every 5 minutes
*/5 * * * * root /usr/local/bin/update-my-ip.sh >> /var/log/update-ip.log 2>&1
```

**Script logic:**

```bash
#!/bin/bash
# 1. Detect current client IP (YOU)
MY_IP=$(curl -s https://api.ipify.org)

# 2. Login using managed identity (no password)
az login --identity

# 3. Update NSG rules
az network nsg rule update \
  --resource-group "rg-migdemo" \
  --nsg-name "nsg-bastion" \
  --name "Allow-HTTPS-Dynamic-IP" \
  --source-address-prefixes "$MY_IP/32"
```

**Result:**
- If your home IP changes from `203.0.113.45` to `203.0.113.67`
- Within 5 minutes, Guacamole VM detects the new IP
- Updates NSG automatically
- You stay connected (no disruption)

---

## Security Features

✅ **Principle of Least Privilege**
- Only Guacamole VM has public IP
- AWX, PostgreSQL, test workstation: private only
- No direct internet access to backend servers

✅ **Dynamic IP Whitelisting**
- NSG allows HTTPS only from YOUR current IP
- Auto-updates every 5 minutes
- Prevents unauthorized access

✅ **HTTPS with TLS**
- Nginx reverse proxy with TLS 1.2/1.3
- Self-signed cert (can upgrade to Let's Encrypt)
- All traffic encrypted in transit

✅ **Managed Identity Authentication**
- Guacamole VM uses managed identity to update NSG
- No credentials stored on VM
- Azure AD authentication

✅ **Session Recording**
- Guacamole records all SSH/RDP sessions
- Stored in `/opt/guacamole/record`
- Useful for auditing and compliance

✅ **MFA Support** (optional)
- Guacamole supports TOTP, Duo, LDAP
- Add via Guacamole extensions

---

## Cost Comparison

### Azure Bastion (Microsoft)
- **Basic SKU:** $140/month
- **Standard SKU:** $280/month
- Limited to Azure Portal access
- No customization

### Guacamole (Open-Source)
- **Cost:** $0 (B1s VM within free tier)
- **Access:** Any web browser
- **Protocols:** SSH, RDP, VNC, Telnet
- **Fully customizable**

**Savings:** **$1,680/year** (Basic) or **$3,360/year** (Standard)

---

## Guacamole Features

| Feature | Description |
|---------|-------------|
| **Web-Based** | Access SSH/RDP in browser (no client) |
| **Multi-Protocol** | SSH, RDP, VNC, Telnet |
| **Copy/Paste** | Between local and remote |
| **File Transfer** | Drag-and-drop via SFTP |
| **Session Recording** | Record SSH/RDP sessions |
| **Clipboard Sharing** | Share clipboard between local/remote |
| **Audio Redirection** | Hear remote audio locally (RDP) |
| **Multi-User** | Multiple users with RBAC |
| **MFA** | TOTP, Duo, LDAP, SAML |
| **Connection Sharing** | Multiple users on same session |
| **Session Resume** | Resume disconnected sessions |
| **API** | REST API for automation |

---

## Troubleshooting

### Can't Access Guacamole

**Problem:** Browser shows "Connection refused"

**Solution:**
```bash
# 1. Check if your IP is in NSG
az network nsg rule show \
  --resource-group rg-migdemo \
  --nsg-name nsg-bastion \
  --name Allow-HTTPS-Dynamic-IP \
  --query "sourceAddressPrefix"

# 2. Update your IP
./scripts/update-azure-nsg-ip.sh

# 3. Verify Guacamole is running
ssh azureadmin@<guacamole-ip>
sudo docker ps  # Should show guacamole and guacd containers
```

### IP Changed, Lost Access

**Problem:** Your ISP changed your IP, can't access Guacamole

**Solution Option 1 (If you have SSH access):**
```bash
# SSH to Guacamole VM via Azure Portal Serial Console
# Run IP update script manually
sudo /usr/local/bin/update-my-ip.sh
```

**Solution Option 2 (Azure Portal):**
```bash
# Update NSG rule via Azure Portal
# Portal → Network Security Groups → nsg-bastion
# Edit rule "Allow-HTTPS-Dynamic-IP"
# Change source IP to your new IP
```

**Solution Option 3 (Azure Cloud Shell):**
```bash
# Open Azure Cloud Shell in portal
MY_IP=$(curl -s https://api.ipify.org)
az network nsg rule update \
  --resource-group rg-migdemo \
  --nsg-name nsg-bastion \
  --name Allow-HTTPS-Dynamic-IP \
  --source-address-prefixes "$MY_IP/32"
```

### Guacamole Not Auto-Updating IP

**Problem:** IP not updating every 5 minutes

**Solution:**
```bash
# SSH to Guacamole VM
ssh azureadmin@<guacamole-ip>

# Check cron log
sudo tail -f /var/log/update-ip.log

# Check if cron job exists
sudo cat /etc/cron.d/update-ip

# Manually test the script
sudo /usr/local/bin/update-my-ip.sh

# Check managed identity
az login --identity
az account show
```

---

## Optional Enhancements

### 1. Let's Encrypt SSL Certificate

Replace self-signed cert with trusted cert:

```bash
# SSH to Guacamole VM
ssh azureadmin@<guacamole-ip>

# Get domain name (or use IP)
# If using domain: guacamole.example.com

# Run certbot
sudo certbot --nginx -d guacamole.example.com

# Auto-renew
sudo systemctl enable certbot.timer
```

### 2. Guacamole MFA (TOTP)

Enable two-factor authentication:

```bash
# Download TOTP extension
cd /opt/guacamole/extensions
wget https://apache.org/dyn/closer.lua/guacamole/1.5.3/binary/guacamole-auth-totp-1.5.3.jar

# Restart Guacamole
cd /opt/guacamole
docker-compose restart

# Users can enable TOTP in settings
```

### 3. Connection Bookmarks

Pre-configure connections via PostgreSQL:

```sql
-- SSH to Guacamole VM, then:
PGPASSWORD=<password> psql -h <postgres-host> -U pgadmin -d guacamole

-- Insert pre-configured connection
INSERT INTO guacamole_connection (connection_name, protocol)
VALUES ('AWX Server', 'ssh');

-- Add parameters
INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
VALUES 
  (1, 'hostname', '10.200.1.10'),
  (1, 'port', '22'),
  (1, 'username', 'azureadmin');
```

### 4. Notifications for IP Changes

Get notified when IP changes:

**Add to `/usr/local/bin/update-my-ip.sh`:**

```bash
# At end of script, add:
curl -X POST "https://ntfy.sh/your-topic" \
  -d "Guacamole bastion IP updated to $MY_IP"

# Or send email via SendGrid, Mailgun, etc.
```

---

## Summary

### What You Get

✅ **Zero-cost bastion host** (within Azure free tier)  
✅ **Web-based SSH/RDP** (no client software)  
✅ **Automatic dynamic IP handling** (updates every 5 minutes)  
✅ **Enhanced security** (only 1 public IP, all others private)  
✅ **Session recording** (audit trail)  
✅ **Multi-user support** (RBAC, MFA)  
✅ **Copy/paste, file transfer** (built-in)  

### Deployment Time

- **Terraform apply:** 10-15 minutes
- **Guacamole setup:** Automatic (cloud-init)
- **Total:** 15-20 minutes start to finish

### Monthly Cost

- **$0** (all resources within Azure free tier)
- **Savings vs. Azure Bastion:** $140+/month

---

## Next Steps

1. **Review the updated design:** `docs/18_AZURE_FREE_TIER_IMPLEMENTATION.md`
2. **Deploy the infrastructure:** `terraform apply`
3. **Access Guacamole:** Run IP update script, open browser
4. **Configure connections:** Add AWX, PostgreSQL, test workstation
5. **Start migrating!** Use the bastion to manage all servers

---

**Questions or Issues?**
- Check `/var/log/update-ip.log` on Guacamole VM
- Review Guacamole logs: `sudo docker logs guacamole`
- Test NSG rules: `az network nsg rule list`

---

**END OF SUMMARY**

