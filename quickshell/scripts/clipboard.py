#!/usr/bin/env python3
"""cliphist-backed clipboard helper for Quickshell (zero-JSON .conf record output)."""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache"))) / "quickshell" / "clip_thumbs"
DATA_DIR = Path(os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))) / "quickshell"
PINS_CONF = DATA_DIR / "clip_pins.conf"
PIN_BLOBS_DIR = DATA_DIR / "clip_pins"

BINARY_RE = re.compile(r"^\[\[\s*binary data\s+(.+?)\s*\]\]$")
URL_RE = re.compile(r"^https?://\S+", re.IGNORECASE)
IMG_EXT_RE = re.compile(r"\b(png|jpg|jpeg|webp|gif|bmp)\b", re.IGNORECASE)


def escape_field(raw: object) -> str:
    s = "" if raw is None else str(raw)
    return (
        s.replace("\\", "\\\\")
        .replace("\r", "\\r")
        .replace("\n", "\\n")
        .replace("=", "\\e")
        .replace(",", "\\c")
        .replace(";", "\\s")
        .replace("|", "\\p")
    )


def unescape_field(raw: str) -> str:
    out: list[str] = []
    i = 0
    n = len(raw)
    while i < n:
        ch = raw[i]
        if ch == "\\" and i + 1 < n:
            nxt = raw[i + 1]
            i += 2
            if nxt == "n":
                out.append("\n")
            elif nxt == "r":
                out.append("\r")
            elif nxt == "e":
                out.append("=")
            elif nxt == "c":
                out.append(",")
            elif nxt == "s":
                out.append(";")
            elif nxt == "p":
                out.append("|")
            else:
                out.append(nxt)
        else:
            out.append(ch)
            i += 1
    return "".join(out)


def parse_records(raw: str, prefix: str) -> list[dict[str, str]]:
    by_idx: dict[int, dict[str, str]] = {}
    head = prefix + "."
    for line in raw.splitlines():
        s = line.strip()
        if not s or s.startswith("#") or "=" not in s:
            continue
        key, val = s.split("=", 1)
        key = key.strip()
        if not key.startswith(head):
            continue
        rest = key[len(head) :]
        if "." not in rest:
            continue
        idx_str, field = rest.split(".", 1)
        if not idx_str.isdigit():
            continue
        idx = int(idx_str)
        by_idx.setdefault(idx, {})[field] = unescape_field(val.strip())
    return [by_idx[i] for i in sorted(by_idx)]


def serialize_records(records: list[dict[str, str]], prefix: str, fields: list[str]) -> str:
    lines = [f"# Quickshell native {prefix} store", f"count={len(records)}"]
    for i, rec in enumerate(records):
        for f in fields:
            lines.append(f"{prefix}.{i}.{f}={escape_field(rec.get(f, ''))}")
    return "\n".join(lines) + "\n"


def emit_records(records: list[dict[str, str]], prefix: str, fields: list[str]) -> None:
    sys.stdout.write(serialize_records(records, prefix, fields))


def cliphist_decode(cid: str) -> bytes:
    res = subprocess.run(["cliphist", "decode", cid], capture_output=True, timeout=5)
    if res.returncode != 0:
        return b""
    return res.stdout


