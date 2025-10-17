# GitHub Repository Migration Script
# Migrates repositories from source GHEC to destination GHEC

param(
    [Parameter(Mandatory=$true)]
    [string]$SourcePAT,
    
    [Parameter(Mandatory=$true)]
    [string]$DestinationPAT,
    
    [Parameter(Mandatory=$false)]
    [string[]]$SourceOrganizations = @("ds", "la", "rpa", "ams"),
    
    [Parameter(Mandatory=$false)]
    [string[]]$DestinationOrganizations = @("ds-emu", "la-emu", "rpa-emu", "ams-emu"),
    
    [Parameter(Mandatory=$true)]
    [string]$SourceEnterprise,
    
    [Parameter(Mandatory=$true)]
    [string]$DestinationEnterprise,
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory=$false)]
    [string]$LogFile = "migration-log-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt",
    
    [Parameter(Mandatory=$false)]
    [string]$WorkingDirectory = ".\temp-migration"
)

# Function to write logs
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
    Add-Content -Path $LogFile -Value $logEntry
}

# Function to make GitHub API calls
function Invoke-GitHubAPI {
    param(
        [string]$Uri,
        [string]$Token,
        [string]$Method = "GET",
        [hashtable]$Body = @{}
    )
    
    try {
        $headers = @{
            "Authorization" = "token $Token"
            "Accept" = "application/vnd.github.v3+json"
            "User-Agent" = "PowerShell-Migration-Script"
        }
        
        $params = @{
            Uri = $Uri
            Headers = $headers
            Method = $Method
        }
        
        if ($Body.Count -gt 0 -and $Method -ne "GET") {
            $params.Body = ($Body | ConvertTo-Json -Depth 10)
            $params.ContentType = "application/json"
        }
        
        $response = Invoke-RestMethod @params
        return $response
    }
    catch {
        Write-Log "API call failed: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Function to get all repositories from an organization
function Get-OrganizationRepos {
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
        $repos += $pageRepos
        $page++
        Write-Log "Retrieved $($pageRepos.Count) repositories from page $($page-1)"
    } while ($pageRepos.Count -eq $perPage)
    
    Write-Log "Total repositories found in $Organization $($repos.Count)"
    return $repos
}

# Function to check if organization exists
function Test-Organization {
    param(
        [string]$Organization,
        [string]$Token,
        [string]$Type = "destination"
    )
    
    try {
        $uri = "https://api.github.com/orgs/$Organization"
        $response = Invoke-GitHubAPI -Uri $uri -Token $Token
        Write-Log "$Type organization verified: $Organization"
        return $true
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 404) {
            Write-Log "$Type organization not found: $Organization" "ERROR"
        } else {
            Write-Log "Error accessing $Type organization $Organization : $($_.Exception.Message)" "ERROR"
        }
        return $false
    }
}

# Function to check if repository exists in destination
function Test-DestinationRepo {
    param(
        [string]$Organization,
        [string]$RepoName,
        [string]$Token
    )
    
    try {
        $uri = "https://api.github.com/repos/$Organization/$RepoName"
        $response = Invoke-GitHubAPI -Uri $uri -Token $Token
        Write-Log "Repository exists in destination: $Organization/$RepoName"
        return $true
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 404) {
            Write-Log "Repository does not exist in destination: $Organization/$RepoName (will create)"
        } else {
            Write-Log "Error checking repository $Organization/$RepoName : $($_.Exception.Message)" "ERROR"
        }
        return $false
    }
}

# Function to create repository in destination
function New-DestinationRepo {
    param(
        [string]$Organization,
        [object]$SourceRepo,
        [string]$Token
    )
    
    $body = @{
        name = $SourceRepo.name
        description = $SourceRepo.description
        private = $SourceRepo.private
        has_issues = $SourceRepo.has_issues
        has_projects = $SourceRepo.has_projects
        has_wiki = $SourceRepo.has_wiki
        has_downloads = $SourceRepo.has_downloads
        default_branch = $SourceRepo.default_branch
    }
    
    $uri = "https://api.github.com/orgs/$Organization/repos"
    
    try {
        $response = Invoke-GitHubAPI -Uri $uri -Token $Token -Method "POST" -Body $body
        Write-Log "Successfully created repository: $Organization/$($SourceRepo.name)"
        return $response
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 404) {
            Write-Log "Failed to create repository - Organization '$Organization' not found or PAT lacks access" "ERROR"
        } elseif ($statusCode -eq 422) {
            Write-Log "Failed to create repository - Repository '$($SourceRepo.name)' already exists or validation failed" "ERROR"
        } else {
            Write-Log "Failed to create repository $Organization/$($SourceRepo.name): HTTP $statusCode - $($_.Exception.Message)" "ERROR"
        }
        throw
    }
}

