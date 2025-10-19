# Migration Best Practices Guide

**Version:** 1.0  
**Last Updated:** January 2025  
**Target Audience:** Project Managers, System Administrators, Migration Engineers

---

## 📋 Table of Contents

1. [Planning & Preparation](#planning--preparation)
2. [Communication Strategy](#communication-strategy)
3. [Technical Best Practices](#technical-best-practices)
4. [Testing & Validation](#testing--validation)
5. [Execution Phase](#execution-phase)
6. [Post-Migration](#post-migration)
7. [Lessons Learned](#lessons-learned)

---

## 📝 Planning & Preparation

### 1. Start with Discovery

**✅ DO:**
- Run automated discovery playbook
- Document ALL dependencies
- Identify custom applications
- Map file shares and permissions
- List all group memberships
- Catalog computers by type/location

**❌ DON'T:**
- Assume you know everything
- Skip documenting "obvious" things
- Ignore legacy systems
- Forget about service accounts

**Tools:**
```bash
ansible-playbook playbooks/00_discovery.yml
```

---

### 2. Build a Realistic Timeline

**✅ DO:**
- Allow buffer time (20-30% extra)
- Schedule during low-usage periods
- Plan for rollback windows
- Include testing phases
- Consider holiday schedules
- Allow for unexpected issues

**❌ DON'T:**
- Rush the timeline
- Schedule during busy season
- Forget about time zones
- Skip testing phases
- Ignore stakeholder availability

**Example Timeline (500 users):**

| Phase | Duration | Activities |
|-------|----------|------------|
| **Planning** | 2 weeks | Discovery, design, approval |
| **Setup** | 1 week | Infrastructure deployment |
| **Testing** | 2 weeks | Pilot users, validation |
| **Wave 1** | 1 week | 25% of users |
| **Wave 2** | 1 week | 50% of users |
| **Wave 3** | 1 week | 25% of users |
| **Cleanup** | 2 weeks | Validation, documentation |
| **Total** | **9 weeks** | |

---

### 3. Define Clear Success Criteria

**✅ DO:**
- Set measurable goals
- Define "done" for each phase
- Establish quality metrics
- Document acceptance criteria
- Get stakeholder sign-off

**❌ DON'T:**
- Use vague definitions
- Change criteria mid-project
- Skip validation steps
- Assume everyone agrees

**Example Success Criteria:**
```yaml
Phase 1 - User Migration:
  - 95% of users migrated successfully
  - All group memberships preserved
  - SID history attached correctly
  - No permissions errors reported
  - Users can login within 2 minutes
  - Rollback plan tested and ready

Phase 2 - Computer Migration:
  - 90% of computers joined to new domain
  - All domain policies applied
  - Network connectivity verified
  - Applications working
  - Printers configured
  - Help desk tickets < 10%

Phase 3 - File Server Migration:
  - 100% of files transferred
  - SHA256 checksums match
  - NTFS permissions preserved
  - Share permissions correct
  - Users can access all files
  - No data loss reported
```

---

### 4. Create Detailed Documentation

**✅ DO:**
- Document current state
- Create network diagrams
- List all dependencies
- Write runbooks
- Document passwords (securely!)
- Keep configuration backups

**❌ DON'T:**
- Rely on memory
- Skip diagrams
- Store passwords in plain text
- Forget to update documentation
- Assume others know what you know

**Essential Documents:**
- Architecture diagram
- Migration runbook
- Rollback procedures
- Contact list
- Configuration backup
- Lessons learned template

---

## 📢 Communication Strategy

### 1. Stakeholder Management

**✅ DO:**
- Identify all stakeholders early
- Create communication plan
- Schedule regular updates
- Set clear expectations
- Provide status reports
- Celebrate milestones

**❌ DON'T:**
- Surprise people with changes
- Go dark during execution
- Over-promise timelines
- Hide problems
- Forget to thank the team

**Stakeholder Matrix:**

| Stakeholder | Interest | Influence | Communication Frequency |
|-------------|----------|-----------|------------------------|
| Executive Sponsor | High | High | Weekly |
| IT Leadership | High | High | Daily during migration |
| Department Managers | Medium | Medium | Weekly |
| End Users | High | Low | At key milestones |
| Help Desk | High | Medium | Daily |
| Vendors | Low | Medium | As needed |

---

### 2. User Communication Plan

**✅ DO:**
- Communicate early (1-2 weeks before)
- Send multiple reminders
- Use multiple channels (email, Teams, posters)
- Provide clear instructions
- Include screenshots
- List support contacts
- Send follow-up after migration

**❌ DON'T:**
- Email only once
- Use technical jargon
- Assume users read emails
- Forget remote workers
- Skip follow-up communication

**Example Communication Schedule:**

| When | Channel | Message |
|------|---------|---------|
| **T-14 days** | Email | Announcement with overview |
| **T-7 days** | Email + Teams | Detailed instructions + FAQ |
| **T-3 days** | Email | Reminder + support contacts |
| **T-1 day** | Email + Phone | Final reminder + what to do |
| **T-Day** | Teams | Live updates during migration |
| **T+1 day** | Email | Thank you + report issues |
| **T+1 week** | Email | Survey + lessons learned |

---

### 3. Change Management

**✅ DO:**
- Explain WHY (not just WHAT)
- Address concerns proactively
- Provide training resources
- Offer extra support during transition
- Gather feedback
- Make adjustments based on input

**❌ DON'T:**
- Mandate without explanation
- Ignore user concerns
- Assume everyone is comfortable with change
- Skip training
- Be defensive about issues

---

## 🔧 Technical Best Practices

### 1. Infrastructure Preparation

**✅ DO:**
- Deploy infrastructure code first
- Test ALL connectivity
- Establish trust before migration
- Configure monitoring early
- Set up backup before starting
- Test rollback procedures

**❌ DON'T:**
- Deploy and migrate same day
- Skip connectivity tests
- Trust without testing
- Forget monitoring
- Assume backups work

**Pre-Flight Checklist:**
```bash
# Infrastructure deployed?
terraform state list

# Trust configured?
Test-ComputerSecureChannel -Server source.local

# Monitoring working?
curl https://prometheus.yourdomain.com/-/healthy

# Backups configured?
az backup vault show -n admt-vault

# ZFS snapshots?
ssh root@fs01 "zfs list -t snapshot | tail -5"

# Rollback tested?
# (Test in Tier 1 first!)
```

---

### 2. Batch Strategy

**✅ DO:**
- Start with small pilot batch (5-10 users)
- Include tech-savvy users in pilot
- Increase batch size gradually
- Group by department/location
- Migrate managers before teams
- Leave time between batches

**❌ DON'T:**
- Migrate everyone at once
- Put VIPs in first batch
- Rush through batches
- Mix multiple departments
- Skip validation between batches

**Recommended Batch Sizes:**

| Total Users | Pilot | Wave 1 | Wave 2 | Wave 3 |
|-------------|-------|--------|--------|--------|
| 50-100 | 5-10 | 20-30 | 30-40 | 20-30 |
| 100-500 | 10-20 | 50-100 | 150-200 | 150-200 |
| 500-1000 | 20-30 | 100-150 | 200-300 | 400-500 |
| 1000+ | 50 | 200 | 400 | 400+ |

---

### 3. Service Account Management

**✅ DO:**
- Use dedicated service account
- Grant minimum required permissions
- Document permissions clearly
- Rotate passwords after migration
- Store in Key Vault
- Monitor service account usage

**❌ DON'T:**
- Use personal account
- Grant Domain Admin unnecessarily
- Share credentials
- Store in plain text
- Forget to disable when done

**Required Permissions:**
```powershell
# Source Domain
- Domain Admin (for ADMT)
- Read all user/computer/group objects
- Access to AD database

# Target Domain
- Domain Admin (for ADMT)
- Create computer objects in target OUs
- Create user objects in target OUs
- Modify group memberships

# File Servers
- Local Administrator
- Full control on shares
- NTFS permissions management

# Database
- db_owner on AWX database
- Backup permissions
```

---

### 4. Error Handling

**✅ DO:**
- Log everything
- Set up alerts for failures
- Have automated retry logic
- Document common errors
- Create troubleshooting guide
- Monitor error rates

**❌ DON'T:**
- Ignore errors
- Assume they'll fix themselves
- Skip logging
- Panic at first error
- Retry indefinitely

**Error Handling Strategy:**
```python
Try:
    Migrate object
Catch:
    Log error with full details
    If (error is retryable):
        Wait 5 minutes
        Retry (max 3 times)
    Else:
        Add to manual review queue
        Alert administrator
        Continue with next object
Finally:
    Update migration status
    Send metrics to monitoring
```

---

## ✅ Testing & Validation

### 1. Test Environment Strategy

**✅ DO:**
- Deploy Tier 1 for testing
- Use realistic test data
- Test ALL scenarios
- Involve end users in UAT
- Document test results
- Fix issues before production

**❌ DON'T:**
- Test in production
- Use dummy data
- Skip edge cases
- Test alone
- Rush through testing
- Ignore test failures

**Test Scenarios:**
```yaml
Functional Tests:
  - User migration (standard)
  - User migration (with profile > 1GB)
  - Computer migration (online)
  - Computer migration (offline - retry)
  - Group migration (nested groups)
  - File server migration (large files)
  - Rollback (user)
  - Rollback (computer)
  - Rollback (full batch)

Performance Tests:
  - Migration rate (users/hour)
  - File transfer speed (MB/s)
  - Login time post-migration
  - Application performance

Security Tests:
  - Permission preservation
  - SID history validation
  - Password complexity
  - Audit log completeness

Recovery Tests:
  - VM restore (< 1 hour)
  - Database restore (< 30 min)
  - ZFS rollback (< 5 min)
  - Regional failover (< 4 hours)
```

---

### 2. Validation Procedures

**✅ DO:**
- Validate after EVERY batch
- Check automated AND manual
- Test from user perspective
- Verify permissions
- Confirm group memberships
- Test applications

**❌ DON'T:**
- Assume success without checking
- Skip validation to save time
- Only check logs
- Forget to test user experience
- Move to next batch with errors

**Validation Checklist:**
```bash
# 1. User can login?
Test-UserLogin -Username "migrated.user" -Domain "target.local"

# 2. Group memberships correct?
Compare-Object (Get-ADPrincipalGroupMembership -Identity user -Server source.local) \
               (Get-ADPrincipalGroupMembership -Identity user -Server target.local)

# 3. SID history attached?
(Get-ADUser -Identity user -Server target.local -Properties SIDHistory).SIDHistory

# 4. File shares accessible?
Test-Path \\fs01.target.local\share

# 5. Applications working?
# (Manual test from user workstation)

# 6. Permissions correct?
Get-Acl \\fs01.target.local\share | Format-List
```

---

## 🚀 Execution Phase

### 1. Migration Day Procedures

**✅ DO:**
- Start early (allow buffer)
- Have full team available
- Monitor continuously
- Take breaks
- Document issues as they occur
- Celebrate small wins

**❌ DON'T:**
- Work exhausted
- Go it alone
- Ignore warning signs
- Skip meals/breaks
- Try to fix everything at once

**Migration Day Timeline:**
```
06:00 - Team arrives
06:15 - Final checks
06:30 - Start pilot batch (5-10 users)
07:00 - Monitor and validate
07:30 - Pilot complete → validate
08:00 - If successful, start Wave 1
09:00 - Break
09:15 - Monitor Wave 1
10:00 - Wave 1 complete → validate
10:30 - Start Wave 2
12:00 - Lunch break
13:00 - Monitor Wave 2
14:00 - Wave 2 complete → validate
14:30 - Start Wave 3 (if time allows)
16:00 - Day wrap-up
16:30 - Team debrief
17:00 - Status report to stakeholders
```

---

### 2. Monitoring During Migration

**✅ DO:**
- Watch Grafana dashboard
- Check logs continuously
- Monitor error rates
- Track batch progress
- Watch system resources
- Respond to alerts quickly

**❌ DON'T:**
- Set and forget
- Ignore alerts
- Wait for users to complain
- Skip log review

**Key Metrics to Watch:**
```promql
# Migration rate (should be steady)
rate(admt_users_migrated_total[5m])

# Error rate (should be < 5%)
rate(admt_migration_failures_total[5m]) / 
rate(admt_migrations_total[5m])

# Domain controller health
up{job="windows-exporter", instance=~"dc.*"}

# Disk space (should not fill)
100 - ((node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100)

# Network throughput
rate(node_network_transmit_bytes_total[5m])
```

---

### 3. Issue Response

**✅ DO:**
- Triage quickly (impact/urgency)
- Fix showstoppers immediately
- Document workarounds
- Queue non-critical issues
- Communicate delays
- Know when to pause

**❌ DON'T:**
- Fix everything immediately
- Let minor issues block progress
- Hide problems
- Panic
- Continue if major issue

**Severity Levels:**

| Level | Description | Response Time | Example |
|-------|-------------|---------------|---------|
| **P1 - Critical** | Migration stopped | Immediate | Trust relationship broken |
| **P2 - High** | Significant impact | < 30 min | Batch failure (50%+ errors) |
| **P3 - Medium** | Limited impact | < 2 hours | Individual user failure |
| **P4 - Low** | Minimal impact | Next business day | Cosmetic issue |

---

## 📊 Post-Migration

### 1. Validation Period

**✅ DO:**
- Keep source domain running (30-90 days)
- Monitor help desk tickets
- Track user satisfaction
- Validate backups
- Check for orphaned accounts
- Document lessons learned

**❌ DON'T:**
- Decommission immediately
- Ignore feedback
- Assume everything is perfect
- Delete backups
- Forget documentation

**Weekly Validation Tasks:**
```bash
# Week 1: Intensive monitoring
- Review all help desk tickets
- Validate critical applications
- Check permission issues
- Monitor performance
- Survey pilot users

# Week 2-4: Standard monitoring
- Track error rates
- Review self-healing events
- Check backup completion
- Validate DR readiness

# Month 2-3: Stabilization
- Audit orphaned accounts
- Review inactive computers
- Clean up old groups
- Update documentation
- Plan decommission
```

---

### 2. Cleanup Activities

**✅ DO:**
- Remove test accounts
- Disable old service accounts
- Clean up temporary groups
- Archive migration logs
- Delete old snapshots (keep some)
- Update documentation

**❌ DON'T:**
- Delete everything immediately
- Remove accounts in use
- Lose migration logs
- Delete all backups
- Forget to update docs

**Cleanup Checklist:**
```powershell
# Test accounts (safe to delete after 30 days)
Get-ADUser -Filter 'Name -like "*test*"' -Server target.local

# Temporary groups
Get-ADGroup -Filter 'Name -like "*temp*" -or Name -like "*migration*"'

# Orphaned computers (not logged in 90 days)
Get-ADComputer -Filter * -Properties LastLogonDate | 
  Where-Object {$_.LastLogonDate -lt (Get-Date).AddDays(-90)}

# Old migration batches
Get-ChildItem C:\ADMT\Batches\ | 
  Where-Object {$_.CreationTime -lt (Get-Date).AddDays(-90)}
```

---

### 3. Lessons Learned

**✅ DO:**
- Schedule debrief within 1 week
- Include all team members
- Document what worked
- Document what didn't
- Share with organization
- Update procedures

**❌ DON'T:**
- Skip debrief
- Blame individuals
- Focus only on negatives
- Keep learnings private
- Forget to follow up

**Debrief Template:**
```markdown
# Migration Lessons Learned

## Project Summary
- Timeline: [actual vs planned]
- Users migrated: [count]
- Success rate: [percentage]
- Issues encountered: [count]

## What Went Well ✅
1. [Example: Automated validation caught errors early]
2. [Example: Communication plan kept users informed]
3. [Example: Self-healing reduced manual interventions]

## What Could Improve 🔧
1. [Example: Need better test data for UAT]
2. [Example: Help desk needed more training]
3. [Example: Batch size too large for first wave]

## Surprises 🤔
1. [Example: Profile migration slower than expected]
2. [Example: Legacy app had undocumented dependency]

## Recommendations 💡
1. [Example: Test profiles > 5GB in staging]
2. [Example: Add 20% buffer to timeline]
3. [Example: Increase help desk staffing during migration]

## Metrics 📊
- RTO achieved: [Yes/No]
- RPO achieved: [Yes/No]
- User satisfaction: [score]
- Help desk tickets: [count]
- Rollbacks performed: [count]

## Action Items 📝
| Item | Owner | Due Date | Status |
|------|-------|----------|--------|
| Update runbook | Admin | Next week | Open |
| Train help desk | Manager | Next sprint | Open |
```

---

## 🏆 Success Factors

### Critical Success Factors

1. **Executive Sponsorship**
   - Visible support from leadership
   - Resources allocated
   - Roadblocks removed

2. **Thorough Planning**
   - Detailed discovery
   - Realistic timeline
   - Clear success criteria

3. **Effective Communication**
   - Regular updates
   - Multiple channels
   - User-friendly messaging

4. **Comprehensive Testing**
   - Realistic test environment
   - All scenarios covered
   - User acceptance testing

5. **Skilled Team**
   - Technical expertise
   - Project management
   - Change management

6. **Proper Tools**
   - ADMT configured correctly
   - Automation in place
   - Monitoring enabled

7. **Risk Management**
   - Backups verified
   - Rollback tested
   - DR plan ready

---

## 🎓 Final Advice

### From Experienced Migration Engineers

> **"Test your rollback procedures BEFORE you need them."**  
> — Every engineer who learned the hard way

> **"Communication solves 80% of migration problems."**  
> — Project manager with 50+ migrations

> **"Always have a Plan B, C, and D."**  
> — SRE who survived a data center fire

> **"Users don't read emails. Plan accordingly."**  
> — Help desk manager who learned this early

> **"Automate everything you can, but test everything you automate."**  
> — DevOps engineer with battle scars

> **"The best migration is one users don't notice."**  
> — Everyone

---

## 📚 Additional Resources

- **Administrator Training:** `docs/training/01_ADMINISTRATOR_GUIDE.md`
- **End User Guide:** `docs/training/02_END_USER_GUIDE.md`
- **Troubleshooting:** `docs/training/03_TROUBLESHOOTING_FLOWCHARTS.md`
- **Quick Reference:** `docs/training/04_QUICK_REFERENCE_CARDS.md`
- **FAQ:** `docs/training/05_FAQ.md`
- **DR Runbook:** `docs/32_DISASTER_RECOVERY_RUNBOOK.md`

---

**Remember:** Every migration is a learning opportunity. Take notes, share knowledge, and make the next one even better!

**Version:** 1.0  
**Last Updated:** January 2025  
**"Practice makes perfect, but proper planning prevents poor performance!"** 🚀

