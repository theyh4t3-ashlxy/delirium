#!/usr/bin/env python3
import os
import sys
import json
import time

# ensure fanctl package is discoverable
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gi
gi.require_version("Gio", "2.0")
gi.require_version("GLib", "2.0")
from gi.repository import Gio, GLib

from fanctl.config import DBUS_NAME, DBUS_PATH, CURVE_PROFILES

# ansi colors
C_RESET = "\033[0m"
C_BOLD = "\033[1m"
C_DIM = "\033[2m"
C_RED = "\033[31m"
C_GREEN = "\033[32m"
C_YELLOW = "\033[33m"
C_BLUE = "\033[34m"
C_CYAN = "\033[36m"

def get_proxy():
    try:
        proxy = Gio.DBusProxy.new_for_bus_sync(
            Gio.BusType.SYSTEM,
            Gio.DBusProxyFlags.NONE,
            None,
            DBUS_NAME,
            DBUS_PATH,
            DBUS_NAME,
            None,
        )
        return proxy
    except Exception as e:
        print(f"{C_RED}error:{C_RESET} could not connect to system bus: {e}", file=sys.stderr)
        sys.exit(1)

def get_status(proxy) -> dict:
    try:
        res = proxy.GetStatus()
        raw = res[0] if isinstance(res, (tuple, list)) else res
        return json.loads(raw)
    except Exception as e:
        print(f"{C_RED}error:{C_RESET} fan daemon is inactive or not responding: {e}", file=sys.stderr)
        print(f"{C_DIM}check systemctl status fan-control{C_RESET}", file=sys.stderr)
        sys.exit(1)

def format_temp_color(temp: float) -> str:
    if temp < 58.0:
        return f"{C_GREEN}{temp:.1f}°C{C_RESET}"
    elif temp < 75.0:
        return f"{C_YELLOW}{temp:.1f}°C{C_RESET}"
    else:
        return f"{C_RED}{C_BOLD}{temp:.1f}°C{C_RESET}"

def cmd_status(proxy):
    data = get_status(proxy)
    temp = data.get("temp", 0.0)
    max_temp = data.get("max_temp", temp)
    rpm = data.get("speed_rpm", 0)
    level = data.get("level", "unknown")
    mode = data.get("mode", "unknown")
    curve_prof = data.get("curve_profile", "balanced")
    cpu_mhz = data.get("cpu_mhz", 0)
    cpu_min = data.get("cpu_min_mhz", 0)
    cpu_max = data.get("cpu_max_mhz", 0)
    is_locked = data.get("is_locked", False)
    auto_unstick = data.get("auto_unstick", True)
    is_shocking = data.get("is_shocking", False)

    lock_badge = f"{C_RED}{C_BOLD}[400MHz LOCKED]{C_RESET}" if is_locked else f"{C_GREEN}[normal]{C_RESET}"
    shock_badge = f" {C_YELLOW}{C_BOLD}⚡ [SHOCK BURST]{C_RESET}" if is_shocking else ""
    unstick_badge = f"{C_GREEN}enabled{C_RESET}" if auto_unstick else f"{C_DIM}disabled{C_RESET}"

    print(f"{C_CYAN}{C_BOLD}thinkpad fanctl{C_RESET}")
    print(f"  {C_DIM}├─{C_RESET} {C_BOLD}fan status:{C_RESET}     {rpm} RPM  (mode: {C_CYAN}{mode}{C_RESET} | level: {C_BOLD}{level}{C_RESET}){shock_badge}")
    print(f"  {C_DIM}├─{C_RESET} {C_BOLD}temperature:{C_RESET}    {format_temp_color(temp)} (max: {format_temp_color(max_temp)})")
    print(f"  {C_DIM}├─{C_RESET} {C_BOLD}curve profile:{C_RESET}  {C_YELLOW}{curve_prof}{C_RESET}")
    print(f"  {C_DIM}├─{C_RESET} {C_BOLD}cpu clock:{C_RESET}      {cpu_mhz} MHz ({cpu_min} - {cpu_max} MHz) {lock_badge}")
    print(f"  {C_DIM}└─{C_RESET} {C_BOLD}auto-unstick:{C_RESET}   {unstick_badge}")

def cmd_set_level(proxy, level: str):
    # alias normalization
    alias = {
        "full": "full-speed",
        "max": "full-speed",
        "off": "0",
    }
    level = alias.get(level.lower(), level.lower())
    valid = [str(i) for i in range(8)] + ["auto", "full-speed", "disengaged", "curve"]

    if level not in valid:
        print(f"{C_RED}error:{C_RESET} invalid level '{level}'. valid: {', '.join(valid)}", file=sys.stderr)
        sys.exit(1)

    try:
        res = proxy.SetLevel("(s)", level)
        success = res[0] if isinstance(res, (tuple, list)) else res
        if success:
            print(f"{C_GREEN}success:{C_RESET} fan level set to {C_BOLD}{level}{C_RESET}")
        else:
            print(f"{C_RED}failed:{C_RESET} hardware controller rejected level {level}", file=sys.stderr)
            sys.exit(1)
    except Exception as e:
        print(f"{C_RED}error:{C_RESET} {e}", file=sys.stderr)
        sys.exit(1)

