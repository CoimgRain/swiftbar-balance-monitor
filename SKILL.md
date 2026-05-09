---
name: swiftbar-balance-monitor
description: Build and maintain macOS SwiftBar/xbar menu bar monitors for API relay, subscription, wallet, quota, token, or balance websites. Use when Codex needs to help a user configure a per-site balance monitor, inspect web/API responses, create Python fetch scripts, create SwiftBar plugin shell entries, add display-mode toggles, fix gray disabled menu text, validate output, restart SwiftBar, or prepare a privacy-safe GitHub skill/repo for this workflow.
---

# SwiftBar Balance Monitor

## Purpose

Help a user build a local macOS SwiftBar monitor for one or more balance/quota websites, even when each site has different APIs, login flows, and response schemas. Treat every website as a site-specific adapter around a reusable structure.

## Model Guidance

For site-specific API discovery, authentication debugging, and response-schema mapping, recommend a strong high-reasoning model. Prefer GPT-5.5 or another top-tier model with high/xhigh reasoning when available; simpler template edits can use a faster model.

## Conversation Flow

Use a guided setup. Ask only for the next missing piece, and prefer discovering details from the local browser/session when the user is already logged in.

Tell the user early that this kind of monitor is usually iterative: each website exposes different fields, auth behavior, quota units, and UI preferences, so the first working version may need adjustment. After each visible result, ask the user to confirm the menu text and dropdown behavior, and invite them to request changes such as labels, percentages, refresh interval, color/readability, shown fields, and ordering.

1. Confirm the monitor target: website name, desired menu label, currency, and what the menu bar should show.
2. Confirm SwiftBar/xbar is installed or install/configure it if the user asks.
3. Identify authentication: cookie, bearer token, API token, or login endpoint. Never ask the user to paste secrets into a public repo or final answer.
4. Inspect API endpoints from browser DevTools, site assets, or existing scripts. Look for user profile, wallet, billing, usage, subscription, and quota endpoints.
5. Create a per-site folder plus one SwiftBar plugin entry under a dedicated `swiftbar-plugins/` directory.
6. Implement fetch logic in Python and keep secrets in local state files or environment variables.
7. Generate display-only rows with the no-op action already included so macOS does not render them as disabled gray text.
8. Validate syntax, plugin output, mode switching, file permissions, SwiftBar process arguments, and privacy before sharing or publishing.
9. Ask the user to inspect the menu bar result and continue refining until it matches their desired display.

## Recommended Layout

Use one project directory for all services:

```text
balance-monitor/
  actions/
    <service>-display-used.sh
    <service>-display-remain.sh
  <service>/
    fetch_usage.py
    state.json        # local only, ignored
    cache.json        # local only, ignored
    cookies.txt       # local only, ignored
  swiftbar-plugins/
    01-<service>.1m.sh
```

Point SwiftBar only at `swiftbar-plugins/`, not the project root.

## Bundled Resources

- `scripts/scaffold_monitor.py`: create a reusable project skeleton from templates.
- `scripts/privacy_scan.py`: scan for secrets and local state before publishing.
- `assets/templates/`: generic Python and shell templates.
- `references/swiftbar-output.md`: SwiftBar output rules, including the no-op row pattern.
- `references/adapter-notes.md`: API discovery and adapter implementation notes.

Load the reference files only when needed. Prefer running the scripts instead of retyping the templates.

## Scaffold

From the skill directory:

```bash
python3 scripts/scaffold_monitor.py \
  --output /path/to/balance-monitor \
  --service-id example \
  --label Ex \
  --currency '$' \
  --subscription-prefix '订' \
  --base-url-env EXAMPLE_BASE_URL \
  --base-url-default https://example.com
```

Then edit `<service>/fetch_usage.py` at the `fetch_all()` TODO to match the site's endpoints and response schema.

## Implementation Rules

- Store local secrets in `state.json`, `cookies.txt`, environment variables, or the user's keychain. Do not hard-code them.
- Add `state.json`, `cache.json`, `cookies.txt`, `.env`, and similar files to `.gitignore`.
- Generate display-only rows with `bash=/usr/bin/true terminal=false`. This keeps menu text in the enabled system color while making clicks harmless; the bundled template already does this.
- Use direct SwiftBar actions for toggles:
  `bash=/absolute/path/to/action.sh terminal=false refresh=true`
- Quote paths with spaces in shell scripts.
- Keep the menu bar title compact. Use `--subscription-prefix '订'` or edit the template when the user wants Chinese compact text such as `订86.4%`.
- If action clicks do nothing, check executable bits, absolute paths, path quoting, and whether SwiftBar is scanning the plugin folder.

## Validation

Run these checks before telling the user it is done:

```bash
python3 -m py_compile <service>/fetch_usage.py
swiftbar-plugins/01-<service>.1m.sh
ps aux | rg -i '[S]wiftBar'
python3 /path/to/skill/scripts/privacy_scan.py /path/to/balance-monitor
```

Restart SwiftBar when needed:

```bash
PLUGIN_DIR="/path/to/balance-monitor/swiftbar-plugins"
pkill -f '/Applications/SwiftBar.app/Contents/MacOS/SwiftBar' || true
open -a SwiftBar --args --folders "$PLUGIN_DIR"
```

## Publishing Safety

Before preparing GitHub upload, run `scripts/privacy_scan.py` on the repo and manually inspect:

```bash
rg -n "cookie|token|secret|password|authorization|bearer|session|user_id|uid|email|phone" .
find . -name 'state.json' -o -name 'cache.json' -o -name 'cookies.txt' -o -name '.env'
```

Remove or ignore all user-specific state, real domains when not meant as public examples, account names, screenshots, browser exports, and generated caches. Publish only reusable instructions, templates, and sanitized examples.
