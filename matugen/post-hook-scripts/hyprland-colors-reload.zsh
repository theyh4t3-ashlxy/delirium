#!/usr/bin/env zsh
# hyprland-colors-reload.zsh - hot-swap matugen palette in Hyprland's Lua VM without a full `hyprctl reload`
# Avoids wiping runtime `hl.config` / `hl.workspace_rule` overrides (like active non-dwindle layouts).

[[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || exit 0
command -v hyprctl >/dev/null 2>&1 || exit 0

read -r -d '' lua_code <<'EOF'
package.loaded.colors = nil
local ok, c = pcall(require, "colors")
if not ok or type(c) ~= "table" then
    error("colors.lua unavailable")
end
local function alpha(rgba, hex_a)
    if type(rgba) ~= "string" or #rgba < 11 then return rgba end
    return rgba:sub(1, 11) .. hex_a .. ")"
end
hl.config({
    general = {
        col = {
            active_border = c.active_border_1,
            inactive_border = c.inactive_border,
        },
    },
    decoration = {
        shadow = {
            color = alpha(c.surface, "cc"),
        },
    },
    group = {
        col = {
            border_active = c.active_border_1,
            border_inactive = c.inactive_border,
        },
        groupbar = {
            text_color = c.on_primary,
            text_color_inactive = c.on_surface,
            col = {
                active = c.active_border_1,
                inactive = c.surface_container,
            },
        },
    },
    misc = {
        background_color = c.surface,
    },
})
EOF

out=$(hyprctl eval "$lua_code" 2>/dev/null)
if [[ "$out" != "ok" ]]; then
    hyprctl reload 2>/dev/null || true
fi
