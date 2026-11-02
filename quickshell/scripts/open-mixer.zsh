#!/usr/bin/env zsh
# Fallback runner for audio control panel
mixers=(pavucontrol pwcc pipewire-control-center easyeffects helvum)

for mixer in "${mixers[@]}"; do
    if command -v "$mixer" >/dev/null 2>&1; then
        exec "$mixer" "$@"
    fi
done
