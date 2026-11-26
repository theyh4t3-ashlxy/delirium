#!/usr/bin/env python3
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

def run(cmd: list[str], timeout: int = 5) -> bool:
    """Run command quietly with timeout and return True if exit code is 0."""
    if not shutil.which(cmd[0]):
        return False
    try:
        res = subprocess.run(
            cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=timeout,
            check=False,
        )
        return res.returncode == 0
    except Exception:
        return False

def run_qs_ipc(target: str, method: str, *args: str) -> tuple[bool, str]:
    """Run Quickshell IPC call safely, verifying connection and output.
    
    Quickshell returns exit status 0 even when target/method is missing or
    when the IPC daemon is not ready, so inspect stdout/stderr.
    """
    if not shutil.which("qs"):
        return False, "qs binary not found"
    try:
        res = subprocess.run(
            ["qs", "ipc", "call", target, method, *args],
            capture_output=True,
            text=True,
            timeout=4,
            check=False,
        )
        out = res.stdout.strip()
        err = res.stderr.strip()
        combined = (out + "\n" + err).strip().lower()

        error_tokens = [
            "target not found",
            "not ready to accept",
            "method not found",
            "could not open config",
            "failed to connect",
        ]
        if any(tok in combined for tok in error_tokens):
            return False, combined

        return res.returncode == 0, out
    except subprocess.TimeoutExpired:
        return False, "timeout"
    except Exception as e:
        return False, str(e)

def in_gnome_session() -> bool:
    return "gnome" in os.environ.get("XDG_CURRENT_DESKTOP", "").lower()


def run_hyprctl(args: list[str]) -> bool:
    """Run hyprctl dispatch and verify response."""
    if in_gnome_session() or not shutil.which("hyprctl"):
        return False
    try:
        res = subprocess.run(
            ["hyprctl", *args],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        return res.returncode == 0 and res.stdout.strip() == "ok"
    except Exception:
        return False

def is_session_locked() -> bool:
    """Check if the session is currently marked as locked."""
    if in_gnome_session() and shutil.which("loginctl"):
        try:
            sid = os.environ.get("XDG_SESSION_ID", "")
            cmd = ["loginctl", "show-session", sid, "-p", "LockedHint", "--value"] if sid else ["loginctl", "show-session", "self", "-p", "LockedHint", "--value"]
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=2, check=False)
            if res.returncode == 0 and res.stdout.strip().lower() == "yes":
                return True
        except Exception:
            pass
    runtime_dir = Path(os.environ.get("XDG_RUNTIME_DIR") or "/tmp")
    user = os.environ.get("USER") or os.environ.get("LOGNAME") or "user"
    for token_path in (
        runtime_dir / f"qs_session_locked_{user}.token",
        runtime_dir / "qs_session_locked.token",
    ):
        if token_path.is_file():
            try:
                if token_path.read_text().strip() == "locked":
                    return True
            except OSError:
                pass
    return False

def lock_session() -> bool:
    """Lock screen via native Quickshell IPC (Hyprland) or loginctl / GNOME."""
    if is_session_locked():
        return True

    # 1. Primary on Hyprland: Quickshell IPC lock
    if not in_gnome_session():
        ok, _ = run_qs_ipc("lock", "lock")
        if ok:
            return True

    # 2. Logind lock-session (works cleanly on both GNOME and Hyprland)
    if run(["loginctl", "lock-session"], timeout=4):
        return True

    if in_gnome_session() and shutil.which("gdbus"):
        if run(["gdbus", "call", "--session", "--dest", "org.gnome.ScreenSaver",
                "--object-path", "/org/gnome/ScreenSaver", "--method", "org.gnome.ScreenSaver.Lock"], timeout=4):
            return True

    # 3. Dedicated locker fallbacks if standalone locker installed
    for locker in ["hyprlock", "swaylock", "waylock"]:
        if shutil.which(locker):
            try:
                subprocess.Popen([locker])
                return True
            except Exception:
                pass

    # Fallback notification if lock failed completely
    run([
        "notify-send",
        "-u", "critical",
        "-a", "session manager",
        "-i", "system-lock-screen",
        "screen lock failed",
        "quickshell lock ipc and system locker fallbacks did not respond.",
    ])
    return False

