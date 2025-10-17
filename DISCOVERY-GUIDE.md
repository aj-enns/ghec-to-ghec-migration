# Organization Discovery Workflow

## Overview

The **Discover Organizations and Repositories** workflow scans your GitHub Enterprise Cloud (GHEC) instances to inventory all organizations and repositories. This is essential for planning migrations and understanding your repository landscape.

## What It Does

- 🔍 **Discovers all organizations** in a GHEC enterprise
- 📦 **Lists all repositories** within each organization (optional)
- 📊 **Generates reports** in multiple formats (JSON, Markdown, CSV)
- ✅ **Validates PAT access** to organizations
- 📝 **Provides detailed metadata** for each repository

## When to Use

✅ **Before starting a migration** - See what you're migrating
✅ **Planning organization mappings** - Understand source/destination structure
✅ **Auditing repository inventory** - Create compliance reports
✅ **Validating PAT permissions** - Ensure access before migration
✅ **Periodic inventory** - Track repository growth over time

## How to Run

### Via GitHub Actions Web UI

1. Go to your repository's **Actions** tab
2. Select **Discover Organizations and Repositories** workflow
3. Click **Run workflow**
4. Configure parameters:
   - **enterprise_type**: 
     - `source` - Scan only source enterprise
     - `destination` - Scan only destination enterprise
     - `both` - Scan both enterprises
   - **include_repositories**: 
     - `true` - Include full repository details (slower, more comprehensive)
     - `false` - Organization names only (faster)
5. Click **Run workflow**

### Via GitHub CLI

```bash
# Scan source enterprise with repositories
gh workflow run discover-organizations.yml \
  -f enterprise_type=source \
  -f include_repositories=true

# Scan both enterprises
gh workflow run discover-organizations.yml \
  -f enterprise_type=both \
  -f include_repositories=true

# Quick scan (organization names only)
gh workflow run discover-organizations.yml \
  -f enterprise_type=both \
  -f include_repositories=false
```

## Output Reports

The workflow generates three types of reports:

### 1. JSON Report (`discovery-report-YYYYMMDD-HHMMSS.json`)

Complete structured data including:
- Enterprise information
- Organization details (ID, name, description, URL)
- Repository metadata (name, size, language, visibility, dates)
- Hierarchical structure (enterprise → organization → repositories)

**Use for**: Programmatic processing, automation, detailed analysis

### 2. Markdown Report (`discovery-report-YYYYMMDD-HHMMSS.md`)

Human-readable formatted report with:
- Executive summary (totals, counts)
- Organization listings with descriptions
- Repository lists with visibility indicators
- URLs for easy navigation

**Use for**: Documentation, sharing with team, migration planning

### 3. CSV Report (`discovery-report-YYYYMMDD-HHMMSS.csv`)

Flat table format with columns:
- Enterprise, Type, Organization, Repository
- FullName, Private, DefaultBranch, Size
- Language, Fork, Archived, LastUpdated

**Use for**: Spreadsheet analysis, filtering, pivot tables, reporting

## Downloading Reports

1. Go to the completed workflow run
2. Scroll to **Artifacts** section
3. Download `discovery-report-{run-number}`
4. Extract the ZIP file
5. Review the three report files

## Example Output

### Markdown Report Sample

```markdown
# GitHub Organization Discovery Report

**Generated**: 2025-10-16 14:30:00
**Scan Type**: both

## Source Enterprise: government-of-manitoba

- **Total Organizations**: 4
- **Total Repositories**: 127

### Organizations

#### govmb-ds
- **Name**: Digital Services
- **Repositories**: 45
- **URL**: https://github.com/govmb-ds

**Repository List**:
- 🔒 Private **web-portal** - Main public-facing web portal
- 🔒 Private **api-gateway** - API gateway service
- 🌐 Public **documentation** - Public documentation site

## Destination Enterprise: government-of-manitoba-emu

- **Total Organizations**: 4
- **Total Repositories**: 12

...
```

## Use Cases

### Use Case 1: Pre-Migration Discovery

**Scenario**: You need to migrate repositories but don't know exactly what exists.

