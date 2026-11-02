#!/usr/bin/env zsh
# Terminal system monitor launcher with fallbacks
mode="${1:-cpu}"

if [ "$mode" = "gpu" ]; then
    if command -v nvtop >/dev/null 2>&1; then
        exec nvtop
    fi
    exec top
else
    for cmd in btop htop top; do
        if command -v "$cmd" >/dev/null 2>&1; then
            exec "$cmd"
        fi
    done
fi
