# GitHub Action Setup Guide

This is a quick reference for setting up and running the GitHub Repository Migration workflow. For detailed setup instructions, see [SECRETS-SETUP.md](SECRETS-SETUP.md).

## Quick Setup

### 1. Create and Configure PATs

#### Source PAT
- **Scopes**: `repo`, `read:org`
- **Created by**: Any user with source org access

#### Destination PAT (EMU)
- **Scopes**: `repo`, `admin:org`, `workflow`
- **Created by**: **EMU account** (required for EMU organizations)
- **Must authorize for SSO**: Go to Settings → Developer settings → Personal access tokens → Configure SSO

See [SECRETS-SETUP.md](SECRETS-SETUP.md) for detailed PAT creation instructions.

### 2. Add Repository Secrets

Go to **Settings > Secrets and variables > Actions** and add these 4 secrets:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `SOURCE_PAT` | Personal Access Token for source | `ghp_xxxxx...` |
| `DESTINATION_PAT` | Personal Access Token for destination (EMU) | `ghp_xxxxx...` |
| `SOURCE_ENTERPRISE` | Source enterprise name | `source-enterprise` |
| `DESTINATION_ENTERPRISE` | Destination enterprise name | `destination-enterprise` |

⚠️ **Important**: Secret names must be exact (case-sensitive).

### 3. Verify Setup

In **Settings > Secrets and variables > Actions**, you should see all 4 secrets listed.

## Running the Migration

### Option 1: GitHub Web Interface (Recommended)

1. Go to **Actions** tab
2. Select **GitHub Repository Migration** workflow
3. Click **Run workflow**
4. Configure:
   - **dry_run**: `true` (always test first!)
   - **source_organizations**: Leave empty for defaults
   - **destination_organizations**: Leave empty for defaults
5. Click **Run workflow**

### Option 2: GitHub CLI

```bash
# Dry run (recommended first)
gh workflow run github-migration.yml -f dry_run=true

# Production run (after successful dry run)
gh workflow run github-migration.yml -f dry_run=false

# Custom organizations
gh workflow run github-migration.yml \
  -f dry_run=true \
  -f source_organizations="org1-rpa,org1-ds" \
  -f destination_organizations="org1-rpa-emu,org1-ds-emu"
```

## Monitoring & Logs

### Real-time Logs
1. **Actions** tab → Click running workflow → Click **migrate-repositories** job
2. Watch live progress

### Download Detailed Logs
1. After completion, scroll to **Artifacts** section
2. Download `migration-logs-{run-number}.zip`
3. Extract and review detailed logs

## Troubleshooting

### "Secret not set" Error
```
SOURCE_PAT environment variable is not set
```
**Cause**: Secret missing or incorrect name

**Solution**:
- Verify exact names: `SOURCE_PAT`, `DESTINATION_PAT`, `SOURCE_ENTERPRISE`, `DESTINATION_ENTERPRISE`
- Check they exist in Settings → Secrets and variables → Actions

### 403 Forbidden on Destination
```
Error accessing destination organization org1-ds-emu: 403 (Forbidden)
```
**Cause**: Usually SSO authorization missing

**Solutions**:
1. **Authorize PAT for SSO**: Settings → Developer settings → Personal access tokens → Configure SSO
2. **Verify EMU account**: PAT must be created by EMU user (not regular account)
3. **Check organization membership**: EMU user must be member/admin of destination orgs
4. **Verify scopes**: PAT needs `admin:org` scope

See [SECRETS-SETUP.md](SECRETS-SETUP.md) for detailed troubleshooting.

### Organization Not Found (404)
**Cause**: Organization doesn't exist or PAT lacks access

**Solution**: Verify organization names and PAT permissions

### PAT Expired
**Solution**: Generate new PAT and update the secret

## Best Practices

✅ **Always run dry run first** - Validates configuration without making changes
✅ **Review logs** - Check dry run logs before production run
✅ **Start small** - Test with one organization before migrating all
✅ **Download logs** - Keep migration logs for records
✅ **Rotate PATs** - Set expiration dates and rotate regularly

## Default Organization Mapping

The workflow uses these defaults (can be overridden):

| Source | Destination |
|--------|-------------|
| org1-ds | org1-ds-emu |
| org1-la | org1-la-emu |
| org1-rpa | org1-rpa-emu |
| org1-ams | org1-ams-emu |

## Additional Resources

- [SECRETS-SETUP.md](SECRETS-SETUP.md) - Detailed secret configuration guide
- [README.md](README.md) - Complete documentation and features
- [Migration-Documentation.md](Migration-Documentation.md) - Script details and local setup