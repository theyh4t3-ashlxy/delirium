#!/usr/bin/env zsh
# Write content to file, creating parent directories if needed
target="$1"
content="${2:-true}"

if [[ -z "$target" ]]; then
    exit 1
fi

mkdir -p "${target:h}"
print -r -- "$content" > "$target"
