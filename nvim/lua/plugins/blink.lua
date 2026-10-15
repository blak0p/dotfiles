return {
  "saghen/blink.cmp",
  lazy = true,
  dependencies = {
    "saghen/blink.compat",
    "L3MON4D3/LuaSnip",
  },
  opts = {
    keymap = {
      preset = "default",
      ["<C-j>"] = { "select_next", "fallback" },
      ["<C-k>"] = { "select_prev", "fallback" },
      ["<CR>"] = { "accept", "fallback" },
      ["<Tab>"] = {
        function(cmp)
          local ok, minuet_vt = pcall(require, "minuet.virtualtext")
          if ok and minuet_vt.action and minuet_vt.action.is_visible() then
            minuet_vt.action.accept()
            return true
          end
        end,
        "snippet_forward",
        "select_next",
        "fallback",
      },
      ["<S-Tab>"] = {
        function(cmp)
          local ok, minuet_vt = pcall(require, "minuet.virtualtext")
          if ok and minuet_vt.action and minuet_vt.action.is_visible() then
            minuet_vt.action.accept_line()
            return true
          end
        end,
        "snippet_backward",
        "select_prev",
        "fallback",
      },
    },
    sources = {
      default = { "lsp", "snippets", "avante_commands", "avante_mentions", "avante_files" },
      compat = {
        "avante_commands",
        "avante_mentions",
        "avante_files",
      },
      -- LSP score_offset is typically 60
      providers = {
        avante_commands = {
          name = "avante_commands",
          module = "blink.compat.source",
          score_offset = 90,
          opts = {},
        },
        avante_files = {
          name = "avante_files",
          module = "blink.compat.source",
          score_offset = 100,
          opts = {},
        },
        avante_mentions = {
          name = "avante_mentions",
          module = "blink.compat.source",
          score_offset = 1000,
          opts = {},
        },
      },
    },
  },
}
