#!/usr/bin/env python3
"""Local-first + lrclib.net lyrics helper for Quickshell NowPlaying (ConfFmt output)."""

from __future__ import annotations

import os
import re
import sys
import urllib.parse
import urllib.request
import json
from pathlib import Path

DATA_DIR = Path(os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))) / "quickshell"
LYRICS_DIR = DATA_DIR / "lyrics"


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


def emit_kv(data: dict[str, str]) -> None:
    lines = ["# Quickshell lyrics response"]
    for k, v in data.items():
        lines.append(f"{k}={escape_field(v)}")
    sys.stdout.write("\n".join(lines) + "\n")


def sanitize_slug(artist: str, title: str) -> str:
    a = re.sub(r'[\\/:*?"<>|\x00-\x1f]+', " ", (artist or "").strip()).strip()
    t = re.sub(r'[\\/:*?"<>|\x00-\x1f]+', " ", (title or "").strip()).strip()
    a = re.sub(r"\s+", " ", a)
    t = re.sub(r"\s+", " ", t)
    if a and t:
        return f"{a} - {t}".lower()
    return (t or a or "untitled").lower()


def read_text_safe(p: Path) -> str:
    for enc in ("utf-8-sig", "utf-8", "latin-1"):
        try:
            return p.read_text(encoding=enc).replace("\r\n", "\n")
        except Exception:
            continue
    return ""


def find_custom_lyrics(artist: str, title: str) -> Path | None:
    if not LYRICS_DIR.exists():
        return None
    slug = sanitize_slug(artist, title)
    for ext in (".lrc", ".txt"):
        p = LYRICS_DIR / f"{slug}{ext}"
        if p.is_file():
            return p
    return None


def find_sidecar_lyrics(track_url: str) -> Path | None:
    if not track_url or not track_url.startswith("file://"):
        return None
    raw_path = urllib.parse.unquote(track_url[7:])
    track_path = Path(raw_path)
    if not track_path.parent.is_dir():
        return None
    for ext in (".lrc", ".txt"):
        cand = track_path.with_suffix(ext)
        if cand.is_file():
            return cand
    return None


def fetch_lrclib(artist: str, title: str) -> str:
    headers = {"User-Agent": "QuickshellNowPlaying/1.0 (local desktop player)"}
    params = urllib.parse.urlencode({"artist_name": artist, "track_name": title})
    url = f"https://lrclib.net/api/get?{params}"
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=5) as resp:
            obj = json.loads(resp.read().decode("utf-8", errors="replace"))
            txt = (obj.get("syncedLyrics") or obj.get("plainLyrics") or "").strip()
            if txt:
                return txt.replace("\r\n", "\n")
    except Exception:
        pass

    q = f"{artist} {title}".strip()
    if not q:
        return ""
    search_url = f"https://lrclib.net/api/search?{urllib.parse.urlencode({'q': q})}"
    try:
        req = urllib.request.Request(search_url, headers=headers)
        with urllib.request.urlopen(req, timeout=5) as resp:
            arr = json.loads(resp.read().decode("utf-8", errors="replace"))
            if isinstance(arr, list):
                for item in arr:
                    if not isinstance(item, dict):
                        continue
                    txt = (item.get("syncedLyrics") or item.get("plainLyrics") or "").strip()
                    if txt:
                        return txt.replace("\r\n", "\n")
    except Exception:
        pass
    return ""


def cmd_lookup(artist: str, title: str, track_url: str, force_online: bool) -> None:
    if not force_online:
        custom = find_custom_lyrics(artist, title)
        if custom:
            emit_kv({"source": "custom", "path": str(custom), "content": read_text_safe(custom)})
            return
        sidecar = find_sidecar_lyrics(track_url)
        if sidecar:
            emit_kv({"source": "sidecar", "path": str(sidecar), "content": read_text_safe(sidecar)})
            return

    online = fetch_lrclib(artist, title)
    if online:
        emit_kv({"source": "lrclib", "path": "", "content": online})
    else:
        emit_kv({"source": "none", "path": "", "content": ""})


