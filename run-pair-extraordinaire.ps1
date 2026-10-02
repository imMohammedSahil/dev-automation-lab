<#
.SYNOPSIS
    Automates the creation and merging of co-authored Pull Requests to unlock / level up
    the "Pair Extraordinaire" achievement badge on GitHub.

.DESCRIPTION
    This script initializes/configures a standalone sandbox repository, creates branches,
    adds co-authored commits (with the standard trailer format), submits PRs, and merges them sequentially.

.PARAMETER TargetTier
    Choose 'Bronze' (1 PR), 'Silver' (10 PRs), 'Gold' (24 PRs), or specify an exact number.

.PARAMETER RepoName
    The name of the remote repository to create/link (default: sandbox-achievements).

.PARAMETER IsPublic
    Whether the repository should be public (default: $true, recommended for achievements).

.PARAMETER DelaySeconds
    Delay between PR cycles to stay well within GitHub API rate limits (default: 4 seconds).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Bronze', 'Silver', 'Gold', 'Custom')]
    [string]$Tier = 'Gold',

    [Parameter(Mandatory = $false)]
    [int]$CustomPrCount = 24,

    [Parameter(Mandatory = $false)]
    [string]$RepoName = "sandbox-achievements",

    [Parameter(Mandatory = $false)]
    [bool]$IsPublic = $true,

    [Parameter(Mandatory = $false)]
    [int]$DelaySeconds = 4,

    [Parameter(Mandatory = $false)]
    [string]$CoAuthorName = "github-actions[bot]",

    [Parameter(Mandatory = $false)]
    [string]$CoAuthorEmail = "41898282+github-actions[bot]@users.noreply.github.com"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "`n========================================================" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Green
    Write-Host "========================================================" -ForegroundColor Cyan
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

# 1. Determine PR Count based on selected Tier
$prTargetCount = switch ($Tier) {
    'Bronze' { 1 }
    'Silver' { 10 }
    'Gold'   { 24 }
    'Custom' { $CustomPrCount }
    Default  { 24 }
}

Write-Step "Target: $Tier Tier ($prTargetCount PRs) for Pair Extraordinaire"

# 2. Check Prerequisites
Write-Step "Checking GitHub CLI and Git Prerequisites"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Git is not installed or not in PATH."
    exit 1
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI ('gh') is not installed. Please install it or authenticate."
    exit 1
}

# Check gh authentication
$authStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "`nGitHub CLI is not authenticated." -ForegroundColor Red
    Write-Host "Please authenticate by running:" -ForegroundColor Yellow
    Write-Host "    gh auth login`n" -ForegroundColor White
    exit 1
}

$currentUser = (gh api user --jq .login 2>&1).Trim()
Write-Success "Authenticated as GitHub user: $currentUser"

# 3. Initialize Local Git Repository if needed
Write-Step "Setting Up Local Repository"

if (-not (Test-Path ".git")) {
    git init -b main
    Write-Success "Initialized empty Git repository on branch 'main'."
} else {
    Write-Info "Git repository already initialized."
}

# Ensure at least one commit exists on main
$hasCommits = $false
try {
    git rev-parse --verify HEAD 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $hasCommits = $true
    }
} catch {
    $hasCommits = $false
}

if (-not $hasCommits) {
    git checkout -B main
    git add .
    git commit -m "chore: initial commit for sandbox environment"
    Write-Success "Created initial commit on branch 'main'."
}

# 4. Create or Link Remote Repository
Write-Step "Checking / Creating Remote Repository '$RepoName'"

$repoExists = $false
try {
    $checkRepo = gh repo view "$currentUser/$RepoName" --json name 2>&1
    if ($LASTEXITCODE -eq 0) {
        $repoExists = $true
        Write-Info "Remote repository '$currentUser/$RepoName' already exists."
    }
} catch {
    $repoExists = $false
}

$remotes = git remote
if ($remotes -notcontains "origin") {
    git remote add origin "https://github.com/$currentUser/$RepoName.git"
    Write-Success "Linked origin remote to https://github.com/$currentUser/$RepoName.git"
}

if (-not $repoExists) {
    $visibilityFlag = if ($IsPublic) { "--public" } else { "--private" }
    Write-Info "Creating remote repository '$RepoName' ($visibilityFlag)..."
    gh repo create "$currentUser/$RepoName" $visibilityFlag --source=. --remote=origin --push
    Write-Success "Remote repository created and linked to origin."
} else {
    git push -u origin main
    Write-Success "Pushed main branch to origin."
}

# 5. Execute Co-Authored PR Workflow
Write-Step "Executing $prTargetCount Co-Authored Pull Requests"

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$successCount = 0

for ($i = 1; $i -le $prTargetCount; $i++) {
    $branchName = "pair-feature-$timestamp-$i"
    $fileName = "activity-log.md"
    $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    Write-Host "`n>>> [PR $i / $prTargetCount] Processing branch '$branchName'..." -ForegroundColor Magenta
    
    # Switch to fresh main
    git checkout -q main
    git pull -q origin main 2>$null

    # Create and checkout feature branch
    git checkout -q -b $branchName

    # Append activity
    $entry = "- **Cycle #$i**: Added co-authored entry on $now by @$currentUser and @$CoAuthorName`n"
    Add-Content -Path $fileName -Value $entry

    git add $fileName

    # Format commit message with required trailer
    $commitMsg = @"
feat(pair): update pair activity entry #$i

Collaborative achievement logging cycle $i of $prTargetCount.

Co-authored-by: $CoAuthorName <$CoAuthorEmail>
"@

    # Commit with explicit trailer
    git commit -m $commitMsg

    # Push feature branch
    Write-Info "Pushing branch '$branchName'..."
    git push -u origin $branchName -q

    # Create Pull Request
    $prTitle = "feat(pair): log co-authored contribution #$i"
    $prBody = @"
### Pair Extraordinaire Contribution #$i

This PR includes a co-authored commit for achievement verification.

- **Co-Author**: \`$CoAuthorName <$CoAuthorEmail>\`
- **Cycle**: $i / $prTargetCount
- **Timestamp**: $now
"@

    Write-Info "Submitting Pull Request..."
    $prUrl = gh pr create --title $prTitle --body $prBody --base main --head $branchName

    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($prUrl)) {
        Write-Error "Failed to create PR for cycle $i."
        continue
    }

    Write-Success "Pull Request created: $prUrl"

    # Merge Pull Request (Standard merge commit preserves all git trailers)
    Write-Info "Merging Pull Request into main..."
    gh pr merge $prUrl --merge --delete-branch --subject "Merge PR #$($i) - $($prTitle)"

    if ($LASTEXITCODE -eq 0) {
        $successCount++
        Write-Success "Pull Request #$i successfully merged and branch deleted!"
    } else {
        Write-Host "Warning: Could not auto-merge immediately. Checking merge status..." -ForegroundColor Yellow
    }

    # Delay to respect GitHub API rate limits
    if ($i -lt $prTargetCount) {
        Write-Info "Waiting $DelaySeconds seconds before next cycle..."
        Start-Sleep -Seconds $DelaySeconds
    }
}

# 6. Final Sync
Write-Step "Final Synchronization & Summary"
git checkout -q main
git pull -q origin main

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host " 🎉 COMPLETED: $successCount of $prTargetCount PRs merged successfully!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host "Your co-authored contributions have been registered." -ForegroundColor Cyan
Write-Host "Check your GitHub profile achievements at: https://github.com/$currentUser" -ForegroundColor Yellow
