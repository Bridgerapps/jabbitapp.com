# Git Sync Playbook (root repo + `jabbitapp.com/`)

This repo commonly ends up in one of these states:

- **ahead**: local commits not pushed
- **behind**: remote has commits you don't have locally
- **diverged**: both happened (you need to choose merge vs rebase)

Use this playbook when `scripts/pipeline-health-check.sh` says the repo is ahead/behind/diverged.

## 0) See the truth (fast)

```bash
cd /home/jabbit/.openclaw/workspace
bash scripts/pipeline-health-check.sh
```

For more detail:

```bash
git status -sb
# show upstream + ahead/behind counts
UP=$(git rev-parse --abbrev-ref --symbolic-full-name @{u})
git rev-list --left-right --count "$UP...HEAD"
```

## 1) If root repo is **ahead** only (needs push)

```bash
cd /home/jabbit/.openclaw/workspace
git push
```

## 2) If root repo is **behind** only (needs pull)

Preferred (keeps history linear):

```bash
cd /home/jabbit/.openclaw/workspace
git pull --rebase
```

If you expect conflicts or want the safest route:

```bash
git fetch
# inspect what changed before integrating
UP=$(git rev-parse --abbrev-ref --symbolic-full-name @{u})
git log --oneline --decorate --graph --max-count=30 "$UP" HEAD
```

## 3) If root repo is **diverged** (ahead N, behind M)

### Option A (preferred for a clean history): rebase your local commits on top of remote

```bash
cd /home/jabbit/.openclaw/workspace
git fetch
UP=$(git rev-parse --abbrev-ref --symbolic-full-name @{u})
git rebase "$UP"
# resolve conflicts if any:
#   - edit files
#   - git add <files>
#   - git rebase --continue
# if you need to abort:
#   git rebase --abort

git push
```

### Option B: merge (keeps both histories; creates a merge commit)

```bash
cd /home/jabbit/.openclaw/workspace
git fetch
UP=$(git rev-parse --abbrev-ref --symbolic-full-name @{u})
git merge "$UP"

git push
```

## 4) `jabbitapp.com/` site repo (if it’s a git repo)

```bash
cd /home/jabbit/.openclaw/workspace/jabbitapp.com
git status -sb

git push
```

## 5) One-command helper

If you just want the status + the exact repo(s) that need attention:

```bash
cd /home/jabbit/.openclaw/workspace
bash scripts/pipeline-health-check.sh
```

## Notes / guardrails

- Don’t resolve a diverged state blindly: pick **rebase** or **merge** intentionally.
- If you’re unsure, copy/paste `git status -sb` + the `rev-list` counts into chat and I’ll recommend the safest next step.
