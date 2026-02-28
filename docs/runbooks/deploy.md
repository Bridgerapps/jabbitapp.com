# Runbook: Deploy/publish site changes (git push)

This repo typically has **two git repos**:
- **root**: automation/scripts + docs
- **jabbitapp.com/**: the static site content (often a submodule-style nested repo)

To publish new SEO pages and internal-link changes, you must push **both**.

## Fast path (recommended)

1) Verify everything is consistent (no writes, just audits):

```bash
bash scripts/site-sync.sh verify
bash scripts/pipeline-health-check.sh --deep
```

2) Ensure you have no uncommitted changes:

```bash
git status
(cd jabbitapp.com && git status)
```

3) Push both repos (site first):

```bash
bash scripts/push-all.sh
```

Dry-run (shows what would be pushed):

```bash
bash scripts/push-all.sh --dry-run
```

## Manual push (if you don’t want the helper)

```bash
(cd jabbitapp.com && git push)
git push
```

## Common failures

- **"no upstream tracking branch"**
  - Fix by setting upstream, e.g.:
    ```bash
    git push -u origin main
    ```

- **"behind upstream"**
  - Pull/rebase first, then retry.

- **Auth errors**
  - Ensure your git remote is using the right SSH key / token.