def cmd_save(artist: str, title: str, content: str) -> None:
    LYRICS_DIR.mkdir(parents=True, exist_ok=True)
    slug = sanitize_slug(artist, title)
    dest = LYRICS_DIR / f"{slug}.lrc"
    clean = (content or "").replace("\r\n", "\n")
    dest.write_text(clean, encoding="utf-8")
    emit_kv({"source": "custom", "path": str(dest), "content": clean})


def cmd_delete(artist: str, title: str) -> None:
    if LYRICS_DIR.exists():
        slug = sanitize_slug(artist, title)
        for ext in (".lrc", ".txt"):
            (LYRICS_DIR / f"{slug}{ext}").unlink(missing_ok=True)
    emit_kv({"source": "none", "path": "", "content": ""})


def cmd_browse(dir_arg: str) -> None:
    LYRICS_DIR.mkdir(parents=True, exist_ok=True)
    home = Path.home()
    if dir_arg:
        cur = Path(os.path.expanduser(dir_arg))
    elif (home / "Music").is_dir():
        cur = home / "Music"
    else:
        cur = LYRICS_DIR
    if not cur.is_dir():
        cur = home

    entries: list[dict[str, str]] = []
    if cur.parent != cur:
        entries.append({"name": "..", "path": str(cur.parent), "isDir": "true"})

    dirs: list[Path] = []
    files: list[Path] = []
    try:
        for p in cur.iterdir():
            if p.name.startswith(".") and cur != LYRICS_DIR:
                continue
            if p.is_dir():
                dirs.append(p)
            elif p.is_file() and p.suffix.lower() in (".lrc", ".txt"):
                files.append(p)
    except Exception:
        pass

    for d in sorted(dirs, key=lambda x: x.name.lower()):
        entries.append({"name": d.name, "path": str(d), "isDir": "true"})
    for f in sorted(files, key=lambda x: x.name.lower()):
        entries.append({"name": f.name, "path": str(f), "isDir": "false"})

    lines = [
        "# Quickshell lyrics browser",
        f"cwd={escape_field(str(cur))}",
        f"count={len(entries)}",
    ]
    for i, ent in enumerate(entries):
        lines.append(f"entry.{i}.name={escape_field(ent['name'])}")
        lines.append(f"entry.{i}.path={escape_field(ent['path'])}")
        lines.append(f"entry.{i}.isDir={ent['isDir']}")
    sys.stdout.write("\n".join(lines) + "\n")


def cmd_read(file_arg: str) -> None:
    p = Path(os.path.expanduser(file_arg))
    if not p.is_file():
        emit_kv({"source": "none", "path": "", "content": ""})
        return
    emit_kv({"source": "file", "path": str(p), "content": read_text_safe(p)})


def main() -> None:
    if len(sys.argv) < 2:
        return
    act = sys.argv[1]
    if act == "lookup":
        artist = sys.argv[2] if len(sys.argv) > 2 else ""
        title = sys.argv[3] if len(sys.argv) > 3 else ""
        url = sys.argv[4] if len(sys.argv) > 4 else ""
        force = (sys.argv[5] == "1") if len(sys.argv) > 5 else False
        cmd_lookup(artist, title, url, force)
    elif act == "save" and len(sys.argv) >= 5:
        cmd_save(sys.argv[2], sys.argv[3], sys.argv[4])
    elif act == "delete" and len(sys.argv) >= 4:
        cmd_delete(sys.argv[2], sys.argv[3])
    elif act == "browse":
        cmd_browse(sys.argv[2] if len(sys.argv) > 2 else "")
    elif act == "read" and len(sys.argv) >= 3:
        cmd_read(sys.argv[2])


if __name__ == "__main__":
    main()
