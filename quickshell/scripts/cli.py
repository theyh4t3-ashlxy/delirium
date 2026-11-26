#!/usr/bin/env python3
"""
cli - quickshell, Brain_Shell, and desktop action controller.
keyboard-first terminal hub with a native python TUI.
"""

from __future__ import annotations

import dataclasses
import difflib
import fcntl
import json
import os
import re
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import termios
import time
import tty
import unicodedata
from collections import deque
from pathlib import Path
from typing import Callable, Dict, List, Optional, Sequence, Tuple

_SCRIPT_DIR = str(Path(__file__).resolve().parent)
if _SCRIPT_DIR not in sys.path:
    sys.path.insert(0, _SCRIPT_DIR)

from _cli_ui import in_kitty as _ui_in_kitty, render_kitty_image as _ui_render_kitty_image


HOME = Path.home()
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache"))
CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local" / "state"))
CACHE_FILE = CACHE_DIR / "current_shell"
DOTFILES_DIR = HOME / ".local" / "share" / "dotfiles"
USER_PREFS_FILE = CONFIG_DIR / "zsh" / "user_prefs.conf"

BRAIN_CANDIDATES = [
    HOME / ".local" / "src" / "Brain_Shell",
    HOME / ".config" / "Brain_Shell",
]

SHELL_PROC_NAMES = ("quickshell", ".quickshell-wra", "qs")

ANSI_RE = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]")


class Style:
    """Inherits active terminal ANSI 0..15 palette live unless disabled."""

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
    def italic(self) -> str:
        return self._c("\033[3m")

    @property
    def reverse(self) -> str:
        return self._c("\033[7m")

    @property
    def black(self) -> str:
        return self._c("\033[30m")

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

    @property
    def white(self) -> str:
        return self._c("\033[37m")

    @property
    def bg_sel(self) -> str:
        # reverse video stays legible across both dark and light matugen palettes
        return self._c("\033[7m")

    def fg_hex(self, hx: str) -> str:
        if not self.enabled or len(hx) != 7 or not hx.startswith("#"):
            return ""
        try:
            r, g, b = int(hx[1:3], 16), int(hx[3:5], 16), int(hx[5:7], 16)
            return f"\033[38;2;{r};{g};{b}m"
        except ValueError:
            return ""

    def bg_hex(self, hx: str) -> str:
        if not self.enabled or len(hx) != 7 or not hx.startswith("#"):
            return ""
        try:
            r, g, b = int(hx[1:3], 16), int(hx[3:5], 16), int(hx[5:7], 16)
            return f"\033[48;2;{r};{g};{b}m"
        except ValueError:
            return ""

    def bg_ansi(self, idx: int) -> str:
        return self._c(f"\033[48;5;{idx}m")


S = Style(enabled=True)


def configure_color(force_color: Optional[bool] = None):
    if force_color is not None:
        S.enabled = force_color
        return
    if os.environ.get("NO_COLOR") is not None:
        S.enabled = False
        return
    S.enabled = sys.stdout.isatty()


# ansi-aware width & layout helpers so box borders never drift
def strip_ansi(text: str) -> str:
    return ANSI_RE.sub("", text)


def char_width(ch: str) -> int:
    if not ch:
        return 0
    o = ord(ch)
    if o < 32 or (0x7F <= o < 0xA0):
        return 0
    cat = unicodedata.category(ch)
    if cat in ("Mn", "Me", "Cf"):
        return 0
    eaw = unicodedata.east_asian_width(ch)
    if eaw in ("W", "F"):
        return 2
    return 1


def vis_len(text: str) -> int:
    return sum(char_width(ch) for ch in strip_ansi(text))


def clip_ansi(text: str, max_width: int, ellipsis: str = "…") -> str:
    if max_width <= 0:
        return ""
    if vis_len(text) <= max_width:
        return text

    ell_w = vis_len(ellipsis) if ellipsis else 0
    target = max(0, max_width - ell_w)
    out: List[str] = []
    width = 0
    has_ansi = False
    i = 0
    n = len(text)
    while i < n:
        m = ANSI_RE.match(text, i)
        if m:
            out.append(m.group(0))
            has_ansi = True
            i = m.end()
            continue
        ch = text[i]
        cw = char_width(ch)
        if width + cw > target:
            break
        out.append(ch)
        width += cw
        i += 1

    if ellipsis and max_width >= ell_w:
        out.append(ellipsis)
    if has_ansi and S.enabled:
        out.append(S.reset)
    return "".join(out)


def pad_ansi(text: str, width: int, align: str = "left") -> str:
    clipped = clip_ansi(text, width)
    gap = max(0, width - vis_len(clipped))
    if align == "right":
        return (" " * gap) + clipped
    if align == "center":
        left = gap // 2
        return (" " * left) + clipped + (" " * (gap - left))
    return clipped + (" " * gap)


def render_box(
    lines: Sequence[str],
    width: int,
    title: str = "",
    footer: str = "",
    border_color: Optional[str] = None,
    scroll_info: Optional[Tuple[int, int, int]] = None,
) -> List[str]:
    width = max(12, width)
    inner = width - 2
    bc = border_color if border_color is not None else S.dim
    rst = S.reset

    if title:
        t = clip_ansi(f" {title} ", max(1, inner - 2))
        rem = max(0, inner - 1 - vis_len(t))
        top = f"{bc}╭─{rst}{t}{bc}{'─' * rem}╮{rst}"
    else:
        top = f"{bc}╭{'─' * inner}╮{rst}"

    if footer:
        f = clip_ansi(f" {footer} ", max(1, inner - 2))
        rem = max(0, inner - 1 - vis_len(f))
        bot = f"{bc}╰{'─' * rem}{rst}{f}{bc}─╯{rst}"
    else:
        bot = f"{bc}╰{'─' * inner}╯{rst}"

    thumb_start = thumb_end = -1
    if scroll_info and len(lines) > 0:
        offset, visible, total = scroll_info
        if total > visible and visible > 0:
            h = len(lines)
            thumb_h = max(1, round((visible / total) * h))
            max_off = max(1, total - visible)
            thumb_start = round((offset / max_off) * (h - thumb_h))
            thumb_end = thumb_start + thumb_h

    body: List[str] = []
    for idx, ln in enumerate(lines):
        if thumb_start <= idx < thumb_end:
            right_edge = f"{S.cyan}┃{rst}"
        else:
            right_edge = f"{bc}│{rst}"
        body.append(f"{bc}│{rst}{pad_ansi(ln, inner)}{right_edge}")
    return [top, *body, bot]


def term_size() -> Tuple[int, int]:
    sz = shutil.get_terminal_size((100, 30))
    return max(40, sz.columns), max(14, sz.lines)


# config, prefs, and runtime discovery
def get_brain_shell_dir() -> Path:
    env_dir = os.environ.get("BRAIN_SHELL_DIR")
    if env_dir:
        p = Path(env_dir).expanduser()
        if p.is_dir():
            return p
    for p in BRAIN_CANDIDATES:
        if p.is_dir():
            return p
    return BRAIN_CANDIDATES[0]


def get_current_shell() -> str:
    if CACHE_FILE.exists():
        try:
            val = CACHE_FILE.read_text(encoding="utf-8").strip()
            if val in ("quickshell", "brain_shell"):
                return val
        except OSError:
            pass
    return "quickshell"


def set_current_shell(target: str):
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    # atomic replace so a crash mid-write never truncates ~/.cache/current_shell
    fd, tmp_name = tempfile.mkstemp(prefix=".current_shell.", dir=str(CACHE_DIR))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(target + "\n")
        os.replace(tmp_name, CACHE_FILE)
    except Exception:
        try:
            os.unlink(tmp_name)
        except OSError:
            pass
        raise


def _read_kv_file(path: Path) -> Dict[str, str]:
    data: Dict[str, str] = {}
    if not path.exists():
        return data
    try:
        for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
            s = raw.strip()
            if not s or s.startswith("#") or "=" not in s:
                continue
            k, v = s.split("=", 1)
            data[k.strip()] = v.strip().strip('"').strip("'")
    except OSError:
        pass
    return data


def _read_settings_conf() -> Dict[str, str]:
    for p in (STATE_DIR / "quickshell" / "settings.conf", CONFIG_DIR / "quickshell" / "settings.conf"):
        if p.exists():
            return _read_kv_file(p)
    return {}


def _read_user_prefs() -> Dict[str, str]:
    return _read_kv_file(USER_PREFS_FILE)


def sanitize_host_dbus():
    """Repair leaked Flatpak DBus env vars when spawning host commands."""
    addr = os.environ.get("DBUS_SESSION_BUS_ADDRESS", "")
    if Path("/.flatpak-info").exists():
        return
    if not addr or "/run/flatpak/bus" in addr:
        host_bus = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")) / "bus"
        if host_bus.is_socket():
            os.environ["DBUS_SESSION_BUS_ADDRESS"] = f"unix:path={host_bus}"


sanitize_host_dbus()


def in_gnome_session() -> bool:
    return "gnome" in os.environ.get("XDG_CURRENT_DESKTOP", "").lower()


def desktop_env_name() -> str:
    if in_gnome_session():
        return "gnome"
    if os.environ.get("HYPRLAND_INSTANCE_SIGNATURE") or "hyprland" in os.environ.get("XDG_CURRENT_DESKTOP", "").lower():
        return "hyprland"
    raw = os.environ.get("XDG_CURRENT_DESKTOP", "").strip().lower()
    return raw or "unknown"


def _dconf_read(path: str) -> str:
    if not shutil.which("dconf"):
        return ""
    try:
        r = subprocess.run(["dconf", "read", path], capture_output=True, text=True, timeout=1.5)
        if r.returncode == 0:
            return r.stdout.strip().strip("'").strip('"')
    except Exception:
        pass
    return ""


def _gsettings_get(schema: str, key: str) -> str:
    if not shutil.which("gsettings"):
        return ""
    try:
        r = subprocess.run(["gsettings", "get", schema, key], capture_output=True, text=True, timeout=1.5)
        if r.returncode == 0:
            return r.stdout.strip().strip("'").strip('"')
    except Exception:
        pass
    return ""


def _gsettings_set(schema: str, key: str, value: str) -> bool:
    if not shutil.which("gsettings"):
        return False
    try:
        r = subprocess.run(["gsettings", "set", schema, key, value], capture_output=True, text=True, timeout=2.0)
        return r.returncode == 0
    except Exception:
        return False


def _gdbus_call(dest: str, path: str, method: str, *args: str, timeout: float = 3.0) -> Tuple[bool, str, str]:
    if not shutil.which("gdbus"):
        return False, "", "'gdbus' not found on path"
    cmd = ["gdbus", "call", "--session", "--dest", dest, "--object-path", path, "--method", method, *args]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.returncode == 0, r.stdout.strip(), r.stderr.strip()
    except Exception as e:
        return False, "", str(e)


def _sync_dnd_conf(enabled: bool):
    state_dir = STATE_DIR / "quickshell"
    state_dir.mkdir(parents=True, exist_ok=True)
    conf_file = state_dir / "settings.conf"
    lines = conf_file.read_text(encoding="utf-8", errors="ignore").splitlines() if conf_file.exists() else []
    target_val = "true" if enabled else "false"
    out = []
    updated = False
    for ln in lines:
        if ln.startswith("dnd="):
            if not updated:
                out.append(f"dnd={target_val}")
                updated = True
        else:
            out.append(ln)
    if not updated:
        out.append(f"dnd={target_val}")
    conf_file.write_text("\n".join(out) + "\n", encoding="utf-8")


