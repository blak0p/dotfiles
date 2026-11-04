-- Spotify (transparente): opacidad con foco / sin foco
-- WM_CLASS reportado es "Spotify" (S mayúscula); match case-insensitive por si acaso
hl.window_rule({match = {class = "^[Ss]potify$"}, opacity = "0.90 0.85"})

-- Vesktop (Discord transparente): opacidad con foco / sin foco
hl.window_rule({match = {class = "^(vesktop)$"}, opacity = "0.94 0.94"})

-- Dolphin: integración visual con el shell, sin sacrificar legibilidad
hl.window_rule({match = {class = "^(org\\.kde\\.dolphin|dolphin)$"}, opacity = "0.94 0.88"})
hl.window_rule({match = {class = "^(virt-manager)$"}, opacity = "1.0 1.0"})
hl.window_rule({name = "virt-manager", match = {class = "^(virt-manager)$"}, float = true, center = true, size = {1100, 750}})
