# Push script for Recipe-App
# Repo: https://github.com/andreitechvision/Recipe-App

$ErrorActionPreference = "Stop"

Set-Location $PSScriptRoot

# Initialize git if not already done
if (-not (Test-Path ".git")) {
    git init
    git remote add origin https://github.com/andreitechvision/Recipe-App.git
}

# Check for sensitive files that shouldn't be committed
$sensitive = git status --porcelain | Where-Object { $_ -match '\.(env|pem|key|secret)$|jwt_secret|resend_key|stripe.*secret' }
if ($sensitive) {
    Write-Host "⚠️  WARNING: Potentially sensitive files detected:" -ForegroundColor Yellow
    Write-Host $sensitive
    Write-Host ""
    $reply = Read-Host "Continue anyway? (y/N)"
    if ($reply -ne "y" -and $reply -ne "Y") {
        Write-Host "Aborted."
        exit 1
    }
}

# Show what will be committed
Write-Host "📦 Files to commit:" -ForegroundColor Cyan
git status --short
Write-Host ""

# Add all changes
git add -A

# Commit (use provided message or prompt)
if ($args.Count -gt 0) {
    $msg = $args[0]
} else {
    $msg = Read-Host "Commit message (default: update)"
    if ([string]::IsNullOrWhiteSpace($msg)) {
        $msg = "update: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    }
}

git commit -m $msg
if ($LASTEXITCODE -ne 0) { Write-Host "Nothing to commit" }

# Push
git branch -M main
git push -u origin main

Write-Host "✅ Recipe-App pushed successfully" -ForegroundColor Green
