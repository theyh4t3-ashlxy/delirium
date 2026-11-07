# fan-control

hardware thermal containment daemon and cli frontend for the thinkpad t16 gen 1.

because lenovo's embedded controller firmware is an unmitigated disaster that trips false-positive bd prochot thermal flags and clamps the alder lake i7-1260p to a comatose 400mhz while idling at 42°c.

## components
- `fanctl`: standalone python cli tool for inspecting fan speed, sensor temperatures, setting manual levels (0-7, auto, full-speed), or switching dynamic fan curves (`quiet`, `balanced`, `performance`).
- `daemon.py`: root-level d-bus system daemon (`org.thinkpad.FanControl`) communicating directly with `/proc/acpi/ibm/fan` and sysfs hwmon sensors.
- `watchdog.py`: the anti-prochot defibrillator. polls cpu core frequencies; if frequencies plunge below 500mhz under active load, it shocks the ec registers with full-speed fan bursts to force-clear the throttle latch.
- `default.nix`: native nix derivation packaged with python3, pygobject3, gtk4, and libadwaita hooks.

## usage
```zsh
fanctl status        # print current temp, fan rpm, and profile
fanctl curve quiet   # engage quiet thermal curve
fanctl max           # emergency full-speed jet engine mode
fanctl auto          # hand control back to bios firmware
```
