# CI/CD Workflows

Automated testing and deployment pipelines for the Auto Domain Migration solution.

## 📋 Available Workflows

### 🔍 Code Quality & Testing

| Workflow | Trigger | Purpose | Duration |
|----------|---------|---------|----------|
| **terraform-validate.yml** | Push/PR to terraform/** | Validate Terraform configurations | ~5 min |
| **powershell-tests.yml** | Push/PR to **.ps1, **.psm1 | Run PowerShell linting and Pester tests | ~8 min |
| **ansible-lint.yml** | Push/PR to ansible/** | Lint Ansible playbooks and roles | ~3 min |
| **pr-validation.yml** | Pull Request | Comprehensive PR validation | ~15 min |

### 🚀 Deployment

| Workflow | Trigger | Purpose | Duration |
|----------|---------|---------|----------|
| **deploy-tier1.yml** | Manual (workflow_dispatch) | Deploy Tier 1 (Demo) infrastructure | ~20 min |

---

## 🔧 Terraform Validation Workflow

**File:** `terraform-validate.yml`

### What it does:
1. **Format Check** - Ensures all `.tf` files are properly formatted
2. **Validation** - Validates Terraform syntax and configuration
3. **TFLint** - Additional linting for best practices
4. **Documentation Check** - Ensures README and examples exist
5. **Security Scan** - Runs tfsec for security issues
6. **Cost Estimation** - Estimates infrastructure costs (on PRs)

### Jobs:
- `terraform-fmt` - Format checking
- `terraform-validate` - Syntax validation
- `tflint` - Linting
- `terraform-docs` - Documentation check
- `terraform-security` - Security scanning with tfsec
- `terraform-cost` - Cost estimation with Infracost
- `summary` - Results summary

### Matrix Strategy:
Runs against all tiers:
- `azure-free-tier`
- `azure-tier2`
- `azure-tier3`

### Required Secrets:
- `INFRACOST_API_KEY` (optional, for cost estimation)

---

## 💻 PowerShell Tests Workflow

**File:** `powershell-tests.yml`

### What it does:
1. **PSScriptAnalyzer** - Lints all PowerShell files
2. **Pester Tests** - Runs unit tests with code coverage
3. **Cross-Platform Tests** - Tests on Windows, Linux, macOS

### Jobs:
- `pslint` - PSScriptAnalyzer linting
- `pester-tests` - Unit tests with coverage
- `powershell-matrix` - Cross-platform syntax checking
- `summary` - Results summary

### Test Matrix:
- **OS:** windows-latest, ubuntu-latest, macos-latest
- **PowerShell:** 7.3, 7.4

### Artifacts:
- `pslint-results` - Linting results JSON
- `pester-test-results` - Test results XML with coverage

---

## ⚙️ Ansible Lint Workflow

**File:** `ansible-lint.yml`

### What it does:
1. **ansible-lint** - Lints playbooks and roles
2. **yamllint** - Validates YAML syntax
3. **Syntax Check** - Checks playbook syntax
4. **Inventory Validation** - Validates inventory files

### Jobs:
- `ansible-lint` - Ansible-specific linting
- `yaml-lint` - YAML syntax validation
- `ansible-syntax` - Playbook syntax checking
- `ansible-inventory` - Inventory file validation
- `summary` - Results summary

### Configuration:
- Custom yamllint rules (200 char line length, specific indentation)
- PEP8 format output for easy parsing

---

## 🔎 PR Validation Workflow

**File:** `pr-validation.yml`

### What it does:
Comprehensive validation of pull requests including:
1. **File Change Detection** - Identifies what was changed
2. **Conditional Testing** - Runs relevant tests based on changes
3. **PR Size Analysis** - Categorizes PR size
4. **Documentation Check** - Ensures docs are updated
5. **Security Scanning** - Trivy and Trufflehog
6. **Commit Quality** - Checks for conventional commits

### Jobs:
- `pr-info` - Display PR information
- `file-changes` - Detect what files changed
- `terraform-check` - Conditional Terraform validation
- `powershell-check` - Conditional PowerShell tests
- `ansible-check` - Conditional Ansible linting
- `pr-size` - Analyze PR size
- `documentation-check` - Check for doc updates and broken links
- `security-scan` - Security vulnerability scanning
- `commit-quality` - Analyze commit messages
- `summary` - Overall summary

### Change Detection:
Automatically detects changes in:
- Terraform files
- PowerShell files
- Ansible files
- Documentation
- Helm charts

### PR Size Categories:
- **Small:** ≤5 files, ≤100 lines
- **Medium:** ≤20 files, ≤500 lines
- **Large:** ≤50 files, ≤1000 lines
- **Extra Large:** >50 files or >1000 lines (warning issued)

---

## 🚀 Deploy Tier 1 Workflow

**File:** `deploy-tier1.yml`

### What it does:
Automated deployment of Tier 1 (Demo) infrastructure to Azure.

### Inputs:
- `azure_subscription` - Azure Subscription ID (required)
- `resource_group` - Resource Group Name (default: admt-tier1-rg)
- `location` - Azure Region (default: eastus)
- `destroy` - Destroy after deployment (for testing, default: false)

### Jobs:
- `validate` - Validate Terraform configuration
- `plan` - Create Terraform plan
- `apply` - Apply infrastructure (requires approval)
- `destroy` - Optional destruction (if destroy=true)

### Environments:
- `tier1-demo` - Production deployment (requires approval)
- `tier1-demo-destroy` - Destruction (requires approval)

### Artifacts:
- `tfplan-tier1` - Terraform plan file
- `terraform-outputs-tier1` - Infrastructure outputs

### Required Secrets:
- `AZURE_CREDENTIALS` - Azure service principal credentials
- `TF_STATE_STORAGE_ACCOUNT` - Storage account for Terraform state

---

## 🔐 Required Secrets

Configure these in GitHub Settings → Secrets and variables → Actions:

### Azure Credentials
```json
{
  "clientId": "your-client-id",
  "clientSecret": "your-client-secret",
  "subscriptionId": "your-subscription-id",
  "tenantId": "your-tenant-id"
}
```

### Terraform State Storage
- `TF_STATE_STORAGE_ACCOUNT` - Azure Storage Account name for Terraform state

### Optional Secrets
- `INFRACOST_API_KEY` - For cost estimation (free at infracost.io)

---

## 📊 Status Badges

Add these to your README.md:

```markdown
![Terraform Validation](https://github.com/yourusername/auto-domain-migration/workflows/Terraform%20Validation/badge.svg)
![PowerShell Tests](https://github.com/yourusername/auto-domain-migration/workflows/PowerShell%20Tests/badge.svg)
![Ansible Lint](https://github.com/yourusername/auto-domain-migration/workflows/Ansible%20Lint/badge.svg)
```

---

## 🎯 Best Practices

### For Contributors

1. **Run Local Tests First**
   ```bash
   # Terraform
   cd terraform/azure-tier2
   terraform fmt -recursive
   terraform validate
   
   # PowerShell
   Invoke-ScriptAnalyzer -Path . -Recurse
   Invoke-Pester
   
   # Ansible
   ansible-lint ansible/
   ```

2. **Write Conventional Commits**
   ```
   feat: add new ADMT function
   fix: resolve DNS migration issue
   docs: update deployment guide
   ci: improve terraform validation
   ```

3. **Keep PRs Small**
   - Aim for <20 files, <500 lines
   - One feature/fix per PR
   - Update documentation in the same PR

4. **Test Cross-Platform**
   - PowerShell scripts should work on Windows, Linux, macOS
   - Use `$PSVersionTable` to check PowerShell version

### For Maintainers

1. **Protect Main Branch**
   - Require PR reviews
   - Require status checks to pass
   - No direct pushes

2. **Use Environments**
   - `tier1-demo` - Requires approval
   - `tier2-production` - Requires approval
   - `tier3-enterprise` - Requires approval + 2 reviewers

3. **Monitor Workflow Costs**
   - GitHub Actions minutes are limited on free plans
   - Use `workflow_dispatch` for manual deployments
   - Cache dependencies where possible

---

## 🐛 Troubleshooting

### Workflow Fails on Terraform Init

**Issue:** Backend configuration not found

**Solution:** Ensure secrets are configured:
```yaml
TF_STATE_STORAGE_ACCOUNT: "yourstorageaccount"
```

### PowerShell Tests Timeout

**Issue:** Tests take too long

**Solution:** Increase timeout or split into multiple jobs:
```yaml
timeout-minutes: 30
```

### Ansible Lint False Positives

**Issue:** ansible-lint reports issues that aren't relevant

**Solution:** Add skip rules to `.ansible-lint`:
```yaml
skip_list:
  - role-name
  - no-handler
```

### PR Validation Runs on Every File

**Issue:** All checks run even for doc changes

**Solution:** The workflow uses path filters - ensure they're working:
```yaml
if: needs.file-changes.outputs.terraform == 'true'
```

---

## 📚 Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Terraform GitHub Actions](https://learn.hashicorp.com/tutorials/terraform/github-actions)
- [PSScriptAnalyzer Rules](https://github.com/PowerShell/PSScriptAnalyzer/tree/master/RuleDocumentation)
- [Ansible Lint Rules](https://ansible-lint.readthedocs.io/rules/)
- [Conventional Commits](https://www.conventionalcommits.org/)

---

## 🔄 Workflow Updates

### Version History

**v1.0** (Initial Release)
- Terraform validation
- PowerShell testing
- Ansible linting
- PR validation
- Tier 1 deployment

### Planned Enhancements

- [ ] Tier 2 & 3 deployment workflows
- [ ] Automated release notes generation
- [ ] Slack/Teams notifications
- [ ] Integration test workflows
- [ ] Performance benchmarking
- [ ] Automated dependency updates (Dependabot)

---

**Questions?** Open an issue or check the main README.md 🚀

