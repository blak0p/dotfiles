-- This file will not be overwritten across dots-hyprland updates.
-- The file name is for the sake of organization and does not matter
-- See the corresponding files in ~/.config/hypr/hyprland for examples

-- Cambiar workspace en ambos monitores simultaneamente
function ws_both(ws)
    local function set_ws(name)
        hl.dispatch(hl.dsp.exec_cmd(
            "hyprctl dispatch focusmonitor " .. name .. " && hyprctl dispatch workspace " .. ws
        ))
    end
    set_ws("HDMI-A-2")
    set_ws("DP-2")
end
