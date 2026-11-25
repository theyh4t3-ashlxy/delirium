#!/usr/bin/env python3
"""
battery.py — sysfs, TLP, ACPI platform_profile, intel_pstate, and fanctl backend
for Quickshell's BatteryPopup widget.
"""
import glob
import json
import os
import shutil
import subprocess
import sys


def _read_text(path: str) -> str:
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read().strip()
    except OSError:
        return ""


def _run_root(shell_cmd: str, timeout: int = 8) -> tuple[bool, str]:
    """Run a root command using passwordless sudo (-n) first, then pkexec fallback."""
    if shutil.which("sudo"):
        try:
            res = subprocess.run(
                ["sudo", "-n", "sh", "-c", shell_cmd],
                capture_output=True,
                text=True,
                timeout=timeout,
                check=False,
            )
            if res.returncode == 0:
                return True, res.stdout.strip()
            err = (res.stderr or res.stdout or "").strip()
        except Exception as exc:
            err = str(exc)
    else:
        err = "sudo unavailable"

    if shutil.which("pkexec"):
        try:
            res = subprocess.run(
                ["pkexec", "sh", "-c", shell_cmd],
                capture_output=True,
                text=True,
                timeout=20,
                check=False,
            )
            if res.returncode == 0:
                return True, res.stdout.strip()
            err = (res.stderr or res.stdout or err).strip()
        except Exception as exc:
            err = str(exc)

    return False, err or "permission denied"


def _discover_battery() -> str | None:
    patterns = [
        "/sys/class/power_supply/BAT*",
        "/sys/class/power_supply/CMB*",
        "/sys/class/power_supply/BATT*",
        "/sys/class/power_supply/macsmc-battery",
    ]
    for pattern in patterns:
        for m in sorted(glob.glob(pattern)):
            if os.path.isdir(m):
                return m
    return None


def _normalize_profile(raw: str) -> str:
    s = (raw or "").strip().lower()
    if s in ("low-power", "power-saver", "saver", "quiet"):
        return "power-saver"
    if s in ("performance", "perf", "max"):
        return "performance"
    if s == "balanced":
        return "balanced"
    return s or "balanced"


def _detect_power_state() -> dict:
    info: dict[str, str] = {}

    # Check powerprofilesctl first if user actually runs PPD / tuned-ppd
    if shutil.which("powerprofilesctl"):
        try:
            cur = subprocess.check_output(
                ["powerprofilesctl", "get"], text=True, timeout=2
            ).strip()
            if cur:
                info["backend"] = "ppd"
                info["profile"] = _normalize_profile(cur)
                lst = subprocess.check_output(
                    ["powerprofilesctl", "list"], text=True, timeout=2
                )
                choices = []
                for p in ("power-saver", "balanced", "performance"):
                    if p in lst:
                        choices.append(p)
                info["choices"] = " ".join(choices) if choices else "power-saver balanced"
        except Exception:
            pass

    if "backend" not in info:
        pp_raw = _read_text("/sys/firmware/acpi/platform_profile")
        pp_choices_raw = _read_text("/sys/firmware/acpi/platform_profile_choices")
        has_tlp = bool(shutil.which("tlp"))
        if pp_raw or pp_choices_raw:
            info["backend"] = "tlp+acpi" if has_tlp else "acpi"
            info["profile"] = _normalize_profile(pp_raw)
            mapped = []
            for tok in pp_choices_raw.split():
                n = _normalize_profile(tok)
                if n not in mapped:
                    mapped.append(n)
            info["choices"] = " ".join(mapped) if mapped else "power-saver balanced"
        else:
            info["backend"] = "tlp+cpufreq" if has_tlp else "cpufreq"
            epp0 = _read_text("/sys/devices/system/cpu/cpufreq/policy0/energy_performance_preference")
            if epp0 in ("power", "balance_power"):
                info["profile"] = "power-saver" if epp0 == "power" else "balanced"
            elif epp0 == "performance":
                info["profile"] = "performance"
            else:
                info["profile"] = "balanced"
            avail_epp = _read_text("/sys/devices/system/cpu/cpufreq/policy0/energy_performance_available_preferences")
            if "performance" in avail_epp:
                info["choices"] = "power-saver balanced performance"
            else:
                info["choices"] = "power-saver balanced"

    epp = _read_text("/sys/devices/system/cpu/cpufreq/policy0/energy_performance_preference")
    if epp:
        info["epp"] = epp
    epp_avail = _read_text("/sys/devices/system/cpu/cpufreq/policy0/energy_performance_available_preferences")
    if epp_avail:
        info["epp_choices"] = epp_avail
    gov = _read_text("/sys/devices/system/cpu/cpufreq/policy0/scaling_governor")
    if gov:
        info["governor"] = gov

    no_turbo = _read_text("/sys/devices/system/cpu/intel_pstate/no_turbo")
    if no_turbo in ("0", "1"):
        info["turbo"] = "1" if no_turbo == "0" else "0"

    return info


