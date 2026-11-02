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

def run_hyprctl(args: list[str]) -> bool:
    """Run hyprctl dispatch and verify response."""
    if not shutil.which("hyprctl"):
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
    runtime_dir = os.environ.get("XDG_RUNTIME_DIR") or "/tmp"
    token_path = Path(runtime_dir) / "qs_session_locked.token"
    if token_path.is_file():
        try:
            return token_path.read_text().strip() == "locked"
        except OSError:
            pass
    return False

def lock_session() -> bool:
    """Lock screen via native Quickshell IPC with loginctl and locker fallbacks."""
    if is_session_locked():
        return True

    # 1. Primary: Quickshell IPC lock
    ok, _ = run_qs_ipc("lock", "lock")
    if ok:
        return True

    # 2. Logind lock-session
    if run(["loginctl", "lock-session"], timeout=4):
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
        "Screen lock failed",
        "Quickshell lock IPC and system locker fallbacks did not respond.",
    ])
    return False

def toggle_caffeine() -> bool:
    """Toggle Quickshell idle monitor on/off (Caffeine mode)."""
    ok, out = run_qs_ipc("caffeine", "toggle")
    if not ok:
        # Fallback to direct idle toggle if caffeine alias not present
        ok, out = run_qs_ipc("idle", "toggle")
        if not ok:
            run([
                "notify-send",
                "-u", "critical",
                "-a", "idle monitor",
                "Idle toggle failed",
                "Quickshell idle IPC service did not respond.",
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
        "Idle Timeout Changed",
        f"Quickshell idle is now {new_state}",
    ])
    return True

def logout_session() -> bool:
    """Clean exit order: UWSM -> hyprshutdown -> hyprctl dispatch exit -> loginctl."""
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
                "Suspend Aborted",
                "Refusing to suspend: screen locker failed to engage.",
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
    print("Usage: session.py [lock|logout|suspend|reboot|poweroff|hibernate|caffeine|status]", file=sys.stderr)

def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help", "help"):
        print_usage()
        sys.exit(0 if (len(sys.argv) > 1 and sys.argv[1] in ("-h", "--help")) else 1)

    action = sys.argv[1].lower()

    actions = {
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
        print(f"Unknown action: {action}", file=sys.stderr)
        print_usage()
        sys.exit(1)

if __name__ == "__main__":
    main()
