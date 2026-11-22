-- # config: the brain of the operation
-- if this file breaks, the whole house of cards comes down.
-- handle with care, or don't. i'm not your boss.

-- fallback colors in case matugen hasn't run yet and our desktop looks like a sad concrete slab
local colors = {
	active_border_1 = "rgba(95CDF7ff)",
	active_border_2 = "rgba(2BB0F6ff)",
	inactive_border = "rgba(41474Dff)",
	surface = "rgba(101417ff)",
	surface_container = "rgba(1C2024ff)",
	on_primary = "rgba(00344Eff)",
	on_surface = "rgba(E0E3E8ff)",
}

-- do not touch. do not breathe near this. do not make sudden eye contact.
-- if matugen breaks, we will literally lose the only thing tethering our sanity to this computer: pretty dynamic colors.
local ok, user_colors = pcall(require, "colors")
if ok and type(user_colors) == "table" then
	for k, v in pairs(user_colors) do
		colors[k] = v
	end
end

-- swap the "ff" alpha channel on any "rgba(rrggbbaa)" string
local function alpha(rgba, hex_a)
	return rgba:sub(1, 11) .. hex_a .. ")"
end

-- cursor & system environment fixes
hl.env("XCURSOR_THEME", "Windows-Aero")
hl.env("HYPRCURSOR_THEME", "Windows-Aero")
hl.env("XCURSOR_SIZE", "24")
hl.env("TZDIR", "/etc/zoneinfo")
hl.env("TZ", "America/Chicago")
hl.env("QT_LOGGING_RULES", "quickshell.dbus.warning=false;quickshell.service.powerprofiles.warning=false")
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("QT_STYLE_OVERRIDE", "Breeze")

hl.config({
	general = {
		layout = "dwindle",
		-- gaps are just empty space for the soul to breathe (or to peek at our wallpaper)
		gaps_out = 10,
		border_size = 2,

		-- clean solid borders, no gradient nonsense
		col = {
			active_border = colors.active_border_1,
			inactive_border = colors.inactive_border,
		},
	},

	cursor = {
		hide_on_key_press = false,
		hide_on_tablet = true,
		hide_on_touch = true,
		inactive_timeout = 0.0,
	},

	animations = {
		-- animations are true because we love buttery-smooth frame drops
		enabled = true,
	},

	decoration = {
		-- 16px round corners because sharp edges are a hazard to my health
		rounding = 16,
		-- 2.0 is a circle, 4.0 is a squircle. keeping it at 2.0 because squircles sound like a weird custom plugin that crashed wayland
		rounding_power = 2.0,
		dim_inactive = false,
		shadow = {
			render_power = 4,
			color = alpha(colors.surface, "cc"),
		},
		blur = {
			-- look, hyprmod enabled blur. so yes we are doing blur now. if my thinkpad explodes because of 2 passes of blur, so be it
			enabled = true,
			size = 4,
			passes = 2,
			new_optimizations = true,
			ignore_opacity = true,
			xray = false,
			noise = 0.015,
			contrast = 1.0,
			vibrancy = 0.15,
			popups = false,
		},
	},

	group = {
		col = {
			border_active = colors.active_border_1,
			border_inactive = colors.inactive_border,
		},
		groupbar = {
			text_color = colors.on_primary,
			text_color_inactive = colors.on_surface,
			col = {
				active = colors.active_border_1,
				inactive = colors.surface_container,
			},
		},
	},

	ecosystem = {
		-- ecosystem permissions is false because we are not a security analyst, we just want our custom stuff to run without crying
		enforce_permissions = false,
	},

	input = {
		touchpad = {
			-- disable while typing is false because we like living on the edge and typing on a laptop trackpad without palm rejection is a true test of strength (or to play roblox)
			disable_while_typing = false,
		},
	},

	misc = {
		force_default_wallpaper = 1,
		-- thank god we can disable the classic anime mascot wallpaper from staring into our soul
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		background_color = colors.surface,
	},

	xwayland = {
		enabled = true,
		-- force zero scaling is false so electron apps don't turn into a blurry, pixelated soup from 2005
		force_zero_scaling = false,
		use_nearest_neighbor = false,
	},
})