def toggle_caffeine() -> bool:
    """Toggle idle monitor on/off (Quickshell on Hyprland, org.gnome.desktop.session idle-delay on GNOME)."""
    if in_gnome_session():
        if not shutil.which("gsettings"):
            return False
        try:
            cur = subprocess.run(
                ["gsettings", "get", "org.gnome.desktop.session", "idle-delay"],
                capture_output=True, text=True, timeout=2, check=False,
            )
            val_str = cur.stdout.strip().split()[-1] if cur.returncode == 0 and cur.stdout.strip() else "300"
            cur_val = int(val_str) if val_str.isdigit() else 300
        except Exception:
            cur_val = 300

        state_file = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local" / "state"))) / "quickshell" / "gnome_prev_idle_delay"
        state_file.parent.mkdir(parents=True, exist_ok=True)
        if cur_val > 0:
            state_file.write_text(str(cur_val), encoding="utf-8")
            ok = run(["gsettings", "set", "org.gnome.desktop.session", "idle-delay", "uint32 0"], timeout=3)
            is_caffeine = True
        else:
            prev = "300"
            if state_file.is_file():
                saved = state_file.read_text(encoding="utf-8").strip()
                if saved.isdigit() and int(saved) > 0:
                    prev = saved
            ok = run(["gsettings", "set", "org.gnome.desktop.session", "idle-delay", f"uint32 {prev}"], timeout=3)
            is_caffeine = False

        if ok:
            new_state = "inhibited (caffeine active)" if is_caffeine else "enabled"
            run(["notify-send", "-a", "idle monitor", "-i", "caffeine" if is_caffeine else "preferences-desktop-screensaver",
                 "idle timeout changed", f"gnome idle timer is now {new_state}"])
        return ok

    ok, out = run_qs_ipc("caffeine", "toggle")
    if not ok:
        # Fallback to direct idle toggle if caffeine alias not present
        ok, out = run_qs_ipc("idle", "toggle")
        if not ok:
            run([
                "notify-send",
                "-u", "critical",
                "-a", "idle monitor",
                "idle toggle failed",
                "quickshell idle ipc service did not respond.",
            ])
            return False

        # 'idle' target returns true when idle monitor is active (caffeine OFF)
        is_caffeine = out.lower() in ("false", "0", "off")
    else:
        # 'caffeine' target returns true when caffeine is active (idle monitor OFF)
        is_caffeine = out.lower() in ("true", "1", "on")

    new_state = "inhibited (caffeine active)" if is_caffeine else "enabled"
    icon = "caffeine" if is_caffeine else "preferences-desktop-screensaver"

    run([
        "notify-send",
        "-a", "idle monitor",
        "-i", icon,
        "idle timeout changed",
        f"quickshell idle is now {new_state}",
    ])
    return True

def logout_session() -> bool:
    """Clean exit order: GNOME quit (if GNOME) -> UWSM -> hyprshutdown -> hyprctl -> loginctl."""
    if in_gnome_session() and shutil.which("gnome-session-quit"):
        if run(["gnome-session-quit", "--logout", "--no-prompt"], timeout=10):
            return True

    # 1. UWSM managed session
    if shutil.which("uwsm") and run(["uwsm", "stop"], timeout=10):
        return True

    # 2. Dedicated shutdown helper
    if shutil.which("hyprshutdown") and run(["hyprshutdown"], timeout=10):
        return True

    # 3. Hyprland dispatcher
    if run_hyprctl(["dispatch", "exit"]):
        return True

    # 4. Logind session termination fallback
    session_id = os.environ.get("XDG_SESSION_ID", "self")
    if run(["loginctl", "terminate-session", session_id], timeout=5):
        return True

    user = os.environ.get("USER")
    if user and run(["loginctl", "terminate-user", user], timeout=5):
        return True

    return False

def suspend_system():
    """Lock first, allow the lock surface to engage, then suspend."""
    if not is_session_locked():
        if not lock_session():
            run([
                "notify-send",
                "-u", "critical",
                "-a", "power manager",
                "suspend aborted",
                "refusing to suspend: screen locker failed to engage.",
            ])
            return
        # Brief pause to let compositor map and render lock layer
        time.sleep(0.35)

    if run(["systemctl", "suspend"], timeout=10):
        return
    run(["loginctl", "suspend"], timeout=10)

