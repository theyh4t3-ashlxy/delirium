#!/usr/bin/env python3
import subprocess
import sys

def pick_color():
    try:
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
            print(f"#{r:02x}{g:02x}{b:02x}")
    except Exception:
        sys.exit(0)

if __name__ == "__main__":
    pick_color()
