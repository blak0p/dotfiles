-- This file sources other files in `hyprland` and `custom` folders
-- You wanna add your stuff in files in `custom`

-- Internal stuff --
require("hyprland.lib")
require("hyprland.services")

-- User layer: your own config in $XDG_CONFIG_HOME/sky/hypr (default
-- ~/.config/sky/hypr), outside this repo so a pull never conflicts with it.
-- Each file is optional and loads after the repo defaults, so it wins.
-- A broken file is reported and skipped instead of breaking the session.
-- Templates: hypr/user-template/ (copied by install.sh when missing).
SKY_USER_HYPR = (os.getenv("XDG_CONFIG_HOME") or (HOME .. "/.config")) .. "/sky/hypr"
local function user_layer(name)
    local file = SKY_USER_HYPR .. "/" .. name .. ".lua"
    if is_file_exists(file) then
        local ok, err = pcall(dofile, file)
        if not ok then print("sky user layer " .. name .. ": " .. tostring(err)) end
    end
end

-- Environment variables --
require("hyprland.env")
if is_file_exists(HOME .. "/.config/hypr/custom/env.lua") then
    require("custom.env")
end
user_layer("env")

-- Default configurations --
require("hyprland.execs")
require("hyprland.general")
require("hyprland.rules")
require("hyprland.colors")
require("hyprland.keybinds")

-- Custom configurations --
if is_file_exists(HOME .. "/.config/hypr/custom/execs.lua") then
    require("custom.execs")
end
if is_file_exists(HOME .. "/.config/hypr/custom/general.lua") then
    require("custom.general")
end
if is_file_exists(HOME .. "/.config/hypr/custom/rules.lua") then
    require("custom.rules")
end
if is_file_exists(HOME .. "/.config/hypr/custom/keybinds.lua") then
    require("custom.keybinds")
end
if is_file_exists(HOME .. "/.config/hypr/custom/keybinds-extra.lua") then
    require("custom.keybinds-extra")
end

-- nwg-displays support --
if is_file_exists(HOME .. "/.config/hypr/workspaces.lua") then
    require("workspaces")
end
if is_file_exists(HOME .. "/.config/hypr/monitors.lua") then
    require("monitors")
end

-- Shell overrides --
require("hyprland.shellOverrides.main")

-- User layer (see top of file) --
user_layer("variables")
user_layer("execs")
user_layer("general")
user_layer("rules")
user_layer("keybinds")
user_layer("monitors")
user_layer("workspaces")

-- Wallpaper colors from sky_theme.py, last so they win over custom/ --
local sky_colors = (os.getenv("XDG_STATE_HOME") or (HOME .. "/.local/state")) .. "/sky/hyprland.lua"
if is_file_exists(sky_colors) then
    local ok, err = pcall(dofile, sky_colors)
    if not ok then print("sky colors: " .. tostring(err)) end
end
