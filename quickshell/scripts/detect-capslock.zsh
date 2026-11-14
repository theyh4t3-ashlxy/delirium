#!/usr/bin/env zsh
# checks if capslock is currently active via sysfs
for f in /sys/class/leds/*capslock*/brightness(N); do
    if [[ -f "$f" ]] && [[ "$(< "$f" 2>/dev/null)" == "1" ]]; then
        print -- "1"
        exit 0
    fi
done
print -- "0"
