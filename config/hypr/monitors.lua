-- Monitores en serie
-- HDMI-A-2 (1080p) a la izquierda, DP-2 (1440p) a la derecha (principal)

hl.monitor({
    output = "HDMI-A-2",
    mode = "1920x1080@60",
    position = "0x0",
    scale = 1
})

hl.monitor({
    output = "DP-2",
    mode = "2560x1440@144",
    position = "1920x0",
    scale = 1
})
