# Twitter distribution runbook

## What’s the problem?
We have multiple Twitter posting “lanes,” and the key names drifted across scripts.

- Posting via **TwitterAPI.io** uses `TWITTER_API_KEY`.
- Older scripts checked `TWITTERAPI_KEY` (no underscore), which caused false “not configured” health output.

## Canonical env var
- **Use:** `TWITTER_API_KEY`
- Back-compat: scripts will also accept `TWITTERAPI_KEY`, but don’t rely on it.

## Setup (recommended)
1) Create a local env file (never commit):

```bash
cp scripts/twitter.env.example scripts/twitter.env
$EDITOR scripts/twitter.env
```

2) Add your key:

```bash
export TWITTER_API_KEY="..."
```

3) Health check:

```bash
bash scripts/twitter-health-check.sh
```

## Posting (explicit only)
The posting script is intentionally “write” behavior; run it only with an explicit message:

```bash
bash scripts/twitter-api-io-post.sh "Your tweet text"
```

## If you want browser-based posting
Use OpenClaw Chrome relay:
- Log in to X/Twitter in Chrome
- Click the OpenClaw Browser Relay toolbar icon on that tab (badge ON)
- Then we can automate posting from that attached tab

## Related scripts
- `scripts/twitter.sh` (entrypoint)
- `scripts/twitter-unified.sh` (status + queue + circuit)
- `scripts/twitter-health-check.sh` (key-aware health)
- `scripts/twitter-api-io-post.sh` (TwitterAPI.io posting)
