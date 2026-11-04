-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Clear search highlight automatically when moving the cursor
vim.api.nvim_create_autocmd("CursorMoved", {
  group = vim.api.nvim_create_augroup("AutoClearHL", { clear = true }),
  callback = function()
    if vim.v.hlsearch == 1 then
      vim.cmd("nohlsearch")
    end
  end,
})
