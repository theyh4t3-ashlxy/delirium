--[[
delirium motion profile: phase-matched springs + least-squares cubic beziers.
solved via python damped-oscillator & frame-delta model for 1920x1200@60hz (340x220mm).
note: hyprland 0.57+ uses `damping` (older 0.55/0.56 used `dampening`).
]]

-- lucid window bloom: wn=18.99 rad/s, zeta=0.869, +0.41% breath (~0.6px), 99.5% @ 260ms (~15.6f)
hl.curve("bloomSpring", {
    type = "spring",
    mass = 1.0,
    stiffness = 360.8,
    damping = 33.0,
})

-- zero-bounce dwindle & workspace glide: wn=24.23 rad/s, zeta=0.984, 0.00% overshoot, 99.5% @ 294ms (~17.7f)
hl.curve("driftSpring", {
    type = "spring",
    mass = 1.0,
    stiffness = 587.3,
    damping = 47.7,
})

-- airy overlay & popup spring: wn=28.08 rad/s, zeta=0.892, +0.20% polish, 99.5% @ 190ms (~11.4f)
hl.curve("veilSpring", {
    type = "spring",
    mass = 1.0,
    stiffness = 788.4,
    damping = 50.1,
})

-- fitted to bloomSpring opening envelope (RMSE=0.0070, p2y=0.99 avoids alpha clamping)
hl.curve("lucidIn", {
    type = "bezier",
    points = { { 0.18, 0.00 }, { 0.36, 0.99 } },
})

-- fitted to k=3.2 exponential release (RMSE=0.0069): responds on frame 1 (~26%), dissolves softly
hl.curve("silkOut", {
    type = "bezier",
    points = { { 0.23, 0.83 }, { 0.70, 0.99 } },
})

-- fitted to driftSpring for focus border, dim, and shadow shifts (RMSE=0.0063)
hl.curve("focusGlide", {
    type = "bezier",
    points = { { 0.24, 0.19 }, { 0.19, 0.99 } },
})

hl.curve("linear", {
    type = "bezier",
    points = { { 0.0, 0.0 }, { 1.0, 1.0 } },
})

-- springs ignore `speed`, keeping matched values for fallback parity
hl.animation({
    leaf = "global",
    enabled = true,
    speed = 2.6,
    spring = "driftSpring",
})

hl.animation({
    leaf = "windows",
    enabled = true,
    speed = 2.6,
    spring = "driftSpring",
    style = "popin 84%",
})

hl.animation({
    leaf = "windowsIn",
    enabled = true,
    speed = 2.6,
    spring = "bloomSpring",
    style = "popin 84%",
})

hl.animation({
    leaf = "windowsOut",
    enabled = true,
    speed = 1.9, -- 11.4f @ 60hz, locked 1:1 with fadeOut
    bezier = "silkOut",
    style = "popin 88%",
})

hl.animation({
    leaf = "windowsMove",
    enabled = true,
    speed = 2.6,
    spring = "driftSpring",
    style = "slide",
})

-- fade timings phase-locked to geometry motion
hl.animation({
    leaf = "fade",
    enabled = true,
    speed = 2.1,
    bezier = "lucidIn",
})

hl.animation({
    leaf = "fadeIn",
    enabled = true,
    speed = 2.1, -- solid alpha right as bloomSpring crosses 95%
    bezier = "lucidIn",
})

hl.animation({
    leaf = "fadeOut",
    enabled = true,
    speed = 1.9,
    bezier = "silkOut",
})

hl.animation({
    leaf = "fadeSwitch",
    enabled = true,
    speed = 2.0,
    bezier = "focusGlide",
})

hl.animation({
    leaf = "fadeShadow",
    enabled = true,
    speed = 2.0,
    bezier = "focusGlide",
})

hl.animation({
    leaf = "fadeDim",
    enabled = true,
    speed = 2.2,
    bezier = "focusGlide",
})

hl.animation({
    leaf = "fadeLayersIn",
    enabled = true,
    speed = 1.6,
    bezier = "lucidIn",
})

hl.animation({
    leaf = "fadeLayersOut",
    enabled = true,
    speed = 1.5,
    bezier = "silkOut",
})

hl.animation({
    leaf = "fadePopupsIn",
    enabled = true,
    speed = 1.3,
    bezier = "lucidIn",
})

hl.animation({
    leaf = "fadePopupsOut",
    enabled = true,
    speed = 1.2,
    bezier = "silkOut",
})

-- physical slide parity on 340x220mm panel: 16% -> 54.4mm horiz, 25% -> 55.0mm vert
hl.animation({
    leaf = "workspaces",
    enabled = true,
    speed = 2.8,
    spring = "driftSpring",
    style = "slidefade 16%",
})

hl.animation({
    leaf = "specialWorkspace",
    enabled = true,
    speed = 2.8,
    spring = "driftSpring",
    style = "slidefadevert 25%",
})

hl.animation({
    leaf = "layers",
    enabled = true,
    speed = 1.9,
    spring = "veilSpring",
    style = "fade",
})

hl.animation({
    leaf = "layersIn",
    enabled = true,
    speed = 1.9,
    spring = "veilSpring",
    style = "popin 92%",
})

hl.animation({
    leaf = "layersOut",
    enabled = true,
    speed = 1.5,
    bezier = "silkOut",
    style = "popin 92%",
})

hl.animation({
    leaf = "border",
    enabled = true,
    speed = 2.0,
    bezier = "focusGlide",
})

-- keep "once" on battery so idle frames stay zero
hl.animation({
    leaf = "borderangle",
    enabled = true,
    speed = 25.0,
    bezier = "linear",
    style = "once",
})

hl.animation({
    leaf = "zoomFactor",
    enabled = true,
    speed = 2.6,
    spring = "driftSpring",
})
