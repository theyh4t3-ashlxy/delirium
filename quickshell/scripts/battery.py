#!/usr/bin/env python3
import glob
import os
import sys

def probe_battery():
    # discover battery sysfs directory
    bat = None
    patterns = [
        "/sys/class/power_supply/BAT*",
        "/sys/class/power_supply/CMB*",
        "/sys/class/power_supply/BATT*",
        "/sys/class/power_supply/macsmc-battery",
    ]
    for pattern in patterns:
        matches = sorted(glob.glob(pattern))
        for m in matches:
            if os.path.isdir(m):
                bat = m
                break
        if bat:
            break

    if bat:
        print(f"name={os.path.basename(bat)}")
        for key, fname in [
            ("cycles", "cycle_count"),
            ("start", "charge_control_start_threshold"),
            ("stop", "charge_control_end_threshold"),
        ]:
            p = os.path.join(bat, fname)
            if os.path.isfile(p):
                try:
                    with open(p, "r") as f:
                        print(f"{key}={f.read().strip()}")
                except OSError:
                    pass

        # check energy_* then fallback to charge_*
        for f_full, f_des in [
            ("energy_full", "energy_full_design"),
            ("charge_full", "charge_full_design"),
        ]:
            p_full = os.path.join(bat, f_full)
            if os.path.isfile(p_full):
                try:
                    with open(p_full, "r") as f:
                        print(f"full={f.read().strip()}")
                    p_des = os.path.join(bat, f_des)
                    if os.path.isfile(p_des):
                        with open(p_des, "r") as f:
                            print(f"design={f.read().strip()}")
                except OSError:
                    pass
                break

    # load average
    if os.path.isfile("/proc/loadavg"):
        try:
            with open("/proc/loadavg", "r") as f:
                parts = f.read().split()
                if parts:
                    print(f"load={parts[0]}")
        except OSError:
            pass

    # gpu count
    gpus = len(glob.glob("/sys/class/drm/card[0-9]"))
    print(f"gpus={gpus}")

if __name__ == "__main__":
    probe_battery()