def cmd_curve(proxy, args):
    if not args:
        try:
            res = proxy.GetCurveProfile()
            prof = res[0] if isinstance(res, (tuple, list)) else res
            print(f"current curve profile: {C_YELLOW}{C_BOLD}{prof}{C_RESET}")
            print(f"available profiles: {', '.join(CURVE_PROFILES.keys())}")
        except Exception as e:
            print(f"{C_RED}error:{C_RESET} {e}", file=sys.stderr)
            sys.exit(1)
        return

    profile = args[0].lower()
    if profile not in CURVE_PROFILES:
        print(f"{C_RED}error:{C_RESET} invalid curve '{profile}'. options: {', '.join(CURVE_PROFILES.keys())}", file=sys.stderr)
        sys.exit(1)

    try:
        res = proxy.SetCurveProfile("(s)", profile)
        success = res[0] if isinstance(res, (tuple, list)) else res
        if success:
            # also activate curve mode if not already active
            proxy.SetLevel("(s)", "curve")
            print(f"{C_GREEN}success:{C_RESET} curve profile set to {C_YELLOW}{C_BOLD}{profile}{C_RESET} and mode activated")
        else:
            print(f"{C_RED}failed:{C_RESET} could not apply profile {profile}", file=sys.stderr)
            sys.exit(1)
    except Exception as e:
        print(f"{C_RED}error:{C_RESET} {e}", file=sys.stderr)
        sys.exit(1)

def cmd_unstick(proxy):
    try:
        print(f"{C_YELLOW}⚡ triggering embedded controller shock...{C_RESET}")
        res = proxy.TriggerUnstick()
        success = res[0] if isinstance(res, (tuple, list)) else res
        if success:
            print(f"{C_GREEN}shock engaged:{C_RESET} fan burst full-speed -> 7 to clear 400MHz lock")
        else:
            print(f"{C_YELLOW}shock ignored:{C_RESET} cooldown active or already shocking", file=sys.stderr)
    except Exception as e:
        print(f"{C_RED}error:{C_RESET} {e}", file=sys.stderr)
        sys.exit(1)

def cmd_watchdog(proxy, args):
    if not args:
        data = get_status(proxy)
        status = "enabled" if data.get("auto_unstick", True) else "disabled"
        print(f"auto-unstick watchdog: {C_BOLD}{status}{C_RESET}")
        return

    val_str = args[0].lower()
    enable = val_str in ["on", "true", "1", "enable", "enabled"]
    try:
        res = proxy.EnableAutoUnstick("(b)", enable)
        success = res[0] if isinstance(res, (tuple, list)) else res
        state_str = "enabled" if enable else "disabled"
        print(f"{C_GREEN}success:{C_RESET} auto-unstick watchdog {C_BOLD}{state_str}{C_RESET}")
    except Exception as e:
        print(f"{C_RED}error:{C_RESET} {e}", file=sys.stderr)
        sys.exit(1)

def cmd_json(proxy):
    data = get_status(proxy)
    print(json.dumps(data, indent=2))

def cmd_watch(proxy, interval: float = 1.0):
    try:
        while True:
            data = get_status(proxy)
            temp = data.get("temp", 0.0)
            rpm = data.get("speed_rpm", 0)
            lvl = data.get("level", "?")
            mode = data.get("mode", "?")
            cpu = data.get("cpu_mhz", 0)
            print(f"\r{format_temp_color(temp)} | {rpm:4d} RPM | lvl: {lvl:5s} | mode: {mode:7s} | {cpu:4d} MHz", end="", flush=True)
            time.sleep(interval)
    except KeyboardInterrupt:
        print()

def print_help():
    print(f"""{C_CYAN}{C_BOLD}fanctl{C_RESET} - thinkpad fan & thermal control cli

{C_BOLD}USAGE:{C_RESET}
  fanctl [command] [args...]

{C_BOLD}COMMANDS:{C_RESET}
  status                   show live temperatures, fan rpm, and cpu clocks (default)
  set <0-7|auto|full|curve> set fan level directly
  curve [profile]          view or switch curve (quiet, balanced, aggressive)
  unstick                  shock embedded controller to clear 400mhz lock
  watchdog <on|off>        enable or disable auto-unstick watchdog
  json                     dump live status as json (for quickshell / scripts)
  watch [interval]         live updating one-line terminal monitor
  help                     show this help

{C_BOLD}SHORTCUTS:{C_RESET}
  fanctl 0..7              same as 'fanctl set 0..7'
  fanctl auto              same as 'fanctl set auto'
  fanctl full              same as 'fanctl set full-speed'
  fanctl quiet             same as 'fanctl curve quiet'
""")

def main():
    args = sys.argv[1:]
    if not args or args[0] in ["status", "-s"]:
        proxy = get_proxy()
        cmd_status(proxy)
        return

    cmd = args[0].lower()
    if cmd in ["help", "-h", "--help"]:
        print_help()
        return

    proxy = get_proxy()

    if cmd in ["curve", "c"]:
        cmd_curve(proxy, args[1:])
    elif cmd in CURVE_PROFILES:
        cmd_curve(proxy, [cmd])
    elif cmd in ["set", "s"]:
        if len(args) < 2:
            print(f"{C_RED}error:{C_RESET} missing level. e.g. fanctl set auto", file=sys.stderr)
            sys.exit(1)
        cmd_set_level(proxy, args[1])
    elif cmd in [str(i) for i in range(8)] + ["auto", "full", "max", "off"]:
        cmd_set_level(proxy, cmd)
    elif cmd in ["unstick", "u", "shock"]:
        cmd_unstick(proxy)
    elif cmd in ["watchdog", "wd"]:
        cmd_watchdog(proxy, args[1:])
    elif cmd in ["json", "-j"]:
        cmd_json(proxy)
    elif cmd in ["watch", "-w"]:
        interval = float(args[1]) if len(args) > 1 else 1.0
        cmd_watch(proxy, interval)
    else:
        print(f"{C_RED}unknown command:{C_RESET} '{cmd}'. try 'fanctl help'", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
