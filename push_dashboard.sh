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

# Helper: macOS Notification Center alert. Silent no-op if osascript is missing
# (e.g. running on Linux / sandbox). Failures suppressed so notify never aborts the script.
notify_failure() {
  local msg="$1"
  if command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"$msg\" with title \"Oil Dashboard\" subtitle \"Push failed\" sound name \"Basso\"" 2>/dev/null || true
  fi
}

# Sanity check: oil.html exists
if [ ! -f "oil.html" ]; then
  echo "[push_dashboard] ERROR: oil.html not found in $PROJECT_DIR"
  notify_failure "oil.html not found in project directory"
  exit 1
fi

# If git not initialized yet, bail — initial setup should be done by hand
if [ ! -d ".git" ]; then
  echo "[push_dashboard] ERROR: .git not found. Run 'git init' + 'git remote add origin' first."
  notify_failure ".git directory missing — initial setup not complete"
  exit 1
fi

# Clean up stale git locks left by previous runs that crashed mid-write.
# Only remove locks older than 2 minutes — fresh locks may belong to a real
# git process running right now (e.g. another invocation of this script).
for lock in .git/index.lock .git/HEAD.lock; do
  if [ -f "$lock" ] && [ -z "$(find "$lock" -mmin -2 2>/dev/null)" ]; then
    echo "[push_dashboard] Removing stale lock: $lock"
    rm -f "$lock"
  fi
done

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
  notify_failure "git push to origin/main failed. Run 'git push origin main' from terminal to retry."
  exit 1
fi
