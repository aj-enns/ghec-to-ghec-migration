# Test PAT Access Script
# This script helps diagnose PAT permission issues

param(
    [Parameter(Mandatory=$true)]
    [string]$PAT,
    
    [Parameter(Mandatory=$true)]
    [string]$Organization
)

Write-Host "Testing PAT access to organization: $Organization" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

# Test 1: Check authenticated user
Write-Host "`n1. Testing authenticated user..." -ForegroundColor Yellow
try {
    $headers = @{
        "Authorization" = "token $PAT"
        "Accept" = "application/vnd.github.v3+json"
    }
    
    $user = Invoke-RestMethod -Uri "https://api.github.com/user" -Headers $headers
    Write-Host "   ✅ Authenticated as: $($user.login)" -ForegroundColor Green
    Write-Host "   Account Type: $($user.type)" -ForegroundColor Gray
    Write-Host "   User ID: $($user.id)" -ForegroundColor Gray
}
catch {
    Write-Host "   ❌ Failed to authenticate: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 2: Check PAT scopes
Write-Host "`n2. Checking PAT scopes..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "https://api.github.com/user" -Headers $headers
    $scopes = $response.Headers['X-OAuth-Scopes']
    if ($scopes) {
        Write-Host "   ✅ PAT Scopes: $scopes" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  No scopes found in response" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "   ❌ Failed to get scopes: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Check organization access
Write-Host "`n3. Testing organization access..." -ForegroundColor Yellow
try {
    $org = Invoke-RestMethod -Uri "https://api.github.com/orgs/$Organization" -Headers $headers
    Write-Host "   ✅ Organization found: $($org.login)" -ForegroundColor Green
    Write-Host "   Organization ID: $($org.id)" -ForegroundColor Gray
    Write-Host "   Organization Type: $($org.type)" -ForegroundColor Gray
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 403) {
        Write-Host "   ❌ 403 Forbidden - PAT lacks permission to access this organization" -ForegroundColor Red
        Write-Host "   Possible reasons:" -ForegroundColor Yellow
        Write-Host "     - PAT not authorized for SSO (if SSO is enabled)" -ForegroundColor Yellow
        Write-Host "     - User is not a member of the organization" -ForegroundColor Yellow
        Write-Host "     - PAT lacks 'read:org' scope" -ForegroundColor Yellow
    }
    elseif ($statusCode -eq 404) {
        Write-Host "   ❌ 404 Not Found - Organization doesn't exist or PAT can't see it" -ForegroundColor Red
    }
    else {
        Write-Host "   ❌ HTTP $statusCode : $($_.Exception.Message)" -ForegroundColor Red
    }
    exit 1
}

# Test 4: Check organization membership
Write-Host "`n4. Testing organization membership..." -ForegroundColor Yellow
try {
    $membership = Invoke-RestMethod -Uri "https://api.github.com/orgs/$Organization/memberships/$($user.login)" -Headers $headers
    Write-Host "   ✅ User is a member with role: $($membership.role)" -ForegroundColor Green
    Write-Host "   State: $($membership.state)" -ForegroundColor Gray
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 403) {
        Write-Host "   ❌ 403 Forbidden - Can't check membership (may need admin:org scope)" -ForegroundColor Red
    }
    elseif ($statusCode -eq 404) {
        Write-Host "   ⚠️  User is not a member of this organization" -ForegroundColor Yellow
    }
    else {
        Write-Host "   ⚠️  HTTP $statusCode : $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Test 5: Check repository creation permission
Write-Host "`n5. Testing repository listing (indicates read access)..." -ForegroundColor Yellow
try {
    $repos = Invoke-RestMethod -Uri "https://api.github.com/orgs/$Organization/repos?per_page=1" -Headers $headers
    Write-Host "   ✅ Can list repositories ($($repos.Count) shown)" -ForegroundColor Green
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Host "   ❌ HTTP $statusCode - Cannot list repositories" -ForegroundColor Red
}

Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
Write-Host "Test Complete!" -ForegroundColor Cyan
