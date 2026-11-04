-- Colorscheme generated from the wallpaper: ~/.local/state/sky/colors.json
-- (written by quickshell/sky/scripts/sky_theme.py). Syntax, text and cursor
-- follow the wallpaper; backgrounds stay transparent so the terminal shows through.

local FALLBACK = "gentleman-kanagawa-blur"

local STATE_DIR = (vim.env.XDG_STATE_HOME or (vim.env.HOME .. "/.local/state")) .. "/sky"

local function palette()
  local f = io.open(STATE_DIR .. "/colors.json", "r")
  if not f then
    return nil
  end
  local ok, data = pcall(vim.json.decode, f:read("*a"))
  f:close()
  if ok and type(data) == "table" and type(data.base16) == "table" then
    return data
  end
end

local p = palette()
local has_mini, base16 = pcall(require, "mini.base16")
if not p or not has_mini then
  vim.notify("sky colorscheme: no palette, using " .. FALLBACK, vim.log.levels.WARN)
  vim.cmd.colorscheme(FALLBACK)
  return
end

base16.setup({ palette = p.base16, use_cterm = nil })
vim.g.colors_name = "sky"

local hl = function(name, val)
  vim.api.nvim_set_hl(0, name, val)
end

-- Transparent everywhere: drop the background of every group painted with a
-- palette surface (editor, floats, completion menu, pickers, statusline...).
local surfaces = {}
for _, key in ipairs({ "base00", "base01", "base02" }) do
  surfaces[tonumber(p.base16[key]:sub(2), 16)] = true
end
for name, val in pairs(vim.api.nvim_get_hl(0, {})) do
  if not val.link and val.bg and surfaces[val.bg] then
    val.bg, val.ctermbg = nil, nil
    hl(name, val)
  end
end
for _, group in ipairs({ "Normal", "NormalNC", "NormalFloat", "SignColumn", "EndOfBuffer", "Pmenu" }) do
  local cur = vim.api.nvim_get_hl(0, { name = group, link = false })
  cur.bg, cur.ctermbg = nil, nil
  hl(group, cur)
end

hl("Cursor", { fg = p.onAccent, bg = p.accent })
hl("lCursor", { link = "Cursor" })
hl("TermCursor", { link = "Cursor" })
hl("CursorLineNr", { fg = p.accent, bold = true })
hl("CursorLine", {})
-- Menus: no background; the selected entry is marked by color, not a block.
hl("PmenuSel", { fg = p.accent, bold = true })
hl("PmenuKind", { fg = p.secondary })
hl("PmenuExtra", { fg = p.outline })
hl("PmenuSbar", {})
hl("PmenuThumb", { bg = p.outlineVariant })
hl("BlinkCmpMenuSelection", { link = "PmenuSel" })
hl("Visual", { bg = p.surface2 })
hl("FloatBorder", { fg = p.outline })
hl("FloatTitle", { fg = p.accent, bold = true })
hl("WinSeparator", { fg = p.outlineVariant })
hl("Comment", { fg = p.outline, italic = true })
hl("@comment", { link = "Comment" })

local ansi = p.ansi or {}
for i = 0, 15 do
  if ansi[i + 1] then
    vim.g["terminal_color_" .. i] = ansi[i + 1]
  end
end

-- Live reload: sky_theme.py replaces colors.json atomically, so watch the directory.
if not vim.g.sky_colors_watching then
  local watcher, timer = vim.uv.new_fs_event(), vim.uv.new_timer()
  if watcher and timer then
    vim.g.sky_colors_watching = true
    watcher:start(STATE_DIR, {}, function(err, filename)
      if err or filename ~= "colors.json" then
        return
      end
      timer:start(200, 0, vim.schedule_wrap(function()
        if vim.g.colors_name == "sky" then
          vim.cmd.colorscheme("sky")
        end
      end))
    end)
    vim.api.nvim_create_autocmd("VimLeavePre", {
      callback = function()
        watcher:stop()
        timer:stop()
      end,
    })
  end
end