def reboot_system():
    """Reboot via systemctl with loginctl fallback."""
    if run(["systemctl", "reboot"], timeout=10):
        return
    run(["loginctl", "reboot"], timeout=10)

def poweroff_system():
    """Power off via systemctl with loginctl fallback."""
    if run(["systemctl", "poweroff"], timeout=10):
        return
    run(["loginctl", "poweroff"], timeout=10)

def hibernate_system():
    """Hibernate via systemctl with loginctl fallback."""
    if run(["systemctl", "hibernate"], timeout=10):
        return
    run(["loginctl", "hibernate"], timeout=10)

def print_usage():
    from _cli_ui import get_style
    st = get_style()
    print(f"""{st.cyan}{st.bold}󰐥 session{st.reset} {st.dim}· desktop power & lock manager (hyprland + gnome){st.reset}

{st.bold}usage:{st.reset}
  session [status]                   show desktop, lock, and caffeine state
  session lock | is-locked           lock session or query lock hint
  session caffeine                   toggle idle monitor / gnome idle-delay
  session logout | suspend | hibernate | reboot | poweroff""")

def cmd_status(as_json: bool = False):
    from _cli_ui import get_style, render_box, term_size
    in_gnome = in_gnome_session()
    locked = is_session_locked()
    desktop = "gnome" if in_gnome else ("hyprland" if os.environ.get("HYPRLAND_INSTANCE_SIGNATURE") else os.environ.get("XDG_CURRENT_DESKTOP", "unknown").lower())
    caffeine = "unknown"
    if in_gnome and shutil.which("gsettings"):
        r = subprocess.run(["gsettings", "get", "org.gnome.desktop.session", "idle-delay"], capture_output=True, text=True, check=False)
        if r.returncode == 0 and r.stdout.strip():
            caffeine = "on (idle=0)" if r.stdout.strip().split()[-1] == "0" else f"off ({r.stdout.strip().split()[-1]}s)"
    elif not in_gnome:
        ok_c, out_c = run_qs_ipc("caffeine", "status")
        if ok_c and out_c.strip().lower() in ("true", "false"):
            caffeine = "on" if out_c.strip().lower() == "true" else "off"
        else:
            ok_i, out_i = run_qs_ipc("idle", "status")
            if ok_i and out_i.strip().lower() in ("true", "false"):
                caffeine = "off" if out_i.strip().lower() == "true" else "on"
    if as_json:
        print(json.dumps({"desktop": desktop, "locked": locked, "caffeine": caffeine}, indent=2))
        return
    st = get_style()
    lines = [
        f" {st.dim}├─{st.reset} {st.bold}{'desktop:':<12}{st.reset} {st.green}{desktop}{st.reset}",
        f" {st.dim}├─{st.reset} {st.bold}{'locked:':<12}{st.reset} {st.yellow if locked else st.dim}{'yes' if locked else 'no'}{st.reset}",
        f" {st.dim}└─{st.reset} {st.bold}{'caffeine:':<12}{st.reset} {caffeine}",
    ]
    cols, _ = term_size()
    print("\n".join(render_box(lines, width=min(cols, 68), title=f"{st.cyan}{st.bold}󰐥 session status{st.reset}", style=st, border_color=st.cyan)))

def main():
    args = sys.argv[1:]
    if any(a in ("-h", "--help", "help") for a in args):
        print_usage()
        return

    as_json = "--json" in args
    clean = [a for a in args if a != "--json"]
    action = clean[0].lower() if clean else "status"

    actions = {
        "status": lambda: cmd_status(as_json=as_json),
        "lock": lock_session,
        "is-locked": lambda: print("locked" if is_session_locked() else "unlocked"),
        "logout": logout_session,
        "exit": logout_session,
        "quit": logout_session,
        "suspend": suspend_system,
        "sleep": suspend_system,
        "caffeine": toggle_caffeine,
        "idle-toggle": toggle_caffeine,
        "reboot": reboot_system,
        "restart": reboot_system,
        "poweroff": poweroff_system,
        "shutdown": poweroff_system,
        "hibernate": hibernate_system,
    }

    handler = actions.get(action)
    if handler:
        handler()
    else:
        print(f"unknown action: {action}", file=sys.stderr)
        print_usage()
        sys.exit(1)

if __name__ == "__main__":
    main()