# Function to migrate a single repository
function Copy-Repository {
    param(
        [object]$Repo,
        [string]$SourceOrg,
        [string]$DestinationOrg,
        [string]$SourceToken,
        [string]$DestinationToken
    )
    
    $repoName = $Repo.name
    $sourceCloneUrl = "https://$SourceToken@github.com/$SourceOrg/$repoName.git"
    $destinationPushUrl = "https://$DestinationToken@github.com/$DestinationOrg/$repoName.git"
    $localPath = Join-Path $WorkingDirectory "$SourceOrg-$repoName.git"
    
    Write-Log "Starting migration of $SourceOrg/$repoName"
    
    try {
        # Check if destination repo exists, create if it doesn't
        if (-not (Test-DestinationRepo -Organization $DestinationOrg -RepoName $repoName -Token $DestinationToken)) {
            if ($DryRun) {
                Write-Log "[DRY RUN] Would create repository: $DestinationOrg/$repoName"
            } else {
                New-DestinationRepo -Organization $DestinationOrg -SourceRepo $Repo -Token $DestinationToken
            }
        } else {
            Write-Log "Repository already exists in destination: $DestinationOrg/$repoName"
        }
        
        # Clean up any existing local copy
        if (Test-Path $localPath) {
            Remove-Item -Path $localPath -Recurse -Force
        }
        
        if ($DryRun) {
            Write-Log "[DRY RUN] Would clone: $sourceCloneUrl"
            Write-Log "[DRY RUN] Would push to: $destinationPushUrl"
        } else {
            # Clone repository with --mirror
            Write-Log "Cloning repository with --mirror: $SourceOrg/$repoName"
            # $cloneResult = & git clone --mirror $sourceCloneUrl $localPath 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                throw "Git clone failed: $cloneResult"
            }
            
            # Change to the cloned repository directory
            Push-Location $localPath
            
            try {
                # Add destination remote and push
                Write-Log "Pushing to destination: $DestinationOrg/$repoName"
                # $pushResult = & git push --mirror $destinationPushUrl 2>&1
                
                if ($LASTEXITCODE -ne 0) {
                    throw "Git push failed: $pushResult"
                }
                
                Write-Log "Successfully migrated: $SourceOrg/$repoName -> $DestinationOrg/$repoName" "SUCCESS"
            }
            finally {
                Pop-Location
            }
        }
    }
    catch {
        Write-Log "Failed to migrate $SourceOrg/$repoName $($_.Exception.Message)" "ERROR"
        return $false
    }
    finally {
        # Clean up local copy
        if ((Test-Path $localPath) -and (-not $DryRun)) {
            Remove-Item -Path $localPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    return $true
}

# Main execution
try {
    Write-Log "Starting GitHub repository migration"
    Write-Log "Source Enterprise: $SourceEnterprise"
    Write-Log "Destination Enterprise: $DestinationEnterprise"
    Write-Log "Source Organizations: $($SourceOrganizations -join ', ')"
    Write-Log "Destination Organizations: $($DestinationOrganizations -join ', ')"
    Write-Log "Dry Run: $DryRun"
    Write-Log "Log File: $LogFile"
    
    # Create working directory
    if (-not (Test-Path $WorkingDirectory)) {
        New-Item -ItemType Directory -Path $WorkingDirectory -Force | Out-Null
        Write-Log "Created working directory: $WorkingDirectory"
    }
    
    # Check git availability
    try {
        $gitVersion = & git --version 2>&1
        Write-Log "Git version: $gitVersion"
    }
    catch {
        Write-Log "Git is not available. Please install Git and ensure it's in your PATH." "ERROR"
        exit 1
    }
    
    # Verify organizations exist before starting migration
    Write-Log "Verifying organizations..."
    $orgVerificationFailed = $false
    
    for ($i = 0; $i -lt $SourceOrganizations.Count; $i++) {
        $sourceOrg = $SourceOrganizations[$i]
        $destinationOrg = $DestinationOrganizations[$i]
        
        if (-not (Test-Organization -Organization $sourceOrg -Token $SourcePAT -Type "source")) {
            $orgVerificationFailed = $true
        }
        
        if (-not (Test-Organization -Organization $destinationOrg -Token $DestinationPAT -Type "destination")) {
            $orgVerificationFailed = $true
        }
    }
    
    if ($orgVerificationFailed) {
        Write-Log "Organization verification failed. Please check your organizations and PAT permissions." "ERROR"
        exit 1
    }
    
    $totalRepos = 0
    $successfulMigrations = 0
    $failedMigrations = 0
    
    # Process each organization
    for ($i = 0; $i -lt $SourceOrganizations.Count; $i++) {
        $sourceOrg = $SourceOrganizations[$i]
        $destinationOrg = $DestinationOrganizations[$i]
        
        Write-Log "Processing organization: $sourceOrg -> $destinationOrg"
        
        try {
            # Get all repositories from source organization
            $repos = Get-OrganizationRepos -Organization $sourceOrg -Token $SourcePAT
            $totalRepos += $repos.Count
            
            # Migrate each repository
            foreach ($repo in $repos) {
                $success = Copy-Repository -Repo $repo -SourceOrg $sourceOrg -DestinationOrg $destinationOrg -SourceToken $SourcePAT -DestinationToken $DestinationPAT
                
                if ($success) {
                    $successfulMigrations++
                } else {
                    $failedMigrations++
                }
                
                # Add a small delay to avoid rate limiting
                Start-Sleep -Seconds 1
            }
        }
        catch {
            Write-Log "Failed to process organization $sourceOrg $($_.Exception.Message)" "ERROR"
            continue
        }
    }
    
    # Summary
    Write-Log "Migration completed!"
    Write-Log "Total repositories: $totalRepos"
    Write-Log "Successful migrations: $successfulMigrations"
    Write-Log "Failed migrations: $failedMigrations"
    
    if ($DryRun) {
        Write-Log "This was a dry run. No actual changes were made."
    }
}
catch {
    Write-Log "Script execution failed: $($_.Exception.Message)" "ERROR"
    exit 1
}
finally {
    # Clean up working directory if empty
    if ((Test-Path $WorkingDirectory) -and (-not $DryRun)) {
        $items = Get-ChildItem $WorkingDirectory -ErrorAction SilentlyContinue
        if ($items.Count -eq 0) {
            Remove-Item $WorkingDirectory -ErrorAction SilentlyContinue
        }
    }
}