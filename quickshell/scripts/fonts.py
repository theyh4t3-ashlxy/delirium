#!/usr/bin/env python3
"""Inspect installed variable fonts and extract SFNT `fvar` axes as flat conf records."""
import pathlib
import struct
import subprocess
import sys


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


def parse_fvar_axes(font_path: str) -> list[tuple[str, float, float, float]]:
    try:
        data = pathlib.Path(font_path).read_bytes()
    except OSError:
        return []
    if len(data) < 12:
        return []

    sfnt_off = 0
    if data[:4] == b"ttcf":
        if len(data) < 16:
            return []
        sfnt_off = struct.unpack_from(">I", data, 12)[0]
    if sfnt_off + 12 > len(data):
        return []

    num_tables = struct.unpack_from(">H", data, sfnt_off + 4)[0]
    fvar_off = None
    for i in range(num_tables):
        entry = sfnt_off + 12 + i * 16
        if entry + 16 > len(data):
            break
        tag, _, offset, _ = struct.unpack_from(">4sIII", data, entry)
        if tag == b"fvar":
            fvar_off = offset
            break
    if fvar_off is None or fvar_off + 12 > len(data):
        return []

    arrays_off, _, axis_count, axis_size = struct.unpack_from(">HHHH", data, fvar_off + 4)
    axes: list[tuple[str, float, float, float]] = []
    for i in range(axis_count):
        base = fvar_off + arrays_off + i * axis_size
        if base + 20 > len(data):
            break
        tag, min_v, def_v, max_v, _, _ = struct.unpack_from(">4siiiHH", data, base)
        axes.append(
            (
                tag.decode("latin1"),
                round(min_v / 65536.0, 2),
                round(def_v / 65536.0, 2),
                round(max_v / 65536.0, 2),
            )
        )
    return axes


def format_axes(axes: list[tuple[str, float, float, float]]) -> str:
    parts = []
    for tag, mn, df, mx in axes:
        parts.append(f"{tag}:{mn:g}:{df:g}:{mx:g}")
    return ";".join(parts)


def scan_fonts() -> dict[str, dict]:
    out = subprocess.check_output(
        ["fc-list", "-f", "%{variable}\t%{family[0]}\t%{style[0]}\t%{file}\n"],
        text=True,
        stderr=subprocess.DEVNULL,
    )
    info: dict[str, dict] = {}
    for line in out.splitlines():
        parts = line.split("\t", 3)
        if len(parts) != 4:
            continue
        is_var_str, fam, style, path = parts
        fam = fam.strip()
        if not fam:
            continue
        is_var = is_var_str.strip().lower() == "true"
        is_italic = "italic" in style.lower() or "oblique" in style.lower() or "italic" in path.lower()

        cur = info.get(fam)
        if cur is None:
            info[fam] = {
                "family": fam,
                "isVar": is_var,
                "path": path,
                "isItalic": is_italic,
            }
        else:
            # Prefer variable variant and non-italic regular file as representative path
            if (is_var and not cur["isVar"]) or (
                is_var == cur["isVar"] and cur["isItalic"] and not is_italic
            ):
                cur["isVar"] = is_var or cur["isVar"]
                cur["path"] = path
                cur["isItalic"] = is_italic
    return info


def emit_records(items: list[dict], prefix: str) -> None:
    lines = ["# Quickshell variable font metadata", f"count={len(items)}"]
    for idx, rec in enumerate(items):
        for key in ("family", "isVar", "axes"):
            lines.append(f"{prefix}.{idx}.{key}={escape_field(rec[key])}")
    sys.stdout.write("\n".join(lines) + "\n")


def cmd_list() -> int:
    fonts = scan_fonts()
    rows = []
    for fam in sorted(fonts, key=lambda s: s.casefold()):
        entry = fonts[fam]
        axes = parse_fvar_axes(entry["path"]) if entry["isVar"] else []
        rows.append(
            {
                "family": fam,
                "isVar": "true" if (entry["isVar"] and len(axes) > 0) else "false",
                "axes": format_axes(axes),
            }
        )
    emit_records(rows, "font")
    return 0


def cmd_inspect(families: list[str]) -> int:
    fonts = scan_fonts()
    by_lower = {k.casefold(): v for k, v in fonts.items()}
    rows = []
    for fam in families:
        key = fam.strip()
        if not key:
            continue
        entry = fonts.get(key) or by_lower.get(key.casefold())
        axes = parse_fvar_axes(entry["path"]) if (entry and entry["isVar"]) else []
        rows.append(
            {
                "family": key,
                "isVar": "true" if axes else "false",
                "axes": format_axes(axes),
            }
        )
    emit_records(rows, "inspect")
    return 0


def main() -> int:
    if len(sys.argv) < 2:
        return 1
    cmd = sys.argv[1]
    if cmd == "list":
        return cmd_list()
    if cmd == "inspect":
        return cmd_inspect(sys.argv[2:])
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
