#!/usr/bin/env zsh
# Probe if Brain_Shell is installed
src="${1:-$HOME/.local/src/Brain_Shell}"
conf="${2:-$HOME/.config/Brain_Shell}"

if [[ -d "$src" || -d "$conf" ]]; then
    exit 0
fi

exit 1
