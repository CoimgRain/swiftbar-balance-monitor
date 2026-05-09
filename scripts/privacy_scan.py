#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib
import re
import sys


SKIP_DIRS = {".git", "__pycache__", ".venv", "node_modules", ".mypy_cache", ".pytest_cache"}
HIGH_RISK_NAMES = {
    ".env",
    "cookies.txt",
    "cookie.txt",
    "state.json",
    "cache.json",
    "secrets.json",
    "credentials.json",
}
HIGH_RISK_SUFFIXES = {".pem", ".key", ".p12", ".pfx", ".har", ".webarchive"}

PATTERNS = [
    ("private key", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    ("bearer token", re.compile(r"(?i)\bbearer\s+(?!<|PLACEHOLDER|CHANGEME|TOKEN\b)[A-Za-z0-9._~+/=-]{20,}")),
    (
        "assigned secret",
        re.compile(
            r"(?i)\b(api[_-]?key|access[_-]?token|refresh[_-]?token|auth[_-]?token|secret|password)\b"
            r"\s*[:=]\s*[\"']?(?!<|PLACEHOLDER|CHANGEME|TODO|your-|example)[A-Za-z0-9._~+/=-]{16,}"
        ),
    ),
    ("cookie header", re.compile(r"(?i)\bcookie\s*[:=]\s*(?!<|PLACEHOLDER|CHANGEME|TODO)[A-Za-z0-9_./%+=;: -]{30,}")),
    ("set-cookie header", re.compile(r"(?i)\bset-cookie\s*:")),
    ("macOS home path", re.compile(r"/Users/[A-Za-z0-9._-]+(?:/|$)")),
    ("email address", re.compile(r"\b[A-Za-z0-9._%+-]+@(?!example\.com\b|example\.invalid\b)[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b")),
    ("phone-like number", re.compile(r"(?<!\d)(?:\+\d[\d -]{8,}\d|[1-9]\d{9,})(?!\d)")),
]


def iter_files(root: pathlib.Path):
    for path in root.rglob("*"):
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        if path.is_file():
            yield path


def is_text(path: pathlib.Path) -> bool:
    try:
        path.read_text(encoding="utf-8")
        return True
    except UnicodeDecodeError:
        return False
    except OSError:
        return False


def scan(root: pathlib.Path) -> list[str]:
    findings: list[str] = []
    for path in iter_files(root):
        rel = path.relative_to(root)
        name = path.name.lower()
        if name in HIGH_RISK_NAMES or path.suffix.lower() in HIGH_RISK_SUFFIXES:
            findings.append(f"HIGH-RISK FILE: {rel}")
        if not is_text(path):
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for label, pattern in PATTERNS:
            for match in pattern.finditer(text):
                line = text.count("\n", 0, match.start()) + 1
                findings.append(f"{label}: {rel}:{line}")
    return findings


def main() -> int:
    parser = argparse.ArgumentParser(description="Scan a monitor repo for secrets before publishing.")
    parser.add_argument("path", help="Directory to scan.")
    args = parser.parse_args()

    root = pathlib.Path(args.path).expanduser().resolve()
    if not root.exists():
        raise SystemExit(f"path does not exist: {root}")

    findings = scan(root)
    if findings:
        print("Potential privacy issues found:")
        for item in findings:
            print(f"- {item}")
        return 1

    print("No obvious secrets or local runtime files found.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
