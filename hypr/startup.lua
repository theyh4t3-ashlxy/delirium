-- autostart stuff that runs when hyprland starts

local wp = "awww-daemon --format argb"
hl.on("hyprland.start", function()
	hl.exec_cmd(wp)
	hl.exec_cmd("qs -d")
	hl.exec_cmd("hyprctl setcursor Windows-Aero 24")
end)
