-- Keybinds personalizados (se cargan al final, pisan los de end-4)

-- Launcher
hl.bind("SUPER + Space", hl.dsp.global("quickshell:searchToggleRelease"), { description = "Shell: Toggle search" })

-- Apps
-- SUPER + Return ya está en keybinds.lua con terminal="kitty"
--hl.bind("SUPER + E", hl.dsp.exec_cmd("thunar"), { description = "App: File manager" })

-- Scripts
hl.bind("SUPER + B", hl.dsp.exec_cmd("$HOME/scripts/steam_toggle.sh"), { description = "Script: Steam toggle" })
hl.bind("SUPER + S", hl.dsp.exec_cmd("$HOME/scripts/cambiar_audio.sh"), { description = "Script: Audio toggle" })
hl.bind(
	"SUPER + U",
	function()
		hl.dispatch(hl.dsp.exec_cmd('/usr/bin/kitty -e /usr/bin/distrobox-enter --name bunker -- fish -C "cd $HOME/dev"'))
	end,
	{ description = "App: Distrobox dev" }
)

-- CodexBar usage popup (distrobox codex usage)
hl.bind(
	"SUPER + SHIFT + U",
	hl.dsp.global("quickshell:codexbarToggle"),
	{ description = "CodexBar: Toggle usage popup" }
)

-- Window management
hl.bind("SUPER + C", hl.dsp.window.close(), { description = "Window: Close" })
hl.bind(
	"SUPER + F",
	hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }),
	{ description = "Window: Fullscreen" }
)

-- Mover ventana entre monitores (Win + flechas)
hl.bind("SUPER + left", hl.dsp.window.move({ monitor = "-1" }), { description = "Window: Move to left monitor" })
hl.bind("SUPER + right", hl.dsp.window.move({ monitor = "+1" }), { description = "Window: Move to right monitor" })

-- Navegación entre monitores (Win + H/L)
hl.bind("SUPER + H", hl.dsp.focus({ monitor = "-1" }), { description = "Monitor: Focus left" })
hl.bind("SUPER + L", hl.dsp.focus({ monitor = "+1" }), { description = "Monitor: Focus right" })

-- Navegación ventanas (Win + J/K)
hl.bind("SUPER + J", hl.dsp.window.cycle_next(), { repeating = true, description = "Window: Cycle next" })
hl.bind(
	"SUPER + K",
	hl.dsp.window.cycle_next({ next = false }),
	{ repeating = true, description = "Window: Cycle prev" }
)

-- Mover ventana con flechas + Shift (Win + Shift + flechas)
hl.bind("SUPER + SHIFT + left", hl.dsp.window.move({ direction = "l" }), { description = "Window: Move left" })
hl.bind("SUPER + SHIFT + right", hl.dsp.window.move({ direction = "r" }), { description = "Window: Move right" })
hl.bind("SUPER + SHIFT + up", hl.dsp.window.move({ direction = "u" }), { description = "Window: Move up" })
hl.bind("SUPER + SHIFT + down", hl.dsp.window.move({ direction = "d" }), { description = "Window: Move down" })
hl.bind("CTRL + SUPER + M", hl.dsp.exec_cmd("flatpak run org.prismlauncher.PrismLauncher"), {
	description = "App: Minecraft",
})
hl.bind("CTRL + SUPER + D", hl.dsp.exec_cmd("flatpak run com.discordapp.Discord"), {
	description = "App: Discord",
})
hl.bind("CTRL + SUPER + C", hl.dsp.exec_cmd("flatpak run com.rtosta.zapzap"), {
	description = "App: Chat",
})

-- Workspace binds sincronizados (pisan los grupales de end-4)
-- Cambian workspace en AMBOS monitores a la vez
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

-- Enviar ventana a workspace (usa workspace global, no grupal)
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
