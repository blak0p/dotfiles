-- This file will not be overwritten across dots-hyprland updates.
-- The file name is for the sake of organization and does not matter
-- See the corresponding files in ~/.config/hypr/hyprland for examples

-- Animaciones de ventana estilo Minflair
hl.curve("ease", { type = "bezier", points = { { 0.25, 0.1 }, { 0.25, 1.0 } } })
hl.curve("overshot", { type = "bezier", points = { { 0.13, 0.99 }, { 0.29, 1.05 } } })

hl.animation({ leaf = "windowsIn", enabled = true, speed = 5, bezier = "overshot", style = "slide bottom" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 5, bezier = "ease", style = "slide bottom" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5, bezier = "overshot", style = "slide" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "overshot", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 5, bezier = "overshot", style = "slidevert" })

-- Bordes visibles para ventanas
hl.config({
    general = {
        border_size = 2,
        col = {
            active_border = "rgba(ffffff30)",
            inactive_border = "rgba(ffffff00)"
        }
    }
})
