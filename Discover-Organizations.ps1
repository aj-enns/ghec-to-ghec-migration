# GitHub Organization and Repository Discovery Script
# Discovers all organizations and repositories in a GitHub Enterprise

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('source', 'destination', 'both')]
    [string]$ScanType = 'source',
    
    [Parameter(Mandatory=$false)]
    [string]$SourcePAT,
    
    [Parameter(Mandatory=$false)]
    [string]$DestinationPAT,
    
    [Parameter(Mandatory=$false)]
    [string]$SourceEnterprise,
    
    [Parameter(Mandatory=$false)]
    [string]$DestinationEnterprise,
    
    [Parameter(Mandatory=$false)]
    [bool]$IncludeRepositories = $true,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFile = "discovery-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
)

# Initialize results
$results = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ScanType = $ScanType
    IncludeRepositories = $IncludeRepositories
    Source = $null
    Destination = $null
}

# Function to write logs
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
}

# Function to make GitHub API calls
function Invoke-GitHubAPI {
    param(
        [string]$Uri,
        [string]$Token,
        [string]$Method = "GET"
    )
    
    try {
        $headers = @{
            "Authorization" = "Bearer $Token"
            "Accept" = "application/vnd.github+json"
            "X-GitHub-Api-Version" = "2022-11-28"
        }
        
        $response = Invoke-RestMethod -Uri $Uri -Headers $headers -Method $Method
        return $response
    }
    catch {
        Write-Log "API call failed: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Function to get all organizations in an enterprise
function Get-EnterpriseOrganizations {
    param(
        [string]$Enterprise,
        [string]$Token
    )
    
    Write-Log "Discovering organizations for enterprise: $Enterprise"
    $orgs = @()
    $page = 1
    $perPage = 100
    
    do {
        try {
            $uri = "https://api.github.com/enterprises/$Enterprise/organizations?page=$page&per_page=$perPage"
            $pageOrgs = Invoke-GitHubAPI -Uri $uri -Token $Token
            
            if ($pageOrgs) {
                $orgs += $pageOrgs
                Write-Log "Retrieved $($pageOrgs.Count) organizations from page $page"
                $page++
            }
        }
        catch {
            # If enterprise endpoint doesn't work, try getting user's organizations
            Write-Log "Enterprise API not available, trying user organizations endpoint" "WARNING"
            $uri = "https://api.github.com/user/orgs?page=$page&per_page=$perPage"
            $pageOrgs = Invoke-GitHubAPI -Uri $uri -Token $Token
            
            if ($pageOrgs) {
                $orgs += $pageOrgs
                Write-Log "Retrieved $($pageOrgs.Count) organizations from page $page"
                $page++
            }
        }
    } while ($pageOrgs -and $pageOrgs.Count -eq $perPage)
    
    Write-Log "Total organizations found: $($orgs.Count)"
    return $orgs
}

# Function to get all repositories for an organization
function Get-OrganizationRepositories {
    param(
        [string]$Organization,
        [string]$Token
    )
    
    Write-Log "Getting repositories for organization: $Organization"
    $repos = @()
    $page = 1
    $perPage = 100
    
    do {
        $uri = "https://api.github.com/orgs/$Organization/repos?page=$page&per_page=$perPage&type=all"
        $pageRepos = Invoke-GitHubAPI -Uri $uri -Token $Token
        
        if ($pageRepos) {
            $repos += $pageRepos
            $page++
        }
    } while ($pageRepos -and $pageRepos.Count -eq $perPage)
    
    Write-Log "Found $($repos.Count) repositories in $Organization"
    return $repos
}

# Function to scan an enterprise
function Scan-Enterprise {
    param(
        [string]$Enterprise,
        [string]$Token,
        [string]$Type
    )
    
    Write-Log "========================================" 
    Write-Log "Scanning $Type Enterprise: $Enterprise"
    Write-Log "========================================"
    
    $enterpriseData = @{
        Name = $Enterprise
        Organizations = @()
        TotalOrganizations = 0
        TotalRepositories = 0
        ScanDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    try {
        # Get all organizations
        $orgs = Get-EnterpriseOrganizations -Enterprise $Enterprise -Token $Token
        $enterpriseData.TotalOrganizations = $orgs.Count
        
        foreach ($org in $orgs) {
            Write-Log "Processing organization: $($org.login)"
            
            $orgData = @{
                Login = $org.login
                Name = $org.name
                Description = $org.description
                Id = $org.id
                Url = $org.html_url
                RepositoryCount = 0
                Repositories = @()
            }
            
            if ($IncludeRepositories) {
                try {
                    $repos = Get-OrganizationRepositories -Organization $org.login -Token $Token
                    $orgData.RepositoryCount = $repos.Count
                    $enterpriseData.TotalRepositories += $repos.Count
                    
                    foreach ($repo in $repos) {
                        $repoData = @{
                            Name = $repo.name
                            FullName = $repo.full_name
                            Description = $repo.description
                            Private = $repo.private
                            DefaultBranch = $repo.default_branch
                            Size = $repo.size
                            Language = $repo.language
                            Fork = $repo.fork
                            Archived = $repo.archived
                            Disabled = $repo.disabled
                            CreatedAt = $repo.created_at
                            UpdatedAt = $repo.updated_at
                            PushedAt = $repo.pushed_at
                            CloneUrl = $repo.clone_url
                            SshUrl = $repo.ssh_url
                            Url = $repo.html_url
                        }
                        $orgData.Repositories += $repoData
                    }
                }
                catch {
                    Write-Log "Failed to get repositories for $($org.login): $($_.Exception.Message)" "ERROR"
                }
            }
            
            $enterpriseData.Organizations += $orgData
        }
        
        Write-Log "Scan complete for $Type enterprise"
        Write-Log "  Organizations: $($enterpriseData.TotalOrganizations)"
        Write-Log "  Total Repositories: $($enterpriseData.TotalRepositories)"
        
        return $enterpriseData
    }
    catch {
        Write-Log "Failed to scan enterprise $Enterprise : $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Main execution
try {
    Write-Log "Starting GitHub Organization Discovery"
    Write-Log "Scan Type: $ScanType"
    Write-Log "Include Repositories: $IncludeRepositories"
    Write-Log ""
    
    # Scan source enterprise
    if ($ScanType -in @('source', 'both')) {
        if (-not $SourcePAT -or -not $SourceEnterprise) {
            Write-Log "Source PAT and Enterprise are required for source scan" "ERROR"
            exit 1
        }
        $results.Source = Scan-Enterprise -Enterprise $SourceEnterprise -Token $SourcePAT -Type "Source"
    }
    
    # Scan destination enterprise
    if ($ScanType -in @('destination', 'both')) {
        if (-not $DestinationPAT -or -not $DestinationEnterprise) {
            Write-Log "Destination PAT and Enterprise are required for destination scan" "ERROR"
            exit 1
        }
        $results.Destination = Scan-Enterprise -Enterprise $DestinationEnterprise -Token $DestinationPAT -Type "Destination"
    }
    
    # Save results to JSON
    Write-Log ""
    Write-Log "Saving results to $OutputFile"
    $results | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFile -Encoding utf8
    Write-Log "✅ JSON report saved: $OutputFile"
    
    # Generate Markdown report
    $mdFile = $OutputFile -replace '\.json$', '.md'
    Write-Log "Generating Markdown report: $mdFile"
    
    $markdown = @"
# GitHub Organization Discovery Report

**Generated**: $($results.Timestamp)  
**Scan Type**: $($results.ScanType)  
**Include Repositories**: $($results.IncludeRepositories)

---

"@
    
    if ($results.Source) {
        $markdown += @"

## Source Enterprise: $($results.Source.Name)

- **Total Organizations**: $($results.Source.TotalOrganizations)
- **Total Repositories**: $($results.Source.TotalRepositories)
- **Scan Date**: $($results.Source.ScanDate)

### Organizations

"@
        foreach ($org in $results.Source.Organizations) {
            $markdown += @"

#### $($org.Login)
- **Name**: $($org.Name)
- **Description**: $($org.Description)
- **Repositories**: $($org.RepositoryCount)
- **URL**: $($org.Url)

"@
            if ($IncludeRepositories -and $org.Repositories.Count -gt 0) {
                $markdown += "**Repository List**:`n`n"
                foreach ($repo in $org.Repositories) {
                    $visibility = if ($repo.Private) { "🔒 Private" } else { "🌐 Public" }
                    $archived = if ($repo.Archived) { " [ARCHIVED]" } else { "" }
                    $markdown += "- $visibility **$($repo.Name)**$archived - $($repo.Description)`n"
                }
                $markdown += "`n"
            }
        }
    }
    
    if ($results.Destination) {
        $markdown += @"

---

## Destination Enterprise: $($results.Destination.Name)

- **Total Organizations**: $($results.Destination.TotalOrganizations)
- **Total Repositories**: $($results.Destination.TotalRepositories)
- **Scan Date**: $($results.Destination.ScanDate)

### Organizations

"@
        foreach ($org in $results.Destination.Organizations) {
            $markdown += @"

#### $($org.Login)
- **Name**: $($org.Name)
- **Description**: $($org.Description)
- **Repositories**: $($org.RepositoryCount)
- **URL**: $($org.Url)

"@
            if ($IncludeRepositories -and $org.Repositories.Count -gt 0) {
                $markdown += "**Repository List**:`n`n"
                foreach ($repo in $org.Repositories) {
                    $visibility = if ($repo.Private) { "🔒 Private" } else { "🌐 Public" }
                    $archived = if ($repo.Archived) { " [ARCHIVED]" } else { "" }
                    $markdown += "- $visibility **$($repo.Name)**$archived - $($repo.Description)`n"
                }
                $markdown += "`n"
            }
        }
    }
    
    $markdown | Out-File -FilePath $mdFile -Encoding utf8
    Write-Log "✅ Markdown report saved: $mdFile"
    
    # Generate CSV summary
    $csvFile = $OutputFile -replace '\.json$', '.csv'
    Write-Log "Generating CSV summary: $csvFile"
    
    $csvData = @()
    
    if ($results.Source) {
        foreach ($org in $results.Source.Organizations) {
            foreach ($repo in $org.Repositories) {
                $csvData += [PSCustomObject]@{
                    Enterprise = $results.Source.Name
                    Type = "Source"
                    Organization = $org.Login
                    Repository = $repo.Name
                    FullName = $repo.FullName
                    Private = $repo.Private
                    DefaultBranch = $repo.DefaultBranch
                    Size = $repo.Size
                    Language = $repo.Language
                    Fork = $repo.Fork
                    Archived = $repo.Archived
                    LastUpdated = $repo.UpdatedAt
                }
            }
        }
    }
    
    if ($results.Destination) {
        foreach ($org in $results.Destination.Organizations) {
            foreach ($repo in $org.Repositories) {
                $csvData += [PSCustomObject]@{
                    Enterprise = $results.Destination.Name
                    Type = "Destination"
                    Organization = $org.Login
                    Repository = $repo.Name
                    FullName = $repo.FullName
                    Private = $repo.Private
                    DefaultBranch = $repo.DefaultBranch
                    Size = $repo.Size
                    Language = $repo.Language
                    Fork = $repo.Fork
                    Archived = $repo.Archived
                    LastUpdated = $repo.UpdatedAt
                }
            }
        }
    }
    
    if ($csvData.Count -gt 0) {
        $csvData | Export-Csv -Path $csvFile -NoTypeInformation -Encoding utf8
        Write-Log "✅ CSV summary saved: $csvFile"
    }
    
    # Final summary
    Write-Log ""
    Write-Log "========================================" 
    Write-Log "Discovery Complete!"
    Write-Log "========================================"
    Write-Log "Reports generated:"
    Write-Log "  - JSON: $OutputFile"
    Write-Log "  - Markdown: $mdFile"
    if ($csvData.Count -gt 0) {
        Write-Log "  - CSV: $csvFile"
    }
    
    exit 0
}
catch {
    Write-Log "Discovery failed: $($_.Exception.Message)" "ERROR"
    exit 1
}
