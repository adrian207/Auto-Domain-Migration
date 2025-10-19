# End User Migration Guide

**Version:** 1.0  
**Last Updated:** January 2025  
**Target Audience:** End Users, Department Managers  
**Duration:** 15 minutes

---

## 📋 What's Happening?

Your organization is migrating to a new domain. This is similar to moving offices - everything moves to a new location, but you still have access to all your files and applications.

### What Changes

- ✅ **Login credentials** - New domain name in your username
- ✅ **Computer name** - Your computer will get a new domain
- ✅ **File server addresses** - New paths to shared drives

### What Stays the Same

- ✅ **Your files** - All documents and data preserved
- ✅ **Your email** - Email address stays the same
- ✅ **Applications** - All software works as before
- ✅ **Permissions** - You keep the same access rights

---

## 📅 Migration Schedule

### Timeline

| Date | Activity | What You Need to Do |
|------|----------|---------------------|
| **Day -7** | Announcement | Read this guide |
| **Day -3** | Backup Reminder | Save important files |
| **Day -1** | Final Notice | Close all applications by 6 PM |
| **Day 0** | Migration | Computer will reboot |
| **Day +1** | Support Available | Contact IT if issues |

### Your Migration Time

**Your computer will be migrated:** _______________  
**Expected downtime:** 15-30 minutes  
**IT Support contact:** _______________

---

## 🔐 New Login Information

### Your New Username

**Old:** `OLD-DOMAIN\firstname.lastname`  
**New:** `NEW-DOMAIN\firstname.lastname`

**Example:**
- **Before:** `ACME\john.smith`
- **After:** `CORP\john.smith`

### Your Password

**Your password stays the same!**  
Use the same password you use today.

### First Login Steps

1. **Turn on your computer**
2. **Press:** Ctrl + Alt + Delete
3. **Username:** NEW-DOMAIN\your.username
4. **Password:** (same as before)
5. **Wait:** First login may take 2-3 minutes

**Tip:** Write down your new username on a sticky note until you remember it!

---

## 💾 Before Migration

### 1. Save Your Work (Required)

**Close these applications:**
- [ ] Microsoft Word, Excel, PowerPoint
- [ ] Outlook (save any drafts)
- [ ] Any work-in-progress files
- [ ] Web browsers with unsaved forms

**Do NOT:**
- ❌ Leave documents open
- ❌ Keep "Save As" dialogs open
- ❌ Have files locked

### 2. Backup Personal Files (Recommended)

**Copy to OneDrive or USB:**
- Desktop files
- Downloads folder
- Any non-network files

**Note:** Network files (H:, S: drives) are already backed up by IT.

### 3. Record Important Information

- [ ] Computer name (Settings → System → About)
- [ ] Mapped drives (File Explorer → This PC)
- [ ] Any local printers

---

## 🖥️ During Migration

### What Will Happen

1. **6:00 PM:** IT will start the migration
2. **~5 min:** Computer will begin setup
3. **~5 min:** Computer will reboot
4. **~5 min:** Configuration completes
5. **6:15 PM:** Ready to use

### Your Computer Will

- ✅ Reboot automatically (2-3 times)
- ✅ Show "Configuring..." screens
- ✅ Login to new domain
- ✅ Restore your desktop

**Do NOT:**
- ❌ Turn off your computer
- ❌ Unplug power
- ❌ Press buttons during reboot

### If You're Working Late

**IT will notify you before starting.**

If you need more time:
1. Contact IT immediately
2. Save your work
3. Close applications
4. Let IT know when ready

---

## ✅ After Migration

### First Login Checklist

1. **Login with new username**
   - NEW-DOMAIN\your.username
   - Same password

2. **Verify desktop**
   - All icons present
   - Wallpaper restored
   - Shortcuts working

3. **Check network drives**
   - H: drive (your files)
   - S: drive (shared files)
   - Any department drives

4. **Test printer**
   - Print a test page
   - Verify default printer

5. **Open Outlook**
   - Emails loading
   - Calendar accessible
   - Can send/receive

### New File Server Paths

