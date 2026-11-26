#!/usr/bin/env python3
import os
import re
import shutil
import subprocess
import sys


def _pick_gnome_color() -> str:
    res = subprocess.run(
        [
            "gdbus", "call", "--session",
            "--dest", "org.gnome.Shell.Screenshot",
            "--object-path", "/org/gnome/Shell/Screenshot",
            "--method", "org.gnome.Shell.Screenshot.PickColor",
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if res.returncode != 0:
        return ""
    m = re.search(r"\(\s*([0-9.]+)\s*,\s*([0-9.]+)\s*,\s*([0-9.]+)\s*\)", res.stdout)
    if not m:
        return ""
    r, g, b = (max(0, min(255, round(float(x) * 255))) for x in m.groups())
    return f"#{r:02x}{g:02x}{b:02x}"


def _copy_clipboard(txt: str) -> None:
    if shutil.which("wl-copy"):
        subprocess.run(["wl-copy"], input=txt, text=True, check=False)


def pick_color():
    if any(a in ("-h", "--help", "help") for a in sys.argv[1:]):
        print("pick · cross-desktop color eyedropper (hyprland & gnome)\n\nusage:\n  pick [--copy|-c]")
        return

    do_copy = ("--copy" in sys.argv or "-c" in sys.argv or os.path.basename(sys.argv[0]) == "pick")
    hx = ""
    try:
        if "gnome" in os.environ.get("XDG_CURRENT_DESKTOP", "").lower():
            hx = _pick_gnome_color()
        elif os.path.basename(sys.argv[0]) == "pick" and shutil.which("hyprpicker"):
            res = subprocess.run(["hyprpicker", "-n"], capture_output=True, text=True, check=False)
            hx = res.stdout.strip()
        else:
            slurp = subprocess.run(
                ["slurp", "-p", "-b", "00000000", "-c", "00000000"],
                capture_output=True,
                text=True,
                check=False,
            )
            geom = slurp.stdout.strip()
            if not geom:
                sys.exit(0)
            grim = subprocess.run(
                ["grim", "-g", geom, "-t", "ppm", "-"],
                capture_output=True,
                check=False,
            )
            raw = grim.stdout
            if len(raw) >= 3:
                r, g, b = raw[-3], raw[-2], raw[-1]
                hx = f"#{r:02x}{g:02x}{b:02x}"
    except Exception:
        sys.exit(1)

    if not hx:
        sys.exit(1)
    if do_copy:
        _copy_clipboard(hx)
    if sys.stdout.isatty() and os.path.basename(sys.argv[0]) == "pick":
        from _cli_ui import get_style
        st = get_style()
        swatch = f"{st.bg_hex(hx)}  {st.reset} " if st.enabled else ""
        print(f"{swatch}{hx}")
    else:
        print(hx)


if __name__ == "__main__":
    pick_color()
