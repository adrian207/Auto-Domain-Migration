# 🧪 Testing Guide - Quick Start

Get your integration test suite running in **5 minutes**!

---

## 🚀 Quick Start (Easiest Method)

### **Step 1: Open PowerShell as Administrator**

1. Press `Windows Key`
2. Type `PowerShell`
3. **Right-click** on "Windows PowerShell"
4. Select **"Run as Administrator"**

### **Step 2: Navigate to Tests Directory**

```powershell
cd "C:\Users\adria\OneDrive\Documents\GitHub\Auto Domain Migration\tests"
```

### **Step 3: Run Quick Start Script**

```powershell
.\QUICK_START.ps1
```

That's it! The script will:
- ✅ Check prerequisites
- ✅ Install Pester if needed
- ✅ Create test directories
- ✅ Run the Fast test suite
- ✅ Generate HTML report
- ✅ Open results in browser

---

## 📊 Expected Output

```
╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║          🧪 Integration Test Suite - Quick Start                    ║
║                                                                      ║
║          Auto Domain Migration Solution v4.0                        ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝

📋 Step 1: Checking Prerequisites...
----------------------------------------
PowerShell Version: 7.4.0
✅ PowerShell version OK
✅ Pester 5.5.0 installed

📁 Step 2: Creating Test Directories...
----------------------------------------
  Created: C:\ADMT\Batches
  Created: C:\ADMT\Logs
  Created: C:\ADMT\Reports
  Created: C:\Temp\FileServerTest
✅ Test directories ready

📄 Step 3: Verifying Test Files...
----------------------------------------
  ✅ Test-AzureInfrastructure.Tests.ps1
  ✅ Test-ADMTMigration.Tests.ps1
  ✅ Test-FileServerMigration.Tests.ps1
  ✅ Test-EndToEndMigration.Tests.ps1
✅ All test files found

🧪 Step 4: Running Tests (Fast suite)...
----------------------------------------

========================================
  Integration Test Suite Runner
========================================
Suite: Fast
Output: .\TestResults
Time: 2024-01-15 14:30:00
========================================

Running tests...
[+] ADMT Module (7 tests) - 2.1s
[+] Prerequisites Validation (3 tests) - 1.5s
[+] Migration Batch Creation (5 tests) - 1.8s
[+] Migration Status (3 tests) - 0.8s
[+] Report Generation (3 tests) - 1.2s
[+] File Data Validation (2 tests) - 0.9s

========================================
  OVERALL TEST SUMMARY
========================================
✅ Fast : 23/25 passed

Total Tests: 25
Passed: 23
Failed: 0
Skipped: 2
Duration: 00:00:08
========================================

╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║                    ✅ ALL TESTS PASSED! 🎉                          ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝

📊 Test Results:
  Location: C:\Users\adria\...\tests\TestResults
  HTML Report: TestReport-20240115_143023.html
  
  Opening HTML report in browser...
```

---

## 🎯 Alternative: Run Specific Test Suites

### **Fast Tests** (< 5 minutes)
```powershell
.\QUICK_START.ps1 -TestSuite Fast
```

### **Unit Tests Only**
```powershell
.\QUICK_START.ps1 -TestSuite Unit
```

### **Integration Tests**
```powershell
.\QUICK_START.ps1 -TestSuite Integration
```

### **All Tests** (15+ minutes)
```powershell
.\QUICK_START.ps1 -TestSuite All
```

---

## 🔧 Manual Setup (If Script Fails)

### **1. Install Pester Manually**

```powershell
# Run as Administrator
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
```

### **2. Verify Installation**

```powershell
Get-Module -ListAvailable -Name Pester
# Should show version 5.x.x
```

### **3. Create Directories**

```powershell
New-Item -Path "C:\ADMT\Batches" -ItemType Directory -Force
New-Item -Path "C:\ADMT\Logs" -ItemType Directory -Force
New-Item -Path "C:\ADMT\Reports" -ItemType Directory -Force
New-Item -Path "C:\Temp\FileServerTest" -ItemType Directory -Force
```

### **4. Run Tests**

```powershell
cd "C:\Users\adria\OneDrive\Documents\GitHub\Auto Domain Migration\tests"
.\scripts\Invoke-AllTests.ps1 -TestSuite Fast -GenerateReport
```

---

## 🐛 Troubleshooting

### **Issue: "Cannot install NuGet provider"**

