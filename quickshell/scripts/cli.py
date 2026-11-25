#!/usr/bin/env python3
"""
cli - quickshell, Brain_Shell, and desktop action controller.
crafted for keyboard-only terminal addicts who refuse to touch the mouse.
"""

import os
import re
import sys
import time
import shutil
import subprocess
from pathlib import Path
from typing import List, Optional

# --- ANSI Styling (inherits active terminal ANSI 0..15 palette live) ---
C_RESET = "\033[0m"
C_BOLD = "\033[1m"
C_DIM = "\033[2m"
C_RED = "\033[31m"
C_GREEN = "\033[32m"
C_YELLOW = "\033[33m"
C_BLUE = "\033[34m"
C_MAGENTA = "\033[35m"
C_CYAN = "\033[36m"

# --- Paths ---
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


def get_brain_shell_dir() -> Path:
    env_dir = os.environ.get("BRAIN_SHELL_DIR")
    if env_dir:
        p = Path(env_dir)
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
            if val:
                return val
        except Exception:
            pass
    return "quickshell"


def set_current_shell(target: str):
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    CACHE_FILE.write_text(target + "\n", encoding="utf-8")


def get_running_pids() -> List[int]:
    pids = set()
    for name in ["quickshell", ".quickshell-wra", "qs"]:
        try:
            out = subprocess.check_output(["pgrep", "-x", name], text=True)
            for line in out.splitlines():
                if line.strip():
                    pids.add(int(line.strip()))
        except Exception:
            pass
    return sorted(list(pids))


def latest_runtime_log(pid: Optional[int] = None) -> Optional[Path]:
    uid = os.getuid()
    by_pid = Path(f"/run/user/{uid}/quickshell/by-pid")
    if not by_pid.is_dir():
        return None
    if pid is not None:
        cand = by_pid / str(pid) / "log.log"
        if cand.exists():
            return cand
    dirs = sorted(
        (d for d in by_pid.iterdir() if d.is_dir() and (d / "log.log").exists()),
        key=lambda d: (d / "log.log").stat().st_mtime,
        reverse=True,
    )
    return (dirs[0] / "log.log") if dirs else None


