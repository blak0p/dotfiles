-- Keybinds personalizados (se cargan al final, pisan los de end-4)
-- Parte pública: window management, workspaces sync, navegación
-- Tus binds personales van en ~/.config/sky/hypr/keybinds.lua (capa de usuario)

-- Launcher
hl.bind("SUPER + Space", hl.dsp.global("quickshell:launcherToggle"), { description = "Shell: Toggle launcher" })

-- Screen snip (Ctrl + Win + S)
hl.bind("CTRL + SUPER + S", hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/screenshot-region.sh"), { description = "Utilities: Screen snip" })

-- Screen record toggle (Super + Alt + R, Super + Shift + R, Ctrl + Alt + R)
hl.bind("SUPER + ALT + R", hl.dsp.exec_cmd("bash " .. HOME .. "/.config/hypr/scripts/record.sh --fullscreen"), { locked = true, description = "Utilities: Record screen toggle" })
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("bash " .. HOME .. "/.config/hypr/scripts/record.sh"), { locked = true, description = "Utilities: Record region toggle" })
hl.bind("CTRL + ALT + R", hl.dsp.exec_cmd("bash " .. HOME .. "/.config/hypr/scripts/record.sh --fullscreen"), { locked = true })

-- Instant replay (sky ReplayService, gpu-screen-recorder): save the last seconds as a clip
hl.bind("ALT + F10", hl.dsp.global("quickshell:replaySave"), { locked = true, description = "Shell: Save replay clip" })
hl.bind("SUPER + ALT + F10", hl.dsp.global("quickshell:replayToggle"), { description = "Shell: Toggle instant replay" })
hl.bind("SUPER + ALT + C", hl.dsp.global("quickshell:replayGallery"), { description = "Shell: Open clips" })
hl.bind("CTRL + ALT + r", hl.dsp.exec_cmd("bash " .. HOME .. "/.config/hypr/scripts/record.sh --fullscreen"), { locked = true })




-- Window management (pisan los de end-4)
hl.bind("SUPER + C", hl.dsp.window.close(), { description = "Window: Close" })
hl.bind("SUPER + F",
    hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }),
    { description = "Window: Fullscreen" })

-- Navegación ventanas (Win + J/K)
hl.bind("SUPER + J", hl.dsp.window.cycle_next(),
    { repeating = true, description = "Window: Cycle next" })
hl.bind("SUPER + K", hl.dsp.window.cycle_next({ next = false }),
    { repeating = true, description = "Window: Cycle prev" })

-- Mover ventana entre monitores
hl.bind("SUPER + left", hl.dsp.window.move({ monitor = "-1" }),
    { description = "Window: Move to left monitor" })
hl.bind("SUPER + right", hl.dsp.window.move({ monitor = "+1" }),
    { description = "Window: Move to right monitor" })

-- Navegación entre monitores (Win + H/L)
hl.bind("SUPER + H", hl.dsp.focus({ monitor = "-1" }),
    { description = "Monitor: Focus left" })
hl.bind("SUPER + L", hl.dsp.focus({ monitor = "+1" }),
    { description = "Monitor: Focus right" })

-- Workspace navigation (Ctrl + Win + H/L)
hl.bind("CTRL + SUPER + H", hl.dsp.focus({ workspace = "r-1" }),
    { description = "Workspace: Previous" })
hl.bind("CTRL + SUPER + L", hl.dsp.focus({ workspace = "r+1" }),
    { description = "Workspace: Next" })

-- Mover ventana con flechas + Shift
hl.bind("SUPER + SHIFT + left", hl.dsp.window.move({ direction = "l" }),
    { description = "Window: Move left" })
hl.bind("SUPER + SHIFT + right", hl.dsp.window.move({ direction = "r" }),
    { description = "Window: Move right" })
hl.bind("SUPER + SHIFT + up", hl.dsp.window.move({ direction = "u" }),
    { description = "Window: Move up" })
hl.bind("SUPER + SHIFT + down", hl.dsp.window.move({ direction = "d" }),
    { description = "Window: Move down" })

-- Enviar ventana a workspace (global, no grupal)
for i = 1, 10 do
    hl.bind("SUPER + ALT + " .. (i % 10), function()
        hl.dispatch(hl.dsp.window.move({ workspace = i, follow = false }))
    end, { description = "Window: Send to workspace " .. i })
end
for i = 1, 10 do
    local numpadkey = { 87, 88, 89, 83, 84, 85, 79, 80, 81, 90 }
    hl.bind("SUPER + ALT + code:" .. numpadkey[i], function()
        hl.dispatch(hl.dsp.window.move({ workspace = i, follow = false }))
    end)
end

-- Wallpaper picker: while the strip is open the shell enters the "wallpapers"
-- submap, so the arrows (and h/l) move between wallpapers instead of going to the window
-- below. Escape is universal, so it always gets you out.
hl.define_submap("wallpapers", function()
    hl.bind("Left", hl.dsp.global("quickshell:wallpaperPrev"),
        { repeating = true, description = "Wallpaper: Previous" })
    hl.bind("Right", hl.dsp.global("quickshell:wallpaperNext"),
        { repeating = true, description = "Wallpaper: Next" })
    hl.bind("H", hl.dsp.global("quickshell:wallpaperPrev"),
        { repeating = true, description = "Wallpaper: Previous (vim)" })
    hl.bind("L", hl.dsp.global("quickshell:wallpaperNext"),
        { repeating = true, description = "Wallpaper: Next (vim)" })
    hl.bind("Return", hl.dsp.global("quickshell:wallpaperApply"),
        { description = "Wallpaper: Apply" })
    hl.bind("Escape", hl.dsp.global("quickshell:wallpaperClose"),
        { description = "Wallpaper: Close" })
end)
