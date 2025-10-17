# GitHub Repository Migration Action

Automate the migration of repositories between GitHub Enterprise Cloud (GHEC) instances using GitHub Actions and PowerShell.

## 📖 What This Does

This workflow automates the complete migration of Git repositories from one GitHub Enterprise Cloud (GHEC) instance to another. It:

- **Clones repositories** from source organizations using `git clone --mirror`
- **Creates destination repositories** in target organizations with matching settings
- **Pushes complete history** to destination using `git push --mirror`
- **Preserves everything**:
  - ✅ All commits with original authors and dates
  - ✅ All branches and tags
  - ✅ Complete commit history and metadata
  - ✅ Repository settings (description, visibility, features)

**What it does NOT migrate:**
- ❌ Issues, Pull Requests, or Discussions
- ❌ GitHub Actions secrets or variables
- ❌ Branch protection rules or repository settings
- ❌ Webhooks or GitHub Apps integrations

For those items, use [GitHub's official migration tools](https://docs.github.com/en/migrations) (GEI/Importer).

## 🎯 Why Use This Workflow?

### Perfect For:

✅ **Enterprise Managed Users (EMU) Migrations**
- Migrating from standard GHEC to EMU instances
- Moving repositories between different EMU enterprises
- Consolidating organizations within the same enterprise

✅ **Bulk Repository Migrations**
- Migrate multiple organizations at once
- Automated, repeatable process
- Can be scheduled or triggered on-demand

✅ **Code-Only Migrations**
- When you only need the Git history (code, commits, branches, tags)
- When issues/PRs will be handled separately
- When starting fresh with new workflow configurations

✅ **Testing & Validation**
- Dry-run mode lets you test without making changes
- Comprehensive logging for auditing
- Validates access and permissions before migrating

### Key Benefits:

🚀 **Automated** - No manual git commands, runs entirely in GitHub Actions
🔒 **Secure** - Uses GitHub Secrets for PATs, no credentials in code
📊 **Transparent** - Real-time logs and detailed migration artifacts
🔄 **Repeatable** - Consistent process across multiple organizations
✅ **Safe** - Dry-run mode and validation before actual migration
🎯 **Flexible** - Custom organization mappings and selective migrations

### When NOT to Use This:

❌ **Need full migration** (issues, PRs, etc.) - Use [GitHub Enterprise Importer (GEI)](https://docs.github.com/en/migrations/using-github-enterprise-importer)
❌ **Migrating from other platforms** (GitLab, Bitbucket) - Use platform-specific importers
❌ **Small one-off migrations** - Manual git commands might be faster
❌ **Need to preserve GitHub-specific metadata** - Use GEI or official migration API

## � Common Use Cases

### Scenario 1: EMU Migration
**Situation**: Your organization is moving from standard GHEC to Enterprise Managed Users (EMU)

**Why this workflow**: 
- Handles the complexity of EMU authentication and SSO
- Validates EMU-specific permissions before migrating
- Can migrate multiple organizations simultaneously
- Preserves complete Git history with original authors

### Scenario 2: Enterprise Consolidation
**Situation**: Merging multiple GitHub enterprises into one EMU instance

**Why this workflow**:
- Automates repetitive migration tasks
- Consistent naming conventions (org-name → org-name-emu)
- Dry-run mode for testing organization mappings
- Detailed logs for compliance and audit requirements

### Scenario 3: Repository Reorganization
**Situation**: Moving repositories between organizations within same enterprise

**Why this workflow**:
- Flexible organization mapping
- Can migrate specific repositories or entire organizations
- Safe testing with dry-run mode
- No manual git command errors

### Scenario 4: Disaster Recovery / Backup
**Situation**: Creating mirrors of critical repositories in a separate enterprise

**Why this workflow**:
- Scheduled automation via GitHub Actions
- Complete repository replication including all branches
- Can be run periodically to keep mirrors updated
- Verification and logging for audit trails

## �🚀 Quick Start

### 1. Create Personal Access Tokens (PATs)

#### For EMU Organizations (Important!)
- **Create destination PAT using an EMU account** (not regular GitHub account)
- **Authorize PAT for SSO**: Go to Settings → Developer settings → Personal access tokens → Configure SSO
- **Verify organization membership**: Ensure EMU user is member/admin of destination organizations

#### Required Scopes:
- **Source PAT**: `repo`, `read:org`
- **Destination PAT**: `repo`, `admin:org`, `workflow`

### 2. Setup Repository Secrets

In your GitHub repository, go to **Settings > Secrets and variables > Actions** and add:

- `SOURCE_PAT` - Personal Access Token for source GitHub instance
- `DESTINATION_PAT` - Personal Access Token for destination GitHub instance (must be EMU account for EMU orgs)
- `SOURCE_ENTERPRISE` - Source enterprise name (e.g., "org1-enterprise")
- `DESTINATION_ENTERPRISE` - Destination enterprise name (e.g., "org1-enterprise-emu")

### 2. Run the Action

1. Go to the **Actions** tab in your repository
2. Select **GitHub Repository Migration** workflow
3. Click **Run workflow**
4. Configure the parameters:
   - **Dry Run**: Choose `true` for testing (recommended first run)
   - **Source Organizations**: Leave empty for defaults or specify comma-separated list
   - **Destination Organizations**: Leave empty for defaults or specify comma-separated list
   - **Working Directory**: Directory for temporary files (default: `./temp-migration`)

## 📋 Features

- ✅ **Secure PAT Handling**: Uses GitHub secrets for Personal Access Tokens
- ✅ **Dry Run Mode**: Test migrations safely without making changes
- ✅ **Organization Discovery**: Automatically discover all organizations and repositories in an enterprise
- ✅ **Custom Organizations**: Override default organization mappings
- ✅ **Comprehensive Logging**: Detailed logs uploaded as artifacts
- ✅ **Error Handling**: Proper error reporting and exit codes
- ✅ **Windows Runner**: Uses Windows latest for PowerShell compatibility

## 🔧 Configuration

### Default Organization Mapping

The action uses these default mappings:

| Source Organizations | Destination Organizations |
|---------------------|---------------------------|
| org1-ds | org1-ds-emu |
| org1-la | org1-la-emu |
| org1-rpa | org1-rpa-emu |
| org1-ams | org1-ams-emu |

### Custom Organizations

To use different organizations, specify them in the workflow inputs:

```
Source Organizations: my-org1,my-org2,my-org3
Destination Organizations: my-org1-new,my-org2-new,my-org3-new
```

### Required PAT Permissions

#### Source PAT (GITHUB_SOURCE_PAT):
- ✅ `repo` - Full control of private repositories (read access needed)
- ✅ `read:org` - Read organization membership and data

#### Destination PAT (GITHUB_DESTINATION_PAT):
- ✅ `repo` - Full control of private repositories (read/write)
- ✅ `admin:org` - Organization administration
  - `write:org` - Create repositories in organization
  - `read:org` - Read organization data
- ✅ `workflow` - Update GitHub Actions workflows (if repos contain workflows)

#### **Important for EMU (Enterprise Managed Users) Organizations:**

If your destination organizations are EMU organizations, you **must**:

1. **Use an EMU account** to create the destination PAT (not a regular GitHub account)
2. **Ensure the EMU user is a member** (preferably owner/admin) of all destination organizations
3. **Authorize PAT for SSO** if SAML SSO is enabled:
   - Go to https://github.com/settings/tokens
   - Find your destination PAT
   - Click **Configure SSO**
   - Click **Authorize** for each destination organization
4. **Verify PAT has enterprise access** if managing enterprise-level resources

> **⚠️ Common Error:** `403 Forbidden` on destination organizations usually means:
> - PAT not authorized for SSO (most common)
> - PAT created by non-EMU user trying to access EMU organizations
> - User not a member of the destination organizations
> - Missing required scopes (admin:org)

## 📝 Workflow Parameters

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `dry_run` | Run in dry-run mode | `true` | No |
| `source_organizations` | Source orgs (comma-separated) | Default mapping | No |
| `destination_organizations` | Destination orgs (comma-separated) | Default mapping | No |
| `working_directory` | Temp directory for cloning | `./temp-migration` | No |

## 📊 Outputs & Artifacts

After each run, the action provides:

1. **Console Logs**: Real-time progress in the action logs
2. **Migration Logs**: Detailed log files uploaded as artifacts
3. **Summary**: Final status and statistics
4. **Error Details**: If migration fails, detailed error information

### Downloading Logs

1. Go to the completed workflow run
2. Scroll to **Artifacts** section
3. Download `migration-logs-{run-number}`
4. Extract and review the detailed migration logs

## 🔄 Typical Workflow

### Step 1: Discover Organizations (Recommended First Step)

Before migrating, discover what organizations and repositories exist:

1. Go to **Actions** tab → **Discover Organizations and Repositories**
2. Click **Run workflow**
3. Configure:
   - **enterprise_type**: `source`, `destination`, or `both`
   - **include_repositories**: `true` (for detailed inventory)
4. Download the generated reports (JSON, Markdown, CSV)
5. Review the reports to plan your migration

**Why do this first?**
- See exactly what will be migrated
- Identify any issues or missing organizations
- Plan your organization mappings
- Verify PAT access to all organizations

### Step 2: Test Migration (Dry Run)
```yaml
Dry Run: true
Source Organizations: (leave empty for defaults)
Destination Organizations: (leave empty for defaults)
```

### Production Run
```yaml
Dry Run: false
Source Organizations: (leave empty for defaults)
Destination Organizations: (leave empty for defaults)
```

### Selective Migration
```yaml
Dry Run: false
Source Organizations: org1-rpa,org1-ds
Destination Organizations: org1-rpa-emu,org1-ds-emu
```

## 🛡️ Security Best Practices

1. **Never commit PATs** to repository code
2. **Use repository secrets** for all sensitive data
3. **Run dry-run first** to validate configuration
4. **Review logs** before running production migrations
5. **Use minimal PAT permissions** required for the task

## 🐛 Troubleshooting

### Common Issues

1. **PAT Not Found**: Ensure secrets `SOURCE_PAT` and `DESTINATION_PAT` are set in repository secrets
2. **403 Forbidden on Destination Organizations**: 
   - Most commonly caused by PAT not authorized for SSO
   - PAT must be created by an EMU user (for EMU organizations)
   - User must be a member/admin of all destination organizations
   - Verify PAT has `admin:org` scope
   - **Solution**: Configure SSO authorization for your PAT (see PAT Permissions section above)
3. **Repository Not Found**: Verify organization names and repository access
4. **Git Clone Failed**: Check network connectivity and repository permissions
5. **Organization Verification Failed**: All organizations must exist and PAT must have access before migration starts

### Debugging Steps

1. **Check Action Logs**: Review the real-time console output
2. **Download Artifacts**: Get detailed migration logs
3. **Run Dry Mode**: Test configuration without making changes
4. **Validate PATs**: Use the included `Test-PAT-Access.ps1` script to verify PAT permissions:
   ```powershell
   .\Test-PAT-Access.ps1 -PAT "your-pat" -Organization "your-org-name"
   ```
5. **Verify SSO Authorization**: Check https://github.com/settings/tokens and ensure SSO is configured

## 💡 Tips

- Always start with a dry run to validate your configuration
- Download and review the migration logs after each run
- Use custom organizations to migrate specific repos first
- Monitor the console logs for real-time progress
- Check repository permissions if you encounter 403/404 errors

## 📖 Related Documentation

- [DISCOVERY-GUIDE.md](DISCOVERY-GUIDE.md) - **Complete guide for organization discovery workflow**
- [SECRETS-SETUP.md](SECRETS-SETUP.md) - Detailed instructions for configuring repository secrets  
- [GitHub-Action-Setup.md](GitHub-Action-Setup.md) - Quick start guide for running workflows
- [Migration-Documentation.md](Migration-Documentation.md) - Detailed script documentation
- [Manual-Environment-Setup.md](Manual-Environment-Setup.md) - Local setup guide
- [GitHub PAT Documentation](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)