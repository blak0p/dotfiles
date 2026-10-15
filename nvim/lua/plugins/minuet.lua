return {
  {
    "milanglacier/minuet-ai.nvim",
    event = { "InsertEnter", "BufReadPre" },
    config = function()
      local url = "http://127.0.0.1:8090"
      local model = "granite3b"

      require("minuet").setup({
        provider = "openai_fim_compatible",
        context_window = 8192,
        n_completions = 1,
        after_cursor_filter_length = 20,
        throttle = 50,
        debounce = 40,
        request_timeout = 5,
        notify = "warn",
        provider_options = {
          openai_fim_compatible = {
            api_key = "TERM",
            name = "Llama.cpp",
            end_point = url .. "/v1/completions",
            model = model,
            stream = true,
            optional = {
              max_tokens = 200,
              temperature = 0.4,
              top_p = 0.95,
              stop = {
                "<|end_of_text|>",
                "<|endoftext|>",
                "<|fim_prefix|>",
                "<|fim_suffix|>",
                "<|fim_middle|>",
                "\n\n\n",
              },
            },
            template = {
              prompt = function(context_before_cursor, context_after_cursor, _)
                return "<|fim_prefix|>"
                  .. context_before_cursor
                  .. "<|fim_suffix|>"
                  .. context_after_cursor
                  .. "<|fim_middle|>"
              end,
              suffix = false,
            },
            transform = {
              function(payload)
                local body = payload.body
                if not body then
                  return payload
                end

                local ft = vim.bo.filetype
                local line = vim.api.nvim_get_current_line()
                local col = vim.api.nvim_win_get_cursor(0)[2]
                local before_cursor = line:sub(1, col)
                local after_cursor = line:sub(col + 1)

                local is_data_file = vim.tbl_contains({ "json", "xml", "yaml", "csv", "sql", "html" }, ft)
                local inside_quotes = (before_cursor:match('["\'][^"\']*$') ~= nil)
                local inside_tag = (before_cursor:match(">([^<]*)$") ~= nil and after_cursor:match("^[^<]*</"))
                local after_colon_or_eq = (before_cursor:match("[:=]%s*[\"']?$") ~= nil)

                if is_data_file or inside_quotes or inside_tag or after_colon_or_eq then
                  -- Data / Mock completion mode: high temperature for realistic varied entries
                  body.temperature = 0.65
                  body.top_p = 0.95

                  -- Stop before spilling outside the current value
                  if inside_quotes then
                    local quote_char = before_cursor:match('(["\'])[^"\']*$')
                    if quote_char then
                      body.stop = body.stop or {}
                      table.insert(body.stop, quote_char)
                    end
                  end

                  if inside_tag then
                    body.stop = body.stop or {}
                    table.insert(body.stop, "</")
                  end
                else
                  -- Code logic mode: precise and deterministic
                  body.temperature = 0.2
                end

                return payload
              end,
            },
          },
        },
        virtualtext = {
          auto_trigger_ft = { "*" },
          auto_trigger_ignore_ft = {
            "markdown",
            "text",
            "help",
            "gitcommit",
            "snacks_dashboard",
            "TelescopePrompt",
            "neo-tree",
            "oil",
          },
          keymap = {
            accept = "<A-CR>",
            accept_line = "<M-l>",
            dismiss = "<M-c>",
            prev = "<M-[>",
            next = "<M-]>",
          },
          show_on_completion_menu = false,
        },
      })

      -- Clean Ghost Text highlight matching VS Code Copilot style
      vim.api.nvim_set_hl(0, "MinuetVirtualText", {
        fg = "#636da6",
        italic = true,
      })

      -- Keymaps for accepting word-by-word without recalculating (like VS Code Copilot)
      local function accept_word()
        local ok, minuet_vt = pcall(require, "minuet.virtualtext")
        if ok and minuet_vt.action and minuet_vt.action.is_visible() then
          minuet_vt.action.accept_word()
          return true
        end
      end
      vim.keymap.set("i", "<M-w>", accept_word, { desc = "Minuet accept word" })
      vim.keymap.set("i", "<M-Right>", accept_word, { desc = "Minuet accept word" })

      -- Automatic background preload on VimEnter / FocusGained
      local function preload_tab_model()
        pcall(vim.fn.jobstart, {
          "curl",
          "-s",
          "-X",
          "POST",
          url .. "/models/load",
          "-H",
          "Content-Type: application/json",
          "-d",
          string.format('{"model":"%s"}', model),
        }, { detach = true })
      end

      local preload_group = vim.api.nvim_create_augroup("MinuetModelLifecycle", { clear = true })
      vim.api.nvim_create_autocmd({ "VimEnter", "FocusGained" }, {
        group = preload_group,
        callback = function()
          vim.defer_fn(preload_tab_model, 300)
        end,
      })

      -- Clean unload on VimLeavePre to release GPU VRAM
      vim.api.nvim_create_autocmd("VimLeavePre", {
        group = preload_group,
        callback = function()
          pcall(vim.fn.system, string.format([[
            curl -s -X POST %s/models/unload -H "Content-Type: application/json" -d '{"model":"%s"}' >/dev/null 2>&1
          ]], url, model))
        end,
      })
    end,
  },
}
