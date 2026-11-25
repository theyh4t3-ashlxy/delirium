# pkgs/fan-control

thermal intervention daemon and cli frontend for the `ThinkPad T16 Gen 1` (`21BWS23200`).

lenovo calibrates stock embedded controller tables for quiet corporate offices where audible fan draw offends conference-call ergonomics. firmware prefers soaking chassis plastic until `BAT0` degrades to `83.1%` health (`43.6 / 52.5 Wh`, sitting at `14.14 V` below nominal minimum) and tripping false-positive `BD PROCHOT` latches—clamping all twelve `i7-1260P` cores into a `400 MHz` coma—over spinning up the cooler. this package strips firmware of discretion.

## modules

- `fanctl`: standalone python cli inspecting thermal sensors, polling tachometer rpm, writing raw EC states (`0`–`7`, `auto`, `full-speed`), and applying dynamic fan curves (`quiet`, `balanced`, `performance`).
- `daemon.py`: privileged d-bus service (`org.thinkpad.FanControl`) writing straight into `/proc/acpi/ibm/fan` and hwmon sysfs nodes without asking `powerprofilesctl` for permission.
- `watchdog.py`: frequency monitor polling core clocks under load. whenever clocks crash below `500 MHz` behind a stuck prochot flag, it forces full-speed fan pulses until the throttle register clears. if the bearing starts clicking from long sessions at max rpm, leave it.
- `default.nix`: nix derivation packaging python3, pygobject3, gtk4, and libadwaita dependencies.

## usage

```zsh
fanctl status        # print temp, fan rpm, and active curve
fanctl curve quiet   # reduce fan draw on battery
fanctl max           # hold maximum thermal evacuation
fanctl auto          # hand register control back to lenovo bios
```
