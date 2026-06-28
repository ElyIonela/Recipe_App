#!/bin/bash
# Push script for Recipe-App
# Repo: https://github.com/andreitechvision/Recipe-App

set -e

cd "$(dirname "$0")"

# Initialize git if not already done
if [ ! -d ".git" ]; then
  git init
  git remote add origin https://github.com/andreitechvision/Recipe-App.git
fi

# Check for sensitive files that shouldn't be committed
SENSITIVE=$(git status --porcelain | grep -E '\.(env|pem|key|secret)$|jwt_secret|resend_key|stripe.*secret' || true)
if [ -n "$SENSITIVE" ]; then
  echo "⚠️  WARNING: Potentially sensitive files detected:"
  echo "$SENSITIVE"
  echo ""
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
  fi
fi

# Show what will be committed
echo "📦 Files to commit:"
git status --short
echo ""

# Add all changes
git add -A

# Commit (use provided message or prompt)
if [ -n "$1" ]; then
  MSG="$1"
else
  read -p "Commit message (default: update): " MSG
  MSG="${MSG:-update: $(date '+%Y-%m-%d %H:%M')}"
fi

git commit -m "$MSG" || echo "Nothing to commit"

# Push
git branch -M main
git push -u origin main

echo "✅ Recipe-App pushed successfully"
