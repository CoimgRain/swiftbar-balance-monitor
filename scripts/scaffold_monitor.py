#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import pathlib
import re
import shutil


ROOT = pathlib.Path(__file__).resolve().parents[1]
TEMPLATE_DIR = ROOT / "assets" / "templates"


def env_prefix(service_id: str) -> str:
    return re.sub(r"[^A-Za-z0-9]+", "_", service_id).strip("_").upper()


def render(template_name: str, values: dict[str, str]) -> str:
    text = (TEMPLATE_DIR / template_name).read_text(encoding="utf-8")
    for key, value in values.items():
        text = text.replace("{{" + key + "}}", value)
    return text


def write(path: pathlib.Path, text: str, executable: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    if executable:
        path.chmod(path.stat().st_mode | 0o111)


def main() -> int:
    parser = argparse.ArgumentParser(description="Create a SwiftBar balance monitor skeleton.")
    parser.add_argument("--output", required=True, help="Project directory to create or update.")
    parser.add_argument("--service-id", required=True, help="Lowercase id, e.g. acme-relay.")
    parser.add_argument("--label", required=True, help="Short menu bar label.")
    parser.add_argument("--currency", default="$", help="Currency prefix, e.g. $, ¥, EUR ")
    parser.add_argument("--subscription-prefix", default="Sub ", help="Compact prefix before subscription percentage.")
    parser.add_argument("--base-url-env", help="Environment variable for base URL.")
    parser.add_argument("--base-url-default", default="https://example.com", help="Default base URL placeholder.")
    parser.add_argument("--plugin-index", default="01", help="SwiftBar filename prefix, e.g. 01.")
    args = parser.parse_args()

    service_id = re.sub(r"[^a-z0-9-]+", "-", args.service_id.lower()).strip("-")
    if not service_id:
        raise SystemExit("service id must contain letters or digits")

    prefix = env_prefix(service_id)
    base_url_env = args.base_url_env or f"{prefix}_BASE_URL"
    values = {
        "SERVICE_ID": service_id,
        "LABEL": args.label,
        "CURRENCY": args.currency,
        "SUBSCRIPTION_PREFIX": args.subscription_prefix,
        "SERVICE_ENV_PREFIX": prefix,
        "BASE_URL_ENV": base_url_env,
        "BASE_URL_DEFAULT": args.base_url_default,
        "MODE": "used",
    }

    out = pathlib.Path(args.output).expanduser().resolve()
    service_dir = out / service_id
    actions_dir = out / "actions"
    plugin_dir = out / "swiftbar-plugins"

    write(service_dir / "fetch_usage.py", render("fetch_usage.py.tpl", values), executable=True)
    write(plugin_dir / f"{args.plugin_index}-{service_id}.1m.sh", render("swiftbar_plugin.sh.tpl", values), executable=True)

    for mode in ("used", "remain"):
        mode_values = dict(values)
        mode_values["MODE"] = mode
        write(actions_dir / f"{service_id}-display-{mode}.sh", render("set_display_mode.sh.tpl", mode_values), executable=True)

    gitignore = out / ".gitignore"
    if gitignore.exists():
        existing = gitignore.read_text(encoding="utf-8")
        addition = render("gitignore.tpl", values)
        if "state.json" not in existing:
            gitignore.write_text(existing.rstrip() + "\n\n" + addition, encoding="utf-8")
    else:
        shutil.copyfile(TEMPLATE_DIR / "gitignore.tpl", gitignore)

    print(f"Created SwiftBar monitor skeleton at {out}")
    print(f"Edit {service_dir / 'fetch_usage.py'} and implement fetch_all().")
    print(f"Point SwiftBar at {plugin_dir}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
