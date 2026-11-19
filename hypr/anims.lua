-- 1. Curves (Mathematically tuned via Python)
hl.curve("superSnappy", {
    type = "bezier",
    points = { { 0.14, 1.42 }, { 0.38, 1.0 } }, -- Fast 81ms snap, +5.8% curve bounce (+1.16% at popin 80%), clean settle
})

hl.curve("fluidOut", {
    type = "bezier",
    points = { { 0.22, 1.0 }, { 0.36, 1.0 } }, -- Quintic ease-out: 0% overshoot, hits 90% travel in 37.5% of duration
})

hl.curve("cleanExit", {
    type = "bezier",
    points = { { 0.30, 0.75 }, { 0.80, 1.0 } }, -- Eliminates the 138ms semi-transparent ghost tail on closing windows
})

hl.curve("linear", {
    type = "bezier",
    points = { { 0.0, 0.0 }, { 1.0, 1.0 } },
})

-- Optional Hyprland 0.55+ Native Physics Spring (ODE solved: zeta=0.776, +2.1% peak at 203ms, 99.9% settled at 337ms)
-- To test this on windowsIn, change `bezier = "superSnappy"` to `spring = "snappySpring"`
hl.curve("snappySpring", {
    type = "spring",
    mass = 1.0,
    stiffness = 600.0,
    dampening = 38.0,
})

-- 2. Global Base
hl.animation({
    leaf = "global",
    enabled = true,
    speed = 3.0,
    bezier = "fluidOut",
})

-- 3. Windows (Split into In, Out, and Move so retiling doesn't overshoot by 91px)
hl.animation({
    leaf = "windows",
    enabled = true,
    speed = 3.0,
    bezier = "fluidOut",
    style = "popin 80%",
})

hl.animation({
    leaf = "windowsIn",
    enabled = true,
    speed = 3.0,
    bezier = "superSnappy",
    style = "popin 80%",
})

hl.animation({
    leaf = "windowsOut",
    enabled = true,
    speed = 1.6,
    bezier = "cleanExit",
    style = "popin 80%",
})

hl.animation({
    leaf = "windowsMove",
    enabled = true,
    speed = 2.8,
    bezier = "fluidOut",
    style = "slide",
})

-- 4. Fades (Synced with windowsIn and windowsOut)
hl.animation({
    leaf = "fade",
    enabled = true,
    speed = 2.2,
    bezier = "fluidOut",
})

hl.animation({
    leaf = "fadeIn",
    enabled = true,
    speed = 2.2, -- Finishes 80ms before windowsIn (300ms) so window is solid during bounce settle
    bezier = "fluidOut",
})

hl.animation({
    leaf = "fadeOut",
    enabled = true,
    speed = 1.6, -- Exact 160ms match with windowsOut
    bezier = "cleanExit",
})

-- 5. Workspaces & Special Workspaces
hl.animation({
    leaf = "workspaces",
    enabled = true,
    speed = 3.0,
    bezier = "fluidOut",
    style = "slidefade 15%",
})

hl.animation({
    leaf = "specialWorkspace",
    enabled = true,
    speed = 2.8,
    bezier = "fluidOut",
    style = "slidefadevert 15%",
})

-- 6. Layers (Menus, Rofi/Wofi, Notifications)
hl.animation({
    leaf = "layers",
    enabled = true,
    speed = 2.2,
    bezier = "fluidOut",
    style = "fade",
})

hl.animation({
    leaf = "layersIn",
    enabled = true,
    speed = 2.2,
    bezier = "fluidOut",
    style = "popin 90%",
})

hl.animation({
    leaf = "layersOut",
    enabled = true,
    speed = 1.5,
    bezier = "cleanExit",
    style = "popin 90%",
})

-- 7. Borders
hl.animation({
    leaf = "border",
    enabled = true,
    speed = 1.8,
    bezier = "fluidOut", -- Prevents RGB color clamping from overshooting curve
})

hl.animation({
    leaf = "borderangle",
    enabled = true,
    speed = 30.0,
    bezier = "linear",
    style = "loop", -- Tip: change to "once" if on a laptop to save idle GPU battery drain
})
