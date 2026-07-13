-- Reglas para ventanas específicas
-- Forzar opacidad completa en Zen para mantener transparencia
hl.window_rule({
    match = { class = "zen-browser" },
    opaque = false,
    force_dim_special = 0,
    dimaround = false,
})
