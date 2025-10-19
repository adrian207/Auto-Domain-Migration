# Frequently Asked Questions (FAQ)

**Version:** 1.0  
**Last Updated:** January 2025  
**Target Audience:** All Users

---

## 📋 Table of Contents

1. [General Questions](#general-questions)
2. [Pre-Migration](#pre-migration)
3. [During Migration](#during-migration)
4. [Post-Migration](#post-migration)
5. [Technical Questions](#technical-questions)
6. [Troubleshooting](#troubleshooting)

---

## 🌐 General Questions

### Q: What is a domain migration?

**A:** A domain migration moves user accounts, computers, and data from one Active Directory domain to another. Think of it like moving from one office building to another - your desk moves, but you still have all your belongings.

---

### Q: Why are we migrating?

**A:** Common reasons include:
- Company merger or acquisition
- Infrastructure modernization
- Security improvements
- Organizational restructuring
- Domain consolidation

---

### Q: How long will the entire migration take?

**A:** Timeline varies by size:
- **Small (< 100 users):** 1-2 weeks
- **Medium (100-500 users):** 2-4 weeks
- **Large (500+ users):** 4-8 weeks

Individual user migration typically takes 15-30 minutes.

---

### Q: Who is responsible for the migration?

**A:** 
- **Project Manager:** Overall coordination
- **System Administrators:** Technical execution
- **Network Team:** Infrastructure support
- **Help Desk:** End-user support
- **End Users:** Following instructions and reporting issues

---

### Q: How much will this cost?

**A:** Costs vary by tier:
- **Tier 1 (Demo):** ~$50/month
- **Tier 2 (Production):** ~$500-800/month
- **Tier 3 (Enterprise):** ~$2,000-3,000/month

Plus one-time setup costs (tools, labor, testing).

---

## 📅 Pre-Migration

### Q: How do I prepare for migration?

**A:** End Users:
1. Save all work
2. Close applications
3. Backup personal files (optional)
4. Note any mapped drives
5. Read migration guide

**Administrators:**
1. Deploy infrastructure
2. Test trust configuration
3. Generate test data
4. Run discovery
5. Plan batches
6. Communicate schedule

---

### Q: What should I back up before migration?

**A:** End Users:
- Desktop files (not on network)
- Downloads folder
- Browser bookmarks (if local)
- Any local application data

**Administrators:**
- Domain controllers (full system)
- File servers (full system)
- Databases
- ADMT configuration
- Current state documentation

---

### Q: Can we do a test migration first?

**A:** **Yes, strongly recommended!**

1. Deploy Tier 1 (demo environment)
2. Generate test data
3. Migrate test users/computers
4. Validate everything works
5. Document lessons learned
6. Apply to production

---

### Q: How do I know when my migration is scheduled?

**A:** You'll receive:
- Email notification (1 week before)
- Reminder email (1 day before)
- Teams/Slack message (day of)
- Manager notification

Check the migration schedule spreadsheet or contact IT.

---

## 🔄 During Migration

### Q: What happens to my computer during migration?

**A:** Your computer will:
1. Begin domain join process (~5 min)
2. Reboot automatically (2-3 times)
3. Apply new domain settings (~5 min)
4. Recreate profile with your files (~5 min)
5. Be ready to use (~15-30 min total)

---

### Q: Will I lose any files?

**A:** **No!** Files are preserved in multiple ways:
- Network files stay on file server (never moved)
- Local profile copied to new domain profile
- Backups taken before migration
- USMT preserves desktop, documents, settings

---

### Q: Can I use my computer during migration?

**A:** **No.** Save all work and close applications before the scheduled time. Your computer will be unavailable for 15-30 minutes.

---

### Q: What if I'm working late when migration starts?

**A:** IT will notify you before starting. If you need more time:
1. Contact IT immediately
2. Save your work
3. Let IT know when ready
4. Migration will proceed when you're done

---

### Q: What if I'm on vacation during my scheduled migration?

**A:** Contact your manager and IT at least 3 days before. Options:
1. Migrate while you're away (computer must be on)
2. Reschedule for when you return

---

## ✅ Post-Migration

### Q: What's different after migration?

**A:** What changes:
- ✅ Domain name in username (OLD-DOMAIN → NEW-DOMAIN)
- ✅ Computer domain membership
- ✅ File server paths (may update)

What stays the same:
- ✅ Your password
- ✅ Your files
- ✅ Your applications
- ✅ Your email address
- ✅ Your permissions

---

### Q: Why is my first login slow?

**A:** First login takes 2-3 minutes because:
- Profile is being created
- Files are being copied
- Group policies applying
- Network drives mapping
- Settings synchronizing

Subsequent logins will be normal speed.

---

### Q: My network drives are missing. What do I do?

**A:** 
1. Open File Explorer
2. Type: `\\newserver\yourfolder`
3. Right-click folder → "Map network drive"
4. Select drive letter (H:, S:, etc.)
5. Check "Reconnect at sign-in"

If still missing after 1 hour, contact IT.

---

### Q: How long should I keep my old domain account?

**A:** Administrators typically keep the old domain running for 30-90 days after migration to ensure:
- All users migrated successfully
- No forgotten applications depend on it
- Files are accessible
- Any issues can be rolled back

---

### Q: Can I still access old file shares?

**A:** Yes, during the transition period:
- Old shares remain accessible
- Files are copied to new servers
- Both paths work temporarily
- Old shares will be decommissioned after validation period

---

## 🔧 Technical Questions

### Q: What tools are used for migration?

**A:**
- **ADMT:** Active Directory Migration Tool (Microsoft official)
- **USMT:** User State Migration Tool (files & settings)
- **SMS:** Storage Migration Service (file servers)
- **Ansible:** Automation orchestration
- **Terraform:** Infrastructure as Code
- **PowerShell:** Custom scripts and functions

---

### Q: Is ADMT supported by Microsoft?

**A:** Yes! ADMT is Microsoft's official migration tool. Latest version:
- **ADMT 3.2** (current)
- Supported on Windows Server 2016+
- Free to use
- Comprehensive documentation

---

### Q: What is SID History and why do we need it?

**A:** **SID History** preserves user access during migration:
- Old SID (Security Identifier) remains attached
- User can access both old and new domain resources
- Permissions don't break during transition
- Allows gradual application updates

---

### Q: How are passwords handled?

**A:** Passwords are **not** migrated directly. Instead:
- **Option 1:** Users keep existing passwords (domain trust)
- **Option 2:** Password Export Server (PES) for migration
- **Option 3:** Force password reset (less common)

Most deployments use Option 1 (trust-based).

---

### Q: What happens to group memberships?

**A:** Group memberships are preserved:
1. Groups migrated first
2. Users migrated with group memberships
3. Nested groups maintained
4. Membership validated post-migration

---

### Q: Are GPOs migrated?

**A:** GPOs are **not** automatically migrated. Instead:
1. Export GPOs from source domain
2. Review and update for new domain
3. Import and test in target domain
4. Apply to migrated OUs

This ensures only current policies are used.

---

### Q: How is Entra ID (Azure AD) involved?

**A:** Entra ID integration is optional:
- Can sync new domain to Entra ID
- Provides hybrid identity
- Enables cloud authentication
- Supports SSO to cloud apps

See `docs/08_ENTRA_SYNC_STRATEGY.md` for details.

---

## 🆘 Troubleshooting

### Q: I can't login. What should I do?

**A:** Try these steps:
1. **Verify username:** Should be NEW-DOMAIN\your.username
2. **Try same password** (it doesn't change)
3. **Restart computer** (fixes 50% of issues)
4. **Wait 30 minutes** (profile may be syncing)
5. **Contact IT** if still fails after 3 attempts

**Do NOT** try more than 3 times (account may lock).

---

### Q: I got an error message. What does it mean?

**A:** Common errors:

| Error | Meaning | Solution |
|-------|---------|----------|
| "Trust relationship failed" | Computer can't auth to domain | Restart; if persists, call IT |
| "Account locked" | Too many failed logins | Call IT to unlock |
| "Cannot find domain controller" | Network/DNS issue | Check network cable; call IT |
| "Profile cannot be loaded" | Profile issue | Restart; if persists, call IT |

Take a screenshot and contact IT with the exact error.

---

### Q: My application isn't working after migration. Why?

**A:** Possible reasons:
1. **Needs re-authentication:** Login again with new domain credentials
2. **License tied to old domain:** Contact application vendor
3. **Path to network drive changed:** Update application settings
4. **Not migrated yet:** May still be connecting to old domain

Contact IT with specific application name and error.

---

### Q: Can I roll back if there are problems?

**A:** **Yes!** Multiple rollback options:
1. **User only:** Remove from target domain, restore in source
2. **Computer only:** Rejoin to source domain
3. **Full batch:** Rollback entire migration batch
4. **Disaster:** Restore from backup

Rollback typically takes 1-2 hours.

---

### Q: Who do I contact for help?

**A:** 
1. **Self-service:** Check this FAQ and user guide
2. **Help Desk:** Phone or email for general issues
3. **IT Support:** For technical migration issues
4. **On-Call Engineer:** For after-hours emergencies

Contact information in migration notification email.

---

## 📊 Statistics & Performance

### Q: What is the success rate of migrations?

**A:** [Inference based on industry standards] Typically:
- **User migrations:** 95-98% first-pass success
- **Computer migrations:** 90-95% first-pass success (some offline)
- **File server migrations:** 98-99% data integrity
- **Overall success:** 95%+ with proper planning

---

### Q: How many users/computers can be migrated per day?

**A:** Typical rates:
- **Users:** 50-100 per hour (automated)
- **Computers:** 20-30 per hour (requires reboot)
- **File servers:** Depends on data size (TB per day)

With Tier 2 infrastructure, can handle 500 users/day comfortably.

---

### Q: What is the average downtime per user?

**A:** 
- **Users:** 0 downtime (can login immediately)
- **Computers:** 15-30 minutes (during reboot)
- **File servers:** 0-5 minutes (during cutover)

Migrations typically scheduled during off-hours to minimize impact.

---

## 🛡️ Security & Compliance

### Q: Is migration secure?

**A:** **Yes!** Security measures include:
- ✅ Encrypted communications (TLS)
- ✅ Secure credential storage (Key Vault)
- ✅ Audit logging (all actions)
- ✅ Role-based access control
- ✅ Multi-factor authentication
- ✅ Backup and recovery

---

### Q: Who has access to migration tools?

**A:** 
- **Domain Admins:** Full access
- **Migration Engineers:** ADMT access
- **Help Desk:** Read-only reporting
- **End Users:** No access

All access audited and logged.

---

### Q: Are there compliance considerations?

**A:** Yes, consider:
- **Data residency:** Where is data stored?
- **Audit requirements:** Are logs retained?
- **PII handling:** Is personal data protected?
- **Retention policies:** How long keep backups?

Consult your compliance team before migration.

---

## 📞 Need More Help?

**Still have questions?**

- **Documentation:** `docs/` folder
- **Training:** `docs/training/` folder
- **GitHub Issues:** Report bugs or suggest improvements
- **IT Support:** Contact your IT department

**Found an error in this FAQ?**
Please submit feedback via GitHub Issues or email it-support@company.com

---

**Version:** 1.0  
**Last Updated:** January 2025  
**Questions answered:** 50+  
**This FAQ is living document - suggestions welcome!**

