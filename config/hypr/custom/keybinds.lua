-- Keybinds personalizados (se cargan al final, pisan los de end-4)

-- Launcher
hl.bind("SUPER + Space", hl.dsp.global("quickshell:searchToggleRelease"), { description = "Shell: Toggle search" })

-- Apps
-- SUPER + Return ya está en keybinds.lua con terminal="kitty"
hl.bind("SUPER + E", hl.dsp.exec_cmd("thunar"), { description = "App: File manager" })

-- Scripts
hl.bind("SUPER + B", hl.dsp.exec_cmd("$HOME/scripts/steam_toggle.sh"), { description = "Script: Steam toggle" })
hl.bind("SUPER + S", hl.dsp.exec_cmd("$HOME/scripts/cambiar_audio.sh"), { description = "Script: Audio toggle" })
hl.bind(
  "SUPER + U",
  hl.dsp.exec_cmd('/usr/bin/kitty -e /usr/bin/distrobox-enter --name bunker -- fish -C "cd /home/alejndro/dev"'),
  { description = "App: Distrobox dev" }
)

-- Window management
hl.bind("SUPER + C", hl.dsp.window.close(), { description = "Window: Close" })
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), { description = "Window: Fullscreen" })

-- Mover ventana entre monitores (Win + flechas)
hl.bind("SUPER + left", hl.dsp.window.move({ monitor = "-1" }), { description = "Window: Move to left monitor" })
hl.bind("SUPER + right", hl.dsp.window.move({ monitor = "+1" }), { description = "Window: Move to right monitor" })

-- Navegación entre monitores (Win + H/L)
hl.bind("SUPER + H", hl.dsp.focus({ monitor = "-1" }), { description = "Monitor: Focus left" })
hl.bind("SUPER + L", hl.dsp.focus({ monitor = "+1" }), { description = "Monitor: Focus right" })

-- Navegación ventanas (Win + J/K)
hl.bind("SUPER + J", hl.dsp.window.cycle_next(), { repeating = true, description = "Window: Cycle next" })
hl.bind("SUPER + K", hl.dsp.window.cycle_next({ next = false }), { repeating = true, description = "Window: Cycle prev" })

-- Workspaces (Win + 1-9)
for i = 1, 10 do
    hl.bind("SUPER + " .. (i % 10), function()
        hl.dispatch(hl.dsp.focus({ workspace = i }))
    end, { description = "Workspace: Focus " .. i })
end

-- Mover ventana a workspace (Win + Shift + 1-9)
for i = 1, 10 do
    hl.bind("SUPER + SHIFT + " .. (i % 10), function()
        hl.dispatch(hl.dsp.window.move({ workspace = i, follow = false }))
    end, { description = "Window: Move to workspace " .. i })
end

-- Mover ventana con flechas + Shift (Win + Shift + flechas)
hl.bind("SUPER + SHIFT + left", hl.dsp.window.move({ direction = "l" }), { description = "Window: Move left" })
hl.bind("SUPER + SHIFT + right", hl.dsp.window.move({ direction = "r" }), { description = "Window: Move right" })
hl.bind("SUPER + SHIFT + up", hl.dsp.window.move({ direction = "u" }), { description = "Window: Move up" })
hl.bind("SUPER + SHIFT + down", hl.dsp.window.move({ direction = "d" }), { description = "Window: Move down" })
