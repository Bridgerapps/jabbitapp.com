#!/usr/bin/env bash
# Push root + jabbitapp.com repo safely.
#
# Why:
# - The website lives in a nested git repo (often a submodule).
# - Pushing in the wrong order can leave root pointing at a non-existent site commit.
# - This script makes “verify → push site → push root” repeatable.
#
# Usage:
#   bash scripts/push-all.sh           # verify + push (site first)
#   bash scripts/push-all.sh --dry-run # print what would happen

set -euo pipefail

WS="/home/jabbit/.openclaw/workspace"
DRY=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY=1
fi

say() { echo "$*"; }
die() { echo "push-all:error:$*" >&2; exit 1; }

require_clean() {
  local repo="$1"
  local name="$2"
  if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
    die "$name is not a git repo ($repo)"
  fi

  if ! git -C "$repo" diff --quiet 2>/dev/null; then
    die "$name has unstaged changes (commit or stash first)"
  fi
  if ! git -C "$repo" diff --cached --quiet 2>/dev/null; then
    die "$name has staged but uncommitted changes (commit first)"
  fi
  if [ -n "$(git -C "$repo" ls-files --others --exclude-standard 2>/dev/null | head -1 || true)" ]; then
    die "$name has untracked files (add/commit or clean first)"
  fi
}

push_repo() {
  local repo="$1"
  local name="$2"

  local upstream
  upstream="$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)"
  if [ -z "$upstream" ]; then
    die "$name has no upstream tracking branch"
  fi

  local behind ahead
  read -r behind ahead < <(git -C "$repo" rev-list --left-right --count "${upstream}...HEAD" 2>/dev/null || echo "0 0")

  if [ "${behind:-0}" -gt 0 ] 2>/dev/null; then
    die "$name is behind upstream by $behind commit(s) (pull/rebase first)"
  fi

  if [ "${ahead:-0}" -eq 0 ] 2>/dev/null; then
    say "$name: nothing to push"
    return 0
  fi

  if [ "$DRY" -eq 1 ]; then
    say "$name: would push $ahead commit(s) to $upstream"
    return 0
  fi

  say "$name: pushing $ahead commit(s)…"
  git -C "$repo" push
}

# 1) Verify (read-only)
bash "$WS/scripts/site-sync.sh" verify >/dev/null
say "push-all:verify:ok"

# 2) Safety: require clean trees
require_clean "$WS/jabbitapp.com" "jabbitapp.com"
require_clean "$WS" "root"

# 3) Push site first, then root
push_repo "$WS/jabbitapp.com" "jabbitapp.com"
push_repo "$WS" "root"

say "push-all:ok"