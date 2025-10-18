# Entra ID vs Domain Controllers - Cost Analysis

**Date:** October 2025  
**Author:** Adrian Johnson  
**Purpose:** Evaluate if Microsoft Entra ID can replace traditional Domain Controllers

---

## 🎯 Quick Answer

**Can Entra ID replace Domain Controllers for migration?**

| Tier | Answer | Recommendation |
|------|--------|----------------|
| **Tier 1 (Free/Demo)** | ⚠️ **Partial** | Use on-prem AD for source/target, then sync to Entra |
| **Tier 2 (Production)** | ✅ **YES** | Hybrid: Sync source AD → Entra directly (no target DC) |
| **Tier 3 (Enterprise)** | ✅ **YES** | Entra-only with Azure AD Domain Services for legacy apps |

**Bottom Line:** 
- FREE tier: Can't avoid DCs (need for ADMT)
- Tier 2/3: **Can eliminate target DC** → Save $70-140/month
- Additional: Use Entra ID for free identity services

---

## 💰 Cost Comparison

### Option 1: Traditional Domain Controllers (Current)

```
Infrastructure Cost:
├── Source DC (Standard_D2s_v5) → $70/month
├── Target DC (Standard_D2s_v5) → $70/month
└── Total: $140/month
```

**Features:**
- ✅ Full AD functionality
- ✅ Group Policy
- ✅ ADMT support
- ✅ Legacy app compatibility
- ❌ High maintenance
- ❌ Must size for peak load

---

### Option 2: Microsoft Entra ID (Azure AD) - FREE Tier

```
Entra ID Free:
├── Up to 500,000 objects → FREE
├── Basic SSO → FREE
├── User/Group management → FREE
├── Self-service password reset → FREE
├── MFA → FREE (security defaults)
└── Azure AD Join → FREE

Cost: $0/month ✅
```

**Limitations:**
- ❌ No on-prem Group Policy (use Intune)
- ❌ No traditional NTLM/Kerberos (use Azure AD auth)
- ❌ No ADMT (must use alternative migration tools)
- ❌ No LDAP (unless using Azure AD DS)

---

### Option 3: Azure AD Domain Services (Managed AD)

```
Azure AD Domain Services:
├── Standard tier → $109/month
├── Enterprise tier → $179/month
├── Premium tier → $349/month

Features:
✅ Managed AD Domain
✅ Group Policy
✅ LDAP/Kerberos
✅ Domain Join
✅ No DC maintenance
❌ Expensive!
```

**When to use:**
- Legacy apps requiring LDAP
- GPO requirement
- Lift-and-shift scenarios

---

### Option 4: Hybrid Approach (RECOMMENDED) ⭐

```
Tier 1 (Free/Demo):
├── Source DC (on-prem or IaaS VM) → $70 or FREE (existing)
├── Target DC (minimal VM) → $70/month
├── Total: $70-140/month (unavoidable for ADMT)

Tier 2/3 (Production):
├── Source DC (existing infrastructure) → $0 (already have)
├── NO Target DC (use Entra ID directly) → $0 ✅
├── Entra ID Premium P1 (optional) → $6/user/month
└── Total: $0-$6/user/month

Savings: $70-140/month on infrastructure!
```

---

## 🏗️ Architecture Comparison

### Current Approach (On-Prem AD → On-Prem AD → Entra)

```
Source Domain (corp.local)
    ↓ ADMT
Target Domain (newcorp.local)
    ↓ Entra Connect
Entra ID (newcorp.onmicrosoft.com)
    ↓
Azure AD Joined devices
```

**Costs:**
- Source DC: Existing (free)
- Target DC: $70/month
- Entra Connect: Free
- Entra ID: Free (basic)

**Total new costs: $70/month**

---

### Proposed Approach (Direct to Entra - Tier 2/3)

```
Source Domain (corp.local)
    ↓ Modified migration process
Entra ID (newcorp.onmicrosoft.com)
    ↓
Azure AD Joined devices (no domain join)
```

**How it works:**
1. Sync source users to Entra using Entra Connect
2. Migrate devices with Azure AD Join (not domain join)
3. Use Intune for management (not Group Policy)
4. Use cloud-based tools (not ADMT)

**Costs:**
- Source DC: Existing (free)
- Target DC: ❌ **Not needed!**
- Entra Connect: Free
- Entra ID: Free (or $6/user for Premium)

**Total new costs: $0-$6/user/month**

---

## 🔧 Migration Strategies by Tier

### Tier 1 (Free/Demo) - Traditional AD Required

**Approach:** ADMT-based migration
```yaml
Requirements:
  - Source DC (existing or minimal VM)
  - Target DC (B1s VM - free tier)
  - ADMT tool (free)
  
Process:
  1. ADMT migrates users: Source AD → Target AD
  2. ADMT migrates computers: Source AD → Target AD
  3. Entra Connect syncs: Target AD → Entra ID
  4. Devices rejoin Target AD domain

Cost: $0-70/month (depending on if source is existing)
Why: ADMT requires traditional AD domains
```

