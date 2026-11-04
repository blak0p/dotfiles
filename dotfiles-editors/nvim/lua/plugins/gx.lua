-- Plugin: gx.nvim
-- URL: https://github.com/chrishrb/gx.nvim
-- Description: Open links under cursor without netrw (URLs, markdown links,
-- GitHub issues, package.json deps, Brewfile, Go imports, web search fallback).

return {
  "chrishrb/gx.nvim",
  keys = {
    { "gx", "<cmd>Browse<cr>", mode = { "n", "x" }, desc = "Open link under cursor" },
  },
  cmd = { "Browse" },
  init = function()
    vim.g.netrw_nogx = 1 -- disable netrw gx, gx.nvim takes over
  end,
  submodules = false, -- submodules only needed for tests
  opts = {
    select_prompt = true, -- prompt when multiple handlers match
    handlers = {
      plugin = true, -- open lazy/packer plugin links
      github = true, -- open GitHub issues (e.g. Fixes #22)
      brewfile = true, -- open Homebrew formulae/casks
      package_json = true, -- open npm deps from package.json
      search = true, -- web search fallback when no URL found
      go = true, -- open pkg.go.dev from Go imports (treesitter)
    },
    handler_options = {
      search_engine = "google",
    },
  },
}