**Steps**:
1. Run discovery on source enterprise with `include_repositories=true`
2. Review the Markdown report to understand what you have
3. Open CSV in Excel to analyze repository sizes, languages, activity
4. Identify archived repositories that may not need migration
5. Create your organization mapping based on discovery results

### Use Case 2: Validation After Migration

**Scenario**: Verify that all repositories were migrated successfully.

**Steps**:
1. Run discovery on both enterprises with `include_repositories=true`
2. Compare CSV files side-by-side
3. Check repository counts match
4. Verify no repositories were missed
5. Identify any discrepancies

### Use Case 3: Compliance Audit

**Scenario**: Generate an inventory report for compliance purposes.

**Steps**:
1. Run discovery with `include_repositories=true`
2. Download Markdown report for documentation
3. Use CSV for detailed analysis (active vs archived, public vs private)
4. Archive reports for audit trail
5. Schedule periodic discovery runs for ongoing compliance

### Use Case 4: Planning Organization Structure

**Scenario**: Decide how to map source to destination organizations.

**Steps**:
1. Run discovery on source with `include_repositories=true`
2. Review organization structure and repository distribution
3. Identify consolidation opportunities (merge small orgs)
4. Plan naming conventions (org-name → org-name-emu)
5. Document decisions before migration

## Required Secrets

The discovery workflow uses the same secrets as the migration workflow:

| Secret | Required When |
|--------|---------------|
| `SOURCE_PAT` | Scanning source enterprise |
| `SOURCE_ENTERPRISE` | Scanning source enterprise |
| `DESTINATION_PAT` | Scanning destination enterprise |
| `DESTINATION_ENTERPRISE` | Scanning destination enterprise |

**Note**: If scanning `both`, all 4 secrets are required.

## PAT Requirements

### For Discovery

**Minimum Scopes**:
- `read:org` - Read organization information
- `repo` (read) - List and view repositories

**Optional Scopes**:
- `admin:enterprise` or `read:enterprise` - For enterprise-level API access (if available)

**Note**: Discovery only requires **read** access, making it safe to run without migration permissions.

## Troubleshooting

### "Enterprise API not available" Warning

**Cause**: PAT lacks enterprise-level API access

**Impact**: Falls back to user organizations endpoint (still works, but may not see all enterprise orgs)

**Solution**: 
- Ensure PAT has `admin:enterprise` or `read:enterprise` scope
- Verify the enterprise name is correct
- Confirm user is enterprise member

### Empty Organization List

**Cause**: PAT lacks access to organizations

**Solution**:
- Verify PAT has `read:org` scope
- Check user is member of organizations
- For EMU: Verify SSO is authorized
- Confirm enterprise name is correct

### 403 Forbidden Errors

**Cause**: PAT not authorized for SSO (EMU organizations)

**Solution**:
- Go to Settings → Developer settings → Personal access tokens
- Find your PAT
- Click **Configure SSO**
- Authorize for all organizations

## Performance

**Scan Times** (approximate):

| Scenario | Organizations | Repositories | Time |
|----------|--------------|--------------|------|
| Small | 5 | 50 | ~30 seconds |
| Medium | 10 | 200 | ~2 minutes |
| Large | 25 | 1000 | ~10 minutes |
| Very Large | 50+ | 5000+ | ~30+ minutes |

**Tips for faster scans**:
- Set `include_repositories=false` for quick org-only scans
- Run discovery during off-peak hours for large enterprises
- Scan source and destination separately if timeout occurs

## Next Steps

After running discovery:

1. ✅ **Review reports** - Understand what exists
2. ✅ **Plan mappings** - Define source → destination organization pairs
3. ✅ **Update workflow** - Modify default organization mappings if needed
4. ✅ **Run dry-run migration** - Test with real data
5. ✅ **Execute migration** - Proceed with confidence

## Related Documentation

- [README.md](README.md) - Main documentation
- [SECRETS-SETUP.md](SECRETS-SETUP.md) - Secret configuration guide
- [GitHub-Action-Setup.md](GitHub-Action-Setup.md) - Action setup guide