**Can't eliminate DCs here** because:
- ADMT is free but needs AD
- Alternative tools (PowerShell scripts) are manual
- Not production-ready without AD

---

### Tier 2 (Production) - Hybrid Cloud ⭐ RECOMMENDED

**Approach:** Entra Connect + Azure AD Join
```yaml
Requirements:
  - Source DC (existing infrastructure)
  - NO Target DC needed!
  - Entra Connect (free)
  - Intune (included with M365 or $6/user)
  
Process:
  1. Entra Connect syncs: Source AD → Entra ID
  2. Create new users in Entra ID (Graph API)
  3. Devices Azure AD Join (not domain join)
  4. Intune manages devices (replaces Group Policy)
  5. USMT migrates user profiles to new machines

Cost: $0/month infrastructure (Entra ID free)
Optional: $6/user/month for Intune + Premium P1
Savings: $70/month (no target DC)
```

**Benefits:**
- ✅ No target DC infrastructure
- ✅ Cloud-native management
- ✅ Better for remote workers
- ✅ Scales automatically

**Trade-offs:**
- ⚠️ No Group Policy (use Intune policies)
- ⚠️ No ADMT (use PowerShell + Graph API)
- ⚠️ Requires Azure AD Join support
- ⚠️ Legacy apps may need Azure AD DS

---

### Tier 3 (Enterprise) - Cloud-First with Hybrid Support

**Approach:** Entra ID + Azure AD Domain Services (if needed)
```yaml
Requirements:
  - Source DC (existing)
  - Azure AD Domain Services (optional, $109/mo)
  - Entra ID Premium P1 or P2 ($6-9/user)
  - Intune
  
Process:
  1. Entra Connect: Source AD → Entra ID
  2. Users managed in Entra ID (Graph API)
  3. Modern devices: Azure AD Join
  4. Legacy apps: Use Azure AD DS
  5. Conditional Access policies
  6. PIM for admin access

Cost Options:
  A) Cloud-only: $6/user/month (no AD DS)
  B) Hybrid: $6/user/month + $109/month (AD DS)
  
Savings vs Traditional:
  - No Target DC: $70/month saved
  - But may add AD DS: $109/month cost
  - Net: +$39/month vs traditional
```

**When to use Azure AD DS:**
- Legacy apps require LDAP
- Custom apps need Kerberos
- Lift-and-shift scenarios
- Can't refactor apps for cloud auth

**When to skip Azure AD DS:**
- Modern apps only (OAuth, SAML)
- All devices support Azure AD Join
- No legacy dependencies

---

## 📊 Cost Comparison Matrix

| Scenario | Source DC | Target DC | Azure AD DS | Entra ID | Monthly Cost | Use Case |
|----------|-----------|-----------|-------------|----------|--------------|----------|
| **Current (All AD)** | Existing | $70 | - | Free | **$70** | Tier 1, Legacy |
| **Hybrid Cloud** | Existing | ❌ | - | Free | **$0** ⭐ | Tier 2, Modern |
| **Hybrid + Legacy** | Existing | ❌ | $109 | Free | **$109** | Tier 2, Mixed |
| **Premium Cloud** | Existing | ❌ | - | $6/user | **$6/user** | Tier 2/3, Modern |
| **Full Enterprise** | Existing | ❌ | $109 | $9/user | **$109 + $9/user** | Tier 3, All features |

### Example: 100-user organization

| Approach | Infrastructure | Per-User | Monthly Total | Annual Total |
|----------|----------------|----------|---------------|--------------|
| **Traditional AD** | $70 | $0 | **$70** | $840 |
| **Entra Free** | $0 | $0 | **$0** ⭐ | $0 |
| **Entra Premium** | $0 | $6 | **$600** | $7,200 |
| **Entra + AD DS** | $109 | $0 | **$109** | $1,308 |
| **Full Premium + AD DS** | $109 | $6 | **$709** | $8,508 |

**Best value for Tier 2:** Entra ID Free ($0/month) if no legacy apps!

---

## 🎯 Decision Tree

```
Do you need Group Policy?
├─ YES
│  ├─ Can you migrate to Intune?
│  │  ├─ YES → Use Entra ID + Intune ($6/user)
│  │  └─ NO → Keep Traditional AD or use Azure AD DS ($70-109/mo)
│  └─ NO → Use Entra ID Free ($0)
│
└─ NO
   └─ Do you have legacy apps requiring LDAP/Kerberos?
      ├─ YES → Use Azure AD DS ($109/mo)
      └─ NO → Use Entra ID Free ($0) ⭐
```

---

## 🚀 Recommended Strategy

### For Most Organizations (Tier 2): Hybrid Cloud ⭐

