return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    keys = {
      { "<leader>e", "<cmd>Neotree toggle<CR>", desc = "Toggle Neo-Tree" },
      { "<leader>fe", "<cmd>Neotree reveal<CR>", desc = "Neo-Tree Reveal" },
    },
    opts = {
      filesystem = {
        filtered_items = {
          visible = false,
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_hidden = false,
        },
        follow_current_file = {
          enabled = true,
        },
        use_libuv_file_watcher = true,
        window = {
          mappings = {
            [","] = "prev_source",
            ["<leader>e"] = "focus_preview",
          },
        },
      },
      git_status = {
        window = {
          mappings = {
            ["A"] = "git_add_file",
            ["D"] = "git_delete_file",
          },
        },
      },
      default_component_configs = {
        indent = {
          with_markers = true,
          with_expanders = true,
        },
        git_status = {
          symbols = {
            added = "✚",
            deleted = "✖",
            modified = "",
            renamed = "",
            staged = "",
            untracked = "",
            ignored = "",
            unstaged = "",
            conflict = "",
          },
        },
      },
    },
  },
}
