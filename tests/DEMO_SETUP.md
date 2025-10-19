# 🧪 Integration Test Suite - Setup & Demo Guide

## Quick Setup (5 minutes)

### 1. Install Pester

Open PowerShell **as Administrator** and run:

```powershell
# Install NuGet provider
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

# Trust PSGallery
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

# Install Pester 5.x
Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
```

### 2. Verify Installation

```powershell
# Check Pester version
Get-Module -ListAvailable -Name Pester

# Should show version 5.x.x
```

### 3. Create Test Directories

```powershell
# Create required directories
New-Item -Path "C:\ADMT\Batches" -ItemType Directory -Force
New-Item -Path "C:\ADMT\Logs" -ItemType Directory -Force
New-Item -Path "C:\ADMT\Reports" -ItemType Directory -Force
New-Item -Path "C:\Temp\FileServerTest" -ItemType Directory -Force
```

---

## 🚀 Running Tests

### Fast Tests (< 5 minutes)

```powershell
cd "C:\Users\adria\OneDrive\Documents\GitHub\Auto Domain Migration\tests"
.\scripts\Invoke-AllTests.ps1 -TestSuite Fast -Verbosity Normal
```

**Expected Output:**
```
========================================
  Integration Test Suite Runner
========================================
Suite: Fast
Output: .\TestResults
Time: 2024-01-15 14:30:00
========================================

========================================
  Running: Fast Tests
  Fast tests (< 5 min)
========================================

Starting discovery in 3 files.
Discovery found 45 tests in 250ms.
Running tests.

Running tests from 'Test-ADMTMigration.Tests.ps1'
[+] ADMT Module 2.1s (2.0s|78ms)
[+] Prerequisites Validation 1.5s (1.4s|102ms)
[+] Migration Batch Creation 1.8s (1.7s|92ms)
[+] Migration Status 0.8s (750ms|43ms)
[+] Report Generation 1.2s (1.1s|89ms)
[!] Rollback Functionality 0.5s (450ms|28ms)
  [!] Should require Force parameter 28ms (18ms|10ms)

Tests completed in 8.2s
Tests Passed: 44, Failed: 0, Skipped: 1, Total: 45, NotRun: 0

========================================
  Fast Test Results
========================================
Total Tests: 45
Passed: 44
Failed: 0
Skipped: 1
Duration: 00:08
Code Coverage: 87.5%
========================================

========================================
  OVERALL TEST SUMMARY
========================================
✅ Fast : 44/45 passed

----------------------------------------
Total Tests: 45
Passed: 44
Failed: 0
Skipped: 1
Total Duration: 00:00:08
========================================

✅ All tests PASSED
```

---

### Unit Tests Only

```powershell
.\scripts\Invoke-AllTests.ps1 -TestSuite Unit -Verbosity Detailed
```

**What runs:**
- ADMT module function tests
- Parameter validation
- Error handling
- Output verification

**Duration:** ~2-3 minutes

---

### Integration Tests

```powershell
.\scripts\Invoke-AllTests.ps1 -TestSuite Integration -GenerateReport
```

**What runs:**
- ADMT migration workflow
- File server operations
- Data integrity checks
- Performance benchmarks

**Duration:** ~5-8 minutes

**Generates:**
- `TestResults/Integration-results-TIMESTAMP.xml`
- `TestResults/Integration-coverage-TIMESTAMP.xml`
- `TestResults/TestReport-TIMESTAMP.html` (opens in browser)

---

### Infrastructure Tests (Requires Azure)

```powershell
# Login to Azure first
Connect-AzAccount

# Run infrastructure validation
.\scripts\Invoke-AllTests.ps1 -TestSuite Infrastructure
```

**What runs:**
- Azure resource verification
- VM deployment checks
- Network validation
- Security compliance
- Cost analysis

**Duration:** ~3-5 minutes

---

### All Tests

```powershell
.\scripts\Invoke-AllTests.ps1 -TestSuite All -GenerateReport -Verbosity Normal
```

**What runs:**
- Unit tests (26 tests)
- Integration tests (40 tests)
- Infrastructure tests (50 tests)
- E2E tests (25 tests, most skipped)

**Duration:** ~15-20 minutes

---

## 📊 Understanding Test Results

### Test Status Indicators

- **[+]** - Test passed ✅
- **[-]** - Test failed ❌
- **[!]** - Test skipped ⏭️
- **[?]** - Test inconclusive

### Common Skip Reasons

```
"Not authenticated to Azure"          # Need: Connect-AzAccount
"AD not available"                     # Need: Active Directory access
"ADMT module not available"            # Need: ADMT installed
"Source server not reachable"          # Need: Infrastructure deployed
"Tier 2 not deployed"                  # Optional tier
```

### Exit Codes

- **0** - All tests passed
- **1** - One or more tests failed

---

## 🎨 HTML Report Example