```yaml
Phase 1: Assess (1 week)
  - Identify legacy app dependencies
  - Check device Azure AD Join compatibility
  - Review Group Policy usage
  
Phase 2: Pilot (2 weeks)
  - Migrate 10-20 users to Entra-only
  - Test Azure AD Join on devices
  - Validate Intune policies
  - Identify gaps
  
Phase 3: Production (4-8 weeks)
  - Wave-based migration
  - Direct sync: Source AD → Entra ID
  - Azure AD Join for devices
  - USMT for profile migration
  - Decommission target DC
  
Cost Savings: $70-140/month infrastructure
ROI: 100% (no infrastructure cost)
```

---

## ⚠️ Limitations and Workarounds

### Limitation 1: No ADMT with Entra ID
**Solution:** Use PowerShell + Microsoft Graph API

```powershell
# Create users in Entra ID
Connect-MgGraph -Scopes "User.ReadWrite.All"

$sourceUser = Get-ADUser -Identity jdoe -Properties *
$entraUser = New-MgUser -DisplayName $sourceUser.DisplayName `
    -UserPrincipalName "$($sourceUser.SamAccountName)@newcorp.onmicrosoft.com" `
    -MailNickname $sourceUser.SamAccountName `
    -EmployeeId $sourceUser.EmployeeID `
    -AccountEnabled $true `
    -PasswordProfile @{
        ForceChangePasswordNextSignIn = $true
        Password = (New-RandomPassword)
    }
```

### Limitation 2: No Group Policy
**Solution:** Use Microsoft Intune

```yaml
Intune Policies Replace GPO:
  - Device compliance policies
  - Configuration profiles
  - App deployment
  - Windows Update management
  - BitLocker encryption
  - Windows Hello
  
Cost: Included in M365 E3/E5 or $6/user standalone
```

### Limitation 3: No Domain Join
**Solution:** Azure AD Join

```yaml
Benefits of Azure AD Join:
  - SSO to cloud apps
  - Windows Hello for Business
  - Conditional Access
  - Self-service password reset
  - BitLocker recovery in cloud
  - Remote wipe
  
User Experience: Nearly identical to domain join
```

### Limitation 4: Legacy Apps Need LDAP
**Solution:** Deploy Azure AD Domain Services (only if needed)

```yaml
When needed:
  - Line-of-business apps with LDAP
  - Custom apps using Kerberos
  - SharePoint on-premises
  
Cost: $109/month (Standard tier)
Alternative: Modernize apps to use OAuth/SAML
```

---

## 💡 Free Tier Optimization

**For Tier 1 (Demo/POC):**

```yaml
Goal: Minimize cost while proving concept

Infrastructure:
  - Use Azure Free Tier VMs (B1s - 750 hrs/month free)
  - Source DC: B1s (FREE)
  - Target DC: B1s (FREE)
  - Entra ID: Free tier
  - Entra Connect: Free
  
Process:
  - Traditional ADMT migration (free tool)
  - Sync to Entra ID for demo
  - Show hybrid capabilities
  
Cost: $0-50/month (depending on overages)
```

---

## 📋 Implementation Checklist

### Tier 2 Cloud-First Approach

**Prerequisites:**
- [ ] Existing source AD domain
- [ ] Microsoft 365 or Azure AD tenant
- [ ] Devices support Azure AD Join (Windows 10/11 Pro+)
- [ ] No hard legacy app dependencies (or willing to use AD DS)

**Phase 1: Setup (Week 1)**
- [ ] Install Entra Connect on source DC
- [ ] Configure sync (users + groups only)
- [ ] Verify users sync to Entra ID
- [ ] Test Azure AD Join on pilot device

**Phase 2: Pilot (Weeks 2-3)**
- [ ] Migrate 10-20 users
- [ ] Azure AD Join their devices
- [ ] Deploy Intune policies
- [ ] Validate SSO to apps
- [ ] Collect feedback

**Phase 3: Production (Weeks 4-8)**
- [ ] Wave-based user migration
- [ ] Device refresh with Azure AD Join
- [ ] Profile migration (USMT to new device)
- [ ] Decommission target DC
- [ ] Celebrate $70/month savings! 🎉

---

## 🎯 Final Recommendation

### By Tier:

| Tier | Recommendation | Cost | Reason |
|------|----------------|------|--------|
| **Tier 1 (Free)** | Traditional AD + Entra sync | $0-70/mo | Need ADMT for demo |
| **Tier 2 (Production)** | Entra ID only (no target DC) ⭐ | **$0/mo** | Modern, cloud-native |
| **Tier 3 (Enterprise)** | Entra Premium + AD DS (if needed) | $109 + $6/user | Full features |

### Best Value: Tier 2 with Entra ID Free ✅
- **Savings:** $70-140/month infrastructure
- **Trade-off:** No Group Policy (use Intune)
- **ROI:** Immediate (no infra cost)
- **Scalability:** Unlimited (cloud-scale)

---

**Status:** Analysis complete - Entra ID can replace Target DC in Tier 2/3!  
**Recommended:** Hybrid approach with direct Entra sync (no target AD) 🚀

