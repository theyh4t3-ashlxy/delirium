#!/usr/bin/env python3
"""shared ansi styling, box rendering, session detection, and kitty icat helpers."""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import unicodedata
from pathlib import Path
from typing import List, Optional, Sequence, Tuple

ANSI_RE = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]")
IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".avif", ".bmp", ".ico", ".tiff"}


class Style:
    def __init__(self, enabled: bool = True):
        self.enabled = enabled

    def _c(self, code: str) -> str:
        return code if self.enabled else ""

    @property
    def reset(self) -> str:
        return self._c("\033[0m")

    @property
    def bold(self) -> str:
        return self._c("\033[1m")

    @property
    def dim(self) -> str:
        return self._c("\033[2m")

    @property
    def red(self) -> str:
        return self._c("\033[31m")

    @property
    def green(self) -> str:
        return self._c("\033[32m")

    @property
    def yellow(self) -> str:
        return self._c("\033[33m")

    @property
    def blue(self) -> str:
        return self._c("\033[34m")

    @property
    def magenta(self) -> str:
        return self._c("\033[35m")

    @property
    def cyan(self) -> str:
        return self._c("\033[36m")

    def bg_hex(self, hex_str: str) -> str:
        if not self.enabled:
            return ""
        hx = hex_str.lstrip("#")
        if len(hx) != 6:
            return ""
        r, g, b = int(hx[0:2], 16), int(hx[2:4], 16), int(hx[4:6], 16)
        return f"\033[48;2;{r};{g};{b}m"

    def fg_hex(self, hex_str: str) -> str:
        if not self.enabled:
            return ""
        hx = hex_str.lstrip("#")
        if len(hx) != 6:
            return ""
        r, g, b = int(hx[0:2], 16), int(hx[2:4], 16), int(hx[4:6], 16)
        return f"\033[38;2;{r};{g};{b}m"


def should_color(force: Optional[bool] = None) -> bool:
    if force is not None:
        return force
    if os.environ.get("NO_COLOR") is not None:
        return False
    if os.environ.get("TERM") == "dumb":
        return False
    return sys.stdout.isatty()


def get_style(force: Optional[bool] = None) -> Style:
    return Style(enabled=should_color(force))


def strip_ansi(text: str) -> str:
    return ANSI_RE.sub("", text)


def char_width(ch: str) -> int:
    if ord(ch) < 32 or unicodedata.combining(ch):
        return 0
    if 0xE000 <= ord(ch) <= 0xF8FF or 0xF0000 <= ord(ch) <= 0x10FFFF:
        return 1
    return 2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1


def vis_len(text: str) -> int:
    return sum(char_width(ch) for ch in strip_ansi(text))


def pad_ansi(text: str, width: int) -> str:
    w = vis_len(text)
    if w >= width:
        return text
    return text + (" " * (width - w))


def term_size() -> Tuple[int, int]:
    sz = shutil.get_terminal_size((96, 28))
    return max(44, sz.columns), max(16, sz.lines)


def render_box(
    lines: Sequence[str],
    width: Optional[int] = None,
    title: str = "",
    footer: str = "",
    style: Optional[Style] = None,
    border_color: Optional[str] = None,
) -> List[str]:
    st = style or get_style()
    bc = border_color if border_color is not None else st.cyan
    cols, _ = term_size()
    if width is None:
        max_line = max((vis_len(l) for l in lines), default=24)
        width = min(cols, max(44, max_line + 4, vis_len(title) + 6))
    inner = max(20, width - 2)

    if title:
        t_txt = f" {title} "
        rem = max(0, inner - 1 - vis_len(t_txt))
        top = f"{bc}╭─{st.reset}{t_txt}{bc}{'─' * rem}╮{st.reset}"
    else:
        top = f"{bc}╭{'─' * inner}╮{st.reset}"

    out = [top]
    for ln in lines:
        out.append(f"{bc}│{st.reset}{pad_ansi(ln, inner)}{bc}│{st.reset}")

    if footer:
        f_txt = f" {footer} "
        rem = max(0, inner - 1 - vis_len(f_txt))
        bot = f"{bc}╰{'─' * rem}{st.reset}{f_txt}{bc}─╯{st.reset}"
    else:
        bot = f"{bc}╰{'─' * inner}╯{st.reset}"
    out.append(bot)
    return out


def sanitize_host_dbus() -> None:
    if Path("/.flatpak-info").exists():
        return
    addr = os.environ.get("DBUS_SESSION_BUS_ADDRESS", "")
    if not addr or "/run/flatpak/bus" in addr:
        bus = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")) / "bus"
        if bus.is_socket():
            os.environ["DBUS_SESSION_BUS_ADDRESS"] = f"unix:path={bus}"


def in_gnome_session() -> bool:
    return "gnome" in os.environ.get("XDG_CURRENT_DESKTOP", "").lower()


def in_kitty() -> bool:
    if not shutil.which("kitten"):
        return False
    return bool(os.environ.get("KITTY_WINDOW_ID") or os.environ.get("TERM") == "xterm-kitty")


def is_pretty_cli(argv: Sequence[str], binary_names: Sequence[str], raw_cmds: Sequence[str] = ()) -> bool:
    """use pretty terminal output when run via dedicated CLI symlink or TTY human flags."""
    if "--kv" in argv:
        return False
    if "--pretty" in argv or "--json" in argv or "-h" in argv or "--help" in argv or "help" in argv[:2]:
        return True
    prog = Path(argv[0]).name if argv else ""
    first_arg = argv[1].lower() if len(argv) > 1 else ""
    if raw_cmds and first_arg in raw_cmds and not prog.lstrip(".") in binary_names:
        return False
    if prog in binary_names:
        return True
    return sys.stdout.isatty() and first_arg not in raw_cmds


def render_kitty_image(img_path: str | Path, max_w: int = 440, max_h: int = 220, align: str = "left") -> bool:
    """render a crisp thumbnail inline in kitty without flooding scrollback."""
    if not in_kitty() or not sys.stdout.isatty():
        return False
    p = Path(img_path)
    if not p.is_file():
        return False

    if shutil.which("magick"):
        try:
            conv = subprocess.run(
                ["magick", f"{p}[0]", "-auto-orient", "-thumbnail", f"{max_w}x{max_h}>", "png:-"],
                capture_output=True,
                timeout=4,
                check=False,
            )
            if conv.returncode == 0 and conv.stdout:
                res = subprocess.run(
                    ["kitten", "icat", f"--align={align}", "--fit=none", "--stdin=yes"],
                    input=conv.stdout,
                    timeout=4,
                    check=False,
                )
                if res.returncode == 0:
                    return True
        except Exception:
            pass

    try:
        res = subprocess.run(
            ["kitten", "icat", f"--align={align}", "--fit=height", "--stdin=no", str(p)],
            timeout=4,
            check=False,
        )
        return res.returncode == 0
    except Exception:
        return False