When you run with `-GenerateReport`, you get a beautiful HTML report:

```html
====================================
🧪 Integration Test Report
====================================

Overall Summary
------------------------------------
Total Tests: 150
Passed: 147 ✅
Failed: 0 ❌
Skipped: 3 ⏭️
Duration: 00:15:23
Timestamp: 2024-01-15 14:45:23

Unit Tests
------------------------------------
Total: 26
Passed: 24 ✅
Failed: 0 ❌
Skipped: 2 ⏭️
Pass Rate: 92.3%

Integration Tests
------------------------------------
Total: 40
Passed: 40 ✅
Failed: 0 ❌
Skipped: 0 ⏭️
Pass Rate: 100%

Infrastructure Tests
------------------------------------
Total: 50
Passed: 48 ✅
Failed: 0 ❌
Skipped: 2 ⏭️
Pass Rate: 96%

E2E Tests
------------------------------------
Total: 34
Passed: 3 ✅
Failed: 0 ❌
Skipped: 31 ⏭️
Pass Rate: 100% (of enabled tests)
```

---

## 🧹 Cleanup After Testing

```powershell
# Preview what will be removed
.\scripts\Reset-TestEnvironment.ps1 -WhatIf

# Clean up test files
.\scripts\Reset-TestEnvironment.ps1

# Full cleanup (with confirmation)
.\scripts\Reset-TestEnvironment.ps1 -IncludeAD -IncludeAzure
```

---

## 🐛 Troubleshooting

### Issue: "Pester module not found"

**Solution:**
```powershell
Install-Module -Name Pester -MinimumVersion 5.0.0 -Force
```

### Issue: "Cannot access C:\ADMT"

**Solution:**
```powershell
# Run as Administrator or create directory
New-Item -Path "C:\ADMT\Batches" -ItemType Directory -Force
```

### Issue: "All tests skipped"

**Cause:** Infrastructure not deployed or not accessible

**Solutions:**
- Deploy infrastructure first (Terraform)
- Authenticate to Azure (`Connect-AzAccount`)
- Ensure DNS resolution working
- Check network connectivity

### Issue: "NuGet provider error"

**Solution:**
```powershell
# Run as Administrator
Install-PackageProvider -Name NuGet -Force
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
```

---

## 🎯 What Each Test Suite Does

### Fast Suite (< 5 min)
✅ Unit tests
✅ Quick validation
✅ Non-destructive checks
✅ Module loading
✅ Function signatures

### Integration Suite (5-8 min)
✅ ADMT workflow
✅ File server operations
✅ Batch creation/deletion
✅ Report generation
✅ Status monitoring

### Infrastructure Suite (3-5 min)
✅ Azure resource existence
✅ VM deployment status
✅ Network configuration
✅ Security settings
✅ Cost tags

### E2E Suite (15-30 min)
⏭️ Complete migration (mostly skipped for safety)
⏭️ Test data generation
⏭️ Trust configuration
⏭️ File server migration
⏭️ Post-migration validation

---

## 📈 Success Criteria

Your test run was successful if:

```
✅ Exit code: 0
✅ Failed tests: 0
✅ Pass rate: > 95%
✅ Code coverage: > 80% (for ADMT module)
✅ Duration: < expected time
✅ No errors in output
```

---

## 🚀 Next Steps

After running tests successfully:

1. **Review HTML report** - Opens automatically with `-GenerateReport`
2. **Check code coverage** - Look at coverage XML files
3. **Address any skipped tests** - Deploy missing infrastructure
4. **Run in CI/CD** - Tests run automatically on push/PR
5. **Integrate with monitoring** - Track test metrics over time

---

## 💡 Pro Tips

### Faster Test Iterations

```powershell
# Test single file
Invoke-Pester -Path .\integration\Test-ADMTMigration.Tests.ps1

# Test specific function
$config = New-PesterConfiguration
$config.Filter.FullName = "*Should create migration batch*"
Invoke-Pester -Configuration $config
```

### Code Coverage for Specific File

```powershell
$config = New-PesterConfiguration
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = "..\ansible\files\ADMT-Functions.psm1"
$result = Invoke-Pester -Configuration $config
$result.CodeCoverage.CoveragePercent
```

### Debug Mode

```powershell
# Enable detailed Pester output
$config = New-PesterConfiguration
$config.Output.Verbosity = "Detailed"
$config.Debug.WriteDebugMessages = $true
Invoke-Pester -Configuration $config
```

---

## 📞 Need Help?

1. Check `tests/README.md` for full documentation
2. Review test output for specific errors
3. Use `-Verbosity Detailed` for more information
4. Check GitHub Issues
5. Review Pester documentation: https://pester.dev

---

**Ready to test?** Run the Fast suite first! ⚡

```powershell
cd tests
.\scripts\Invoke-AllTests.ps1 -TestSuite Fast
```

🎉 **Happy Testing!**

