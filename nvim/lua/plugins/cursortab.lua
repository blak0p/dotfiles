return {
  {
    url = "git@github.com:blak0p/cursortab.nvim.git",
    lazy = false,
    build = "cd server && go build",
    config = function(_, opts)
      require("cursortab").setup(opts)

      -- Custom highlight groups for high-contrast, crystal-clear suggestion diffs
      vim.api.nvim_set_hl(0, "CursorTabAddition", {
        bg = "#20382b",
        fg = "#9ece6a",
        bold = false,
      })
      vim.api.nvim_set_hl(0, "CursorTabDeletion", {
        bg = "#3d2228",
        fg = "#f7768e",
        strikethrough = true,
      })
      vim.api.nvim_set_hl(0, "CursorTabModification", {
        bg = "#252e3f",
        fg = "#7aa2f7",
      })
      vim.api.nvim_set_hl(0, "CursorTabCompletion", {
        fg = "#7aa2f7",
        italic = true,
      })
      vim.api.nvim_set_hl(0, "CursorTabJumpSymbol", {
        fg = "#bb9af7",
        bold = true,
      })

      -- Keymaps for partial accept and explicit dismiss
      vim.keymap.set("i", "<M-l>", function()
        local ok_ct, cursortab = pcall(require, "cursortab")
        if ok_ct and cursortab.partial_accept and cursortab.partial_accept() then
          return
        end
      end, { desc = "Cursortab partial accept (line)" })

      vim.keymap.set("i", "<M-c>", function()
        local ok_ct, cursortab = pcall(require, "cursortab")
        if ok_ct and cursortab.dismiss and cursortab.dismiss() then
          return
        end
      end, { desc = "Cursortab dismiss suggestion" })

      local url = (opts.provider and opts.provider.url) or "http://127.0.0.1:8090"
      local model = (opts.provider and opts.provider.model) or "zeta-2.1"

      local function preload_tab_model(notify)
        pcall(vim.fn.jobstart, {
          "bash",
          "-c",
          string.format([[
            systemctl --user is-active --quiet llama-server.service || systemctl --user start llama-server.service
            curl -s -X POST %s/models/load \
              -H "Content-Type: application/json" \
              -d '{"model":"%s"}' >/dev/null 2>&1
          ]], url, model),
        }, {
          on_exit = function(_, code)
            if notify and code == 0 then
              vim.notify("Tab model (" .. model .. ") ready", vim.log.levels.INFO)
            end
          end,
        })
      end

      -- Preload tab model immediately upon plugin configuration and on VimEnter / FocusGained
      preload_tab_model(false)

      vim.api.nvim_create_autocmd({ "VimEnter", "FocusGained" }, {
        desc = "Preload tab model in llama-server when Neovim starts or gains focus",
        callback = function()
          preload_tab_model(false)
        end,
      })

      vim.api.nvim_create_user_command("CursortabWarmup", function()
        preload_tab_model(true)
      end, { desc = "Preload/warmup cursortab model in llama-server" })

      -- Clean unload on Neovim exit
      vim.api.nvim_create_autocmd("VimLeavePre", {
        desc = "Unload tab model from llama-server on Neovim exit",
        callback = function()
          pcall(vim.fn.system, string.format([[
            curl -s -X POST %s/models/unload -H "Content-Type: application/json" -d '{"model":"%s"}' >/dev/null 2>&1
            curl -s -X POST %s/models/unload -H "Content-Type: application/json" -d '{"model":"zeta8b"}' >/dev/null 2>&1
          ]], url, model, url))
        end,
      })
    end,
    opts = {
      log_level = "info",
      keymaps = {
        accept = "<Tab>",
        partial_accept = "<S-Tab>",
        trigger = "<C-Space>",
      },
      ui = {
        completions = {
          addition_style = "highlight",
          fg_opacity = 0.85,
        },
        jump = {
          symbol = "󰁔",
          text = " TAB ",
          show_distance = true,
        },
      },
      behavior = {
        idle_completion_delay = 100,
        text_change_debounce = 80,
        max_visible_lines = 15,
        cursor_prediction = {
          enabled = true,
          auto_advance = true,
          proximity_threshold = 3,
        },
        ignore_filetypes = {
          "",
          "terminal",
          "prompt",
          "codecompanion",
          "copilot-chat",
          "oil",
          "oil_preview",
          "neo-tree",
          "neo-tree-popup",
          "NvimTree",
          "TelescopePrompt",
          "fzf",
          "snacks_picker_input",
          "minifiles",
          "netrw",
          "lazy",
          "mason",
          "help",
          "qf",
          "trouble",
          "undotree",
          "diff",
          "gitcommit",
          "gitrebase",
        },
      },
      provider = {
        type = "zeta-2.1",
        url = "http://127.0.0.1:8090",
        model = "zeta-2.1",
        temperature = 0.2,
        context_size = 16384,
        max_tokens = 256,
      },
    },
  },
}
