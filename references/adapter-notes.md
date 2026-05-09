# Adapter Notes

## Endpoint Discovery

Prefer primary evidence from the user's session:

- Browser DevTools Network panel after opening wallet, profile, billing, usage, subscription, or dashboard pages.
- Site JavaScript assets, searched for `/api/`, `wallet`, `quota`, `subscription`, `amount`, `usage`, `self`, `profile`, `billing`.
- Existing local scripts, if the user already has a partial monitor.

Record only endpoint shapes and field mappings. Do not copy cookies, bearer tokens, or account identifiers into reusable docs.

## Common Data Mapping

Map site responses into this normalized object:

```python
{
    "ok": True,
    "label": "Ex",
    "balance": 50.20,
    "currency": "$",
    "username": "optional",
    "updated_at_text": "2026-01-01 12:00:00",
    "subscription": {
        "active": True,
        "used": 259.12,
        "remain": 40.88,
        "total": 300.00,
        "used_percent": 86.4,
        "remain_percent": 13.6,
        "items": []
    }
}
```

Only `balance` is mandatory. Add subscription and usage fields as the site supports them.

## Authentication Patterns

Use the simplest stable local method:

- Cookie header from an authenticated browser session.
- Bearer/API token from user settings.
- Login endpoint only when it is stable and does not require CAPTCHA/2FA.

Store auth in local state or environment variables. If CAPTCHA/2FA appears, ask the user to provide a local cookie or token instead of automating around the challenge.

## Site-Specific Adapter Checklist

1. Fetch the current user or wallet profile.
2. Convert raw quota units to money or credits if needed.
3. Fetch subscription/plan usage when available.
4. Save a cache so SwiftBar can show the last known state if the network fails.
5. Format display rows with the no-op SwiftBar action.
6. Add display-mode state only when the user wants toggles.
7. Validate with the exact SwiftBar plugin script.