def _reload_gnome_theme() -> Tuple[bool, str]:
    hooks_dir = CONFIG_DIR / "matugen" / "post-hook-scripts"
    ran = []
    for name in ("gnome-theme-reload.zsh", "gtk-themes-reload.zsh", "ptyxis-theme-reload.zsh"):
        script = hooks_dir / name
        if script.exists():
            try:
                subprocess.run(["zsh", str(script)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5.0)
                ran.append(name.replace("-reload.zsh", ""))
            except Exception:
                pass
    if not ran:
        return False, f"no gnome reload hooks found in {hooks_dir}"
    return True, f"reloaded gnome hooks: {', '.join(ran)}"


def _get_ptyxis_palette() -> str:
    uuid = _dconf_read("/org/gnome/Ptyxis/default-profile-uuid")
    if not uuid:
        raw_list = _dconf_read("/org/gnome/Ptyxis/profile-uuids")
        m = re.search(r"'([0-9a-fA-F-]+)'", raw_list)
        uuid = m.group(1) if m else ""
    return _dconf_read(f"/org/gnome/Ptyxis/Profiles/{uuid}/palette") if uuid else ""


_UWSM_CACHE: Optional[bool] = None


def is_uwsm_active() -> bool:
    global _UWSM_CACHE
    if _UWSM_CACHE is not None:
        return _UWSM_CACHE
    if not shutil.which("uwsm"):
        _UWSM_CACHE = False
        return False
    if os.environ.get("UWSM_FINALIZE_VARNAMES"):
        _UWSM_CACHE = True
        return True
    try:
        r = subprocess.run(
            ["uwsm", "check", "is-active"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=1.0,
        )
        _UWSM_CACHE = r.returncode == 0
    except Exception:
        _UWSM_CACHE = False
    return _UWSM_CACHE


def wrap_uwsm(cmd: List[str]) -> List[str]:
    return ["uwsm", "app", "--", *cmd] if is_uwsm_active() else cmd


def launch_detached(cmd: List[str]) -> Tuple[bool, str]:
    if not cmd:
        return False, "empty command"
    if not shutil.which(cmd[0]):
        return False, f"binary not found: {cmd[0]}"
    try:
        subprocess.Popen(
            cmd,
            start_new_session=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return True, ""
    except Exception as e:
        return False, str(e)


def runtime_by_pid_dir() -> Path:
    return Path(f"/run/user/{os.getuid()}/quickshell/by-pid")


def get_running_pids() -> List[int]:
    uid = str(os.getuid())
    pids = set()
    if shutil.which("pgrep"):
        for name in SHELL_PROC_NAMES:
            try:
                out = subprocess.check_output(
                    ["pgrep", "-u", uid, "-x", name],
                    stderr=subprocess.DEVNULL,
                    text=True,
                    timeout=1.5,
                )
                for line in out.splitlines():
                    s = line.strip()
                    if s.isdigit():
                        pids.add(int(s))
            except Exception:
                pass
        return sorted(pids)

    # fallback to /proc scan if pgrep is missing
    proc = Path("/proc")
    my_uid = os.getuid()
    if proc.is_dir():
        for entry in proc.iterdir():
            if not entry.name.isdigit():
                continue
            try:
                if entry.stat().st_uid != my_uid:
                    continue
                comm = (entry / "comm").read_text(encoding="utf-8", errors="ignore").strip()
                if comm in SHELL_PROC_NAMES:
                    pids.add(int(entry.name))
            except OSError:
                continue
    return sorted(pids)


def detect_running_shell(pids: Sequence[int]) -> Optional[str]:
    """Check /proc/<pid>/cmdline so we know what's actually running vs what's cached."""
    brain_marker = get_brain_shell_dir().name.lower()
    for pid in pids:
        try:
            raw = Path(f"/proc/{pid}/cmdline").read_bytes()
            args = [a.decode("utf-8", errors="ignore") for a in raw.split(b"\x00") if a]
            joined = " ".join(args).lower()
            if brain_marker in joined or "brain_shell" in joined:
                return "brain_shell"
        except OSError:
            continue
    return "quickshell" if pids else None


def get_proc_ram_mb(pids: Sequence[int]) -> Optional[int]:
    if not pids:
        return None
    total_kb = 0
    found = False
    for pid in pids:
        try:
            status = Path(f"/proc/{pid}/status").read_text(encoding="utf-8", errors="ignore")
            m = re.search(r"(?m)^VmRSS:\s*(\d+)\s*kB", status)
            if m:
                total_kb += int(m.group(1))
                found = True
        except OSError:
            continue
    if found:
        return total_kb // 1024
    try:
        out = subprocess.check_output(
            ["ps", "-o", "rss=", "-p", ",".join(map(str, pids))],
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=1.5,
        )
        vals = [int(x.strip()) for x in out.splitlines() if x.strip().isdigit()]
        return sum(vals) // 1024 if vals else None
    except Exception:
        return None


def get_proc_uptime(pids: Sequence[int]) -> str:
    if not pids:
        return "-"
    try:
        out = subprocess.check_output(
            ["ps", "-o", "etimes=", "-p", str(pids[0])],
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=1.5,
        ).strip()
        secs = int(out)
        if secs < 60:
            return f"{secs}s"
        mins, s = divmod(secs, 60)
        if mins < 60:
            return f"{mins}m {s}s"
        hrs, m = divmod(mins, 60)
        if hrs < 24:
            return f"{hrs}h {m}m"
        days, h = divmod(hrs, 24)
        return f"{days}d {h}h"
    except Exception:
        return "-"


def find_stale_runtime_entries() -> List[Path]:
    by_pid = runtime_by_pid_dir()
    if not by_pid.is_dir():
        return []
    stale: List[Path] = []
    for item in by_pid.iterdir():
        name = item.name
        if name.isdigit():
            if not Path(f"/proc/{name}").exists():
                stale.append(item)
        elif item.is_symlink() and not item.exists():
            stale.append(item)
    return stale


def clean_stale_runtime_dirs() -> int:
    # quickshell stores by-pid/<pid> as directories, so unlink alone used to miss them
    removed = 0
    for item in find_stale_runtime_entries():
        try:
            if item.is_symlink() or item.is_file():
                item.unlink()
            elif item.is_dir():
                shutil.rmtree(item)
            removed += 1
        except OSError:
            pass
    return removed


def latest_runtime_log(pids: Optional[Sequence[int]] = None) -> Optional[Path]:
    by_pid = runtime_by_pid_dir()
    if not by_pid.is_dir():
        return None
    if pids:
        live_logs: List[Path] = []
        for pid in pids:
            cand = by_pid / str(pid) / "log.log"
            if cand.exists():
                live_logs.append(cand)
        if live_logs:
            live_logs.sort(key=lambda p: p.stat().st_mtime, reverse=True)
            return live_logs[0]

    cands = [d / "log.log" for d in by_pid.iterdir() if d.is_dir() and (d / "log.log").exists()]
    if not cands:
        return None
    cands.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    return cands[0]


def tail_lines(path: Path, count: int) -> List[str]:
    if count <= 0 or not path.exists():
        return []
    try:
        with path.open("r", encoding="utf-8", errors="ignore") as fh:
            return list(deque((ln.rstrip("\r\n") for ln in fh), maxlen=count))
    except OSError:
        return []


def summarize_log(path: Optional[Path]) -> Tuple[bool, int, int, List[str]]:
    if not path or not path.exists():
        return False, 0, 0, []
    loaded = False
    err_cnt = 0
    warn_cnt = 0
    err_lines: List[str] = []
    try:
        with path.open("r", encoding="utf-8", errors="ignore") as fh:
            for raw in fh:
                ln = raw.rstrip("\r\n")
                if "Configuration Loaded" in ln:
                    loaded = True
                if " ERROR:" in ln or " Fatal:" in ln:
                    err_cnt += 1
                    err_lines.append(ln)
                elif " WARN:" in ln:
                    warn_cnt += 1
    except OSError:
        pass
    return loaded, err_cnt, warn_cnt, err_lines[-5:]


def has_no_new_privs() -> bool:
    """NoNewPrivs=1 blocks setuid unix_chkpwd and bricks lockscreen unlock."""
    try:
        status = Path("/proc/self/status").read_text(encoding="utf-8", errors="ignore")
        return re.search(r"(?m)^NoNewPrivs:\s*1\b", status) is not None
    except OSError:
        return False


def normalize_shell_target(target: str, current: Optional[str] = None) -> Optional[str]:
    cur = current or get_current_shell()
    t = target.lower().strip()
    if t in ("toggle", "t"):
        return "quickshell" if cur == "brain_shell" else "brain_shell"
    if t in ("restart", "reload", "r"):
        return cur
    if t in ("quickshell", "qs", "default", "stock"):
        return "quickshell"
    if t in ("brain_shell", "bs", "brain", "brainshell"):
        return "brain_shell"
    return None


def kill_running_shell(graceful_timeout: float = 1.5, quiet: bool = False) -> int:
    if not quiet:
        print(f"{S.dim}󰚰 terminating running shell instances...{S.reset}")

    before = get_running_pids()
    brain_dir = str(get_brain_shell_dir())
    uid = str(os.getuid())

    if shutil.which("qs"):
        for cmd in (["qs", "kill"], ["qs", "-p", brain_dir, "kill"]):
            try:
                subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1.5)
            except Exception:
                pass

    if shutil.which("pkill"):
        for name in SHELL_PROC_NAMES:
            try:
                subprocess.run(
                    ["pkill", "-u", uid, "-x", name],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    timeout=1.0,
                )
            except Exception:
                pass
    else:
        for pid in before:
            try:
                os.kill(pid, signal.SIGTERM)
            except OSError:
                pass

    deadline = time.time() + graceful_timeout
    while time.time() < deadline:
        if not get_running_pids():
            break
        time.sleep(0.05)

    survivors = get_running_pids()
    if survivors:
        if shutil.which("pkill"):
            for name in SHELL_PROC_NAMES:
                try:
                    subprocess.run(
                        ["pkill", "-9", "-u", uid, "-x", name],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                        timeout=1.0,
                    )
                except Exception:
                    pass
        else:
            for pid in survivors:
                try:
                    os.kill(pid, signal.SIGKILL)
                except OSError:
                    pass
        time.sleep(0.1)

    clean_stale_runtime_dirs()
    return len(before)


def launch_shell(shell_name: str, force: bool = False, quiet: bool = False) -> Tuple[bool, str, List[int]]:
    if has_no_new_privs() and not force:
        msg = (
            f"refusing to launch {shell_name} under nonewprivs=1: "
            "setuid unix_chkpwd fails inside sandboxed shells and bricks lockscreen unlock "
            "(run from a normal terminal, or pass --force)."
        )
        if not quiet:
            print(f"{S.red}󰅚 {msg}{S.reset}", file=sys.stderr)
        return False, msg, []

    if not shutil.which("qs"):
        msg = "'qs' binary not found in path."
        if not quiet:
            print(f"{S.red}󰅚 {msg}{S.reset}", file=sys.stderr)
        return False, msg, []

    if shell_name == "brain_shell":
        brain_path = get_brain_shell_dir()
        if not brain_path.is_dir():
            msg = f"brain_shell directory not found at {brain_path}"
            if not quiet:
                print(f"{S.red}󰅚 {msg}{S.reset}", file=sys.stderr)
            return False, msg, []
        cmd = wrap_uwsm(["qs", "-d", "-p", str(brain_path)])
    else:
        cmd = wrap_uwsm(["qs", "-d"])

    if not quiet:
        print(f"{S.cyan}󰄛 launching {S.bold}{shell_name}{S.reset}...")

    old_pids = set(get_running_pids())
    ok, err = launch_detached(cmd)
    if not ok:
        msg = f"error launching {shell_name}: {err}"
        if not quiet:
            print(f"{S.red}󰅚 {msg}{S.reset}", file=sys.stderr)
        return False, msg, []

    pids: List[int] = []
    loaded_ok = False
    err_lines: List[str] = []
    deadline = time.time() + 3.0
    while time.time() < deadline:
        live = get_running_pids()
        new_pids = [p for p in live if p not in old_pids] or live
        if new_pids:
            pids = new_pids
            log_file = latest_runtime_log(new_pids)
            if log_file and log_file.exists():
                txt = log_file.read_text(encoding="utf-8", errors="ignore")
                if "Configuration Loaded" in txt:
                    loaded_ok = True
                    break
                if "Failed to load configuration" in txt:
                    err_lines = [ln for ln in txt.splitlines() if " ERROR:" in ln or " Fatal:" in ln]
                    break
        time.sleep(0.1)

    if err_lines:
        msg = f"{shell_name} config error: {err_lines[-1].strip()}"
        if not quiet:
            print(f"{S.red}󰅚 {shell_name} config error:{S.reset}", file=sys.stderr)
            for ln in err_lines[-3:]:
                print(f"  {S.red}{ln}{S.reset}", file=sys.stderr)
        return False, msg, pids

    if loaded_ok:
        pid_txt = ", ".join(map(str, pids))
        msg = f"{shell_name} loaded cleanly (pid {pid_txt})"
        if not quiet:
            print(f"{S.green}󰄲 {S.bold}{shell_name}{S.reset} {S.green}loaded cleanly (pid {pid_txt}).{S.reset}")
        return True, msg, pids

    if pids:
        pid_txt = ", ".join(map(str, pids))
        msg = f"{shell_name} engaged (pid {pid_txt})"
        if not quiet:
            print(f"{S.green}󰄲 {S.bold}{shell_name}{S.reset} {S.green}engaged (pid {pid_txt}).{S.reset}")
        return True, msg, pids

    msg = "launch dispatched, but no daemon appeared (check 'cli logs')"
    if not quiet:
        print(f"{S.yellow}󰀦 {msg}{S.reset}")
    return False, msg, []


def switch_shell(target_arg: str, force: bool = False, quiet: bool = False) -> Tuple[bool, str]:
    if in_gnome_session():
        t = target_arg.strip().lower()
        if t in ("restart", "reload", "r"):
            ok, msg = _reload_gnome_theme()
            if not quiet:
                stream = sys.stdout if ok else sys.stderr
                col = S.green if ok else S.red
                icon = "󰄲" if ok else "󰅚"
                print(f"{col}{icon} {msg}{S.reset}", file=stream)
            return ok, msg
        msg = "quickshell / brain_shell switch is hyprland-only; use 'cli reload' to refresh gnome matugen themes."
        if not quiet:
            print(f"{S.yellow}󰀦 {msg}{S.reset}", file=sys.stderr)
        return False, msg

    current = get_current_shell()
    target = normalize_shell_target(target_arg, current)
    if not target:
        msg = f"unknown shell target '{target_arg}'. use 'quickshell' or 'brain_shell'."
        if not quiet:
            print(f"{S.red}error:{S.reset} {msg}", file=sys.stderr)
        return False, msg

    # validate everything before killing the running shell or mutating state
    if has_no_new_privs() and not force:
        msg = (
            f"refusing to reload into {target} under nonewprivs=1: "
            "keeping host shell alive so lockscreen unix_chkpwd keeps setuid permissions."
        )
        if not quiet:
            print(f"{S.red}󰅚 {msg}{S.reset}", file=sys.stderr)
        return False, msg

    if not shutil.which("qs"):
        msg = "'qs' binary not found; refusing to kill active shell."
        if not quiet:
            print(f"{S.red}󰅚 {msg}{S.reset}", file=sys.stderr)
        return False, msg

    if target == "brain_shell" and not get_brain_shell_dir().is_dir():
        msg = f"brain_shell directory not found at {get_brain_shell_dir()}; keeping {current} alive."
        if not quiet:
            print(f"{S.red}󰅚 {msg}{S.reset}", file=sys.stderr)
        return False, msg

    if not quiet:
        print(f"{S.magenta}󰑐 switching shell:{S.reset} {S.dim}{current}{S.reset} -> {S.bold}{S.cyan}{target}{S.reset}")

    set_current_shell(target)
    kill_running_shell(quiet=quiet)
    ok, msg, _ = launch_shell(target, force=force, quiet=quiet)
    return ok, msg


def send_ipc(
    target_object: str,
    method: str = "toggle",
    profile_dir: Optional[str] = None,
    extra_args: Optional[Sequence[str]] = None,
    timeout: float = 3.0,
) -> Tuple[bool, str, str]:
    if not shutil.which("qs"):
        return False, "", "'qs' binary not found in path"
    cmd = ["qs", "ipc"]
    if profile_dir:
        cmd.extend(["-p", str(profile_dir)])
    cmd.extend(["call", target_object, method])
    if extra_args:
        cmd.extend(extra_args)
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return res.returncode == 0, res.stdout.strip(), res.stderr.strip()
    except subprocess.TimeoutExpired:
        return False, "", f"ipc call timed out ({target_object}.{method})"
    except Exception as e:
        return False, "", str(e)


def resolve_terminal() -> Optional[str]:
    prefs = _read_user_prefs()
    order = (
        ["ptyxis", "kitty", "ghostty", "foot", "alacritty", "wezterm"]
        if in_gnome_session()
        else ["kitty", "ptyxis", "ghostty", "foot", "alacritty", "wezterm"]
    )
    candidates = [
        prefs.get("PREFERRED_TERMINAL", ""),
        os.environ.get("TERMINAL", ""),
        *order,
    ]
    for cand in candidates:
        if cand and shutil.which(cand):
            return cand
    return None


def launch_in_terminal(inner_cmd: List[str]) -> Tuple[bool, str]:
    term = resolve_terminal()
    if not term:
        return False, "no supported terminal emulator found (kitty/ptyxis/ghostty/foot/alacritty/wezterm)"
    if term == "wezterm":
        cmd = [term, "start", "--", *inner_cmd]
    elif term == "ptyxis":
        cmd = [term, "--", *inner_cmd]
    elif term == "foot":
        cmd = [term, *inner_cmd]
    else:
        cmd = [term, "-e", *inner_cmd]
    return launch_detached(wrap_uwsm(cmd))


def open_file_manager(target_dir: Optional[str] = None) -> Tuple[bool, str]:
    target_path = Path(target_dir).expanduser() if target_dir else HOME
    if target_path.exists() and target_path.is_file():
        target_path = target_path.parent
    target = str(target_path)

    prefs = _read_user_prefs()
    pref_fm = prefs.get("PREFERRED_FILE_MANAGER", "yazi") or "yazi"

    if pref_fm == "yazi" and shutil.which("yazi"):
        ok, err = launch_in_terminal(["yazi", target])
        if ok:
            return True, f"opened yazi at {target}"

    if pref_fm in ("dolphin", "nautilus", "thunar") and shutil.which(pref_fm):
        ok, err = launch_detached(wrap_uwsm([pref_fm, target]))
        return ok, f"opened {pref_fm} at {target}" if ok else err

    if pref_fm not in ("yazi", "dolphin", "nautilus", "thunar") and shutil.which(pref_fm):
        ok, err = launch_detached(wrap_uwsm([pref_fm, target]))
        return ok, f"opened {pref_fm} at {target}" if ok else err

    if shutil.which("yazi"):
        ok, err = launch_in_terminal(["yazi", target])
        if ok:
            return True, f"opened yazi at {target}"
    fallback_fms = ("nautilus", "dolphin", "thunar", "xdg-open") if in_gnome_session() else ("dolphin", "nautilus", "thunar", "xdg-open")
    for fm in fallback_fms:
        if shutil.which(fm):
            ok, err = launch_detached(wrap_uwsm([fm, target]))
            return ok, f"opened {fm} at {target}" if ok else err
    return False, "no file manager found on path"


def _find_helper_script(filename: str) -> Optional[Path]:
    for cand in (
        DOTFILES_DIR / "quickshell" / "scripts" / filename,
        CONFIG_DIR / "quickshell" / "scripts" / filename,
    ):
        if cand.exists():
            return cand
    return None


def _find_wp_script() -> Optional[Path]:
    return _find_helper_script("wallpaper.py")


def trigger_wallpaper(args: Optional[Sequence[str]] = None, interactive_passthrough: bool = True) -> Tuple[bool, str]:
    args = list(args or [])
    current = get_current_shell()
    brain_dir = get_brain_shell_dir()
    wp_script = _find_wp_script()

    if args:
        if not wp_script:
            return False, "wallpaper.py not found; cannot forward wallpaper subcommands"
        if interactive_passthrough:
            res = subprocess.run([sys.executable, str(wp_script), *args])
            return res.returncode == 0, "" if res.returncode == 0 else f"wallpaper.py exited {res.returncode}"
        res = subprocess.run([sys.executable, str(wp_script), *args], capture_output=True, text=True)
        out = (res.stdout or res.stderr).strip()
        return res.returncode == 0, out or ("wallpaper updated" if res.returncode == 0 else "wallpaper command failed")

    if current == "brain_shell" and brain_dir.is_dir():
        ok, _, err = send_ipc("wallpaper-toggle", "toggle", profile_dir=str(brain_dir))
        return ok, "toggled brain_shell wallpaper picker" if ok else (err or "ipc failed")

    if wp_script:
        ok, err = launch_detached([sys.executable, str(wp_script), "random", "all"])
        return ok, "rolling random wallpaper..." if ok else err

    ok, _, err = send_ipc("wallpaper", "toggle")
    return ok, "toggled wallpaper picker" if ok else (err or "ipc failed")


def handle_record(args: Sequence[str]) -> Tuple[bool, str]:
    current = get_current_shell()
    brain_dir = get_brain_shell_dir()
    if current == "brain_shell" and brain_dir.is_dir():
        ok, _, err = send_ipc("screenrec-on", "toggle", profile_dir=str(brain_dir))
        return ok, "toggled brain_shell screen recorder" if ok else (err or "ipc failed")

    sub = args[0].lower() if args else "toggle"
    sub_map = {
        "screen": "screen", "display": "screen", "full": "screen",
        "region": "region", "area": "region", "crop": "region",
        "window": "window",
        "stop": "stop", "end": "stop",
        "discard": "discard", "cancel": "discard",
        "toggle": "toggle",
    }
    method = sub_map.get(sub, "toggle")
    ok, _, err = send_ipc("record", method)
    return ok, f"record -> {method}" if ok else (err or "ipc failed")


# pure data collectors so CLI and TUI share one source of truth
@dataclasses.dataclass
class CheckResult:
    status: str  # ok | warn | fail
    area: str
    detail: str
    fixable: bool = False


def collect_status() -> dict:
    in_gnome = in_gnome_session()
    configured = "gnome" if in_gnome else get_current_shell()
    pids = [] if in_gnome else get_running_pids()
    detected = "gnome" if in_gnome else detect_running_shell(pids)
    log_path = None if in_gnome else latest_runtime_log(pids if pids else None)
    loaded, err_cnt, warn_cnt, err_lines = (True, 0, 0, []) if in_gnome else summarize_log(log_path)
    cfg = _read_settings_conf()
    curr_wall = HOME / ".curr_wall"
    if curr_wall.is_symlink() and not curr_wall.exists():
        wp_label = f"broken symlink -> {os.readlink(curr_wall)}"
    elif curr_wall.exists():
        wp_label = str(curr_wall.resolve())
    else:
        wp_label = cfg.get("currentWallpaper", "unknown")

    ptyxis_pal = _get_ptyxis_palette()
    gnome_theme = _dconf_read("/org/gnome/shell/extensions/user-theme/name")
    gnome_accent = _dconf_read("/org/gnome/desktop/interface/accent-color")

    return {
        "desktop": desktop_env_name(),
        "gnome": in_gnome,
        "gnome_theme": gnome_theme,
        "gnome_accent": gnome_accent,
        "ptyxis_palette": ptyxis_pal,
        "configured_shell": configured,
        "running_shell": detected,
        "mismatch": bool(not in_gnome and detected and detected != configured),
        "pids": pids,
        "ram_mb": get_proc_ram_mb(pids),
        "uptime": get_proc_uptime(pids),
        "loaded": loaded,
        "log_path": str(log_path) if log_path else None,
        "log_errors": err_cnt,
        "log_warns": warn_cnt,
        "recent_errors": err_lines,
        "mode": cfg.get("matugenMode", "dark"),
        "scheme": cfg.get("matugenScheme", "scheme-tonal-spot"),
        "wallpaper": wp_label,
        "brain_dir": str(get_brain_shell_dir()),
        "brain_exists": get_brain_shell_dir().is_dir(),
        "qs_dir": str(DOTFILES_DIR / "quickshell"),
        "uwsm_active": is_uwsm_active(),
        "no_new_privs": has_no_new_privs(),
        "stale_runtime_dirs": len(find_stale_runtime_entries()),
    }


def collect_theme() -> dict:
    cfg = _read_settings_conf()
    mode = cfg.get("matugenMode", "dark")
    scheme = cfg.get("matugenScheme", "scheme-tonal-spot")

    curr_wall = HOME / ".curr_wall"
    wp_broken = curr_wall.is_symlink() and not curr_wall.exists()
    wp_exists = curr_wall.exists()
    if wp_broken:
        wp_target = f"{os.readlink(curr_wall)} (broken symlink)"
    elif wp_exists:
        wp_target = str(curr_wall.resolve())
    else:
        wp_target = cfg.get("currentWallpaper", "unknown")

    tokens: Dict[str, str] = {}
    zsh_matugen = CONFIG_DIR / "zsh" / "matugen.zsh"
    if zsh_matugen.exists():
        for ln in zsh_matugen.read_text(encoding="utf-8", errors="ignore").splitlines():
            m = re.match(r'^typeset -g (MATUGEN_\w+)="([^"]+)"', ln.strip())
            if m:
                tokens[m.group(1)] = m.group(2)

    kitty_ansi: Dict[str, str] = {}
    kitty_colors = CONFIG_DIR / "kitty" / "colors.conf"
    if kitty_colors.exists():
        kc = kitty_colors.read_text(encoding="utf-8", errors="ignore")
        for m in re.finditer(r"^(color\d+|foreground|background)\s+(#[0-9a-fA-F]{6})\b", kc, re.M):
            kitty_ansi[m.group(1)] = m.group(2)

    ptyxis_pal_file = HOME / ".local" / "share" / "org.gnome.Ptyxis" / "palettes" / "matugen.palette"
    return {
        "desktop": desktop_env_name(),
        "mode": mode,
        "scheme": scheme,
        "wallpaper": wp_target,
        "wallpaper_broken": wp_broken,
        "gnome_theme": _dconf_read("/org/gnome/shell/extensions/user-theme/name"),
        "gnome_accent": _dconf_read("/org/gnome/desktop/interface/accent-color"),
        "ptyxis_palette": _get_ptyxis_palette(),
        "ptyxis_palette_exists": ptyxis_pal_file.exists(),
        "tokens": tokens,
        "kitty_ansi": kitty_ansi,
    }


def collect_doctor() -> List[CheckResult]:
    checks: List[CheckResult] = []
    st = collect_status()
    in_gnome = bool(st.get("gnome"))

    if in_gnome:
        ok_gs, gs_out, _ = _gdbus_call(
            "org.gnome.Shell",
            "/org/gnome/Shell",
            "org.freedesktop.DBus.Properties.Get",
            "org.gnome.Shell",
            "ShellVersion",
            timeout=2.0,
        )
        ver_m = re.search(r"'([^']+)'", gs_out) if ok_gs else None
        checks.append(CheckResult(
            "ok" if ok_gs else "warn",
            "gnome-shell",
            f"gnome {ver_m.group(1).lower()} session active" if ver_m else "gnome session active (shell dbus unreachable)",
        ))

        shell_theme = st.get("gnome_theme") or "unset"
        gs_css = HOME / ".local" / "share" / "themes" / "Matugen" / "gnome-shell" / "gnome-shell.css"
        if gs_css.exists() and shell_theme == "Matugen":
            checks.append(CheckResult("ok", "shell-theme", f"user-theme={shell_theme.lower()} · accent={st.get('gnome_accent') or 'default'}"))
        elif gs_css.exists():
            checks.append(CheckResult("warn", "shell-theme", f"matugen css exists but user-theme='{shell_theme.lower()}' (run 'cli reload')", fixable=True))
        else:
            checks.append(CheckResult("warn", "shell-theme", "~/.local/share/themes/Matugen/gnome-shell/gnome-shell.css missing"))

        gtk4_ok = (CONFIG_DIR / "gtk-4.0" / "matugen.css").exists()
        gtk3_ok = (CONFIG_DIR / "gtk-3.0" / "matugen.css").exists()
        checks.append(CheckResult(
            "ok" if (gtk4_ok and gtk3_ok) else "warn",
            "gtk-colors",
            "gtk-3.0 & gtk-4.0 matugen.css present" if (gtk4_ok and gtk3_ok) else f"gtk3={gtk3_ok} gtk4={gtk4_ok}",
        ))
    else:
        if not shutil.which("qs"):
            checks.append(CheckResult("fail", "qs-binary", "'qs' not found on path"))
        elif st["pids"]:
            pid_str = ", ".join(map(str, st["pids"]))
            shell_lbl = st["running_shell"] or st["configured_shell"]
            detail = f"{shell_lbl} running (pid {pid_str}) · loaded={st['loaded']} · errors={st['log_errors']}"
            if st["mismatch"]:
                detail += f" (cache says {st['configured_shell']})"
                status = "warn"
            elif st["loaded"] and st["log_errors"] == 0:
                status = "ok"
            elif st["loaded"]:
                status = "warn"
            else:
                status = "fail"
            checks.append(CheckResult(status, "shell", detail))
        else:
            checks.append(CheckResult("fail", "shell", f"{st['configured_shell']} is not running (run 'cli reload')"))

        if st["pids"] and shutil.which("qs"):
            prof = str(get_brain_shell_dir()) if (st["running_shell"] == "brain_shell" and st["brain_exists"]) else None
            cmd = ["qs", "ipc"] + (["-p", prof] if prof else []) + ["show"]
            try:
                r = subprocess.run(cmd, capture_output=True, text=True, timeout=1.5)
                if r.returncode == 0:
                    targets = sum(1 for ln in r.stdout.splitlines() if ln.strip().startswith("target "))
                    checks.append(CheckResult("ok", "ipc", f"responsive ({targets} targets exported)" if targets else "responsive"))
                else:
                    first_err = (r.stderr or "ipc show failed").strip().splitlines()[0]
                    checks.append(CheckResult("warn", "ipc", first_err))
            except subprocess.TimeoutExpired:
                checks.append(CheckResult("fail", "ipc", "shell ipc timed out (daemon may be wedged)"))
            except Exception as e:
                checks.append(CheckResult("warn", "ipc", str(e)))

        if st["no_new_privs"]:
            checks.append(CheckResult("warn", "privileges", "nonewprivs=1 active (reloads blocked to protect lockscreen auth)"))
        else:
            checks.append(CheckResult("ok", "privileges", "nonewprivs=0 (setuid lockscreen unlock ok)"))

        bdir = get_brain_shell_dir()
        checks.append(CheckResult(
            "ok" if bdir.is_dir() else "warn",
            "brain_shell",
            f"{bdir}" + ("" if bdir.is_dir() else " (missing)"),
        ))

        stale_cnt = st["stale_runtime_dirs"]
        if stale_cnt == 0:
            checks.append(CheckResult("ok", "runtime-dirs", "no stale quickshell pid dirs"))
        else:
            checks.append(CheckResult(
                "warn",
                "runtime-dirs",
                f"{stale_cnt} stale dead pid dir(s) in {runtime_by_pid_dir()} (run 'cli doctor --fix')",
                fixable=True,
            ))

        try:
            r = subprocess.run(["hyprctl", "version"], capture_output=True, text=True, timeout=2)
            checks.append(CheckResult("ok" if r.returncode == 0 else "warn", "hyprland", "socket active" if r.returncode == 0 else "hyprctl returned non-zero"))
        except Exception:
            checks.append(CheckResult("warn", "hyprland", "hyprctl unavailable or outside session"))

    ptyxis_bin = shutil.which("ptyxis")
    ptyxis_pal_file = HOME / ".local" / "share" / "org.gnome.Ptyxis" / "palettes" / "matugen.palette"
    ptyxis_pal = st.get("ptyxis_palette") or "unset"
    if ptyxis_bin and ptyxis_pal_file.exists() and ptyxis_pal == "matugen":
        checks.append(CheckResult("ok", "ptyxis", "native binary + matugen.palette active"))
    elif ptyxis_bin:
        checks.append(CheckResult(
            "warn" if in_gnome else "ok",
            "ptyxis",
            f"native binary ok · palette={ptyxis_pal} · file={'yes' if ptyxis_pal_file.exists() else 'no'}",
            fixable=ptyxis_pal_file.exists() and ptyxis_pal != "matugen",
        ))
    elif in_gnome:
        checks.append(CheckResult("warn", "ptyxis", "native ptyxis not on path yet (run 'rebuild')"))

    try:
        r = subprocess.run(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"], capture_output=True, text=True, timeout=2)
        checks.append(CheckResult("ok" if r.returncode == 0 else "warn", "pipewire", r.stdout.strip() if r.returncode == 0 else "no default audio sink"))
    except Exception:
        checks.append(CheckResult("warn", "pipewire", "wpctl missing"))

    curr_wall = HOME / ".curr_wall"
    if curr_wall.is_symlink() and not curr_wall.exists():
        checks.append(CheckResult("warn", "wallpaper", f"~/.curr_wall is a broken symlink -> {os.readlink(curr_wall)}"))
    elif curr_wall.exists():
        checks.append(CheckResult("ok", "wallpaper", curr_wall.resolve().name))
    else:
        checks.append(CheckResult("warn", "wallpaper", "~/.curr_wall missing"))

    kitty_colors = CONFIG_DIR / "kitty" / "colors.conf"
    if kitty_colors.exists():
        kc = kitty_colors.read_text(encoding="utf-8", errors="ignore")
        c0 = re.search(r"^color0\s+(#[0-9a-fA-F]{6})", kc, re.M)
        c15 = re.search(r"^color15\s+(#[0-9a-fA-F]{6})", kc, re.M)
        if c0 and c15 and c0.group(1).lower() != c15.group(1).lower():
            checks.append(CheckResult("ok", "kitty-ansi", f"color0={c0.group(1)} color15={c15.group(1)}"))
        else:
            checks.append(CheckResult("warn", "kitty-ansi", "ansi fg/bg collapsed; run 'cli wp reload'"))
    else:
        checks.append(CheckResult("fail", "kitty-ansi", "~/.config/kitty/colors.conf missing"))

    btop_conf = CONFIG_DIR / "btop" / "btop.conf"
    if btop_conf.exists():
        bc = btop_conf.read_text(encoding="utf-8", errors="ignore")
        tm = re.search(r'^color_theme\s*=\s*"([^"]+)"', bc, re.M)
        ft = re.search(r"^force_tty\s*=\s*(\w+)", bc, re.M)
        theme_val = tm.group(1) if tm else "?"
        ftty_val = ft.group(1) if ft else "?"
        is_link = btop_conf.parent.is_symlink()
        checks.append(CheckResult(
            "ok" if (is_link and ftty_val == "false") else "warn",
            "btop",
            f"theme={theme_val} force_tty={ftty_val} symlink={is_link}",
        ))
    else:
        checks.append(CheckResult("warn", "btop", "~/.config/btop/btop.conf missing"))

    broken = [m for m in ("zsh", "kitty", "nvim", "yazi", "btop", "fastfetch", "matugen") if not (CONFIG_DIR / m).exists()]
    checks.append(CheckResult(
        "ok" if not broken else "warn",
        "symlinks",
        "all core app configs linked" if not broken else f"missing: {', '.join(broken)}",
    ))

    if USER_PREFS_FILE.exists():
        zwc_cnt = len(list((CONFIG_DIR / "zsh").glob("*.zwc")))
        prefs_txt = USER_PREFS_FILE.read_text(encoding="utf-8", errors="ignore")
        has_legacy = "ENABLE_PSYCHO_ROASTS=" in prefs_txt or "SHOW_GREETING_ROAST=" in prefs_txt
        note = f"prefs loaded · {zwc_cnt} .zwc bytecode files"
        if has_legacy:
            note += " (legacy keys auto-migrate on next shell)"
        checks.append(CheckResult("ok", "zsh", note))
    else:
        checks.append(CheckResult("warn", "zsh", f"{USER_PREFS_FILE} missing"))

    return checks


# single action registry feeding CLI dispatch, TUI menu, inspector, and typo hints
@dataclasses.dataclass
class ActionSpec:
    id: str
    category: str  # Shell | Desktop | Capture | System
    icon: str
    label: str
    desc: str
    aliases: Tuple[str, ...] = ()
    bs_ipc: Optional[Tuple[str, str]] = None
    qs_ipc: Optional[Tuple[str, str]] = None
    cli_hint: str = ""
    in_menu: bool = True
    kind: str = "ipc"  # ipc | lifecycle | modal | special


ACTIONS: List[ActionSpec] = [
    ActionSpec("switch", "shell", "󰑐", "switch shell", "toggle between quickshell and brain_shell",
               ("shell", "toggle", "t"), cli_hint="cli shell toggle", kind="lifecycle"),
    ActionSpec("reload", "shell", "󰁕", "reload active shell", "gracefully restart current shell and verify load",
               ("restart", "r"), cli_hint="cli reload", kind="lifecycle"),
    ActionSpec("kill", "shell", "󰅚", "kill running shells", "terminate lingering shell daemons & sweep dead pids",
               ("stop", "k"), cli_hint="cli kill", kind="lifecycle"),
    ActionSpec("status", "system", "󰋼", "shell status", "inspect active shell, pids, ram, uptime, and profile",
               ("info", "current"), cli_hint="cli status", kind="modal"),
    ActionSpec("doctor", "system", "󰚰", "run diagnostics", "health check for shell, ipc, hyprland, pipewire, and theme",
               ("health", "check"), cli_hint="cli doctor [--fix]", kind="modal"),
    ActionSpec("theme", "system", "󰏘", "inspect theme & palette", "view wallpaper, matugen tokens, and ansi 0..15 blocks",
               ("palette", "colors"), cli_hint="cli theme", kind="modal"),
    ActionSpec("logs", "system", "󰍉", "runtime shell logs", "inspect or live-follow active quickshell runtime log",
               ("log",), cli_hint="cli logs [n|-f|-e]", kind="modal"),

    ActionSpec("launcher", "desktop", "󰍜", "app launcher", "toggle application launcher",
               ("d",), ("dashboard-launcher", "toggle"), ("launcher", "toggle"), "cli launcher"),
    ActionSpec("dashboard", "desktop", "󰕮", "dashboard / quicksettings", "toggle main control center",
               ("dash", "quicksettings", "home"), ("dashboard-home", "toggle"), ("quicksettings", "toggle"), "cli dashboard"),
    ActionSpec("notifs", "desktop", "󰂚", "notification center", "toggle notification history panel",
               ("notifications", "n"), ("notification-toggle", "toggle"), ("notifs", "toggle"), "cli notifs"),
    ActionSpec("dnd", "desktop", "󰂛", "do not disturb / focus", "toggle focus / dnd mode",
               ("focus",), ("focus-toggle", "toggle"), ("notifs", "dnd"), "cli dnd"),
    ActionSpec("clipboard", "desktop", "󰅇", "clipboard history", "open clipboard manager popup",
               ("clip", "v"), ("clipboard-toggle", "toggle"), ("clipboard", "toggle"), "cli clip"),
    ActionSpec("notes", "desktop", "󰎞", "quick notes / kanban", "toggle notes / task board",
               ("quicknotes", "tasks", "todo"), ("dashboard-kanban", "toggle"), ("notes", "toggle"), "cli notes"),
    ActionSpec("files", "desktop", "󰈙", "file manager", "open preferred file manager (yazi / dolphin / etc.)",
               ("filemanager", "fm", "e"), cli_hint="cli files [dir]", kind="special"),
    ActionSpec("wallpaper", "desktop", "󰄛", "roll wallpaper", "randomize wallpaper or open brain_shell picker",
               ("wall", "wp", "w"), cli_hint="cli wp [subcmd...]", kind="special"),
    ActionSpec("audio", "desktop", "󰕾", "audio output", "toggle output volume panel",
               ("volume", "a"), ("audioOut-toggle", "toggle"), ("volume", "toggle"), "cli audio"),
    ActionSpec("mixer", "desktop", "󰺢", "audio mixer", "toggle per-app audio mixer",
               ("audiomix",), ("audioMix-toggle", "toggle"), ("volume", "toggle"), "cli mixer", in_menu=False),
    ActionSpec("mic", "desktop", "󰍬", "audio input / mic", "toggle microphone panel",
               ("audioin",), ("audioIn-toggle", "toggle"), ("volume", "toggle"), "cli mic", in_menu=False),
    ActionSpec("media", "desktop", "󰝚", "media controls", "toggle media player popup",
               (), ("dashboard-home", "toggle"), ("media", "toggle"), "cli media"),
    ActionSpec("nowplaying", "desktop", "󰎈", "now playing", "toggle now playing overlay",
               (), ("dashboard-home", "toggle"), ("nowplaying", "toggle"), "cli nowplaying", in_menu=False),
    ActionSpec("wifi", "desktop", "󰤨", "network / wi-fi", "toggle network popup",
               ("network",), ("wifi-toggle", "toggle"), ("network", "toggle"), "cli wifi"),
    ActionSpec("bluetooth", "desktop", "󰂯", "bluetooth", "toggle bluetooth popup",
               ("bt",), ("bluetooth-toggle", "toggle"), ("bluetooth", "toggle"), "cli bt"),
    ActionSpec("vpn", "desktop", "󰖂", "vpn toggle", "toggle vpn popup / state",
               (), ("vpn-toggle", "toggle"), ("network", "vpn"), "cli vpn", in_menu=False),
    ActionSpec("hotspot", "desktop", "󱜠", "hotspot", "toggle wireless hotspot",
               (), ("hotspot-toggle", "toggle"), ("network", "hotspot"), "cli hotspot", in_menu=False),
    ActionSpec("caffeine", "desktop", "󰅶", "caffeine / idle inhibit", "toggle sleep inhibitor",
               ("idle",), ("focus-toggle", "toggle"), ("caffeine", "toggle"), "cli caffeine"),
    ActionSpec("battery", "desktop", "󰁹", "battery", "toggle battery details popup",
               (), ("dashboard-home", "toggle"), ("battery", "toggle"), "cli battery", in_menu=False),
    ActionSpec("clock", "desktop", "󰥔", "clock", "toggle clock widget",
               (), ("dashboard-home", "toggle"), ("clock", "toggle"), "cli clock", in_menu=False),
    ActionSpec("calendar", "desktop", "󰃭", "calendar", "toggle calendar popup",
               (), ("dashboard-home", "toggle"), ("calendar", "toggle"), "cli calendar", in_menu=False),
    ActionSpec("layout", "desktop", "󰕰", "layout switcher", "toggle hyprland / bar layout switcher",
               ("layoutswitcher",), ("layout-toggle", "toggle"), ("layout", "toggle"), "cli layout"),
    ActionSpec("studio", "desktop", "󰏗", "bar studio", "open bar customization studio",
               ("barstudio",), ("studio", "toggle"), ("studio", "toggle"), "cli studio [layout|style|widgets|motion]"),
    ActionSpec("sandbox", "desktop", "󰔟", "motion sandbox", "open bar studio motion lab",
               ("motion",), ("sandbox", "toggle"), ("sandbox", "toggle"), "cli motion"),
    ActionSpec("config", "desktop", "󰒓", "shell settings", "open shell config panel",
               ("settings",), ("dashboard-config", "toggle"), ("quicksettings", "toggle"), "cli settings", in_menu=False),
    ActionSpec("keybinds", "desktop", "󰌌", "keybindings cheatsheet", "view desktop shortcut overlay",
               ("keys", "shortcuts"), ("keybinds", "toggle"), ("keybinds", "toggle"), "cli keybinds"),
    ActionSpec("welcome", "desktop", "󰋽", "welcome / onboarding", "open welcome wizard",
               ("intro", "onboarding"), ("welcome", "toggle"), ("welcome", "toggle"), "cli welcome", in_menu=False),

    ActionSpec("capture", "capture", "󰹑", "screen capture studio", "open unified screenshot & recording panel",
               ("screencapture",), ("capture", "toggle"), ("capture", "toggle"), "cli capture"),
    ActionSpec("screenshot", "capture", "󰄀", "screenshot studio", "open screenshot tool (region/window/full/annotate)",
               ("ss",), ("screenshot-toggle", "toggle"), ("screenshot", "open"), "cli ss [region|window|full|delay|pin]"),
    ActionSpec("record", "capture", "󰻃", "screen recording", "toggle or control screen recorder",
               ("rec",), cli_hint="cli record [screen|region|window|stop]", kind="special"),
    ActionSpec("stats", "system", "󰄪", "system monitor (btop)", "open stats dashboard or btop",
               ("system", "btop"), cli_hint="cli stats | btop", kind="special"),
    ActionSpec("lock", "system", "󰌾", "lock session", "lock desktop session immediately",
               (), ("lock-session", "toggle"), ("lock", "lock"), "cli lock"),
    ActionSpec("powermenu", "system", "󰐥", "power menu", "open shutdown / reboot / suspend menu",
               ("power",), ("PowerMenu-toggle", "toggle"), ("powermenu", "toggle"), "cli power"),
]

ACTION_BY_KEY: Dict[str, ActionSpec] = {}
for _a in ACTIONS:
    ACTION_BY_KEY[_a.id] = _a
    for _al in _a.aliases:
        ACTION_BY_KEY[_al] = _a


def _dispatch_gnome_action(act: str, args: Sequence[str]) -> Optional[Tuple[bool, str]]:
    if act in ("lock",):
        if shutil.which("loginctl"):
            r = subprocess.run(["loginctl", "lock-session"], capture_output=True, text=True)
            if r.returncode == 0:
                return True, "locked gnome session"
        ok, _, err = _gdbus_call("org.gnome.ScreenSaver", "/org/gnome/ScreenSaver", "org.gnome.ScreenSaver.Lock")
        return ok, "locked gnome session" if ok else (err or "lock failed")

    if act in ("dnd", "focus"):
        sub = args[0].lower() if args else "toggle"
        cur_banners = _gsettings_get("org.gnome.desktop.notifications", "show-banners")
        cur_dnd = cur_banners == "false"
        if sub == "status":
            return True, f"dnd is {'active' if cur_dnd else 'inactive'}"
        if sub in ("on", "enable", "1"):
            next_dnd = True
        elif sub in ("off", "disable", "0"):
            next_dnd = False
        else:
            next_dnd = not cur_dnd
        ok = _gsettings_set("org.gnome.desktop.notifications", "show-banners", "false" if next_dnd else "true")
        _sync_dnd_conf(next_dnd)
        return ok, f"gnome dnd -> {'on' if next_dnd else 'off'}" if ok else "failed to toggle gnome notifications"

    if act in ("launcher", "d"):
        ok, out, _ = _gdbus_call(
            "org.gnome.Shell",
            "/org/gnome/Shell",
            "org.freedesktop.DBus.Properties.Get",
            "org.gnome.Shell",
            "OverviewActive",
        )
        cur_open = "true" in out.lower() if ok else False
        nxt = "false" if cur_open else "true"
        ok2, _, err = _gdbus_call(
            "org.gnome.Shell",
            "/org/gnome/Shell",
            "org.freedesktop.DBus.Properties.Set",
            "org.gnome.Shell",
            "OverviewActive",
            f"<boolean {nxt}>",
        )
        return ok2, f"gnome overview -> {'closed' if cur_open else 'open'}" if ok2 else (err or "failed to toggle overview")

    if act in ("screenshot", "ss", "capture", "screencapture"):
        sub = args[0].lower() if args else "interactive"
        if sub == "full":
            shot_dir = HOME / "Pictures" / "Screenshots"
            shot_dir.mkdir(parents=True, exist_ok=True)
            out_path = str(shot_dir / f"Screenshot_{time.strftime('%Y%m%d_%H%M%S')}.png")
            ok, out, err = _gdbus_call(
                "org.gnome.Shell.Screenshot",
                "/org/gnome/Shell/Screenshot",
                "org.gnome.Shell.Screenshot.Screenshot",
                "true",
                "true",
                out_path,
                timeout=8.0,
            )
            return ok, f"saved screenshot -> {out_path}" if ok else (err or "gnome shell denied screenshot dbus call")
        ok, _, err = _gdbus_call(
            "org.gnome.Shell.Screenshot",
            "/org/gnome/Shell/Screenshot",
            "org.gnome.Shell.Screenshot.InteractiveScreenshot",
            timeout=15.0,
        )
        if not ok:
            return False, err or "gnome shell restricts programmatic interactive screenshot; press print key"
        return True, "opened gnome interactive screenshot"

    if act in ("powermenu", "power"):
        sub = args[0].lower() if args else "poweroff"
        if sub == "logout":
            return launch_detached(["gnome-session-quit", "--logout"])
        if sub == "suspend":
            r = subprocess.run(["systemctl", "suspend"], capture_output=True, text=True)
            return r.returncode == 0, "suspending..." if r.returncode == 0 else r.stderr.strip()
        if sub in ("reboot", "restart"):
            return launch_detached(["gnome-session-quit", "--reboot"])
        return launch_detached(["gnome-session-quit", "--power-off"])

    if act in ("config", "settings"):
        return launch_detached(["gnome-control-center"])
    if act in ("audio", "volume", "a", "mixer", "audiomix", "mic", "audioin"):
        return launch_detached(["gnome-control-center", "sound"])
    if act in ("wifi", "network"):
        return launch_detached(["gnome-control-center", "wifi"])
    if act in ("bluetooth", "bt"):
        return launch_detached(["gnome-control-center", "bluetooth"])

    if act in ("reload", "restart", "r"):
        return _reload_gnome_theme()

    if act in ("caffeine", "idle"):
        sess_script = _find_helper_script("session.py")
        if not sess_script:
            return False, "session.py not found"
        r = subprocess.run([sys.executable, str(sess_script), "caffeine"], capture_output=True, text=True)
        return r.returncode == 0, "toggled gnome idle timeout" if r.returncode == 0 else (r.stderr.strip() or "caffeine toggle failed")

    if act in ("clipboard", "clip", "v"):
        clip_script = _find_helper_script("clipboard.py")
        if not clip_script:
            return False, "clipboard.py not found"
        if args:
            r = subprocess.run([sys.executable, str(clip_script), *args])
            return r.returncode == 0, "" if r.returncode == 0 else f"clipboard.py exited {r.returncode}"
        if sys.stdin.isatty() and sys.stdout.isatty():
            r = subprocess.run([sys.executable, str(clip_script)])
            return r.returncode == 0, ""
        return launch_in_terminal([sys.executable, str(clip_script)])

    if act in ("record", "rec", "notifs", "notifications", "n",
               "notes", "quicknotes", "tasks", "todo", "media", "nowplaying", "vpn", "hotspot",
               "battery", "clock", "calendar", "layout", "layoutswitcher",
               "studio", "barstudio", "sandbox", "motion", "keybinds", "keys", "shortcuts",
               "welcome", "intro", "onboarding", "dashboard", "dash", "quicksettings", "home"):
        return False, f"'{act}' is a hyprland/quickshell widget (not active inside gnome)"

    return None


def dispatch_action(
    action_name: str,
    args: Optional[Sequence[str]] = None,
    interactive_passthrough: bool = True,
) -> Tuple[bool, str]:
    args = list(args or [])
    act = action_name.lower()

    if act in ("files", "filemanager", "fm", "e"):
        return open_file_manager(args[0] if args else None)

    if act in ("wallpaper", "wall", "wp", "w"):
        return trigger_wallpaper(args, interactive_passthrough=interactive_passthrough)

    if act in ("pick", "eyedropper", "colorpicker"):
        pick_script = _find_helper_script("colorpicker.py")
        if not pick_script:
            return False, "colorpicker.py not found"
        if interactive_passthrough and sys.stdout.isatty():
            r = subprocess.run([sys.executable, str(pick_script), "--copy"])
            return r.returncode == 0, "" if r.returncode == 0 else "color pick cancelled"
        r = subprocess.run([sys.executable, str(pick_script), "--copy"], capture_output=True, text=True)
        hx = r.stdout.strip()
        return (r.returncode == 0 and bool(hx)), (f"picked {hx}" if hx else "color pick cancelled")

    if act in ("stats", "system", "btop"):
        current = get_current_shell()
        brain_dir = get_brain_shell_dir()
        is_bs = (not in_gnome_session()) and current == "brain_shell" and brain_dir.is_dir()
        if is_bs and act != "btop":
            ok, _, err = send_ipc("dashboard-stats", "toggle", profile_dir=str(brain_dir))
            return ok, "toggled brain_shell stats" if ok else (err or "ipc failed")
        if not shutil.which("btop"):
            return False, "btop not found on path"
        ok, err = launch_in_terminal(["btop"])
        return ok, "launched btop" if ok else err

    if in_gnome_session():
        gnome_res = _dispatch_gnome_action(act, args)
        if gnome_res is not None:
            return gnome_res
        return False, f"unknown or hyprland-only action '{act}' inside gnome session"

    current = get_current_shell()
    brain_dir = get_brain_shell_dir()
    is_bs = current == "brain_shell" and brain_dir.is_dir()
    b_profile = str(brain_dir) if is_bs else None

    if act in ("record", "rec"):
        return handle_record(args)

    if act in ("screenshot", "ss") and not is_bs:
        sub = args[0].lower() if args else "open"
        if sub in ("open", "close", "toggle", "region", "window", "full", "annotate", "picker"):
            ok, _, err = send_ipc("screenshot", sub)
        elif sub in ("pin", "pinlast"):
            ok, _, err = send_ipc("screenshot", "pinLast")
        elif sub in ("clearpins", "unpin"):
            ok, _, err = send_ipc("screenshot", "clearPins")
        elif sub in ("last", "editlast", "edit"):
            if len(args) > 1:
                ok, _, err = send_ipc("screenshot", "editFile", extra_args=[args[1]])
            else:
                ok, _, err = send_ipc("screenshot", "editLast")
        elif sub in ("clip", "clipboard"):
            ok, _, err = send_ipc("screenshot", "editClipboard")
        elif sub == "delay":
            sec = args[1] if len(args) > 1 else "3"
            ok, _, err = send_ipc("screenshot", "delay", extra_args=[sec])
        else:
            ok, _, err = send_ipc("screenshot", "toggle")
        return ok, f"screenshot -> {sub}" if ok else (err or "ipc failed")

    if act in ("studio", "barstudio") and not is_bs:
        sub = args[0].lower() if args else "toggle"
        if sub in ("layout", "style", "widgets", "motion"):
            ok, _, err = send_ipc("studio", "tab", extra_args=[sub])
        elif sub in ("open", "close", "toggle"):
            ok, _, err = send_ipc("studio", sub)
        else:
            ok, _, err = send_ipc("studio", "toggle", extra_args=args)
        return ok, f"studio -> {sub}" if ok else (err or "ipc failed")

    if act in ("sandbox", "motion") and not is_bs:
        sub = args[0].lower() if args else "toggle"
        meth = sub if sub in ("open", "close", "toggle") else "toggle"
        ok, _, err = send_ipc("sandbox", meth)
        return ok, f"sandbox -> {meth}" if ok else (err or "ipc failed")

    if act == "idle" and not is_bs:
        ok, _, err = send_ipc("idle", "toggle", extra_args=args)
        return ok, "toggled idle" if ok else (err or "ipc failed")

    spec = ACTION_BY_KEY.get(act)
    if spec and spec.bs_ipc and spec.qs_ipc:
        target, meth = spec.bs_ipc if is_bs else spec.qs_ipc
        ok, _, err = send_ipc(target, meth, profile_dir=b_profile, extra_args=args)
        return ok, f"{spec.id} -> {target}.{meth}" if ok else (err or "ipc failed")

    method = args[0] if args else "toggle"
    extra = args[1:] if len(args) > 1 else []
    ok, _, err = send_ipc(act, method, profile_dir=b_profile, extra_args=extra)
    if ok:
        return True, f"ipc -> {act}.{method}"

    all_keys = sorted(set(ACTION_BY_KEY.keys()) | {"qs", "bs", "ui", "menu", "ipc", "act", "clean", "help"})
    close = difflib.get_close_matches(act, all_keys, n=3, cutoff=0.6)
    hint = f" (did you mean: {', '.join(close)}?)" if close else ""
    return False, f"{err or f'ipc call failed for {act}.{method}'}{hint}"


# shared python-rendered views
def format_log_line(ln: str) -> str:
    if " ERROR:" in ln or " Fatal:" in ln:
        return f"{S.red}{ln}{S.reset}"
    if " WARN:" in ln:
        return f"{S.yellow}{ln}{S.reset}"
    if "Configuration Loaded" in ln:
        return f"{S.green}{ln}{S.reset}"
    return ln


def build_status_lines(st: dict) -> List[str]:
    if st.get("gnome"):
        shell_theme = st.get("gnome_theme") or "default"
        accent = st.get("gnome_accent") or "default"
        ptyxis_pal = st.get("ptyxis_palette") or "unset"
        lines = [
            f" {S.dim}├─{S.reset} {S.bold}{'desktop:':<16}{S.reset} {S.green}{S.bold}gnome{S.reset} {S.dim}(wayland){S.reset}",
            f" {S.dim}├─{S.reset} {S.bold}{'gnome shell:':<16}{S.reset} user-theme={S.cyan}{shell_theme}{S.reset} {S.dim}·{S.reset} accent={S.magenta}{accent}{S.reset}",
            f" {S.dim}├─{S.reset} {S.bold}{'ptyxis palette:':<16}{S.reset} {S.green if ptyxis_pal == 'matugen' else S.yellow}{ptyxis_pal}{S.reset}",
            f" {S.dim}├─{S.reset} {S.bold}{'theme:':<16}{S.reset} {S.blue}{st['mode']}{S.reset} {S.dim}·{S.reset} {S.magenta}{st['scheme']}{S.reset}",
            f" {S.dim}└─{S.reset} {S.bold}{'wallpaper:':<16}{S.reset} {st['wallpaper']}",
        ]
        return lines

    pids = st["pids"]
    if pids:
        pid_str = f"{S.green}{', '.join(map(str, pids))}{S.reset}"
        ram = f" · {st['ram_mb']} mb" if st["ram_mb"] is not None else ""
        up = f" · up {st['uptime']}" if st["uptime"] != "-" else ""
        health = f"{S.green}loaded{S.reset}" if st["loaded"] else f"{S.yellow}starting/unverified{S.reset}"
        if st["log_errors"]:
            health += f" · {S.red}{st['log_errors']} err{S.reset}"
        runtime_val = f"{pid_str}{ram}{up} ({health})"
    else:
        runtime_val = f"{S.red}inactive / dead{S.reset}"

    shell_val = f"{S.yellow}{S.bold}{st['configured_shell']}{S.reset}"
    if st["mismatch"]:
        shell_val += f" {S.red}(running: {st['running_shell']}){S.reset}"

    lines = [
        f" {S.dim}├─{S.reset} {S.bold}{'active shell:':<16}{S.reset} {shell_val}",
        f" {S.dim}├─{S.reset} {S.bold}{'runtime:':<16}{S.reset} {runtime_val}",
        f" {S.dim}├─{S.reset} {S.bold}{'theme:':<16}{S.reset} {S.blue}{st['mode']}{S.reset} {S.dim}·{S.reset} {S.magenta}{st['scheme']}{S.reset}",
        f" {S.dim}├─{S.reset} {S.bold}{'wallpaper:':<16}{S.reset} {st['wallpaper']}",
        f" {S.dim}├─{S.reset} {S.bold}{'session wrap:':<16}{S.reset} {'uwsm active' if st['uwsm_active'] else 'direct'}",
        f" {S.dim}├─{S.reset} {S.bold}{'brain path:':<16}{S.reset} {S.dim}{st['brain_dir']}{S.reset}"
        + ("" if st["brain_exists"] else f" {S.yellow}(missing){S.reset}"),
        f" {S.dim}└─{S.reset} {S.bold}{'quickshell:':<16}{S.reset} {S.dim}{st['qs_dir']}{S.reset}",
    ]
    if st["no_new_privs"]:
        lines.append(f" {S.yellow}󰀦 nonewprivs=1 detected: reloads guarded to protect lockscreen auth.{S.reset}")
    if st["stale_runtime_dirs"]:
        lines.append(f" {S.yellow}󰀦 {st['stale_runtime_dirs']} stale runtime pid dir(s) — run 'cli clean'.{S.reset}")
    return lines


def build_theme_lines(th: dict, compact: bool = False) -> List[str]:
    wp_disp = f"{S.red}{th['wallpaper']}{S.reset}" if th["wallpaper_broken"] else th["wallpaper"]
    lines = [
        f" {S.dim}├─{S.reset} {S.bold}{'mode / scheme:':<15}{S.reset} {S.blue}{th['mode']}{S.reset} {S.dim}·{S.reset} {S.magenta}{th['scheme']}{S.reset}",
        f" {S.dim}├─{S.reset} {S.bold}{'wallpaper:':<15}{S.reset} {wp_disp}",
    ]
    if th.get("ptyxis_palette") or th.get("gnome_theme"):
        gt = th.get("gnome_theme") or "default"
        ga = th.get("gnome_accent") or "default"
        pp = th.get("ptyxis_palette") or "unset"
        lines.append(
            f" {S.dim}├─{S.reset} {S.bold}{'gnome / ptyxis:':<15}{S.reset} "
            f"shell={S.cyan}{gt}{S.reset} · accent={S.magenta}{ga}{S.reset} · ptyxis={S.green if pp == 'matugen' else S.yellow}{pp}{S.reset}"
        )

    tokens = th["tokens"]
    if tokens:
        pairs = [
            ("primary", tokens.get("MATUGEN_PRIMARY", "")),
            ("secondary", tokens.get("MATUGEN_SECONDARY", "")),
            ("tertiary", tokens.get("MATUGEN_TERTIARY", "")),
            ("surface", tokens.get("MATUGEN_SURFACE", "")),
            ("on_surface", tokens.get("MATUGEN_ON_SURFACE", "")),
            ("outline", tokens.get("MATUGEN_OUTLINE", "")),
            ("error", tokens.get("MATUGEN_ERROR", "")),
        ]
        swatches = []
        for lbl, hx in pairs:
            if len(hx) == 7 and hx.startswith("#"):
                swatch = f"{S.bg_hex(hx)}  {S.reset} " if S.enabled else ""
                swatches.append(f"{swatch}{lbl} {S.dim}{hx}{S.reset}")
        per_row = 2 if compact else 4
        for idx in range(0, len(swatches), per_row):
            chunk = "  ".join(swatches[idx:idx + per_row])
            if idx == 0:
                lines.append(f" {S.dim}├─{S.reset} {S.bold}{'tokens:':<15}{S.reset} {chunk}")
            else:
                lines.append(f" {S.dim}│ {S.reset} {'':<15} {chunk}")
    elif th["kitty_ansi"]:
        fg = th["kitty_ansi"].get("foreground", "")
        bg = th["kitty_ansi"].get("background", "")
        if fg or bg:
            sw_fg = f"{S.bg_hex(fg)}  {S.reset} " if (S.enabled and fg) else ""
            sw_bg = f"{S.bg_hex(bg)}  {S.reset} " if (S.enabled and bg) else ""
            lines.append(
                f" {S.dim}├─{S.reset} {S.bold}{'kitty fg/bg:':<15}{S.reset} "
                f"{sw_fg}fg={S.dim}{fg}{S.reset}  {sw_bg}bg={S.dim}{bg}{S.reset}"
            )

    if S.enabled:
        block = "  " if compact else "   "
        row0 = "".join(f"{S.bg_ansi(i)}{block}{S.reset}" for i in range(8))
        row1 = "".join(f"{S.bg_ansi(i)}{block}{S.reset}" for i in range(8, 16))
        lines.append(f" {S.dim}├─{S.reset} {S.bold}{'ansi 0..7:':<15}{S.reset} {row0}")
        lines.append(f" {S.dim}└─{S.reset} {S.bold}{'ansi 8..15:':<15}{S.reset} {row1}")
    else:
        lines.append(f" {S.dim}└─{S.reset} {'ansi palette:':<15} (color output disabled)")
    return lines


def build_doctor_lines(checks: Sequence[CheckResult]) -> Tuple[List[str], int, int, int]:
    ok_cnt = warn_cnt = fail_cnt = 0
    lines: List[str] = []
    for c in checks:
        if c.status == "ok":
            ok_cnt += 1
            badge = f"{S.green}󰄲 ok  {S.reset}"
        elif c.status == "warn":
            warn_cnt += 1
            badge = f"{S.yellow}󰀦 warn{S.reset}"
        else:
            fail_cnt += 1
            badge = f"{S.red}󰅚 fail{S.reset}"
        lines.append(f" {badge}  {S.bold}{c.area:<14}{S.reset} {c.detail}")
    return lines, ok_cnt, warn_cnt, fail_cnt


# CLI commands
def show_status(as_json: bool = False):
    st = collect_status()
    if as_json:
        print(json.dumps(st, indent=2))
        return
    cols, _ = term_size()
    w = min(cols, 92)
    title = f"{S.cyan}{S.bold}󰄛 desktop shell status{S.reset}"
    print("\n".join(render_box(build_status_lines(st), width=w, title=title, border_color=S.cyan)))


def _active_theme_preview(th: dict) -> Optional[Path]:
    static_img = HOME / ".curr_wall_static.jpg"
    if static_img.exists() and static_img.is_file():
        return static_img
    cur_link = HOME / ".curr_wall"
    cand = cur_link.resolve() if cur_link.exists() else Path(str(th.get("wallpaper", "")))
    if cand.exists() and cand.is_file() and cand.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp", ".gif", ".avif", ".bmp"):
        return cand
    return None


def show_theme(as_json: bool = False, show_img: bool = True):
    th = collect_theme()
    if as_json:
        print(json.dumps(th, indent=2))
        return
    cols, _ = term_size()
    w = min(cols, 96)
    title = f"{S.magenta}{S.bold}󰏘 active palette & matugen state{S.reset}"
    print("\n".join(render_box(build_theme_lines(th, compact=w < 74), width=w, title=title, border_color=S.magenta)))
    if show_img and _ui_in_kitty():
        p_img = _active_theme_preview(th)
        if p_img:
            print("")
            _ui_render_kitty_image(p_img, max_w=420, max_h=210, align="left")


def run_doctor(fix: bool = False, as_json: bool = False):
    if fix:
        cleaned = clean_stale_runtime_dirs()
        if not as_json and cleaned:
            print(f"{S.green}󰄲 cleaned {cleaned} stale runtime pid dir(s).{S.reset}")
        if in_gnome_session():
            ok, msg = _reload_gnome_theme()
            if not as_json:
                col = S.green if ok else S.yellow
                print(f"{col}󰄲 {msg}{S.reset}")

    checks = collect_doctor()
    if as_json:
        payload = {
            "checks": [dataclasses.asdict(c) for c in checks],
            "summary": {
                "ok": sum(1 for c in checks if c.status == "ok"),
                "warn": sum(1 for c in checks if c.status == "warn"),
                "fail": sum(1 for c in checks if c.status == "fail"),
            },
        }
        print(json.dumps(payload, indent=2))
        if payload["summary"]["fail"] > 0:
            sys.exit(1)
        return

    lines, ok_cnt, warn_cnt, fail_cnt = build_doctor_lines(checks)
    cols, _ = term_size()
    w = min(cols, 100)
    title = f"{S.cyan}{S.bold}󰚰 cli doctor · desktop & terminal health{S.reset}"
    footer = f"{S.green}{ok_cnt} ok{S.reset} {S.dim}·{S.reset} {S.yellow}{warn_cnt} warn{S.reset} {S.dim}·{S.reset} {S.red}{fail_cnt} fail{S.reset}"
    border = S.red if fail_cnt else (S.yellow if warn_cnt else S.green)
    print("\n".join(render_box(lines, width=w, title=title, footer=footer, border_color=border)))
    if fail_cnt > 0:
        sys.exit(1)


def follow_log_colored(log_path: Path, errors_only: bool = False):
    print(f"{S.dim}tailing {log_path} (ctrl+c to stop)...{S.reset}")
    try:
        with log_path.open("r", encoding="utf-8", errors="ignore") as fh:
            for ln in tail_lines(log_path, 25):
                if errors_only and not (" ERROR:" in ln or " Fatal:" in ln or " WARN:" in ln):
                    continue
                print(format_log_line(ln))
            fh.seek(0, os.SEEK_END)
            while True:
                line = fh.readline()
                if not line:
                    time.sleep(0.12)
                    continue
                s = line.rstrip("\r\n")
                if errors_only and not (" ERROR:" in s or " Fatal:" in s or " WARN:" in s):
                    continue
                print(format_log_line(s), flush=True)
    except KeyboardInterrupt:
        pass


def show_logs(args: Sequence[str]):
    pids = get_running_pids()
    log_path = latest_runtime_log(pids if pids else None)
    if not log_path:
        print(f"{S.yellow}󰀦 no runtime quickshell log found.{S.reset}", file=sys.stderr)
        sys.exit(1)

    errors_only = any(a in ("-e", "--errors", "errors") for a in args)
    if any(a in ("-f", "--follow", "follow") for a in args):
        follow_log_colored(log_path, errors_only=errors_only)
        return

    n = 40
    for a in args:
        if a.isdigit():
            n = max(1, int(a))

    raw_lines = tail_lines(log_path, n * 4 if errors_only else n)
    if errors_only:
        raw_lines = [ln for ln in raw_lines if " ERROR:" in ln or " Fatal:" in ln or " WARN:" in ln][-n:]

    cols, _ = term_size()
    w = min(cols, 110)
    fmt = [f" {format_log_line(ln)}" for ln in raw_lines] or [f" {S.dim}(no matching log entries){S.reset}"]
    tag = "errors/warns" if errors_only else f"last {len(raw_lines)} lines"
    title = f"{S.cyan}{S.bold}󰍉 quickshell log{S.reset} {S.dim}({log_path.parent.name} · {tag}){S.reset}"
    print("\n".join(render_box(fmt, width=w, title=title, border_color=S.cyan)))


def print_help():
    current = "gnome" if in_gnome_session() else get_current_shell()
    cols, _ = term_size()
    w = min(cols, 96)

    def row(cmd: str, desc: str) -> str:
        return f"  {S.cyan}{cmd:<34}{S.reset} {S.dim}{desc}{S.reset}"

    lines = [
        f" {S.bold}active session:{S.reset} {S.yellow}{current}{S.reset}   {S.dim}usage: cli [flags] [command] [args...]{S.reset}",
        f" {S.dim}global flags: --force  --json  --no-img  --no-color  --color{S.reset}",
        "",
        f" {S.bold}{S.magenta}interactive & diagnostics{S.reset}",
        row("cli | cli ui", "open pure-python tui control hub"),
        row("cli status [--json]", "active shell, pids, ram, uptime & theme"),
        row("cli version [--json]", "active desktop, shell runtime & theme summary"),
        row("cli doctor [--fix] [--json]", "full desktop, ipc, matugen & symlink health check"),
        row("cli theme [--json] [--no-img]", "wallpaper, matugen tokens & ansi 0..15 palette"),
        row("cli logs [n] [-f] [-e]", "inspect or colored-follow active runtime log"),
        row("cli clean", "remove stale dead quickshell runtime pid dirs"),
        "",
        f" {S.bold}{S.magenta}shell lifecycle{S.reset}",
        row("cli shell [qs|bs|toggle|restart]", "switch or toggle active shell"),
        row("cli qs | cli bs", "jump directly to quickshell or brain_shell"),
        row("cli reload | restart | r", "gracefully restart active shell & verify load"),
        row("cli kill | stop | k", "terminate running shell daemons cleanly"),
        "",
        f" {S.bold}{S.magenta}desktop actions (native ipc){S.reset}",
        row("cli launcher | d", "toggle app launcher"),
        row("cli dashboard | quicksettings", "toggle dashboard / quicksettings"),
        row("cli notifs | n | dnd | focus", "notification center or do-not-disturb"),
        row("cli clip | v | notes", "clipboard history or quick notes / kanban"),
        row("cli files | fm | e [dir]", "open preferred file manager (yazi / dolphin)"),
        row("cli wp [subcmd...] | wall", "roll wallpaper or forward args to wallpaper.py"),
        row("cli audio | mixer | mic | media", "volume, mixer, mic, or media popups"),
        row("cli wifi | bt | vpn | hotspot", "network, bluetooth, vpn, or hotspot toggles"),
        row("cli capture | record [sub]", "screen capture panel or recording controls"),
        row("cli ss | cli pick", "screenshot studio or cross-desktop eyedropper"),
        row("cli studio [tab] | motion", "bar studio tabs or motion sandbox"),
        row("cli lock | power | caffeine", "lock session, power menu, or idle inhibit"),
        row("cli keybinds | welcome | stats", "shortcuts overlay, welcome wizard, or btop"),
        row("cli act <name> [args] | ipc ...", "dispatch custom shell action or raw qs ipc"),
    ]
    title = f"{S.cyan}{S.bold}󰄛 cli · keyboard-driven desktop controller{S.reset}"
    print("\n".join(render_box(lines, width=w, title=title, border_color=S.cyan)))


# pure-python interactive tui (zero third-party deps, double-buffered, resize-safe)
class ControlHubTUI:
    CATEGORIES = ("all", "shell", "desktop", "capture", "system")

    def __init__(self, force: bool = False):
        self.force = force
        self.cat_idx = 0
        self.selected = 0
        self.scroll = 0
        self.query = ""
        self.searching = False

        self.modal_kind: Optional[str] = None
        self.modal_scroll = 0
        self.modal_lines: List[str] = []
        self.modal_title = ""

        self.toast_msg = ""
        self.toast_ok = True
        self.toast_until = 0.0

        self.status_data: dict = {}
        self.theme_data: dict = {}
        self.doctor_data: List[CheckResult] = []
        self.log_preview: List[str] = []
        self.last_refresh = 0.0

        self.running = True
        self.menu_actions: List[ActionSpec] = [a for a in ACTIONS if a.in_menu]

        self._orig_termios = None
        self._wakeup_r: Optional[int] = None
        self._wakeup_w: Optional[int] = None
        self._prev_winch = None

    def set_toast(self, msg: str, ok: bool = True, duration: float = 4.5):
        self.toast_msg = msg
        self.toast_ok = ok
        self.toast_until = time.time() + duration

    def refresh_telemetry(self, include_doctor: bool = False):
        self.status_data = collect_status()
        self.theme_data = collect_theme()
        lp = Path(self.status_data["log_path"]) if self.status_data.get("log_path") else None
        self.log_preview = tail_lines(lp, 40) if lp else []
        if include_doctor or not self.doctor_data:
            self.doctor_data = collect_doctor()
        self.last_refresh = time.time()
        if self.modal_kind:
            self._rebuild_modal()

    def filtered_actions(self) -> List[ActionSpec]:
        cat = self.CATEGORIES[self.cat_idx]
        q = self.query.strip().lower()
        out: List[Tuple[int, ActionSpec]] = []
        for a in self.menu_actions:
            if cat != "all" and a.category != cat:
                continue
            if not q:
                out.append((0, a))
                continue
            hay = f"{a.id} {' '.join(a.aliases)} {a.label} {a.desc} {a.category}".lower()
            if a.id.startswith(q) or a.label.lower().startswith(q):
                out.append((0, a))
            elif q in hay:
                out.append((1, a))
            else:
                it = iter(hay)
                if all(ch in it for ch in q):
                    out.append((2, a))
        out.sort(key=lambda pair: pair[0])
        return [a for _, a in out]

    def current_action(self) -> Optional[ActionSpec]:
        items = self.filtered_actions()
        if not items:
            self.selected = 0
            return None
        self.selected = max(0, min(self.selected, len(items) - 1))
        return items[self.selected]

    def _enter_screen(self):
        fd = sys.stdin.fileno()
        self._orig_termios = termios.tcgetattr(fd)
        tty.setraw(fd)
        sys.stdout.write("\033[?1049h\033[?25l\033[2J\033[H")
        sys.stdout.flush()

    def _leave_screen(self):
        sys.stdout.write("\033[?25h\033[?1049l")
        sys.stdout.flush()
        if self._orig_termios is not None:
            termios.tcsetattr(sys.stdin.fileno(), termios.TCSADRAIN, self._orig_termios)
            self._orig_termios = None

    def _run_foreground(self, fn: Callable[[], None]):
        self._leave_screen()
        try:
            fn()
        finally:
            self._enter_screen()
            self.refresh_telemetry(include_doctor=True)

    def _setup_signals(self):
        r, w = os.pipe()
        for fd in (r, w):
            fl = fcntl.fcntl(fd, fcntl.F_GETFL)
            fcntl.fcntl(fd, fcntl.F_SETFL, fl | os.O_NONBLOCK)
        self._wakeup_r, self._wakeup_w = r, w

        def _on_winch(_sig, _frame):
            try:
                if self._wakeup_w is not None:
                    os.write(self._wakeup_w, b"R")
            except OSError:
                pass

        self._prev_winch = signal.signal(signal.SIGWINCH, _on_winch)

    def _teardown_signals(self):
        if self._prev_winch is not None:
            signal.signal(signal.SIGWINCH, self._prev_winch)
            self._prev_winch = None
        for fd in (self._wakeup_r, self._wakeup_w):
            if fd is not None:
                try:
                    os.close(fd)
                except OSError:
                    pass
        self._wakeup_r = self._wakeup_w = None

    def _read_key(self, timeout: float = 0.25) -> Optional[str]:
        stdin_fd = sys.stdin.fileno()
        watch = [stdin_fd]
        if self._wakeup_r is not None:
            watch.append(self._wakeup_r)

        try:
            ready, _, _ = select.select(watch, [], [], timeout)
        except InterruptedError:
            return "RESIZE"

        if not ready:
            return None

        if self._wakeup_r is not None and self._wakeup_r in ready:
            try:
                os.read(self._wakeup_r, 64)
            except OSError:
                pass
            return "RESIZE"

        if stdin_fd not in ready:
            return None

        b = os.read(stdin_fd, 1)
        if not b:
            return "EOF"
        if b == b"\x03":
            return "CTRL_C"
        if b == b"\x15":
            return "CTRL_U"
        if b == b"\x0e":
            return "DOWN"
        if b == b"\x10":
            return "UP"
        if b in (b"\r", b"\n"):
            return "ENTER"
        if b == b"\t":
            return "TAB"
        if b in (b"\x7f", b"\x08"):
            return "BACKSPACE"
        if b == b"\x1b":
            seq = b""
            while select.select([stdin_fd], [], [], 0.025)[0]:
                nxt = os.read(stdin_fd, 1)
                if not nxt:
                    break
                seq += nxt
                if len(seq) >= 6 or (len(seq) >= 2 and 0x40 <= seq[-1] <= 0x7E):
                    break
            if not seq:
                return "ESC"
            mapping = {
                b"[A": "UP", b"OA": "UP",
                b"[B": "DOWN", b"OB": "DOWN",
                b"[C": "RIGHT", b"OC": "RIGHT",
                b"[D": "LEFT", b"OD": "LEFT",
                b"[Z": "SHIFT_TAB",
                b"[5~": "PGUP",
                b"[6~": "PGDN",
                b"[H": "HOME", b"[1~": "HOME", b"OH": "HOME",
                b"[F": "END", b"[4~": "END", b"OF": "END",
            }
            return mapping.get(seq, "ESC")

        first = b[0]
        if first >= 0xC0:
            extra = 1 if first < 0xE0 else (2 if first < 0xF0 else 3)
            for _ in range(extra):
                if select.select([stdin_fd], [], [], 0.02)[0]:
                    b += os.read(stdin_fd, 1)
        try:
            ch = b.decode("utf-8", errors="ignore")
        except Exception:
            return None
        return ch if ch else None

    def _open_modal(self, kind: str):
        self.modal_kind = kind
        self.modal_scroll = 0
        if kind == "doctor":
            self.doctor_data = collect_doctor()
        else:
            self.refresh_telemetry(include_doctor=False)
        self._rebuild_modal()

    def _rebuild_modal(self):
        kind = self.modal_kind
        if kind == "status":
            self.modal_title = f"{S.cyan}{S.bold}󰋼 desktop shell status{S.reset}"
            self.modal_lines = build_status_lines(self.status_data)
        elif kind == "theme":
            self.modal_title = f"{S.magenta}{S.bold}󰏘 active palette & matugen state{S.reset}"
            cols, _ = term_size()
            self.modal_lines = build_theme_lines(self.theme_data, compact=cols < 80)
        elif kind == "doctor":
            lines, ok_c, warn_c, fail_c = build_doctor_lines(self.doctor_data)
            self.modal_title = (
                f"{S.cyan}{S.bold}󰚰 diagnostics{S.reset}  "
                f"{S.green}{ok_c} ok{S.reset} {S.dim}·{S.reset} "
                f"{S.yellow}{warn_c} warn{S.reset} {S.dim}·{S.reset} "
                f"{S.red}{fail_c} fail{S.reset}"
            )
            self.modal_lines = lines
        elif kind == "logs":
            lp = self.status_data.get("log_path")
            self.modal_title = f"{S.cyan}{S.bold}󰍉 runtime log{S.reset} {S.dim}({lp or 'none'}){S.reset}"
            if lp and Path(lp).exists():
                raw = tail_lines(Path(lp), 120)
                self.modal_lines = [f" {format_log_line(ln)}" for ln in raw] or [f" {S.dim}(log file is empty){S.reset}"]
            else:
                self.modal_lines = [f" {S.yellow}󰀦 no runtime quickshell log found.{S.reset}"]

    def _execute_action(self, spec: ActionSpec):
        if spec.kind == "modal":
            self._open_modal(spec.id)
            return

        if spec.id == "switch":
            cur = get_current_shell()
            other = "quickshell" if cur == "brain_shell" else "brain_shell"
            self.set_toast(f"switching {cur} -> {other}...", ok=True, duration=10.0)
            self.render()
            ok, msg = switch_shell(other, force=self.force, quiet=True)
            self.refresh_telemetry(include_doctor=True)
            self.set_toast(msg, ok=ok)
            return

        if spec.id == "reload":
            cur = get_current_shell()
            self.set_toast(f"reloading {cur}...", ok=True, duration=10.0)
            self.render()
            ok, msg = switch_shell("restart", force=self.force, quiet=True)
            self.refresh_telemetry(include_doctor=True)
            self.set_toast(msg, ok=ok)
            return

        if spec.id == "kill":
            if st_cur := self.status_data.get("gnome"):
                self.set_toast("nothing to kill (running gnome session)", ok=True)
                return
            self.set_toast("terminating shell instances...", ok=True, duration=10.0)
            self.render()
            killed = kill_running_shell(quiet=True)
            self.refresh_telemetry(include_doctor=True)
            self.set_toast(f"terminated {killed} process(es) & cleaned stale pid dirs", ok=True)
            return

        ok, msg = dispatch_action(spec.id, [], interactive_passthrough=False)
        self.set_toast(msg or f"dispatched {spec.id}", ok=ok)

    def _build_preview_lines(self, spec: Optional[ActionSpec], width: int, height: int) -> List[str]:
        st = self.status_data
        th = self.theme_data
        lines: List[str] = []

        if not spec:
            return [f" {S.dim}no matching actions for '{self.query}'{S.reset}"]

        cur = st.get("configured_shell", "quickshell")
        other = "quickshell" if cur == "brain_shell" else "brain_shell"

        lines.append(f" {S.cyan}{S.bold}{spec.icon}  {spec.label}{S.reset}")
        lines.append(f" {S.dim}{spec.desc}{S.reset}")
        lines.append("")

        if spec.cli_hint:
            lines.append(f" {S.bold}cli:{S.reset}      {S.green}{spec.cli_hint}{S.reset}")
        if spec.aliases:
            lines.append(f" {S.bold}aliases:{S.reset}  {S.dim}{', '.join(spec.aliases)}{S.reset}")

        is_bs = cur == "brain_shell" and st.get("brain_exists", False)
        if spec.bs_ipc and spec.qs_ipc:
            tgt, meth = spec.bs_ipc if is_bs else spec.qs_ipc
            prof = " -p Brain_Shell" if is_bs else ""
            lines.append(f" {S.bold}ipc:{S.reset}      {S.magenta}qs ipc{prof} call {tgt} {meth}{S.reset}")

        lines.append(f" {S.dim}{'─' * max(8, width - 2)}{S.reset}")

        if spec.id in ("switch", "reload", "kill", "status"):
            if spec.id == "switch":
                lines.append(f" {S.bold}transition:{S.reset} {S.yellow}{cur}{S.reset} -> {S.cyan}{S.bold}{other}{S.reset}")
                lines.append("")
            lines.extend(build_status_lines(st))
        elif spec.id == "theme":
            lines.extend(build_theme_lines(th, compact=True))
        elif spec.id == "doctor":
            ok_c = sum(1 for c in self.doctor_data if c.status == "ok")
            warn_c = sum(1 for c in self.doctor_data if c.status == "warn")
            fail_c = sum(1 for c in self.doctor_data if c.status == "fail")
            lines.append(
                f" {S.bold}health:{S.reset} {S.green}{ok_c} ok{S.reset} · "
                f"{S.yellow}{warn_c} warn{S.reset} · {S.red}{fail_c} fail{S.reset}"
            )
            issues = [c for c in self.doctor_data if c.status != "ok"]
            if issues:
                lines.append("")
                for c in issues[: max(1, height - len(lines) - 1)]:
                    col = S.red if c.status == "fail" else S.yellow
                    icon = "󰅚" if c.status == "fail" else "󰀦"
                    lines.append(f" {col}{icon} {c.area}:{S.reset} {c.detail}")
            else:
                lines.append(f" {S.green}󰄲 all desktop checks green.{S.reset}")
        elif spec.id == "logs":
            lp = st.get("log_path")
            lines.append(f" {S.bold}file:{S.reset} {S.dim}{lp or 'none'}{S.reset}")
            lines.append(
                f" {S.bold}errs:{S.reset} {S.red if st.get('log_errors') else S.green}{st.get('log_errors', 0)}{S.reset}  "
                f"{S.bold}warns:{S.reset} {S.yellow if st.get('log_warns') else S.dim}{st.get('log_warns', 0)}{S.reset}"
            )
            lines.append("")
            avail = max(1, height - len(lines))
            for ln in self.log_preview[-avail:]:
                lines.append(f" {format_log_line(ln)}")
        else:
            lines.append(f" {S.bold}active profile:{S.reset} {S.yellow}{cur}{S.reset}")
            if st.get("gnome"):
                lines.append(f" {S.bold}session:{S.reset}        {S.green}gnome wayland{S.reset} ({(st.get('gnome_theme') or 'default').lower()})")
                lines.append(f" {S.bold}ptyxis:{S.reset}         {st.get('ptyxis_palette') or 'unset'}")
            elif st.get("pids"):
                lines.append(f" {S.bold}daemon:{S.reset}         {S.green}live{S.reset} (pid {', '.join(map(str, st['pids']))})")
            else:
                lines.append(f" {S.bold}daemon:{S.reset}         {S.red}not running{S.reset} {S.dim}(ipc may fail){S.reset}")
            lines.append(f" {S.bold}theme:{S.reset}          {S.blue}{th.get('mode', '?')}{S.reset} · {S.magenta}{th.get('scheme', '?')}{S.reset}")
            lines.append("")
            lines.append(f" {S.dim}press enter to dispatch immediately.{S.reset}")

        return lines[:height]

    def build_frame(self, cols: int, rows: int) -> List[str]:
        st = self.status_data
        th = self.theme_data
        frame: List[str] = []

        # header bar
        cur = st.get("configured_shell", "quickshell")
        pids = st.get("pids", [])
        if st.get("gnome"):
            pill = f"{S.green}● gnome{S.reset}"
            gt = (st.get("gnome_theme") or "default").lower()
            pp = st.get("ptyxis_palette") or "unset"
            meta = f"theme:{gt} · ptyxis:{pp}"
        elif pids:
            pill = f"{S.green}● {cur}{S.reset}"
            meta = f"pid {pids[0]}"
            if st.get("ram_mb") is not None:
                meta += f" · {st['ram_mb']}mb"
            if st.get("uptime", "-") != "-":
                meta += f" · {st['uptime']}"
        else:
            pill = f"{S.red}○ {cur} (stopped){S.reset}"
            meta = "no daemon"

        err_badge = f"  {S.red}󰅚 {st['log_errors']} err{S.reset}" if st.get("log_errors") else ""
        left_hdr = f" {S.cyan}{S.bold}󰄛 cli{S.reset} {S.dim}control hub{S.reset}   {pill} {S.dim}({meta}){S.reset}{err_badge}"
        right_hdr = f"{S.blue}{th.get('mode', 'dark')}{S.reset} {S.dim}·{S.reset} {S.magenta}{th.get('scheme', '')}{S.reset} "
        gap = max(1, cols - 2 - vis_len(left_hdr) - vis_len(right_hdr))
        hdr_line = left_hdr + (" " * gap) + right_hdr if cols >= 66 else left_hdr
        frame.extend(render_box([hdr_line], width=cols, border_color=S.cyan))

        # tabs + search bar (or modal sub-bar)
        if self.modal_kind:
            extra_hint = ""
            if self.modal_kind == "logs":
                extra_hint = f"  {S.cyan}f{S.reset} live follow"
            elif self.modal_kind == "doctor":
                extra_hint = f"  {S.cyan}x{S.reset} clean stale dirs"
            sub = f" {self.modal_title}    {S.dim}↑↓/jk scroll · r refresh{extra_hint} · esc/q back{S.reset}"
            frame.append(pad_ansi(sub, cols))
        else:
            tabs = []
            for idx, name in enumerate(self.CATEGORIES):
                if idx == self.cat_idx:
                    tabs.append(f"{S.bg_sel}{S.bold} {idx + 1}:{name} {S.reset}")
                else:
                    tabs.append(f"{S.dim} {idx + 1}:{name} {S.reset}")
            tab_str = " ".join(tabs)
            if self.searching:
                srch = f"  {S.cyan}/{S.reset}{S.bold}{self.query}{S.reset}{S.bg_sel} {S.reset}"
            elif self.query:
                srch = f"  {S.cyan}filter:{S.reset} {self.query} {S.dim}(esc clears){S.reset}"
            else:
                srch = f"  {S.dim}/ to search{S.reset}"
            frame.append(pad_ansi(f" {tab_str}{srch}", cols))

        # body area (3 rows header + 1 tab bar + 2 footer = 6 reserved)
        body_h = max(6, rows - 6)
        inner_h = max(4, body_h - 2)

        if self.modal_kind:
            total = len(self.modal_lines)
            max_scroll = max(0, total - inner_h)
            self.modal_scroll = max(0, min(self.modal_scroll, max_scroll))
            visible = self.modal_lines[self.modal_scroll:self.modal_scroll + inner_h]
            while len(visible) < inner_h:
                visible.append("")
            pos_txt = f"{self.modal_scroll + 1}-{min(total, self.modal_scroll + inner_h)}/{total}" if total else "0/0"
            frame.extend(render_box(
                visible,
                width=cols,
                footer=f"{S.dim}{pos_txt}{S.reset}",
                border_color=S.blue,
                scroll_info=(self.modal_scroll, inner_h, total),
            ))
        else:
            items = self.filtered_actions()
            spec = self.current_action()
            if self.selected < self.scroll:
                self.scroll = self.selected
            elif self.selected >= self.scroll + inner_h:
                self.scroll = self.selected - inner_h + 1
            self.scroll = max(0, min(self.scroll, max(0, len(items) - inner_h)))

            split = cols >= 82
            left_w = max(36, int(cols * 0.44)) if split else cols
            right_w = (cols - left_w - 1) if split else 0
            left_inner = left_w - 2

            list_lines: List[str] = []
            if not items:
                list_lines.append(f" {S.dim}no actions match '{self.query}'{S.reset}")
            else:
                slice_items = items[self.scroll:self.scroll + inner_h]
                for offset, a in enumerate(slice_items):
                    real_idx = self.scroll + offset
                    is_sel = real_idx == self.selected
                    label = a.label
                    if a.id == "switch":
                        other = "quickshell" if cur == "brain_shell" else "brain_shell"
                        label = "switch shell (hyprland)" if st.get("gnome") else f"switch -> {other}"
                    elif a.id == "reload":
                        label = "reload gnome themes" if st.get("gnome") else f"reload {cur}"

                    if is_sel:
                        tag_plain = f"[{a.category.lower()}] "
                        max_left = max(4, left_inner - len(tag_plain) - 1)
                        left_clipped = clip_ansi(f" ❯ {a.icon}  {label}", max_left)
                        space = max(1, left_inner - vis_len(left_clipped) - len(tag_plain))
                        line = f"{S.bg_sel}{S.bold}{left_clipped}{' ' * space}{tag_plain}{S.reset}"
                    else:
                        tag_plain = f"{a.category.lower()} "
                        max_left = max(4, left_inner - len(tag_plain) - 1)
                        left_clipped = clip_ansi(f"   {S.cyan}{a.icon}{S.reset}  {label}", max_left)
                        space = max(1, left_inner - vis_len(left_clipped) - len(tag_plain))
                        line = f"{left_clipped}{' ' * space}{S.dim}{tag_plain}{S.reset}"
                    list_lines.append(line)

            while len(list_lines) < inner_h:
                list_lines.append("")

            cnt_footer = f"{S.dim}{self.selected + 1}/{len(items)}{S.reset}" if items else f"{S.dim}0/0{S.reset}"
            left_box = render_box(
                list_lines,
                width=left_w,
                title=f"{S.bold}actions{S.reset}",
                footer=cnt_footer,
                border_color=S.cyan if not self.searching else S.yellow,
                scroll_info=(self.scroll, inner_h, len(items)),
            )

            if split:
                prev_lines = self._build_preview_lines(spec, right_w - 2, inner_h)
                while len(prev_lines) < inner_h:
                    prev_lines.append("")
                right_box = render_box(
                    prev_lines,
                    width=right_w,
                    title=f"{S.bold}inspector{S.reset}",
                    border_color=S.dim,
                )
                for lb, rb in zip(left_box, right_box):
                    frame.append(f"{lb} {rb}")
            else:
                frame.extend(left_box)

        # footer toast + key hints
        now = time.time()
        if self.toast_msg and now < self.toast_until:
            icon = f"{S.green}󰄲" if self.toast_ok else f"{S.red}󰅚"
            col = S.green if self.toast_ok else S.red
            toast_line = f" {icon} {col}{self.toast_msg}{S.reset}"
        else:
            toast_line = f" {S.dim}ready · active profile: {cur}{S.reset}"

        if self.modal_kind:
            hints = f" {S.dim}↑↓/jk scroll · pgup/pgdn jump · r refresh · esc/q back{S.reset}"
        elif self.searching:
            hints = f" {S.dim}type to filter · ↑↓ move · enter run · ctrl+u clear · esc exit search{S.reset}"
        else:
            hints = f" {S.dim}↑↓/jk move · tab/1-5 category · / search · enter run · r refresh · q quit{S.reset}"

        frame.append(pad_ansi(toast_line, cols))
        frame.append(pad_ansi(hints, cols))

        frame = frame[:rows]
        while len(frame) < rows:
            frame.append(" " * cols)
        return frame

    def render(self):
        cols, rows = term_size()
        lines = self.build_frame(cols, rows)
        buf = "\033[H" + "\r\n".join(f"{ln}\033[K" for ln in lines)
        sys.stdout.write(buf)
        sys.stdout.flush()

    def _handle_modal_key(self, key: str):
        _, rows = term_size()
        page = max(4, rows - 10)
        if key in ("ESC", "q", "Q", "LEFT", "h"):
            self.modal_kind = None
            return
        if key in ("DOWN", "j"):
            self.modal_scroll += 1
        elif key in ("UP", "k"):
            self.modal_scroll -= 1
        elif key == "PGDN":
            self.modal_scroll += page
        elif key == "PGUP":
            self.modal_scroll -= page
        elif key in ("HOME", "g"):
            self.modal_scroll = 0
        elif key in ("END", "G"):
            self.modal_scroll = max(0, len(self.modal_lines))
        elif key in ("r", "R"):
            self.refresh_telemetry(include_doctor=(self.modal_kind == "doctor"))
            self.set_toast("refreshed", ok=True, duration=2.0)
        elif key in ("f", "F") and self.modal_kind == "logs":
            lp = self.status_data.get("log_path")
            if lp and Path(lp).exists():
                self._run_foreground(lambda: follow_log_colored(Path(lp)))
        elif key in ("x", "X") and self.modal_kind == "doctor":
            cleaned = clean_stale_runtime_dirs()
            self.refresh_telemetry(include_doctor=True)
            self.set_toast(f"cleaned {cleaned} stale runtime pid dir(s)", ok=True)

    def _handle_key(self, key: str):
        if key in ("CTRL_C", "EOF"):
            self.running = False
            return
        if key == "RESIZE":
            return

        if self.modal_kind:
            self._handle_modal_key(key)
            return

        items = self.filtered_actions()

        if self.searching:
            if key == "ESC":
                self.searching = False
                return
            if key == "CTRL_U":
                self.query = ""
                self.selected = 0
                return
            if key == "BACKSPACE":
                self.query = self.query[:-1]
                self.selected = 0
                return
            if key == "UP":
                if items:
                    self.selected = (self.selected - 1) % len(items)
                return
            if key == "DOWN":
                if items:
                    self.selected = (self.selected + 1) % len(items)
                return
            if key == "ENTER":
                self.searching = False
                spec = self.current_action()
                if spec:
                    self._execute_action(spec)
                return
            if len(key) == 1 and key.isprintable():
                self.query += key
                self.selected = 0
                return
            return

        if key in ("q", "Q"):
            self.running = False
        elif key == "ESC":
            if self.query:
                self.query = ""
                self.selected = 0
            else:
                self.running = False
        elif key == "/":
            self.searching = True
        elif key in ("DOWN", "j"):
            if items:
                self.selected = (self.selected + 1) % len(items)
        elif key in ("UP", "k"):
            if items:
                self.selected = (self.selected - 1) % len(items)
        elif key == "PGDN":
            if items:
                self.selected = min(len(items) - 1, self.selected + 8)
        elif key == "PGUP":
            if items:
                self.selected = max(0, self.selected - 8)
        elif key in ("HOME", "g"):
            self.selected = 0
        elif key in ("END", "G"):
            self.selected = max(0, len(items) - 1)
        elif key in ("TAB", "RIGHT", "l"):
            self.cat_idx = (self.cat_idx + 1) % len(self.CATEGORIES)
            self.selected = 0
            self.scroll = 0
        elif key in ("SHIFT_TAB", "LEFT", "h"):
            self.cat_idx = (self.cat_idx - 1) % len(self.CATEGORIES)
            self.selected = 0
            self.scroll = 0
        elif key in ("1", "2", "3", "4", "5"):
            idx = int(key) - 1
            if idx < len(self.CATEGORIES):
                self.cat_idx = idx
                self.selected = 0
                self.scroll = 0
        elif key in ("r", "R"):
            self.refresh_telemetry(include_doctor=True)
            self.set_toast("telemetry refreshed", ok=True, duration=2.0)
        elif key == "ENTER":
            spec = self.current_action()
            if spec:
                self._execute_action(spec)

    def run(self):
        self.refresh_telemetry(include_doctor=True)
        self._setup_signals()
        self._enter_screen()
        try:
            while self.running:
                if time.time() - self.last_refresh >= 4.0:
                    self.refresh_telemetry(include_doctor=False)
                self.render()
                key = self._read_key(timeout=0.25)
                if key is not None:
                    self._handle_key(key)
        finally:
            self._leave_screen()
            self._teardown_signals()


def launch_tui(force: bool = False):
    if not (sys.stdin.isatty() and sys.stdout.isatty()):
        print_help()
        return
    ControlHubTUI(force=force).run()


def _extract_global_flags(argv: List[str]) -> Tuple[List[str], dict]:
    flags = {
        "force": False,
        "json": False,
        "color": None,
        "fix": False,
        "img": True,
    }
    passthrough_cmds = {"ipc", "wp", "wall", "wallpaper", "w"}
    out: List[str] = []
    stop_parsing = False
    for tok in argv:
        if stop_parsing:
            out.append(tok)
            continue
        if tok == "--force":
            flags["force"] = True
        elif tok == "--json":
            flags["json"] = True
        elif tok == "--no-img":
            flags["img"] = False
        elif tok == "--no-color":
            flags["color"] = False
        elif tok == "--color":
            flags["color"] = True
        elif tok == "--fix":
            flags["fix"] = True
        else:
            out.append(tok)
            if len(out) == 1 and tok.lower() in passthrough_cmds:
                stop_parsing = True
    return out, flags


def main():
    args, flags = _extract_global_flags(sys.argv[1:])
    configure_color(flags["color"])

    if not args:
        launch_tui(force=flags["force"])
        return

    cmd = args[0].lower()
    rest = args[1:]

    if cmd in ("ui", "tui", "menu", "hub"):
        launch_tui(force=flags["force"])
        return

    if cmd in ("-h", "--help", "help"):
        print_help()
        return

    if cmd in ("-v", "--version", "version"):
        st = collect_status()
        payload = {
            "cli": "dotfiles-cli",
            "desktop": st.get("desktop"),
            "shell": st.get("running_shell") or st.get("configured_shell"),
            "mode": st.get("mode"),
            "scheme": st.get("scheme"),
        }
        if flags["json"]:
            print(json.dumps(payload, indent=2))
        else:
            print(f"{S.cyan}{S.bold}cli{S.reset} · desktop={payload['desktop']} · shell={payload['shell']} · {payload['mode']} ({payload['scheme']})")
        return

    if cmd in ("doctor", "health", "check"):
        run_doctor(fix=flags["fix"], as_json=flags["json"])
        return

    if cmd in ("clean", "prune"):
        removed = clean_stale_runtime_dirs()
        print(f"{S.green}󰄲 cleaned {removed} stale runtime pid dir(s).{S.reset}")
        return

    if cmd in ("theme", "palette", "colors"):
        show_theme(as_json=flags["json"], show_img=flags["img"])
        return

    if cmd in ("log", "logs"):
        show_logs(rest)
        return

    if cmd in ("status", "info", "current"):
        show_status(as_json=flags["json"])
        return

    if cmd in ("shell", "switch", "toggle", "t"):
        target = rest[0] if rest else "toggle"
        ok, _ = switch_shell(target, force=flags["force"])
        if not ok:
            sys.exit(1)
        return

    if cmd in ("qs", "quickshell"):
        ok, _ = switch_shell("quickshell", force=flags["force"])
        if not ok:
            sys.exit(1)
        return

    if cmd in ("bs", "brain", "brain_shell", "brainshell"):
        ok, _ = switch_shell("brain_shell", force=flags["force"])
        if not ok:
            sys.exit(1)
        return

    if cmd in ("reload", "restart", "r"):
        ok, _ = switch_shell("restart", force=flags["force"])
        if not ok:
            sys.exit(1)
        return

    if cmd in ("kill", "stop", "k"):
        if in_gnome_session():
            print(f"{S.dim}nothing to kill (gnome session active).{S.reset}")
            return
        killed = kill_running_shell()
        print(f"{S.yellow}󰅚 terminated {killed} shell process(es) and cleaned stale runtime dirs.{S.reset}")
        return

    if cmd == "ipc":
        if not shutil.which("qs"):
            print(f"{S.red}󰅚 'qs' binary not found in path.{S.reset}", file=sys.stderr)
            sys.exit(1)
        ipc_args = list(rest)
        if "-p" not in ipc_args and get_current_shell() == "brain_shell" and get_brain_shell_dir().is_dir():
            ipc_args = ["-p", str(get_brain_shell_dir()), *ipc_args]
        try:
            res = subprocess.run(["qs", "ipc", *ipc_args])
            sys.exit(res.returncode)
        except Exception as e:
            print(f"{S.red}error executing qs ipc: {e}{S.reset}", file=sys.stderr)
            sys.exit(1)

    if cmd in ("act", "action"):
        if not rest:
            print(f"{S.red}error:{S.reset} missing action name. e.g. cli act launcher", file=sys.stderr)
            sys.exit(1)
        ok, msg = dispatch_action(rest[0], rest[1:])
        if not ok:
            print(f"{S.red}󰅚 {msg}{S.reset}", file=sys.stderr)
            sys.exit(1)
        return

    ok, msg = dispatch_action(cmd, rest)
    if not ok:
        print(f"{S.red}󰅚 {msg}{S.reset}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
