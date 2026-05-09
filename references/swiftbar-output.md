# SwiftBar Output Notes

## Basic Format

SwiftBar/xbar plugins print plain text:

```text
Menu title
---
Menu row | key=value key=value
```

Rows above the first `---` are menu bar titles. Rows below are dropdown items.

## Active Display Rows

Plain informational rows may be rendered by macOS as disabled gray menu items. To keep them readable without performing work, attach a harmless no-op action:

```text
Balance: $12.34 | bash=/usr/bin/true terminal=false
Updated: 2026-01-01 12:00:00 | bash=/usr/bin/true terminal=false
```

Use this for balance, usage, account, and timestamp rows.

## Action Rows

Use absolute paths and quote paths inside scripts:

```text
Refresh | refresh=true
Open Wallet | href=https://example.com/wallet
Show Used Percent | bash=/abs/path/actions/example-display-used.sh terminal=false refresh=true
```

If a click does nothing, check:

- The action script is executable.
- The path is absolute.
- SwiftBar is scanning the `swiftbar-plugins/` directory.
- The shell script quotes paths containing spaces.

## Compact Titles

Keep menu titles short because menu bar space is scarce:

```text
Ex $50.20 / Sub 86.4%
```

For Chinese compact labels, `订86.4%` is a good subscription percentage form.