**Solution:**
```powershell
# Run PowerShell as Administrator
# Then try again
Install-PackageProvider -Name NuGet -Force
```

### **Issue: "Execution policy prevents script"**

**Solution:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### **Issue: "Pester module not found"**

**Solution:**
```powershell
# Ensure you're installing version 5.x
Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser -SkipPublisherCheck

# Verify
Get-Module -ListAvailable -Name Pester
```

### **Issue: "Access denied to C:\ADMT"**

**Solution:**
```powershell
# Create directories manually as Administrator
New-Item -Path "C:\ADMT\Batches" -ItemType Directory -Force
```

### **Issue: "Tests are all skipped"**

**This is normal!** Many tests skip because:
- Azure resources not deployed yet
- Domain controllers not accessible
- File servers not running

**Run anyway to see the framework in action!**

---

## 📈 Understanding Test Results

### **Test Status:**
- **[+]** = Test Passed ✅
- **[-]** = Test Failed ❌
- **[!]** = Test Skipped ⏭️

### **Common Skip Reasons:**
```
"Not authenticated to Azure"        → Need to run Connect-AzAccount
"AD not available"                  → Need Active Directory access
"ADMT module not available"         → ADMT not installed (expected)
"Source server not reachable"       → Infrastructure not deployed yet
```

### **What "Success" Looks Like:**

Even with skipped tests, if you see:
- ✅ **Failed: 0**
- ✅ **Exit Code: 0**
- ✅ Tests that did run all passed

**That's a success!** 🎉

---

## 🎨 HTML Report

The HTML report will automatically open and show:

- 📊 **Overall Summary** - Pass/fail statistics
- 📈 **Test Categories** - Unit, Integration, Infrastructure, E2E
- ⏱️ **Duration** - How long each suite took
- 📝 **Test Details** - Individual test results
- 📦 **Artifacts** - Links to XML results and coverage files

---

## 🚀 Next Steps After Running Tests

### **Option 1: Deploy Infrastructure**
```bash
cd terraform/azure-tier1
terraform init
terraform plan
terraform apply
```

Then re-run tests to see **real infrastructure validation**!

### **Option 2: Run More Test Suites**
```powershell
# Try integration tests
.\QUICK_START.ps1 -TestSuite Integration

# Or run everything
.\QUICK_START.ps1 -TestSuite All
```

### **Option 3: Examine Test Files**
```powershell
# Open test files to see what they validate
code infrastructure\Test-AzureInfrastructure.Tests.ps1
code integration\Test-ADMTMigration.Tests.ps1
```

### **Option 4: Customize Tests**
- Edit test files to add your own scenarios
- Adjust skip conditions
- Add new test cases

---

## 📞 Need Help?

### **Documentation:**
- `tests/README.md` - Complete test documentation
- `tests/DEMO_SETUP.md` - Detailed setup guide
- `tests/DEMO_OUTPUT.txt` - Example output
- `PROJECT_STATUS.md` - Overall project status

### **Common Commands:**
```powershell
# Run fast tests
.\QUICK_START.ps1

# Run with more detail
.\scripts\Invoke-AllTests.ps1 -TestSuite Fast -Verbosity Detailed

# Clean up test environment
.\scripts\Reset-TestEnvironment.ps1 -WhatIf

# Run single test file
Invoke-Pester -Path .\integration\Test-ADMTMigration.Tests.ps1
```

---

## ✨ What You're Testing

Your test suite validates:

### **✅ Unit Tests (26 tests)**
- PowerShell module loading
- Function signatures
- Parameter validation
- Error handling
- Output correctness

### **✅ Integration Tests (40 tests)**
- ADMT workflow
- Batch creation/management
- File operations
- Data integrity
- Performance benchmarks

### **✅ Infrastructure Tests (50 tests)**
- Azure resources (all 3 tiers)
- VMs, networking, storage
- Security configurations
- Cost tagging

### **✅ E2E Tests (34 tests)**
- Complete migration workflow
- 7-phase validation
- Safety controls

**Total: 150+ tests ensuring your solution works!**

---

## 🎉 Ready?

**Let's run it!**

```powershell
cd "C:\Users\adria\OneDrive\Documents\GitHub\Auto Domain Migration\tests"
.\QUICK_START.ps1
```

**Enjoy watching your tests pass!** ✅

---

**Questions?** Check the other documentation files or run with `-Verbosity Detailed` for more information! 🚀

