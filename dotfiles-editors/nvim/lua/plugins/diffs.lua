return {
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>gd", false },
      { "<leader>gD", false },
    },
  },
  {
    "sindrets/diffview.nvim",
    event = "VeryLazy",
     opts = {
      enhanced_diff_hl = true,
      use_icons = true,
      signs = {
        fold_closed = "",
        fold_open = "",
        done = "✓",
      },
      view = {
        default = {
          layout = "diff2_horizontal",
          disable_diagnostics = false,
        },
        merge_tool = {
          layout = "diff3_horizontal",
          disable_diagnostics = false,
        },
        file_history = {
          layout = "diff2_horizontal",
        },
      },
      file_panel = {
        listing_style = "tree",
        tree_options = {
          flatten_dirs = true,
          folder_statuses = "only_folded",
        },
        win_config = {
          position = "left",
          width = 35,
        },
      },
    },
     config = function()
       require("diffview")
       vim.keymap.set("n", "gd", "<cmd>DiffviewOpen<CR>", { desc = "Diff view" })
       vim.keymap.set("n", "gh", "<cmd>DiffviewOpen HEAD<CR>", { desc = "Diff view (HEAD)" })
       local ns = vim.api.nvim_create_namespace("diffview_reviewed")
       local reviewed = {}

      vim.api.nvim_create_autocmd("User", {
        pattern = "DiffviewViewOpened",
        callback = function()
          local view = require("diffview.lib").get_current_view()
          if not view or not view.panel then return end
          local bufnr = view.panel.bufnr
          if not bufnr then return end

          vim.keymap.set("n", "m", function()
            local line = vim.fn.line(".")
            local text = vim.fn.getline(line)
            if text == "" then return end
            local key = bufnr .. ":" .. text
            if reviewed[key] then
              reviewed[key] = nil
              pcall(vim.api.nvim_buf_del_extmark, bufnr, ns, line)
            else
              reviewed[key] = true
              vim.api.nvim_buf_set_extmark(bufnr, ns, line - 1, 0, {
                sign_text = "✓",
                sign_hl = "DiagnosticSignOk",
                priority = 200,
              })
            end
          end, { buffer = bufnr, desc = "Toggle reviewed" })
        end,
      })
    end,
  },
}
