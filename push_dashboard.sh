#!/bin/bash
# push_dashboard.sh — auto-commit + push oil.html to GitHub after each refresh.
#
# Invoked by the oil-dashboard-refresh scheduled task immediately after
# regenerate_dashboard.py finishes. Idempotent: if oil.html hasn't changed
# since the last commit, this exits cleanly without creating an empty commit.
#
# Requires:
#   - gh CLI authenticated (gh auth status)
#   - Git remote 'origin' pointing to the public oil-dashboard repo
#   - .gitignore configured to deny everything except oil.html (deny-by-default)
#
# Run manually to test:
#   ./push_dashboard.sh

set -e

PROJECT_DIR="/Users/paullentkowski/Documents/Claude/Projects/Oil Tail Risk and Macro Signals"
cd "$PROJECT_DIR"

# Sanity check: oil.html exists
if [ ! -f "oil.html" ]; then
  echo "[push_dashboard] ERROR: oil.html not found in $PROJECT_DIR"
  exit 1
fi

# If git not initialized yet, bail — initial setup should be done by hand
if [ ! -d ".git" ]; then
  echo "[push_dashboard] ERROR: .git not found. Run 'git init' + 'git remote add origin' first."
  exit 1
fi

# Stage oil.html (the .gitignore allow-list ensures nothing else can sneak in)
git add oil.html

# If nothing changed (no staged diff), exit cleanly
if git diff --cached --quiet; then
  echo "[push_dashboard] No changes to oil.html — skipping push"
  exit 0
fi

# Commit with a timestamped message
COMMIT_MSG="Dashboard refresh $(date '+%Y-%m-%d %H:%M %Z')"
git commit -m "$COMMIT_MSG" >/dev/null

# Push to origin/main. Use --quiet to keep logs clean; failure surfaces via exit code.
if git push origin main --quiet; then
  echo "[push_dashboard] Pushed: $COMMIT_MSG"
else
  echo "[push_dashboard] ERROR: git push failed. Check 'gh auth status' and network."
  exit 1
fi
