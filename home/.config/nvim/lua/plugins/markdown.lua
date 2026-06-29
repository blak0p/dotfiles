return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.nvim" }, -- if you use the mini.nvim suite
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {
      heading = {
        enabled = true,
        sign = false,
        style = "normal",
        icons = {},
        left_pad = 1,
      },
      bullet = {
        enabled = true,
        icons = { "●", "○", "◆", "◇" },
        right_pad = 1,
        highlight = "render-markdownBullet",
      },
      checkbox = {
        enabled = true,
        unchecked = {
          icon = "󰄱     ",
          highlight = "RenderMarkdownUnchecked",
        },
        checked = {
          icon = "󰱒     ",
          highlight = "RenderMarkdownChecked",
        },
        custom = {
          todo = { raw = "[-]", rendered = "󰥔     ", highlight = "RenderMarkdownTodo" },
        },
      },
      code = {
        width = "block",
        border = "thin",
        disable_background = false,
        language = true,
        language_icon = true,
        language_name = true,
        highlight = "RenderMarkdownCode",
        highlight_border = "RenderMarkdownCodeBorder",
      },
    },
    config = function(_, opts)
      vim.api.nvim_set_hl(0, "RenderMarkdownCode", { bg = "#1a1b2e" })
      vim.api.nvim_set_hl(0, "RenderMarkdownCodeBorder", { fg = "#7fb4ca" })
      require("render-markdown").setup(opts)
    end,
  },
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        markdown = {},
      },
    },
  },
}
