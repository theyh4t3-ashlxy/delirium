#!/usr/bin/env python3
"""
cli - quickshell, brain_shell, and desktop action controller.
crafted for keyboard-only terminal addicts who refuse to touch the mouse.
"""

import os
import sys
import time
import shutil
import subprocess
from pathlib import Path
from typing import List, Optional

# --- ANSI Styling ---
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
CACHE_FILE = CACHE_DIR / "current_shell"
DOTFILES_DIR = HOME / ".local" / "share" / "dotfiles"
USER_PREFS_FILE = HOME / ".config" / "zsh" / "user_prefs.conf"

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

def is_running(process_name: str) -> bool:
    try:
        res = subprocess.run(["pgrep", "-f", process_name], stdout=subprocess.DEVNULL)
        return res.returncode == 0
    except Exception:
        return False

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

def kill_running_shell(graceful_timeout: float = 1.5):
    print(f"{C_DIM}󰚰 terminating running shell instances...{C_RESET}")
    brain_dir = str(get_brain_shell_dir())

    # 1. Graceful IPC kill
    for cmd in [
        ["qs", "kill"],
        ["qs", "-p", brain_dir, "kill"],
    ]:
        try:
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass

    # 2. SIGTERM
    for name in [".quickshell-wra", "quickshell", "qs"]:
        try:
            subprocess.run(["pkill", "-x", name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass

    # 3. Wait for process exit
    start = time.time()
    while time.time() - start < graceful_timeout:
        if not get_running_pids():
            break
        time.sleep(0.05)

    # 4. SIGKILL if stubborn
    if get_running_pids():
        for name in [".quickshell-wra", "quickshell", "qs"]:
            try:
                subprocess.run(["pkill", "-9", "-x", name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except Exception:
                pass
        time.sleep(0.1)

    # Clean stale runtime PID mappings
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
        if has_uwsm:
            cmd = ["uwsm", "app", "--", "qs", "-d", "-p", brain_path]
        else:
            cmd = ["qs", "-d", "-p", brain_path]
    else:
        if has_uwsm:
            cmd = ["uwsm", "app", "--", "qs", "-d"]
        else:
            cmd = ["qs", "-d"]

    # Launch detached so shell doesn't die when terminal closes
    try:
        subprocess.Popen(
            cmd,
            start_new_session=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        time.sleep(0.3)
        print(f"{C_GREEN}󰄲 {C_BOLD}{shell_name}{C_RESET} {C_GREEN}engaged successfully.{C_RESET}")
    except Exception as e:
        print(f"{C_RED}error launching {shell_name}: {e}{C_RESET}", file=sys.stderr)

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
        if has_uwsm:
            run_detached(["uwsm", "app", "--", "kitty", "-e", "yazi", target])
        else:
            run_detached(["kitty", "-e", "yazi", target])
    elif pref_fm in ("dolphin", "nautilus", "thunar"):
        if shutil.which(pref_fm):
            if has_uwsm:
                run_detached(["uwsm", "app", "--", pref_fm, target])
            else:
                run_detached([pref_fm, target])
        elif shutil.which("kitty"):
            run_detached(["kitty", "-e", "yazi", target])
        else:
            run_detached(["xdg-open", target])
    else:
        if shutil.which(pref_fm):
            if has_uwsm:
                run_detached(["uwsm", "app", "--", pref_fm, target])
            else:
                run_detached([pref_fm, target])
        elif shutil.which("yazi"):
            run_detached(["kitty", "-e", "yazi", target])
        elif shutil.which("dolphin"):
            run_detached(["dolphin", target])
        elif shutil.which("nautilus"):
            run_detached(["nautilus", target])
        else:
            run_detached(["xdg-open", target])

def trigger_wallpaper():
    current = get_current_shell()
    brain_dir = get_brain_shell_dir()
    if current == "brain_shell" and brain_dir.is_dir():
        send_ipc("wallpaper-toggle", "toggle", profile_dir=str(brain_dir))
        return

    wp_script = DOTFILES_DIR / "quickshell" / "scripts" / "wallpaper.py"
    if not wp_script.exists():
        wp_script = HOME / ".config" / "quickshell" / "scripts" / "wallpaper.py"

    if wp_script.exists():
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

def dispatch_action(action_name: str, args: Optional[List[str]] = None):
    args = args or []
    act = action_name.lower()
    current = get_current_shell()
    brain_dir = get_brain_shell_dir()
    is_bs = (current == "brain_shell" and brain_dir.is_dir())
    b_profile = str(brain_dir) if is_bs else None

    # 1. Specialized handlers
    if act in ("files", "filemanager", "fm", "e"):
        target_dir = args[0] if args else None
        open_file_manager(target_dir)
        return

    if act in ("wallpaper", "wall", "wp", "w"):
        trigger_wallpaper()
        return

    if act in ("record", "rec"):
        handle_record(args)
        return

    if act in ("stats", "system"):
        if is_bs:
            send_ipc("dashboard-stats", "toggle", profile_dir=b_profile)
        else:
            has_uwsm = shutil.which("uwsm") is not None
            cmd = ["uwsm", "app", "--", "kitty", "-e", "btop"] if has_uwsm else ["kitty", "-e", "btop"]
            subprocess.Popen(cmd, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return

    # 2. Dual-mode IPC mappings (brain_shell vs standard quickshell)
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
        "screenshot": ("screenshot-toggle", "toggle", "screenshot", "open"),
        "ss": ("screenshot-toggle", "toggle", "screenshot", "open"),
        "capture": ("capture", "toggle", "capture", "toggle"),
        "screencapture": ("capture", "toggle", "capture", "toggle"),
        "layout": ("layout-toggle", "toggle", "layout", "toggle"),
        "layoutswitcher": ("layout-toggle", "toggle", "layout", "toggle"),
        "lock": ("lock-session", "toggle", "lock", "lock"),
        "powermenu": ("PowerMenu-toggle", "toggle", "powermenu", "toggle"),
        "power": ("PowerMenu-toggle", "toggle", "powermenu", "toggle"),
        "wifi": ("wifi-toggle", "toggle", "quicksettings", "toggle"),
        "bluetooth": ("bluetooth-toggle", "toggle", "quicksettings", "toggle"),
        "bt": ("bluetooth-toggle", "toggle", "quicksettings", "toggle"),
        "vpn": ("vpn-toggle", "toggle", "quicksettings", "toggle"),
        "hotspot": ("hotspot-toggle", "toggle", "quicksettings", "toggle"),
        "focus": ("focus-toggle", "toggle", "notifs", "toggle"),
        "dnd": ("focus-toggle", "toggle", "notifs", "toggle"),
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

    if act in ipc_map:
        bs_target, bs_meth, qs_target, qs_meth = ipc_map[act]
        if is_bs:
            send_ipc(bs_target, bs_meth, profile_dir=b_profile, extra_args=args)
        else:
            send_ipc(qs_target, qs_meth, extra_args=args)
        return

    # Fallback: attempt direct IPC call with provided target
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

    # Get memory footprint if running
    mem_info = ""
    if pids:
        try:
            mem_out = subprocess.check_output(["ps", "-o", "rss=", "-p", str(pids[0])], text=True).strip()
            mem_mb = int(mem_out) // 1024
            mem_info = f" ({mem_mb} MB RAM)"
        except Exception:
            pass

    print(f"{C_CYAN}{C_BOLD}desktop shell status{C_RESET}")
    print(f"  {C_DIM}├─{C_RESET} {C_BOLD}active shell:{C_RESET}     {C_YELLOW}{C_BOLD}{current}{C_RESET}")
    print(f"  {C_DIM}├─{C_RESET} {C_BOLD}runtime pid(s):{C_RESET}   {pid_str}{mem_info}")
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
        "󰚰 kill running shell instances",
        "󰍜 toggle app launcher",
        "󰕮 toggle dashboard / home",
        "󰂚 toggle notification center",
        "󰅇 toggle clipboard history",
        "󰈙 open file manager (yazi / dolphin)",
        "󰄛 roll random wallpaper",
        "󰐥 open power menu",
        "󰌌 view keybindings cheatsheet",
        "󰋜 open welcome wizard",
    ]

    proc = subprocess.Popen(
        [
            "fzf",
            "--header=[󰄛 cli shell control - select action]",
            "--reverse",
            "--height=45%",
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
    elif "kill running shell" in choice:
        kill_running_shell()
        print(f"{C_YELLOW}󰅚 shells killed.{C_RESET}")
    elif "toggle app launcher" in choice:
        dispatch_action("launcher")
    elif "toggle dashboard" in choice:
        dispatch_action("dashboard")
    elif "toggle notification" in choice:
        dispatch_action("notifs")
    elif "toggle clipboard" in choice:
        dispatch_action("clipboard")
    elif "open file manager" in choice:
        dispatch_action("files")
    elif "roll random wallpaper" in choice:
        dispatch_action("wallpaper")
    elif "open power menu" in choice:
        dispatch_action("powermenu")
    elif "view keybindings" in choice:
        dispatch_action("keybinds")
    elif "open welcome wizard" in choice:
        dispatch_action("welcome")

def print_help():
    current = get_current_shell()
    print(f"""{C_CYAN}{C_BOLD}cli{C_RESET} - keyboard-driven shell & desktop controller
{C_DIM}active shell:{C_RESET} {C_YELLOW}{current}{C_RESET}

{C_BOLD}USAGE:{C_RESET}
  cli [command] [args...]

{C_BOLD}SHELL SWITCHING & LIFECYCLE:{C_RESET}
  cli shell [qs|bs|toggle|restart]  switch or toggle shell (quickshell <-> brain_shell)
  cli qs                            shortcut to switch to standard quickshell
  cli bs                            shortcut to switch to brain_shell
  cli reload | restart | r          gracefully reload active shell
  cli kill | stop | k               kill any hung or lingering quickshell instances
  cli status | info                 print active shell, pids, and memory footprint

{C_BOLD}DESKTOP ACTIONS (NATIVE IPC):{C_RESET}
  cli launcher | d                  toggle app launcher
  cli dashboard | dash | home       toggle dashboard / control center
  cli notifs | n                    toggle notification center
  cli clip | v                      toggle clipboard history
  cli files | fm | e [dir]          launch preferred file manager (yazi / dolphin)
  cli wall | wp | w                 roll random wallpaper & regenerate tokens
  cli audio | a                     toggle volume / audio control
  cli mixer                         toggle audio mixer
  cli screenshot | ss               capture screenshot
  cli record | rec [subcommand]     screen recording (screen/region/window/stop)
  cli lock                          lock session
  cli power                         open power menu
  cli keybinds | keys               view keybindings cheatsheet
  cli welcome                       open welcome wizard
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
        # Raw pass-through to qs ipc
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

    # Direct action invocation (e.g. cli launcher, cli notifs, cli files, cli wp)
    dispatch_action(cmd, args[1:])

if __name__ == "__main__":
    main()