**Old Network Paths:**
- `\\oldserver\share\`

**New Network Paths:**
- `\\newserver\share\`

**Most shortcuts will update automatically!**

### Mapped Drives

Your mapped drives (H:, S:, etc.) should reconnect automatically.

**If not:**
1. Open File Explorer
2. Click "Map network drive"
3. Select drive letter
4. Enter new path: `\\newserver\sharename`
5. Check "Reconnect at sign-in"
6. Click Finish

---

## 🆘 Common Issues & Solutions

### Issue 1: Can't Login

**Error:** "The trust relationship between this workstation and the primary domain failed"

**Solution:**
1. Restart your computer
2. Try login again
3. If still fails, contact IT

**Do NOT** try more than 3 times (account may lock).

---

### Issue 2: Network Drives Missing

**Symptoms:** H: or S: drive not showing

**Solution:**
1. Click Start → File Explorer
2. Type: `\\newserver\yourfolder`
3. Right-click folder → "Map network drive"
4. Select drive letter
5. Check "Reconnect at sign-in"

**If still missing:** Contact IT with drive letter.

---

### Issue 3: Printer Not Working

**Symptoms:** Can't print or printer missing

**Solution:**
1. Go to Settings → Devices → Printers
2. Click "Add a printer"
3. Select your printer from list
4. Set as default if needed

**If not listed:** Contact IT with printer name.

---

### Issue 4: Outlook Not Loading

**Symptoms:** "Cannot connect to Exchange"

**Solution:**
1. Close Outlook completely
2. Wait 30 seconds
3. Open Outlook again
4. Wait 2-3 minutes for sync

**Still not working?** Restart computer, then try again.

---

### Issue 5: Can't Access Shared Folder

**Symptoms:** "You don't have permission"

**Solution:**
1. Note exact folder path
2. Note exact error message
3. Contact IT (permissions may need adjustment)

**Timeframe:** Usually fixed within 1 hour.

---

## 📞 Getting Help

### Self-Service

1. **Check this guide** (you're reading it!)
2. **Restart your computer** (fixes 50% of issues)
3. **Wait 30 minutes** (profiles syncing)

### IT Support

**Contact IT if:**
- Can't login after 3 tries
- Network drives missing after 1 hour
- Applications not working
- Any error messages

**How to Contact:**
- **Phone:** ________________
- **Email:** it-support@company.com
- **Portal:** https://helpdesk.company.com
- **Teams:** #it-support

**When calling, have ready:**
- Your username
- Computer name
- Exact error message (take photo if possible)
- What you were trying to do

---

## 💡 Tips & Tricks

### Speed Up First Login

- Use wired network (not WiFi) if possible
- First login slower (profile copying)
- Subsequent logins normal speed

### Bookmarks & Shortcuts

- Bookmark new file server paths
- Update shortcuts on desktop
- Save frequently-used folders to Quick Access

### Password Reminders

- Same password as before
- Only username changes (adds NEW-DOMAIN\)
- Password expiration unchanged

### Working from Home

**VPN:**
- Use same VPN software
- Connect before logging in
- Username format: NEW-DOMAIN\your.username

**Remote Desktop:**
- New computer name: `computername.new.local`
- Everything else same

---

## ❓ Frequently Asked Questions

### Q: Will I lose my files?

**A:** No! All files are backed up and will be restored. Network files never leave the server.

---

### Q: Do I need a new password?

**A:** No! Keep using your current password. Only the domain name in your username changes.

---

### Q: How long will my computer be down?

**A:** Typically 15-30 minutes. Actual time depends on profile size and network speed.

---

### Q: Can I work during the migration?

**A:** No. Save all work and close applications before 6 PM on migration day.

---

### Q: What if I'm on vacation during migration?

**A:** Contact IT before you leave. Your computer can be migrated while you're away.

---

### Q: Will my applications still work?

**A:** Yes! All applications remain installed and configured.

---

### Q: What about my Outlook emails?

**A:** All emails, calendar, and contacts are stored on Exchange server. Nothing changes.

---

### Q: Can I postpone my migration?

**A:** Contact your manager and IT at least 3 days before scheduled date. Limited postponements available.

---

### Q: What if I forget my new username?

**A:** It's the same as your old one, just with NEW-DOMAIN\ instead of OLD-DOMAIN\. Contact IT if unsure.

---

### Q: Will my mobile devices be affected?

**A:** No. Phones, tablets, and other mobile devices are not affected.

---

## ✅ Quick Reference Card

**Print this page and keep at your desk!**

```
┌─────────────────────────────────────────────────┐
│         DOMAIN MIGRATION QUICK REFERENCE        │
├─────────────────────────────────────────────────┤
│                                                 │
│  NEW USERNAME: NEW-DOMAIN\firstname.lastname    │
│  PASSWORD: (same as before)                     │
│                                                 │
│  NEW FILE SERVER: \\newserver\                  │
│                                                 │
│  MIGRATION DATE: _______________                │
│  MIGRATION TIME: 6:00 PM - 6:30 PM              │
│                                                 │
│  BEFORE MIGRATION:                              │
│  □ Save all work                                │
│  □ Close all applications                       │
│  □ Leave computer on                            │
│                                                 │
│  AFTER MIGRATION:                               │
│  □ Login with NEW-DOMAIN\username               │
│  □ Verify desktop & files                       │
│  □ Test email & printer                         │
│  □ Report any issues to IT                      │
│                                                 │
│  IT SUPPORT:                                    │
│  Phone: _______________                         │
│  Email: it-support@company.com                  │
│  Portal: https://helpdesk.company.com           │
│                                                 │
└─────────────────────────────────────────────────┘
```

---

## 🎓 Summary

### Remember

1. **Username changes** - Add NEW-DOMAIN\
2. **Password stays same** - Use current password
3. **Save all work** - Close apps before 6 PM
4. **First login slower** - Be patient (2-3 min)
5. **IT is here to help** - Contact for any issues

### Stay Calm

This is a routine IT operation. Thousands of similar migrations happen successfully every year. Our IT team has:

- ✅ Tested thoroughly
- ✅ Created backups
- ✅ Planned for issues
- ✅ Available for support

**You've got this!** 💪

---

**Thank you for your cooperation during this migration!**

If you have questions not covered in this guide, please contact IT Support.

**Version:** 1.0  
**Last Updated:** January 2025  
**IT Department**