def wl_copy_bytes(data: bytes, mime: str | None = None) -> None:
    cmd = ["wl-copy"]
    if mime:
        cmd.extend(["--type", mime])
    proc = subprocess.Popen(
        cmd,
        stdin=subprocess.PIPE,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    assert proc.stdin is not None
    proc.stdin.write(data)
    proc.stdin.close()
    try:
        proc.wait(timeout=2)
    except subprocess.TimeoutExpired:
        pass


def _watcher_running() -> bool:
    if not shutil.which("pgrep"):
        return False
    return subprocess.run(["pgrep", "-f", r"wl-paste.*cliphist store"], capture_output=True).returncode == 0


def ensure_watch() -> None:
    if not (shutil.which("wl-paste") and shutil.which("cliphist")):
        return
    if not _watcher_running():
        subprocess.Popen(
            ["wl-paste", "--watch", "cliphist", "store"],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )


def ensure_thumb(cid: str, ext: str) -> str:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    thumb = CACHE_DIR / f"{cid}.{ext.lower()}"
    if thumb.exists() and thumb.stat().st_size > 0:
        return str(thumb)
    data = cliphist_decode(cid)
    if data:
        thumb.write_bytes(data)
        return str(thumb)
    return ""


def parse_clip_row(cid: str, preview: str, decode_thumb: bool) -> dict[str, str]:
    m = BINARY_RE.match(preview.strip())
    if m:
        meta = m.group(1).strip()
        ext_m = IMG_EXT_RE.search(meta)
        if ext_m:
            ext = ext_m.group(1).lower()
            thumb = ensure_thumb(cid, ext) if decode_thumb else ""
            return {
                "id": cid,
                "kind": "image",
                "preview": f"image ({meta})",
                "meta": meta,
                "thumb": thumb,
            }
        return {
            "id": cid,
            "kind": "binary",
            "preview": f"binary ({meta})",
            "meta": meta,
            "thumb": "",
        }
    if URL_RE.match(preview.strip()):
        return {"id": cid, "kind": "link", "preview": preview, "meta": "url", "thumb": ""}
    return {"id": cid, "kind": "text", "preview": preview, "meta": "text", "thumb": ""}


def cmd_list(limit: int = 60) -> None:
    res = subprocess.run(["cliphist", "list"], capture_output=True, text=True, timeout=5)
    records: list[dict[str, str]] = []
    if res.returncode == 0 and res.stdout:
        img_count = 0
        for line in res.stdout.splitlines():
            if "\t" not in line:
                continue
            cid, preview = line.split("\t", 1)
            cid = cid.strip()
            if not cid:
                continue
            is_img = bool(BINARY_RE.match(preview.strip()) and IMG_EXT_RE.search(preview))
            rec = parse_clip_row(cid, preview, decode_thumb=(is_img and img_count < 24))
            if rec["kind"] == "image":
                img_count += 1
            records.append(rec)
            if len(records) >= limit:
                break
    emit_records(records, "clip", ["id", "kind", "preview", "meta", "thumb"])


def load_pins() -> list[dict[str, str]]:
    if not PINS_CONF.exists():
        return []
    return parse_records(PINS_CONF.read_text(encoding="utf-8"), "pin")


def save_pins(pins: list[dict[str, str]]) -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    PINS_CONF.write_text(
        serialize_records(pins, "pin", ["id", "kind", "preview", "meta", "thumb", "text"]),
        encoding="utf-8",
    )


def cmd_copy(cid: str) -> None:
    data = cliphist_decode(cid)
    if data:
        wl_copy_bytes(data)


def cmd_delete(cid: str) -> None:
    res = subprocess.run(["cliphist", "list"], capture_output=True, text=True, timeout=5)
    if res.returncode == 0 and res.stdout:
        prefix = f"{cid}\t"
        for line in res.stdout.splitlines():
            if line.startswith(prefix):
                subprocess.run(["cliphist", "delete"], input=line + "\n", text=True, timeout=5)
                break
    if CACHE_DIR.exists():
        for p in CACHE_DIR.glob(f"{cid}.*"):
            p.unlink(missing_ok=True)


def cmd_wipe() -> None:
    subprocess.run(["cliphist", "wipe"], capture_output=True, timeout=5)
    if CACHE_DIR.exists():
        shutil.rmtree(CACHE_DIR, ignore_errors=True)


def cmd_pin(cid: str) -> None:
    res = subprocess.run(["cliphist", "list"], capture_output=True, text=True, timeout=5)
    preview = ""
    if res.returncode == 0 and res.stdout:
        prefix = f"{cid}\t"
        for line in res.stdout.splitlines():
            if line.startswith(prefix):
                preview = line.split("\t", 1)[1]
                break
    if not preview:
        return
    rec = parse_clip_row(cid, preview, decode_thumb=False)
    data = cliphist_decode(cid)
    if not data:
        return
    pins = load_pins()
    pin_id = f"{int(time.time() * 1000)}_{cid}"

    if rec["kind"] == "image":
        PIN_BLOBS_DIR.mkdir(parents=True, exist_ok=True)
        ext_m = IMG_EXT_RE.search(rec["meta"])
        ext = ext_m.group(1).lower() if ext_m else "png"
        blob_path = PIN_BLOBS_DIR / f"{pin_id}.{ext}"
        blob_path.write_bytes(data)
        pins.insert(
            0,
            {
                "id": pin_id,
                "kind": "image",
                "preview": rec["preview"],
                "meta": rec["meta"],
                "thumb": str(blob_path),
                "text": "",
            },
        )
    else:
        txt = data.decode("utf-8", errors="replace")
        for existing in pins:
            if existing.get("kind") != "image" and existing.get("text", "") == txt:
                return
        pins.insert(
            0,
            {
                "id": pin_id,
                "kind": rec["kind"],
                "preview": rec["preview"],
                "meta": rec["meta"],
                "thumb": "",
                "text": txt,
            },
        )
    save_pins(pins)


def cmd_unpin(pin_id: str) -> None:
    pins = load_pins()
    kept: list[dict[str, str]] = []
    for p in pins:
        if p.get("id") == pin_id:
            thumb = p.get("thumb", "")
            if thumb and thumb.startswith(str(PIN_BLOBS_DIR)):
                Path(thumb).unlink(missing_ok=True)
            continue
        kept.append(p)
    save_pins(kept)


def cmd_copy_pin(pin_id: str) -> None:
    for p in load_pins():
        if p.get("id") == pin_id:
            if p.get("kind") == "image":
                thumb = Path(p.get("thumb", ""))
                if thumb.exists():
                    ext = thumb.suffix.lstrip(".").lower() or "png"
                    mime = "image/jpeg" if ext in ("jpg", "jpeg") else f"image/{ext}"
                    wl_copy_bytes(thumb.read_bytes(), mime=mime)
            else:
                wl_copy_bytes(p.get("text", "").encode("utf-8"))
            break


def _build_pretty_rows(limit: int = 80) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for p in load_pins():
        rows.append({
            "id": p.get("id", ""),
            "pinned": "1",
            "kind": p.get("kind", "text"),
            "preview": p.get("preview", ""),
            "thumb": p.get("thumb", ""),
            "text": p.get("text", ""),
        })

    res = subprocess.run(["cliphist", "list"], capture_output=True, text=True, timeout=5)
    if res.returncode == 0 and res.stdout:
        img_count = 0
        for line in res.stdout.splitlines():
            if "\t" not in line:
                continue
            cid, preview = line.split("\t", 1)
            cid = cid.strip()
            if not cid:
                continue
            is_img = bool(BINARY_RE.match(preview.strip()) and IMG_EXT_RE.search(preview))
            rec = parse_clip_row(cid, preview, decode_thumb=(is_img and img_count < 30))
            if rec["kind"] == "image":
                img_count += 1
            rows.append({
                "id": rec["id"],
                "pinned": "0",
                "kind": rec["kind"],
                "preview": rec["preview"],
                "thumb": rec["thumb"],
                "text": "",
            })
            if len(rows) >= limit:
                break
    return rows


def _interactive_fzf() -> None:
    from _cli_ui import get_style
    st = get_style()
    if not shutil.which("fzf"):
        print(f"{st.yellow}󰀦 fzf required for interactive clipboard picker{st.reset}", file=sys.stderr)
        sys.exit(1)

    ensure_watch()
    rows = _build_pretty_rows(120)
    if not rows:
        print(f"{st.dim}clipboard history is empty{st.reset}")
        return

    fzf_lines = []
    for r in rows:
        tag = "[pin]" if r["pinned"] == "1" else f"[{r['kind']}]"
        clean_prev = " ".join(r["preview"].split())[:110]
        fzf_lines.append(f"{r['pinned']}\t{r['id']}\t{r['thumb']}\t{tag} {clean_prev}")

    preview_cmd = (
        't={3}; '
        'if [ -n "$t" ] && [ -f "$t" ]; then '
        '  if [ -n "${KITTY_WINDOW_ID:-}" ] && command -v kitten >/dev/null 2>&1; then '
        '    kitten icat --clear --transfer-mode=memory --unicode-placeholder --stdin=no --place="${FZF_PREVIEW_COLUMNS}x${FZF_PREVIEW_LINES}@0x0" "$t"; '
        '  else file -b "$t"; fi; '
        'elif [ {1} = "1" ]; then '
        f'  python3 "{Path(__file__).resolve()}" _show-pin {{2}}; '
        'else cliphist decode {2} 2>/dev/null | head -c 4096; fi'
    )

    proc = subprocess.run(
        [
            "fzf",
            "--delimiter=\t",
            "--with-nth=4",
            "--reverse",
            "--height=65%",
            "--header=[clip · enter=copy · ctrl-p=pin · ctrl-d=delete]",
            "--expect=ctrl-p,ctrl-d",
            "--preview", preview_cmd,
            "--preview-window=right:55%:wrap",
        ],
        input="\n".join(fzf_lines),
        text=True,
        capture_output=True,
    )
    if proc.returncode != 0 or not proc.stdout.strip():
        return

    out_lines = proc.stdout.splitlines()
    key = out_lines[0].strip() if len(out_lines) > 1 else ""
    sel = out_lines[1] if len(out_lines) > 1 else out_lines[0]
    parts = sel.split("\t", 3)
    if len(parts) < 2:
        return
    is_pin, item_id = parts[0] == "1", parts[1]

    if key == "ctrl-p" and not is_pin:
        cmd_pin(item_id)
        print(f"{st.green}󰄲 pinned entry {item_id}{st.reset}")
    elif key == "ctrl-d":
        if is_pin:
            cmd_unpin(item_id)
        else:
            cmd_delete(item_id)
        print(f"{st.yellow}󰆴 deleted entry {item_id}{st.reset}")
    else:
        if is_pin:
            cmd_copy_pin(item_id)
        else:
            cmd_copy(item_id)
        print(f"{st.green}󰄲 copied {item_id} to clipboard{st.reset}")


def _cmd_status(as_json: bool = False) -> None:
    import json
    from _cli_ui import get_style, render_box, term_size

    rows = _build_pretty_rows(500)
    pinned = sum(1 for r in rows if r.get("pinned") == "1")
    history = len(rows) - pinned
    watching = _watcher_running()
    has_cliphist = bool(shutil.which("cliphist"))
    if as_json:
        print(json.dumps({
            "history": history,
            "pinned": pinned,
            "total": len(rows),
            "watcher_active": watching,
            "cliphist": has_cliphist,
        }, indent=2))
        return

    st = get_style()
    w_lbl = f"{st.green}active{st.reset}" if watching else f"{st.yellow}stopped{st.reset}"
    lines = [
        f" {st.dim}├─{st.reset} {st.bold}{'watcher:':<12}{st.reset} {w_lbl} (cliphist={'ok' if has_cliphist else 'missing'})",
        f" {st.dim}├─{st.reset} {st.bold}{'history:':<12}{st.reset} {history} entries",
        f" {st.dim}└─{st.reset} {st.bold}{'pinned:':<12}{st.reset} {pinned} items",
    ]
    cols, _ = term_size()
    print("\n".join(render_box(lines, width=min(cols, 72), title=f"{st.cyan}{st.bold}󰅇 clip · status{st.reset}", style=st, border_color=st.cyan)))


def main() -> None:
    from _cli_ui import get_style, is_pretty_cli

    args = sys.argv[1:]
    if any(a in ("-h", "--help", "help") for a in args):
        st = get_style()
        print(f"{st.cyan}{st.bold}󰅇 clip{st.reset} · clipboard history & pin manager (kitty image previews)\n\nusage:\n  clip                   interactive fzf picker\n  clip status [--json]   show history count, pins & watcher state\n  clip list [--json]     list entries + pins\n  clip copy <id>         copy history item\n  clip pin <id>          pin history item\n  clip wipe              clear history cache")
        return

    as_json = "--json" in args
    clean_args = [a for a in args if a not in ("--json", "--pretty", "--kv")]
    pretty = is_pretty_cli(sys.argv, ("clip",), raw_cmds=("ensure-watch", "list", "copy", "pin", "unpin", "copy-pin", "delete", "wipe", "_show-pin"))

    if not clean_args:
        _interactive_fzf()
        return

    action = clean_args[0].lower()
    if action in ("status", "info"):
        _cmd_status(as_json=as_json)
    elif action == "_show-pin" and len(clean_args) >= 2:
        for p in load_pins():
            if p.get("id") == clean_args[1]:
                sys.stdout.write(p.get("text", "") or p.get("preview", ""))
                break
    elif action == "ensure-watch":
        ensure_watch()
    elif action == "list":
        limit = int(clean_args[1]) if len(clean_args) > 1 and clean_args[1].isdigit() else 60
        if pretty:
            import json
            rows = _build_pretty_rows(limit)
            if as_json:
                print(json.dumps(rows, indent=2))
            else:
                for r in rows:
                    tag = "[pin]" if r["pinned"] == "1" else f"[{r['kind']}]"
                    print(f"{r['id']:<16} {tag:<8} {' '.join(r['preview'].split())[:72]}")
        else:
            cmd_list(limit)
    elif action == "copy" and len(clean_args) > 1:
        cmd_copy(clean_args[1])
    elif action == "pin" and len(clean_args) > 1:
        cmd_pin(clean_args[1])
    elif action == "unpin" and len(clean_args) > 1:
        cmd_unpin(clean_args[1])
    elif action == "copy-pin" and len(clean_args) > 1:
        cmd_copy_pin(clean_args[1])
    elif action == "delete" and len(clean_args) > 1:
        cmd_delete(clean_args[1])
    elif action == "wipe":
        cmd_wipe()
    else:
        st = get_style()
        print(f"{st.red}󰅚 unknown command or missing arg: {' '.join(clean_args)}{st.reset}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
