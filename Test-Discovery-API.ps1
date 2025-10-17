# Test script to diagnose discovery API issues
# This will help identify why the discovery workflow found 0 organizations

param(
    [Parameter(Mandatory=$true)]
    [string]$Token,
    
    [Parameter(Mandatory=$false)]
    [string]$Enterprise
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "GitHub Discovery API Diagnostic Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$headers = @{
    "Authorization" = "Bearer $Token"
    "Accept" = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
}

# Test 1: Check authenticated user
Write-Host "Test 1: Checking authenticated user..." -ForegroundColor Yellow
try {
    $user = Invoke-RestMethod -Uri "https://api.github.com/user" -Headers $headers
    Write-Host "✅ Authenticated as: $($user.login)" -ForegroundColor Green
    Write-Host "   Type: $($user.type)" -ForegroundColor Gray
    Write-Host "   Site Admin: $($user.site_admin)" -ForegroundColor Gray
    Write-Host ""
}
catch {
    Write-Host "❌ Failed to authenticate: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    exit 1
}

# Test 2: Try enterprise API (if enterprise name provided)
if ($Enterprise) {
    Write-Host "Test 2: Trying Enterprise API..." -ForegroundColor Yellow
    try {
        $uri = "https://api.github.com/enterprises/$Enterprise/organizations?per_page=10"
        Write-Host "   Calling: $uri" -ForegroundColor Gray
        $enterpriseOrgs = Invoke-RestMethod -Uri $uri -Headers $headers
        Write-Host "✅ Enterprise API works! Found $($enterpriseOrgs.Count) organizations (first page)" -ForegroundColor Green
        
        if ($enterpriseOrgs.Count -gt 0) {
            Write-Host "   First few organizations:" -ForegroundColor Gray
            $enterpriseOrgs | Select-Object -First 5 | ForEach-Object {
                Write-Host "   - $($_.login)" -ForegroundColor Gray
            }
        }
        Write-Host ""
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        Write-Host "⚠️  Enterprise API not accessible (Status: $statusCode)" -ForegroundColor Yellow
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Gray
        Write-Host "   This is expected if you don't have enterprise admin rights" -ForegroundColor Gray
        Write-Host ""
    }
}

# Test 3: Try user organizations endpoint
Write-Host "Test 3: Trying User Organizations API..." -ForegroundColor Yellow
try {
    $uri = "https://api.github.com/user/orgs?per_page=100"
    Write-Host "   Calling: $uri" -ForegroundColor Gray
    $userOrgs = Invoke-RestMethod -Uri $uri -Headers $headers
    Write-Host "✅ User Orgs API works! Found $($userOrgs.Count) organizations" -ForegroundColor Green
    
    if ($userOrgs.Count -gt 0) {
        Write-Host "   Your organizations:" -ForegroundColor Gray
        $userOrgs | ForEach-Object {
            Write-Host "   - $($_.login)" -ForegroundColor Cyan
        }
    }
    else {
        Write-Host "   ⚠️  No organizations found" -ForegroundColor Yellow
        Write-Host "   Possible reasons:" -ForegroundColor Gray
        Write-Host "   1. PAT doesn't have 'read:org' scope" -ForegroundColor Gray
        Write-Host "   2. User is not a member of any organizations" -ForegroundColor Gray
        Write-Host "   3. SSO authorization needed for EMU organizations" -ForegroundColor Gray
    }
    Write-Host ""
}
catch {
    Write-Host "❌ User Orgs API failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
}

# Test 4: Try getting specific org details (if we found any)
if ($userOrgs -and $userOrgs.Count -gt 0) {
    Write-Host "Test 4: Testing organization details access..." -ForegroundColor Yellow
    $testOrg = $userOrgs[0].login
    try {
        $uri = "https://api.github.com/orgs/$testOrg"
        Write-Host "   Calling: $uri" -ForegroundColor Gray
        $orgDetail = Invoke-RestMethod -Uri $uri -Headers $headers
        Write-Host "✅ Can access organization details" -ForegroundColor Green
        Write-Host "   Name: $($orgDetail.name)" -ForegroundColor Gray
        Write-Host "   Description: $($orgDetail.description)" -ForegroundColor Gray
        Write-Host ""
    }
    catch {
        Write-Host "❌ Cannot access org details: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
    }
    
    # Test 5: Try getting repositories for the org
    Write-Host "Test 5: Testing repository access..." -ForegroundColor Yellow
    try {
        $uri = "https://api.github.com/orgs/$testOrg/repos?per_page=10"
        Write-Host "   Calling: $uri" -ForegroundColor Gray
        $repos = Invoke-RestMethod -Uri $uri -Headers $headers
        Write-Host "✅ Can access repositories! Found $($repos.Count) repos (first page)" -ForegroundColor Green
        
        if ($repos.Count -gt 0) {
            Write-Host "   First few repositories:" -ForegroundColor Gray
            $repos | Select-Object -First 5 | ForEach-Object {
                Write-Host "   - $($_.full_name) $(if($_.private){'🔒'}else{'🌐'})" -ForegroundColor Gray
            }
        }
        Write-Host ""
    }
    catch {
        Write-Host "❌ Cannot access repositories: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
    }
}

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary & Recommendations" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($userOrgs -and $userOrgs.Count -gt 0) {
    Write-Host "✅ Discovery should work with $($userOrgs.Count) organizations found" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "1. Run the discovery workflow again" -ForegroundColor White
    Write-Host "2. It will use the User Organizations endpoint (this is normal)" -ForegroundColor White
    Write-Host "3. Check the generated reports for the $($userOrgs.Count) organizations" -ForegroundColor White
}
else {
    Write-Host "⚠️  No organizations were found" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Troubleshooting Steps:" -ForegroundColor Yellow
    Write-Host "1. Verify PAT has 'read:org' scope" -ForegroundColor White
    Write-Host "   - Go to: https://github.com/settings/tokens" -ForegroundColor Gray
    Write-Host "   - Check your token has 'read:org' checked" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. For EMU organizations, authorize SSO:" -ForegroundColor White
    Write-Host "   - Go to: https://github.com/settings/tokens" -ForegroundColor Gray
    Write-Host "   - Find your token" -ForegroundColor Gray
    Write-Host "   - Click 'Configure SSO'" -ForegroundColor Gray
    Write-Host "   - Authorize for all organizations" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Verify you are a member of organizations:" -ForegroundColor White
    Write-Host "   - Go to: https://github.com/$($user.login)" -ForegroundColor Gray
    Write-Host "   - Check 'Organizations' tab" -ForegroundColor Gray
    Write-Host ""
    Write-Host "4. If using EMU, ensure you're logged in with EMU account:" -ForegroundColor White
    Write-Host "   - EMU usernames typically end with '_<enterprise>'" -ForegroundColor Gray
    Write-Host "   - Your username: $($user.login)" -ForegroundColor Gray
}

Write-Host ""
