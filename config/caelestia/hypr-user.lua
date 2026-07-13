hl.monitor({
    output   = "HDMI-A-2",
    mode     = "1920x1080@60",
    position = "0x0",
    scale    = 1,
})

hl.monitor({
    output   = "DP-2",
    mode     = "2560x1440@144",
    position = "1920x0",
    scale    = 1,
})

-- Distrobox bunker
local vars = require("variables")
hl.bind("SUPER + D", hl.dsp.exec_cmd(vars.terminal .. " -e distrobox enter bunker"))

-- Steam autopicture toggle
hl.bind("SUPER + B", hl.dsp.exec_cmd("/home/alejndro/scripts/steam_toggle.sh"))

-- Cambiar audio
hl.bind("SUPER + S", hl.dsp.exec_cmd("/home/alejndro/scripts/cambiar_audio.sh"))