def _detect_dgpu_status() -> tuple[int, str]:
    cards = sorted(glob.glob("/sys/class/drm/card[0-9]"))
    gpu_count = len(cards)
    dgpu_state = ""
    # Prefer non-boot / discrete runtime PM card if multiple GPUs exist
    for c in cards:
        vendor = _read_text(os.path.join(c, "device/vendor")).lower()
        rt = _read_text(os.path.join(c, "device/power/runtime_status"))
        if vendor and vendor != "0x8086" and rt:
            dgpu_state = rt
            break
    if not dgpu_state and gpu_count > 1:
        for c in reversed(cards):
            rt = _read_text(os.path.join(c, "device/power/runtime_status"))
            if rt:
                dgpu_state = rt
                break
    return gpu_count, dgpu_state


def _detect_fan_telemetry() -> dict:
    out: dict[str, str] = {}
    if shutil.which("fanctl"):
        try:
            raw = subprocess.check_output(["fanctl", "json"], text=True, timeout=2).strip()
            data = json.loads(raw)
            out["fan_available"] = "1"
            out["cpu_temp"] = str(round(float(data.get("temp", 0.0)), 1))
            out["fan_rpm"] = str(int(data.get("speed_rpm", 0)))
            out["fan_level"] = str(data.get("level", "auto"))
            out["fan_mode"] = str(data.get("mode", "auto"))
            out["curve_profile"] = str(data.get("curve_profile", "balanced"))
            out["cpu_mhz"] = str(int(data.get("cpu_mhz", 0)))
            out["cpu_locked"] = "1" if data.get("is_locked") else "0"
            out["auto_unstick"] = "1" if data.get("auto_unstick", True) else "0"
            out["is_shocking"] = "1" if data.get("is_shocking") else "0"
            nvmes = data.get("nvme_temps") or []
            if nvmes:
                comp = next((n for n in nvmes if "composite" in str(n.get("label", "")).lower()), nvmes[0])
                out["nvme_temp"] = str(round(float(comp.get("temp", 0.0)), 1))
            return out
        except Exception:
            pass

    # Fallback reading /proc/acpi/ibm/fan and cpufreq directly
    if os.path.exists("/proc/acpi/ibm/fan"):
        out["fan_available"] = "1"
        for line in _read_text("/proc/acpi/ibm/fan").splitlines():
            if ":" in line:
                k, v = [p.strip() for p in line.split(":", 1)]
                if k == "speed":
                    out["fan_rpm"] = v.split()[0]
                elif k == "level":
                    out["fan_level"] = v
                    out["fan_mode"] = v
    freqs = []
    for path in glob.glob("/sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq"):
        txt = _read_text(path)
        if txt.isdigit():
            freqs.append(int(txt) // 1000)
    if freqs:
        avg_mhz = sum(freqs) // len(freqs)
        out["cpu_mhz"] = str(avg_mhz)
        out["cpu_locked"] = "1" if max(freqs) <= 450 else "0"
    return out


def probe_battery() -> None:
    bat = _discover_battery()
    if bat:
        print(f"name={os.path.basename(bat)}")
        for key, fname in [
            ("cycles", "cycle_count"),
            ("start", "charge_control_start_threshold"),
            ("stop", "charge_control_end_threshold"),
        ]:
            val = _read_text(os.path.join(bat, fname))
            if val:
                print(f"{key}={val}")

        # Fallback legacy threshold sysfs names
        if not _read_text(os.path.join(bat, "charge_control_end_threshold")):
            for key, fname in [
                ("start", "charge_start_threshold"),
                ("stop", "charge_stop_threshold"),
            ]:
                val = _read_text(os.path.join(bat, fname))
                if val:
                    print(f"{key}={val}")

        volt_raw = _read_text(os.path.join(bat, "voltage_now"))
        if volt_raw.isdigit():
            print(f"voltage={int(volt_raw) / 1_000_000:.2f}")

        for f_full, f_des in [
            ("energy_full", "energy_full_design"),
            ("charge_full", "charge_full_design"),
        ]:
            full_val = _read_text(os.path.join(bat, f_full))
            if full_val:
                print(f"full={full_val}")
                des_val = _read_text(os.path.join(bat, f_des))
                if des_val:
                    print(f"design={des_val}")
                break

    loadavg = _read_text("/proc/loadavg")
    if loadavg:
        print(f"load={loadavg.split()[0]}")

    gpus, dgpu_state = _detect_dgpu_status()
    print(f"gpus={gpus}")
    if dgpu_state:
        print(f"dgpu_state={dgpu_state}")

    for k, v in _detect_power_state().items():
        print(f"{k}={v}")

    for k, v in _detect_fan_telemetry().items():
        print(f"{k}={v}")


def set_profile(target: str) -> None:
    norm = _normalize_profile(target)
    if norm not in ("power-saver", "balanced", "performance"):
        print(f"ok=false\nerror=invalid profile {target}")
        return

    if shutil.which("powerprofilesctl"):
        res = subprocess.run(
            ["powerprofilesctl", "set", norm],
            capture_output=True, text=True, check=False, timeout=5
        )
        if res.returncode == 0:
            print(f"ok=true\nprofile={norm}")
            return

    acpi_map = {
        "power-saver": "low-power",
        "balanced": "balanced",
        "performance": "performance",
    }
    # Alder Lake warning in configuration.nix: use balance_power instead of raw "power" to avoid 400MHz stall
    epp_map = {
        "power-saver": "balance_power",
        "balanced": "balance_performance",
        "performance": "performance",
    }

    acpi_val = acpi_map[norm]
    epp_val = epp_map[norm]
    cmd_parts = []
    if os.path.exists("/sys/firmware/acpi/platform_profile"):
        cmd_parts.append(f"printf '%s\\n' '{acpi_val}' > /sys/firmware/acpi/platform_profile")
    cmd_parts.append(
        f"for p in /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference; do "
        f"[ -w \"$p\" ] && printf '%s\\n' '{epp_val}' > \"$p\" || true; done"
    )
    ok, err = _run_root(" && ".join(cmd_parts))
    if ok:
        print(f"ok=true\nprofile={norm}\nepp={epp_val}")
    else:
        print(f"ok=false\nerror={err}")


def set_epp(epp: str) -> None:
    allowed = ("power", "balance_power", "balance_performance", "performance", "default")
    val = (epp or "").strip().lower()
    if val not in allowed:
        print(f"ok=false\nerror=invalid epp {epp}")
        return
    cmd = (
        f"for p in /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference; do "
        f"[ -w \"$p\" ] && printf '%s\\n' '{val}' > \"$p\" || true; done"
    )
    ok, err = _run_root(cmd)
    print(f"ok={'true' if ok else 'false'}")
    if ok:
        print(f"epp={val}")
    else:
        print(f"error={err}")


def set_turbo(state: str) -> None:
    enable = (state or "").strip().lower() in ("1", "on", "true", "enable")
    no_turbo = "0" if enable else "1"
    path = "/sys/devices/system/cpu/intel_pstate/no_turbo"
    if not os.path.exists(path):
        print("ok=false\nerror=intel_pstate no_turbo unavailable")
        return
    ok, err = _run_root(f"printf '%s\\n' '{no_turbo}' > {path}")
    print(f"ok={'true' if ok else 'false'}")
    if ok:
        print(f"turbo={'1' if enable else '0'}")
    else:
        print(f"error={err}")


def set_thresholds(start_s: str, stop_s: str) -> None:
    try:
        start_v = int(start_s)
        stop_v = int(stop_s)
    except ValueError:
        print("ok=false\nerror=invalid threshold values")
        return

    start_v = max(10, min(95, start_v))
    stop_v = max(start_v + 5, min(100, stop_v))
    bat = _discover_battery()
    bat_name = os.path.basename(bat) if bat else "BAT0"

    cmds = []
    if shutil.which("tlp"):
        cmds.append(f"tlp setcharge {start_v} {stop_v} {bat_name}")
    elif bat:
        s_path = os.path.join(bat, "charge_control_start_threshold")
        e_path = os.path.join(bat, "charge_control_end_threshold")
        cmds.append(f"[ -w '{s_path}' ] && printf '%s\\n' '{start_v}' > '{s_path}' || true")
        cmds.append(f"[ -w '{e_path}' ] && printf '%s\\n' '{stop_v}' > '{e_path}'")

    if not cmds:
        print("ok=false\nerror=charge threshold sysfs not found")
        return

    ok, err = _run_root(" && ".join(cmds), timeout=10)
    print(f"ok={'true' if ok else 'false'}")
    if ok:
        print(f"start={start_v}\nstop={stop_v}")
    else:
        print(f"error={err}")


def run_fan_action(sub: str, arg: str = "") -> None:
    if not shutil.which("fanctl"):
        print("ok=false\nerror=fanctl not installed")
        return

    if sub == "curve" and arg in ("quiet", "balanced", "aggressive"):
        cmd = ["fanctl", "curve", arg]
    elif sub == "level" and arg:
        cmd = ["fanctl", "set", arg]
    elif sub == "unstick":
        cmd = ["fanctl", "unstick"]
    elif sub == "watchdog" and arg in ("on", "off"):
        cmd = ["fanctl", "watchdog", arg]
    else:
        print("ok=false\nerror=invalid fan command")
        return

    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=5, check=False)
        ok = res.returncode == 0
        print(f"ok={'true' if ok else 'false'}")
        if not ok:
            print(f"error={(res.stderr or res.stdout).strip()}")
    except Exception as exc:
        print(f"ok=false\nerror={exc}")


def main() -> None:
    args = sys.argv[1:]
    if not args or args[0] == "probe":
        probe_battery()
        return

    cmd = args[0].lower()
    if cmd == "set-profile" and len(args) >= 2:
        set_profile(args[1])
    elif cmd == "set-epp" and len(args) >= 2:
        set_epp(args[1])
    elif cmd == "set-turbo" and len(args) >= 2:
        set_turbo(args[1])
    elif cmd == "set-thresholds" and len(args) >= 3:
        set_thresholds(args[1], args[2])
    elif cmd == "fan-curve" and len(args) >= 2:
        run_fan_action("curve", args[1])
    elif cmd == "fan-level" and len(args) >= 2:
        run_fan_action("level", args[1])
    elif cmd == "fan-unstick":
        run_fan_action("unstick")
    elif cmd == "fan-watchdog" and len(args) >= 2:
        run_fan_action("watchdog", args[1])
    else:
        probe_battery()


if __name__ == "__main__":
    main()
