#!/usr/bin/env zsh
# Auto-detects primary backlight device from sysfs
for dev in /sys/class/backlight/*(N); do
    print -- "${dev:t}"
    exit 0
done