def kill_running_shell(graceful_timeout: float = 1.5):
    print(f"{C_DIM}󰚰 terminating running shell instances...{C_RESET}")
    brain_dir = str(get_brain_shell_dir())

    for cmd in [
        ["qs", "kill"],
        ["qs", "-p", brain_dir, "kill"],
    ]:
        try:
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass

    for name in [".quickshell-wra", "quickshell", "qs"]:
        try:
            subprocess.run(["pkill", "-x", name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass

    start = time.time()
    while time.time() - start < graceful_timeout:
        if not get_running_pids():
            break
        time.sleep(0.05)

    if get_running_pids():
        for name in [".quickshell-wra", "quickshell", "qs"]:
            try:
                subprocess.run(["pkill", "-9", "-x", name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except Exception:
                pass
        time.sleep(0.1)

    uid = os.getuid()
    runtime_pids = Path(f"/run/user/{uid}/quickshell/by-pid")
    if runtime_pids.exists():
        for item in runtime_pids.glob("*"):
            try:
                if item.is_file() or item.is_symlink():
                    item.unlink()
            except Exception:
                pass


def launch_shell(shell_name: str):
    print(f"{C_CYAN}󰄛 launching {C_BOLD}{shell_name}{C_RESET}...")
    has_uwsm = shutil.which("uwsm") is not None

    if shell_name == "brain_shell":
        brain_path = str(get_brain_shell_dir())
        if not Path(brain_path).is_dir():
            print(f"{C_RED}󰅚 Brain_Shell directory not found at {brain_path}{C_RESET}", file=sys.stderr)
            sys.exit(1)
        cmd = ["uwsm", "app", "--", "qs", "-d", "-p", brain_path] if has_uwsm else ["qs", "-d", "-p", brain_path]
    else:
        cmd = ["uwsm", "app", "--", "qs", "-d"] if has_uwsm else ["qs", "-d"]

    try:
        subprocess.Popen(
            cmd,
            start_new_session=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except Exception as e:
        print(f"{C_RED}error launching {shell_name}: {e}{C_RESET}", file=sys.stderr)
        return

    # wait briefly to verify startup PID & configuration load status
    pids: List[int] = []
    loaded_ok = False
    err_line = ""
    deadline = time.time() + 2.8
    while time.time() < deadline:
        pids = get_running_pids()
        if pids:
            log_file = latest_runtime_log(pids[0])
            if log_file and log_file.exists():
                txt = log_file.read_text(encoding="utf-8", errors="ignore")
                if "Configuration Loaded" in txt:
                    loaded_ok = True
                    break
                if "Failed to load configuration" in txt:
                    for ln in txt.splitlines():
                        if "ERROR:" in ln:
                            err_line = ln
                    break
        time.sleep(0.1)

    if err_line:
        print(f"{C_RED}󰅚 {shell_name} config error:{C_RESET} {err_line}", file=sys.stderr)
    elif loaded_ok:
        pid_txt = ", ".join(map(str, pids))
        print(f"{C_GREEN}󰄲 {C_BOLD}{shell_name}{C_RESET} {C_GREEN}loaded cleanly (pid {pid_txt}).{C_RESET}")
    elif pids:
        pid_txt = ", ".join(map(str, pids))
        print(f"{C_GREEN}󰄲 {C_BOLD}{shell_name}{C_RESET} {C_GREEN}engaged (pid {pid_txt}).{C_RESET}")
    else:
        print(f"{C_YELLOW}󰀦 launch dispatched, check 'cli logs' if daemon did not appear.{C_RESET}")


def switch_shell(target: str):
    current = get_current_shell()

    if target in ("toggle", "t"):
        target = "quickshell" if current == "brain_shell" else "brain_shell"
    elif target in ("restart", "reload", "r"):
        target = current
    elif target in ("qs", "default", "stock"):
        target = "quickshell"
    elif target in ("bs", "brain", "brainshell"):
        target = "brain_shell"

    if target not in ("quickshell", "brain_shell"):
        print(f"{C_RED}error:{C_RESET} unknown shell target '{target}'. use 'quickshell' or 'brain_shell'.", file=sys.stderr)
        sys.exit(1)

    print(f"{C_MAGENTA}󰑐 switching shell:{C_RESET} {C_DIM}{current}{C_RESET} -> {C_BOLD}{C_CYAN}{target}{C_RESET}")
    set_current_shell(target)
    kill_running_shell()
    launch_shell(target)


def send_ipc(target_object: str, method: str = "toggle", profile_dir: Optional[str] = None, extra_args: Optional[List[str]] = None) -> bool:
    cmd = ["qs", "ipc"]
    if profile_dir:
        cmd.extend(["-p", str(profile_dir)])
    cmd.extend(["call", target_object, method])
    if extra_args:
        cmd.extend(extra_args)
    try:
        res = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return res.returncode == 0
    except Exception:
        return False


def open_file_manager(target_dir: Optional[str] = None):
    target = target_dir or str(HOME)
    pref_fm = "yazi"
    if USER_PREFS_FILE.exists():
        try:
            for line in USER_PREFS_FILE.read_text(encoding="utf-8").splitlines():
                line = line.strip()
                if line.startswith("PREFERRED_FILE_MANAGER="):
                    val = line.split("=", 1)[1].strip().strip('"').strip("'")
                    if val:
                        pref_fm = val
                    break
        except Exception:
            pass

    has_uwsm = shutil.which("uwsm") is not None

    def run_detached(cmd_list):
        try:
            subprocess.Popen(
                cmd_list,
                start_new_session=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except Exception as e:
            print(f"{C_RED}error launching {cmd_list[0]}: {e}{C_RESET}", file=sys.stderr)

    if pref_fm == "yazi":
        run_detached(["uwsm", "app", "--", "kitty", "-e", "yazi", target] if has_uwsm else ["kitty", "-e", "yazi", target])
    elif pref_fm in ("dolphin", "nautilus", "thunar"):
        if shutil.which(pref_fm):
            run_detached(["uwsm", "app", "--", pref_fm, target] if has_uwsm else [pref_fm, target])
        elif shutil.which("kitty"):
            run_detached(["kitty", "-e", "yazi", target])
        else:
            run_detached(["xdg-open", target])
    else:
        if shutil.which(pref_fm):
            run_detached(["uwsm", "app", "--", pref_fm, target] if has_uwsm else [pref_fm, target])
        elif shutil.which("yazi"):
            run_detached(["kitty", "-e", "yazi", target])
        elif shutil.which("dolphin"):
            run_detached(["dolphin", target])
        elif shutil.which("nautilus"):
            run_detached(["nautilus", target])
        else:
            run_detached(["xdg-open", target])


def _find_wp_script() -> Optional[Path]:
    for cand in (
        DOTFILES_DIR / "quickshell" / "scripts" / "wallpaper.py",
        CONFIG_DIR / "quickshell" / "scripts" / "wallpaper.py",
    ):
        if cand.exists():
            return cand
    return None


def trigger_wallpaper(args: Optional[List[str]] = None):
    args = args or []
    current = get_current_shell()
    brain_dir = get_brain_shell_dir()
    wp_script = _find_wp_script()

    # Forward explicit subcommands (`cli wp dark`, `cli wp status`, `cli wp scheme ...`) straight to wallpaper.py
    if args and wp_script:
        res = subprocess.run([sys.executable, str(wp_script)] + args)
        sys.exit(res.returncode)

    if current == "brain_shell" and brain_dir.is_dir():
        send_ipc("wallpaper-toggle", "toggle", profile_dir=str(brain_dir))
        return

    if wp_script:
        subprocess.Popen(
            [sys.executable, str(wp_script), "random", "all"],
            start_new_session=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    else:
        send_ipc("wallpaper", "toggle")


def handle_record(args: List[str]):
    current = get_current_shell()
    brain_dir = get_brain_shell_dir()
    if current == "brain_shell" and brain_dir.is_dir():
        send_ipc("screenrec-on", "toggle", profile_dir=str(brain_dir))
        return

    sub = args[0] if args else "toggle"
    sub_map = {
        "screen": "screen", "display": "screen", "full": "screen",
        "region": "region", "area": "region", "crop": "region",
        "window": "window",
        "stop": "stop", "end": "stop",
        "discard": "discard", "cancel": "discard",
        "toggle": "toggle",
    }
    method = sub_map.get(sub, "toggle")
    send_ipc("record", method)


def _read_settings_conf() -> dict:
    data = {}
    for p in (STATE_DIR / "quickshell" / "settings.conf", CONFIG_DIR / "quickshell" / "settings.conf"):
        if p.exists():
            try:
                for line in p.read_text(encoding="utf-8").splitlines():
                    s = line.strip()
                    if not s or s.startswith("#") or "=" not in s:
                        continue
                    k, v = s.split("=", 1)
                    data[k.strip()] = v.strip().strip('"').strip("'")
                break
            except Exception:
                pass
    return data


def show_theme():
    cfg = _read_settings_conf()
    mode = cfg.get("matugenMode", "dark")
    scheme = cfg.get("matugenScheme", "scheme-tonal-spot")
    curr_wall = HOME / ".curr_wall"
    wp_target = str(curr_wall.resolve()) if curr_wall.exists() else cfg.get("currentWallpaper", "unknown")

    zsh_matugen = CONFIG_DIR / "zsh" / "matugen.zsh"
    tokens = {}
    if zsh_matugen.exists():
        for ln in zsh_matugen.read_text(encoding="utf-8", errors="ignore").splitlines():
            m = re.match(r'^typeset -g (MATUGEN_\w+)="([^"]+)"', ln.strip())
            if m:
                tokens[m.group(1)] = m.group(2)

    print(f"{C_CYAN}{C_BOLD}active palette & matugen state{C_RESET}")
    print(f"  {C_DIM}├─{C_RESET} {C_BOLD}mode / scheme:{C_RESET}  {C_BLUE}{mode}{C_RESET} {C_DIM}•{C_RESET} {C_MAGENTA}{scheme}{C_RESET}")
    print(f"  {C_DIM}├─{C_RESET} {C_BOLD}wallpaper:{C_RESET}      {wp_target}")

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
                r, g, b = int(hx[1:3], 16), int(hx[3:5], 16), int(hx[5:7], 16)
                swatches.append(f"\033[48;2;{r};{g};{b}m  {C_RESET} {lbl}={C_DIM}{hx}{C_RESET}")
        print(f"  {C_DIM}├─{C_RESET} {C_BOLD}tokens:{C_RESET}         " + "  ".join(swatches[:4]))
        print(f"  {C_DIM}│ {C_RESET}                 " + "  ".join(swatches[4:]))

    row0 = "".join(f"\033[48;5;{i}m   \033[0m" for i in range(8))
    row1 = "".join(f"\033[48;5;{i}m   \033[0m" for i in range(8, 16))
    print(f"  {C_DIM}├─{C_RESET} {C_BOLD}ansi 0..7:{C_RESET}      {row0}")
    print(f"  {C_DIM}└─{C_RESET} {C_BOLD}ansi 8..15:{C_RESET}     {row1}")


def show_logs(args: List[str]):
    pids = get_running_pids()
    log_path = latest_runtime_log(pids[0] if pids else None)
    if not log_path:
        print(f"{C_YELLOW}󰀦 no runtime quickshell log found.{C_RESET}")
        sys.exit(1)

    if "-f" in args or "--follow" in args:
        print(f"{C_DIM}tailing {log_path} (ctrl+c to stop)...{C_RESET}")
        try:
            subprocess.run(["tail", "-f", str(log_path)])
        except KeyboardInterrupt:
            pass
        return

    n = 40
    for a in args:
        if a.isdigit():
            n = max(1, int(a))
    lines = log_path.read_text(encoding="utf-8", errors="ignore").splitlines()[-n:]
    print(f"{C_CYAN}{C_BOLD}quickshell log{C_RESET} {C_DIM}({log_path}, last {len(lines)} lines){C_RESET}")
    for ln in lines:
        if " ERROR:" in ln or " Fatal:" in ln:
            print(f"{C_RED}{ln}{C_RESET}")
        elif " WARN:" in ln:
            print(f"{C_YELLOW}{ln}{C_RESET}")
        else:
            print(ln)


def run_doctor():
    print(f"{C_CYAN}{C_BOLD}cli doctor • desktop & terminal health check{C_RESET}\n")
    ok_cnt = warn_cnt = fail_cnt = 0

    def chk(status: str, area: str, detail: str):
        nonlocal ok_cnt, warn_cnt, fail_cnt
        if status == "ok":
            ok_cnt += 1
            badge = f"{C_GREEN}󰄲 ok  {C_RESET}"
        elif status == "warn":
            warn_cnt += 1
            badge = f"{C_YELLOW}󰀦 warn{C_RESET}"
        else:
            fail_cnt += 1
            badge = f"{C_RED}󰅚 fail{C_RESET}"
        print(f"  {badge} {C_BOLD}{area:<16}{C_RESET} {detail}")

    # 1. Shell daemon + runtime log errors
    current = get_current_shell()
    pids = get_running_pids()
    if pids:
        lp = latest_runtime_log(pids[0])
        err_cnt = 0
        loaded = False
        if lp and lp.exists():
            txt = lp.read_text(encoding="utf-8", errors="ignore")
            err_cnt = sum(1 for l in txt.splitlines() if " ERROR:" in l)
            loaded = "Configuration Loaded" in txt
        st = "ok" if (loaded and err_cnt == 0) else ("warn" if loaded else "fail")
        chk(st, "shell", f"{current} running (pid {pids[0]}) • loaded={loaded} • errors={err_cnt}")
    else:
        chk("fail", "shell", f"{current} is not running (run 'cli reload')")

    # 2. Brain_Shell checkout presence
    bdir = get_brain_shell_dir()
    chk("ok" if bdir.is_dir() else "warn", "brain_shell", f"{bdir}" + ("" if bdir.is_dir() else " (missing)"))

    # 3. Hyprland session
    try:
        r = subprocess.run(["hyprctl", "version"], capture_output=True, text=True, timeout=2)
        if r.returncode == 0:
            chk("ok", "hyprland", "socket active")
        else:
            chk("warn", "hyprland", "hyprctl returned non-zero")
    except Exception:
        chk("warn", "hyprland", "hyprctl unavailable or outside session")

    # 4. Audio (PipeWire)
    try:
        r = subprocess.run(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"], capture_output=True, text=True, timeout=2)
        if r.returncode == 0:
            chk("ok", "pipewire", r.stdout.strip())
        else:
            chk("warn", "pipewire", "no default audio sink")
    except Exception:
        chk("warn", "pipewire", "wpctl missing")

    # 5. Matugen templates + Kitty ANSI health
    kitty_colors = CONFIG_DIR / "kitty" / "colors.conf"
    if kitty_colors.exists():
        kc = kitty_colors.read_text(encoding="utf-8", errors="ignore")
        c0 = re.search(r'^color0\s+(#[0-9a-fA-F]{6})', kc, re.M)
        c15 = re.search(r'^color15\s+(#[0-9a-fA-F]{6})', kc, re.M)
        if c0 and c15 and c0.group(1).lower() != c15.group(1).lower():
            chk("ok", "kitty-ansi", f"color0={c0.group(1)} color15={c15.group(1)}")
        else:
            chk("warn", "kitty-ansi", "ANSI foreground/background collapsed; run 'wp reload'")
    else:
        chk("fail", "kitty-ansi", "~/.config/kitty/colors.conf missing")

    # 6. btop configuration check
    btop_conf = CONFIG_DIR / "btop" / "btop.conf"
    if btop_conf.exists():
        bc = btop_conf.read_text(encoding="utf-8", errors="ignore")
        tm = re.search(r'^color_theme\s*=\s*"([^"]+)"', bc, re.M)
        ft = re.search(r'^force_tty\s*=\s*(\w+)', bc, re.M)
        theme_val = tm.group(1) if tm else "?"
        ftty_val = ft.group(1) if ft else "?"
        is_link = btop_conf.parent.is_symlink()
        chk("ok" if is_link and ftty_val == "false" else "warn", "btop", f"theme={theme_val} force_tty={ftty_val} symlink={is_link}")
    else:
        chk("warn", "btop", "~/.config/btop/btop.conf missing")

    # 7. Dotfile symlinks
    broken = []
    for mod in ("zsh", "kitty", "nvim", "yazi", "btop", "fastfetch", "matugen"):
        p = CONFIG_DIR / mod
        if not p.exists():
            broken.append(mod)
    chk("ok" if not broken else "warn", "symlinks", "all core app configs linked" if not broken else f"missing: {', '.join(broken)}")

    # 8. Zsh preferences & compiled bytecode
    if USER_PREFS_FILE.exists():
        zwc_cnt = len(list((CONFIG_DIR / "zsh").glob("*.zwc")))
        prefs_txt = USER_PREFS_FILE.read_text(encoding="utf-8", errors="ignore")
        has_legacy = ("ENABLE_PSYCHO_ROASTS=" in prefs_txt or "SHOW_GREETING_ROAST=" in prefs_txt)
        note = f"prefs loaded • {zwc_cnt} .zwc bytecode files"
        if has_legacy:
            note += " (legacy keys auto-migrate on next shell)"
        chk("ok", "zsh", note)
    else:
        chk("warn", "zsh", f"{USER_PREFS_FILE} missing")

    print(f"\n{C_DIM}summary:{C_RESET} {C_GREEN}{ok_cnt} ok{C_RESET} • {C_YELLOW}{warn_cnt} warn{C_RESET} • {C_RED}{fail_cnt} fail{C_RESET}")
    if fail_cnt > 0:
        sys.exit(1)


def dispatch_action(action_name: str, args: Optional[List[str]] = None):
    args = args or []
    act = action_name.lower()
    current = get_current_shell()
    brain_dir = get_brain_shell_dir()
    is_bs = (current == "brain_shell" and brain_dir.is_dir())
    b_profile = str(brain_dir) if is_bs else None

    if act in ("files", "filemanager", "fm", "e"):
        target_dir = args[0] if args else None
        open_file_manager(target_dir)
        return

    if act in ("wallpaper", "wall", "wp", "w"):
        trigger_wallpaper(args)
        return

    if act in ("record", "rec"):
        handle_record(args)
        return

    if act in ("stats", "system", "btop"):
        if is_bs and act != "btop":
            send_ipc("dashboard-stats", "toggle", profile_dir=b_profile)
        else:
            has_uwsm = shutil.which("uwsm") is not None
            cmd = ["uwsm", "app", "--", "kitty", "-e", "btop"] if has_uwsm else ["kitty", "-e", "btop"]
            subprocess.Popen(cmd, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return

    # Map key -> (brain_shell_target, brain_shell_method, qs_target, qs_method)
    ipc_map = {
        "launcher": ("dashboard-launcher", "toggle", "launcher", "toggle"),
        "d": ("dashboard-launcher", "toggle", "launcher", "toggle"),
        "dashboard": ("dashboard-home", "toggle", "quicksettings", "toggle"),
        "dash": ("dashboard-home", "toggle", "quicksettings", "toggle"),
        "quicksettings": ("dashboard-home", "toggle", "quicksettings", "toggle"),
        "home": ("dashboard-home", "toggle", "quicksettings", "toggle"),
        "notifs": ("notification-toggle", "toggle", "notifs", "toggle"),
        "notifications": ("notification-toggle", "toggle", "notifs", "toggle"),
        "n": ("notification-toggle", "toggle", "notifs", "toggle"),
        "clipboard": ("clipboard-toggle", "toggle", "clipboard", "toggle"),
        "clip": ("clipboard-toggle", "toggle", "clipboard", "toggle"),
        "v": ("clipboard-toggle", "toggle", "clipboard", "toggle"),
        "notes": ("dashboard-kanban", "toggle", "notes", "toggle"),
        "quicknotes": ("dashboard-kanban", "toggle", "notes", "toggle"),
        "tasks": ("dashboard-kanban", "toggle", "notes", "toggle"),
        "todo": ("dashboard-kanban", "toggle", "notes", "toggle"),
        "audio": ("audioOut-toggle", "toggle", "volume", "toggle"),
        "volume": ("audioOut-toggle", "toggle", "volume", "toggle"),
        "a": ("audioOut-toggle", "toggle", "volume", "toggle"),
        "mixer": ("audioMix-toggle", "toggle", "volume", "toggle"),
        "audiomix": ("audioMix-toggle", "toggle", "volume", "toggle"),
        "audioin": ("audioIn-toggle", "toggle", "volume", "toggle"),
        "mic": ("audioIn-toggle", "toggle", "volume", "toggle"),
        "media": ("dashboard-home", "toggle", "media", "toggle"),
        "nowplaying": ("dashboard-home", "toggle", "nowplaying", "toggle"),
        "screenshot": ("screenshot-toggle", "toggle", "screenshot", "open"),
        "ss": ("screenshot-toggle", "toggle", "screenshot", "open"),
        "capture": ("capture", "toggle", "capture", "toggle"),
        "screencapture": ("capture", "toggle", "capture", "toggle"),
        "layout": ("layout-toggle", "toggle", "layout", "toggle"),
        "layoutswitcher": ("layout-toggle", "toggle", "layout", "toggle"),
        "lock": ("lock-session", "toggle", "lock", "lock"),
        "powermenu": ("PowerMenu-toggle", "toggle", "powermenu", "toggle"),
        "power": ("PowerMenu-toggle", "toggle", "powermenu", "toggle"),
        "wifi": ("wifi-toggle", "toggle", "network", "toggle"),
        "network": ("wifi-toggle", "toggle", "network", "toggle"),
        "bluetooth": ("bluetooth-toggle", "toggle", "bluetooth", "toggle"),
        "bt": ("bluetooth-toggle", "toggle", "bluetooth", "toggle"),
        "battery": ("dashboard-home", "toggle", "battery", "toggle"),
        "clock": ("dashboard-home", "toggle", "clock", "toggle"),
        "calendar": ("dashboard-home", "toggle", "calendar", "toggle"),
        "caffeine": ("focus-toggle", "toggle", "caffeine", "toggle"),
        "idle": ("focus-toggle", "toggle", "idle", "toggle"),
        "vpn": ("vpn-toggle", "toggle", "network", "vpn"),
        "hotspot": ("hotspot-toggle", "toggle", "network", "hotspot"),
        "focus": ("focus-toggle", "toggle", "notifs", "dnd"),
        "dnd": ("focus-toggle", "toggle", "notifs", "dnd"),
        "config": ("dashboard-config", "toggle", "quicksettings", "toggle"),
        "settings": ("dashboard-config", "toggle", "quicksettings", "toggle"),
        "keybinds": ("keybinds", "toggle", "keybinds", "toggle"),
        "keys": ("keybinds", "toggle", "keybinds", "toggle"),
        "shortcuts": ("keybinds", "toggle", "keybinds", "toggle"),
        "welcome": ("welcome", "toggle", "welcome", "toggle"),
        "intro": ("welcome", "toggle", "welcome", "toggle"),
        "onboarding": ("welcome", "toggle", "welcome", "toggle"),
        "studio": ("studio", "toggle", "studio", "toggle"),
        "barstudio": ("studio", "toggle", "studio", "toggle"),
        "sandbox": ("sandbox", "toggle", "sandbox", "toggle"),
        "motion": ("sandbox", "toggle", "sandbox", "toggle"),
    }

    if act in ("screenshot", "ss") and not is_bs:
        sub = args[0].lower() if args else "open"
        if sub in ("open", "close", "toggle", "region", "window", "full", "annotate", "picker"):
            send_ipc("screenshot", sub)
        elif sub in ("pin", "pinlast"):
            send_ipc("screenshot", "pinLast")
        elif sub in ("clearpins", "unpin"):
            send_ipc("screenshot", "clearPins")
        elif sub in ("last", "editlast", "edit"):
            if len(args) > 1:
                send_ipc("screenshot", "editFile", extra_args=[args[1]])
            else:
                send_ipc("screenshot", "editLast")
        elif sub in ("clip", "clipboard"):
            send_ipc("screenshot", "editClipboard")
        elif sub == "delay":
            sec = args[1] if len(args) > 1 else "3"
            send_ipc("screenshot", "delay", extra_args=[sec])
        else:
            send_ipc("screenshot", "toggle")
        return

    if act in ("studio", "barstudio") and not is_bs:
        sub = args[0].lower() if args else "toggle"
        if sub in ("layout", "style", "widgets", "motion"):
            send_ipc("studio", "tab", extra_args=[sub])
        elif sub in ("open", "close", "toggle"):
            send_ipc("studio", sub)
        else:
            send_ipc("studio", "toggle", extra_args=args)
        return

    if act in ("sandbox", "motion") and not is_bs:
        sub = args[0].lower() if args else "toggle"
        meth = sub if sub in ("open", "close", "toggle") else "toggle"
        send_ipc("sandbox", meth)
        return

    if act in ipc_map:
        bs_target, bs_meth, qs_target, qs_meth = ipc_map[act]
        if is_bs:
            send_ipc(bs_target, bs_meth, profile_dir=b_profile, extra_args=args)
        else:
            send_ipc(qs_target, qs_meth, extra_args=args)
        return

    method = args[0] if args else "toggle"
    extra = args[1:] if len(args) > 1 else []
    if is_bs:
        send_ipc(act, method, profile_dir=b_profile, extra_args=extra)
    else:
        send_ipc(act, method, extra_args=extra)


def show_status():
    current = get_current_shell()
    pids = get_running_pids()
    pid_str = f"{C_GREEN}{', '.join(map(str, pids))}{C_RESET}" if pids else f"{C_RED}inactive / dead{C_RESET}"

    mem_info = ""
    if pids:
        try:
            mem_out = subprocess.check_output(["ps", "-o", "rss=", "-p", str(pids[0])], text=True).strip()
            mem_mb = int(mem_out) // 1024
            mem_info = f" ({mem_mb} MB RAM)"
        except Exception:
            pass

    cfg = _read_settings_conf()
    mode = cfg.get("matugenMode", "dark")
    scheme = cfg.get("matugenScheme", "scheme-tonal-spot")

    print(f"{C_CYAN}{C_BOLD}desktop shell status{C_RESET}")
    print(f"  {C_DIM}├─{C_RESET} {C_BOLD}active shell:{C_RESET}     {C_YELLOW}{C_BOLD}{current}{C_RESET}")
    print(f"  {C_DIM}├─{C_RESET} {C_BOLD}runtime pid(s):{C_RESET}   {pid_str}{mem_info}")
    print(f"  {C_DIM}├─{C_RESET} {C_BOLD}theme:{C_RESET}            {C_BLUE}{mode}{C_RESET} • {C_MAGENTA}{scheme}{C_RESET}")
    print(f"  {C_DIM}├─{C_RESET} {C_BOLD}brain path:{C_RESET}       {C_DIM}{get_brain_shell_dir()}{C_RESET}")
    print(f"  {C_DIM}└─{C_RESET} {C_BOLD}quickshell path:{C_RESET}  {C_DIM}{DOTFILES_DIR / 'quickshell'}{C_RESET}")


def interactive_menu():
    if not shutil.which("fzf"):
        print_help()
        return

    current = get_current_shell()
    other = "quickshell" if current == "brain_shell" else "brain_shell"

    options = [
        f"󰑐 switch shell -> {other} (currently: {current})",
        f"󰁕 reload / restart {current}",
        "󰚰 run cli doctor (system & theme diagnostics)",
        "󰏘 inspect active palette & wallpaper (cli theme)",
        "󰍉 tail runtime shell log",
        "󰚰 kill running shell instances",
        "󰍜 toggle app launcher",
        "󰕮 toggle quicksettings / dashboard",
        "󰹑 open screen capture / recording studio",
        "󰂚 toggle notification center",
        "󰅇 toggle clipboard history",
        "󰈙 open file manager (yazi / dolphin)",
        "󰄛 roll random wallpaper",
        "󰌾 lock session",
        "󰐥 open power menu",
        "󰌌 view keybindings cheatsheet",
    ]

    proc = subprocess.Popen(
        [
            "fzf",
            "--header=[󰄛 cli control hub - select action]",
            "--reverse",
            "--height=55%",
        ],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        text=True,
    )
    choice, _ = proc.communicate(input="\n".join(options))
    if not choice or proc.returncode != 0:
        return

    choice = choice.strip()
    if "switch shell" in choice:
        switch_shell(other)
    elif "reload / restart" in choice:
        switch_shell("restart")
    elif "cli doctor" in choice:
        run_doctor()
    elif "inspect active palette" in choice:
        show_theme()
    elif "tail runtime shell log" in choice:
        show_logs(["40"])
    elif "kill running shell" in choice:
        kill_running_shell()
        print(f"{C_YELLOW}󰅚 shells killed.{C_RESET}")
    elif "toggle app launcher" in choice:
        dispatch_action("launcher")
    elif "toggle quicksettings" in choice:
        dispatch_action("dashboard")
    elif "open screen capture" in choice:
        dispatch_action("capture")
    elif "toggle notification" in choice:
        dispatch_action("notifs")
    elif "toggle clipboard" in choice:
        dispatch_action("clipboard")
    elif "open file manager" in choice:
        dispatch_action("files")
    elif "roll random wallpaper" in choice:
        dispatch_action("wallpaper")
    elif "lock session" in choice:
        dispatch_action("lock")
    elif "open power menu" in choice:
        dispatch_action("powermenu")
    elif "view keybindings" in choice:
        dispatch_action("keybinds")


def print_help():
    current = get_current_shell()
    print(f"""{C_CYAN}{C_BOLD}cli{C_RESET} - keyboard-driven shell & desktop controller
{C_DIM}active shell:{C_RESET} {C_YELLOW}{current}{C_RESET}

{C_BOLD}USAGE:{C_RESET}
  cli [command] [args...]

{C_BOLD}DIAGNOSTICS & THEME:{C_RESET}
  cli doctor                        run desktop, matugen, ANSI, btop, and zsh health checks
  cli theme | palette               print active wallpaper, mode/scheme, and ANSI color blocks
  cli logs [lines|-f]               tail active quickshell/Brain_Shell runtime log

{C_BOLD}SHELL SWITCHING & LIFECYCLE:{C_RESET}
  cli shell [qs|bs|toggle|restart]  switch or toggle shell (quickshell <-> brain_shell)
  cli qs | cli bs                   shortcut to switch to quickshell or Brain_Shell
  cli reload | restart | r          gracefully reload active shell & verify load status
  cli kill | stop | k               kill any hung or lingering quickshell instances
  cli status | info                 print active shell, pids, theme mode, and RAM

{C_BOLD}DESKTOP ACTIONS (NATIVE IPC):{C_RESET}
  cli launcher | d                  toggle app launcher
  cli dashboard | quicksettings     toggle dashboard / quicksettings
  cli notifs | n                    toggle notification center
  cli dnd | focus                   toggle do not disturb
  cli clip | v                      toggle clipboard history
  cli files | fm | e [dir]          launch preferred file manager (yazi / dolphin)
  cli wp [subcmd...] | wall         roll wallpaper or pass commands directly to wp
  cli audio | media | nowplaying    toggle audio or now playing popup
  cli capture | record [sub]        screen capture panel or recording
  cli ss [region|window|full|annotate|picker|delay <s>|pin|edit|clip]  screenshot studio
  cli lock | power                  lock session or open power menu
  cli caffeine | idle               toggle sleep inhibitor popup
  cli keybinds | welcome            view keybindings cheatsheet or welcome wizard
  cli studio [layout|style|widgets|motion]  open bar studio on a specific tab
  cli motion | sandbox              jump straight to bar studio motion lab
  cli act <action> [args]           dispatch arbitrary shell action
  cli ipc [args...]                 raw pass-through to quickshell ipc

{C_BOLD}INTERACTIVE:{C_RESET}
  cli                               open interactive fzf picker menu
""")


def main():
    args = sys.argv[1:]
    if not args:
        interactive_menu()
        return

    cmd = args[0].lower()

    if cmd in ("-h", "--help", "help"):
        print_help()
        return

    if cmd in ("doctor", "health", "check"):
        run_doctor()
        return

    if cmd in ("theme", "palette", "colors"):
        show_theme()
        return

    if cmd in ("log", "logs"):
        show_logs(args[1:])
        return

    if cmd in ("status", "info", "current"):
        show_status()
        return

    if cmd in ("shell", "switch", "toggle", "t"):
        target = args[1].lower() if len(args) > 1 else "toggle"
        switch_shell(target)
        return

    if cmd in ("qs", "quickshell"):
        switch_shell("quickshell")
        return

    if cmd in ("bs", "brain", "brain_shell", "brainshell"):
        switch_shell("brain_shell")
        return

    if cmd in ("reload", "restart", "r"):
        switch_shell("restart")
        return

    if cmd in ("kill", "stop", "k"):
        kill_running_shell()
        print(f"{C_YELLOW}󰅚 quickshell processes terminated.{C_RESET}")
        return

    if cmd == "ipc":
        ipc_cmd = ["qs", "ipc"] + args[1:]
        try:
            res = subprocess.run(ipc_cmd)
            sys.exit(res.returncode)
        except Exception as e:
            print(f"{C_RED}error executing qs ipc: {e}{C_RESET}", file=sys.stderr)
            sys.exit(1)

    if cmd in ("act", "action"):
        if len(args) < 2:
            print(f"{C_RED}error:{C_RESET} missing action name. e.g. cli act launcher", file=sys.stderr)
            sys.exit(1)
        dispatch_action(args[1], args[2:])
        return

    dispatch_action(cmd, args[1:])


if __name__ == "__main__":
    main()
