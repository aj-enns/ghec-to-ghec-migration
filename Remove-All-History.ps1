# Script to Remove All Git History and Start Fresh
# This creates a new repository with only the current state

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Remove All Git History - Fresh Start" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Check if we're in a git repository
try {
    $gitRoot = git rev-parse --show-toplevel 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Not in a git repository!" -ForegroundColor Red
        exit 1
    }
    $gitRoot = $gitRoot.Trim()
    Write-Host "Repository root: $gitRoot" -ForegroundColor Gray
}
catch {
    Write-Host "❌ Git is not available or not in a git repository!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "⚠️  WARNING: This will PERMANENTLY DELETE all git history!" -ForegroundColor Yellow
Write-Host ""
Write-Host "This will:" -ForegroundColor Yellow
Write-Host "  1. Delete all commit history" -ForegroundColor Yellow
Write-Host "  2. Delete all branches except main" -ForegroundColor Yellow
Write-Host "  3. Delete all tags" -ForegroundColor Yellow
Write-Host "  4. Create a single initial commit with current files" -ForegroundColor Yellow
Write-Host "  5. Require force push to update remote" -ForegroundColor Yellow
Write-Host ""
Write-Host "Current state will be preserved in the new initial commit." -ForegroundColor Cyan
Write-Host ""

# Show current status
Write-Host "Current repository info:" -ForegroundColor Cyan
$currentBranch = git branch --show-current
$commitCount = git rev-list --count HEAD
$remoteUrl = git remote get-url origin 2>$null

Write-Host "  Branch: $currentBranch" -ForegroundColor Gray
Write-Host "  Total commits: $commitCount" -ForegroundColor Gray
if ($remoteUrl) {
    Write-Host "  Remote: $remoteUrl" -ForegroundColor Gray
}

Write-Host ""
Write-Host "⚠️  CRITICAL: All collaborators will need to re-clone!" -ForegroundColor Red
Write-Host ""

$confirm = Read-Host "Type 'DELETE ALL HISTORY' to continue (anything else cancels)"

if ($confirm -ne "DELETE ALL HISTORY") {
    Write-Host ""
    Write-Host "❌ Operation cancelled - no changes made" -ForegroundColor Red
    exit 0
}

Write-Host ""
Write-Host "Starting history removal..." -ForegroundColor Green
Write-Host ""

# Check for uncommitted changes
Write-Host "1. Checking for uncommitted changes..." -ForegroundColor Cyan
$status = git status --porcelain
if ($status) {
    Write-Host "   ⚠️  You have uncommitted changes!" -ForegroundColor Yellow
    Write-Host ""
    git status
    Write-Host ""
    $commitNow = Read-Host "Commit them now? (y/n)"
    
    if ($commitNow -eq "y") {
        git add -A
        $commitMsg = Read-Host "Enter commit message"
        git commit -m "$commitMsg"
        Write-Host "   ✅ Changes committed" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Please commit or stash your changes first" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "   ✅ No uncommitted changes" -ForegroundColor Green
}

Write-Host ""
Write-Host "2. Creating backup branch (just in case)..." -ForegroundColor Cyan
$backupBranch = "backup-before-history-removal-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
git branch $backupBranch
Write-Host "   ✅ Backup created: $backupBranch" -ForegroundColor Green

Write-Host ""
Write-Host "3. Removing all git history..." -ForegroundColor Cyan

# Delete .git directory
$gitDir = Join-Path $gitRoot ".git"
Write-Host "   Deleting .git directory..." -ForegroundColor Gray
Remove-Item -Path $gitDir -Recurse -Force

Write-Host "   ✅ Git history deleted" -ForegroundColor Green

Write-Host ""
Write-Host "4. Initializing new repository..." -ForegroundColor Cyan
git init
Write-Host "   ✅ New repository initialized" -ForegroundColor Green

Write-Host ""
Write-Host "5. Creating initial commit with all current files..." -ForegroundColor Cyan
git add -A
git commit -m "Initial commit - fresh start"
Write-Host "   ✅ Initial commit created" -ForegroundColor Green

# Rename branch to main if needed
$currentBranch = git branch --show-current
if ($currentBranch -ne "main") {
    Write-Host ""
    Write-Host "6. Renaming branch to 'main'..." -ForegroundColor Cyan
    git branch -M main
    Write-Host "   ✅ Branch renamed to main" -ForegroundColor Green
}

# Re-add remote if it existed
if ($remoteUrl) {
    Write-Host ""
    Write-Host "7. Re-adding remote origin..." -ForegroundColor Cyan
    git remote add origin $remoteUrl
    Write-Host "   ✅ Remote added: $remoteUrl" -ForegroundColor Green
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "✅ History Removal Complete!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green

Write-Host ""
Write-Host "Repository summary:" -ForegroundColor Cyan
$newCommitCount = git rev-list --count HEAD
Write-Host "  New commit count: $newCommitCount" -ForegroundColor Gray
Write-Host "  Branch: main" -ForegroundColor Gray

Write-Host ""
Write-Host "================================================" -ForegroundColor Yellow
Write-Host "⚠️  NEXT STEPS - REQUIRED!" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Yellow
Write-Host ""

if ($remoteUrl) {
    Write-Host "To update the remote repository, run:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   git push -f origin main" -ForegroundColor White
    Write-Host ""
    Write-Host "⚠️  This will PERMANENTLY REPLACE all history on GitHub!" -ForegroundColor Red
    Write-Host ""
    Write-Host "All collaborators must then:" -ForegroundColor Yellow
    Write-Host "  1. Delete their local repository" -ForegroundColor Yellow
    Write-Host "  2. Clone fresh from GitHub" -ForegroundColor Yellow
    Write-Host ""
    
    $pushNow = Read-Host "Push to remote now? (y/n)"
    if ($pushNow -eq "y") {
        Write-Host ""
        Write-Host "Pushing to remote..." -ForegroundColor Cyan
        git push -f origin main
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Successfully pushed to remote!" -ForegroundColor Green
        } else {
            Write-Host "❌ Push failed. You may need to run the command manually." -ForegroundColor Red
        }
    }
} else {
    Write-Host "No remote configured. Add remote with:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   git remote add origin <your-repo-url>" -ForegroundColor White
    Write-Host "   git push -u origin main" -ForegroundColor White
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Done! Your repository now has a clean history." -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
