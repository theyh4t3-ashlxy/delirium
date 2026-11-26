--[[
real spring physics for spatial stuff, fitted beziers for fades/exits.
tuned for 1920x1200@60hz (340x220mm 16:10, 8px outer margin, eDP laptop).
note: hyprland 0.57+ renamed `dampening` -> `damping`. swap it back if you're on 0.55/0.56.
]]

-- alive window open: soft inertia launch, subtle +2% breath (+3.8px max edge), melts to rest
hl.curve("openSpring", {
    type = "spring",
    mass = 1.0,
    stiffness = 503.6,
    damping = 35.0,
})

-- glass-pane glide for moves & workspaces: near-critically damped (0% bounce, soft cushion)
hl.curve("glideSpring", {
    type = "spring",
    mass = 1.0,
    stiffness = 438.6,
    damping = 41.1,
})

-- lighter spring for menus/notifs so small ui feels nimble
hl.curve("layerSpring", {
    type = "spring",
    mass = 1.0,
    stiffness = 685.4,
    damping = 46.1,
})

-- least-squares fitted to openSpring so opacity & borders breathe with the same momentum
hl.curve("organicFade", {
    type = "bezier",
    points = { { 0.16, 0.00 }, { 0.37, 0.98 } },
})

-- gentle release that accelerates smoothly away instead of slamming into a wall
hl.curve("softExit", {
    type = "bezier",
    points = { { 0.38, 0.08 }, { 0.74, 0.60 } },
})

hl.curve("linear", {
    type = "bezier",
    points = { { 0.0, 0.0 }, { 1.0, 1.0 } },
})

-- springs ignore `speed`, keeping sensible fallbacks anyway because hyprland's example config does
hl.animation({
    leaf = "global",
    enabled = true,
    speed = 2.5,
    spring = "glideSpring",
})

hl.animation({
    leaf = "windows",
    enabled = true,
    speed = 2.5,
    spring = "glideSpring",
    style = "popin 80%",
})

hl.animation({
    leaf = "windowsIn",
    enabled = true,
    speed = 2.8,
    spring = "openSpring",
    style = "popin 80%",
})

hl.animation({
    leaf = "windowsOut",
    enabled = true,
    speed = 1.66, -- 10f @ 60hz
    bezier = "softExit",
    style = "popin 80%",
})

hl.animation({
    leaf = "windowsMove",
    enabled = true,
    speed = 2.8,
    spring = "glideSpring",
    style = "slide",
})

-- fades synced to the spring envelopes (and explicitly set so closing layers don't inherit a ghost tail)
hl.animation({
    leaf = "fade",
    enabled = true,
    speed = 2.0,
    bezier = "organicFade",
})

hl.animation({
    leaf = "fadeIn",
    enabled = true,
    speed = 2.0, -- hits 100% solid at frame 12 right as openSpring crests its +2% breath
    bezier = "organicFade",
})

hl.animation({
    leaf = "fadeOut",
    enabled = true,
    speed = 1.66,
    bezier = "softExit",
})

hl.animation({
    leaf = "fadeLayersIn",
    enabled = true,
    speed = 1.5,
    bezier = "organicFade",
})

hl.animation({
    leaf = "fadeLayersOut",
    enabled = true,
    speed = 1.33,
    bezier = "softExit",
})

hl.animation({
    leaf = "fadePopupsIn",
    enabled = true,
    speed = 1.16,
    bezier = "organicFade",
})

hl.animation({
    leaf = "fadePopupsOut",
    enabled = true,
    speed = 1.0,
    bezier = "softExit",
})

-- 15% of 340mm (51mm) and 22% of 220mm (48.4mm) so both axes feel like the same physical slide
hl.animation({
    leaf = "workspaces",
    enabled = true,
    speed = 2.8,
    spring = "glideSpring",
    style = "slidefade 15%",
})

hl.animation({
    leaf = "specialWorkspace",
    enabled = true,
    speed = 2.8,
    spring = "glideSpring",
    style = "slidefadevert 22%",
})

hl.animation({
    leaf = "layers",
    enabled = true,
    speed = 2.0,
    spring = "layerSpring",
    style = "fade",
})

hl.animation({
    leaf = "layersIn",
    enabled = true,
    speed = 2.0,
    spring = "layerSpring",
    style = "popin 90%",
})

hl.animation({
    leaf = "layersOut",
    enabled = true,
    speed = 1.33,
    bezier = "softExit",
    style = "popin 90%",
})

hl.animation({
    leaf = "border",
    enabled = true,
    speed = 2.0,
    bezier = "organicFade",
})

-- please keep this on "once" (or false) on a laptop, "loop" burns 60fps idle redraws 24/7
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
    speed = 2.5,
    spring = "glideSpring",
})
