#!/usr/bin/env python3
"""Scan, list, and delete Bar Studio .conf presets cleanly without JSON."""
import sys
from pathlib import Path

BUILTIN_ORDER = [
    "solid",
    "glass",
    "frosted",
    "translucent",
    "tinted",
    "outlined",
    "oled",
    "monochrome",
    "islands",
]


def escape_field(raw: str) -> str:
    return (
        str(raw)
        .replace("\\", "\\\\")
        .replace("\r", "\\r")
        .replace("\n", "\\n")
        .replace("=", "\\e")
        .replace(",", "\\c")
        .replace(";", "\\s")
        .replace("|", "\\p")
    )


def parse_conf(path: Path) -> dict[str, str]:
    data: dict[str, str] = {}
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return data
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, val = line.split("=", 1)
        key = key.strip()
        val = val.strip()
        if (val.startswith('"') and val.endswith('"')) or (
            val.startswith("'") and val.endswith("'")
        ):
            val = val[1:-1]
        data[key] = val
    return data


def cmd_list(builtin_dir: Path, user_dir: Path) -> int:
    records: list[dict[str, str]] = []
    seen: set[str] = set()

    if builtin_dir.is_dir():
        all_builtin = {
            p.stem: p
            for p in builtin_dir.glob("*.conf")
            if p.name != "catalog.conf"
        }
        ordered_keys = [k for k in BUILTIN_ORDER if k in all_builtin] + sorted(
            k for k in all_builtin if k not in BUILTIN_ORDER
        )
        for pid in ordered_keys:
            path = all_builtin[pid]
            data = parse_conf(path)
            raw_text = path.read_text(encoding="utf-8")
            seen.add(pid)
            records.append(
                {
                    "id": pid,
                    "name": data.get("name", pid),
                    "desc": data.get("desc", ""),
                    "barStyle": data.get("barStyle", "solid"),
                    "barFloating": data.get("barFloating", "false"),
                    "barGrouping": data.get("barGrouping", "clusters"),
                    "barWidgetChrome": data.get("barWidgetChrome", "grouped"),
                    "cornerStyle": data.get("cornerStyle", "continuous-bezier"),
                    "isBuiltin": "true",
                    "raw": raw_text,
                }
            )

    if user_dir.is_dir():
        for path in sorted(user_dir.glob("*.conf"), key=lambda p: p.name.lower()):
            pid = path.stem
            if pid in seen:
                continue
            data = parse_conf(path)
            raw_text = path.read_text(encoding="utf-8")
            records.append(
                {
                    "id": pid,
                    "name": data.get("name", pid),
                    "desc": data.get("desc", "saved custom preset"),
                    "barStyle": data.get("barStyle", "solid"),
                    "barFloating": data.get("barFloating", "false"),
                    "barGrouping": data.get("barGrouping", "clusters"),
                    "barWidgetChrome": data.get("barWidgetChrome", "grouped"),
                    "cornerStyle": data.get("cornerStyle", "continuous-bezier"),
                    "isBuiltin": "false",
                    "raw": raw_text,
                }
            )

    lines = ["# Quickshell native preset store", f"count={len(records)}"]
    fields = [
        "id",
        "name",
        "desc",
        "barStyle",
        "barFloating",
        "barGrouping",
        "barWidgetChrome",
        "cornerStyle",
        "isBuiltin",
        "raw",
    ]
    for idx, rec in enumerate(records):
        for field in fields:
            lines.append(f"preset.{idx}.{field}={escape_field(rec.get(field, ''))}")
    sys.stdout.write("\n".join(lines) + "\n")
    return 0


def cmd_delete(user_dir: Path, pid: str) -> int:
    clean = "".join(c for c in pid.strip() if c.isalnum() or c in "-_")
    if not clean:
        return 1
    base = user_dir.resolve()
    target = (base / f"{clean}.conf").resolve()
    if target.parent != base or not target.is_file():
        return 1
    target.unlink()
    return 0


def main() -> int:
    if len(sys.argv) < 2:
        return 1
    action = sys.argv[1]
    if action == "list" and len(sys.argv) >= 4:
        return cmd_list(Path(sys.argv[2]), Path(sys.argv[3]))
    if action == "delete" and len(sys.argv) >= 4:
        return cmd_delete(Path(sys.argv[2]), sys.argv[3])
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
