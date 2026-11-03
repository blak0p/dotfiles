-- Keybinds personalizados (se cargan al final, pisan los de end-4)
-- Parte pública: window management, workspaces sync, navegación
-- Los binds privados se cargan desde keybinds-extra.lua si existe localmente

-- Launcher
hl.bind("SUPER + Space", hl.dsp.global("quickshell:launcherToggle"), { description = "Shell: Toggle launcher" })

-- Screen snip (Ctrl + Win + S)
hl.bind("CTRL + SUPER + S", hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/screenshot-region.sh"), { description = "Utilities: Screen snip" })

-- Screen record toggle (Super + Alt + R, Super + Shift + R, Ctrl + Alt + R)
hl.bind("SUPER + ALT + R", hl.dsp.exec_cmd("bash " .. HOME .. "/.config/hypr/scripts/record.sh --fullscreen"), { locked = true, description = "Utilities: Record screen toggle" })
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("bash " .. HOME .. "/.config/hypr/scripts/record.sh"), { locked = true, description = "Utilities: Record region toggle" })
hl.bind("CTRL + ALT + R", hl.dsp.exec_cmd("bash " .. HOME .. "/.config/hypr/scripts/record.sh --fullscreen"), { locked = true })
hl.bind("CTRL + ALT + r", hl.dsp.exec_cmd("bash " .. HOME .. "/.config/hypr/scripts/record.sh --fullscreen"), { locked = true })


-- Rename workspace: Dynamic Island modal con Win+R
hl.bind("SUPER + R", hl.dsp.global("quickshell:workspaceRenameToggle"), { description = "Workspace: Rename active (Dynamic Island)" })


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

-- Workspace sync: cambian AMBOS monitores a la vez (en vez de workspace groups)
for i = 1, 10 do
    hl.bind("SUPER + " .. (i % 10), function()
        ws_both(i)
    end, { description = "Workspace sync: Focus " .. i })
end
for i = 1, 10 do
    local numpadkey = { 87, 88, 89, 83, 84, 85, 79, 80, 81, 90 }
    hl.bind("SUPER + code:" .. numpadkey[i], function()
        ws_both(i)
    end)
end

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
