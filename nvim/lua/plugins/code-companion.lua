return {
  "olimorris/codecompanion.nvim",
  enabled = false,
  lazy = true,
   init = function()
    require("plugins.codecompanion.codecompanion-notifier"):init()
    local group = vim.api.nvim_create_augroup("CodeCompanionHooks", {})
    local function update_current_context(args)
      local bufnr = args.buf
      if vim.bo[bufnr].buftype == "" and vim.bo[bufnr].filetype ~= "codecompanion" then
        _G.codecompanion_current_context = bufnr
      end
    end

    vim.api.nvim_create_autocmd("BufEnter", {
      group = group,
      callback = update_current_context,
    })
    update_current_context({ buf = vim.api.nvim_get_current_buf() })

    vim.api.nvim_create_autocmd({ "User" }, {
      pattern = "CodeCompanionInlineFinished",
      group = group,
      callback = function(request)
        vim.lsp.buf.format({ bufnr = request.buf })
      end,
    })
  end,
  cmd = {
    "CodeCompanion",
    "CodeCompanionActions",
    "CodeCompanionChat",
    "CodeCompanionCmd",
  },
  keys = {
    { "<leader>ac", "<cmd>CodeCompanionChat Toggle<cr>", mode = { "n", "v" }, desc = "AI Toggle [C]hat" },
    { "<leader>an", "<cmd>CodeCompanionChat<cr>", mode = { "n", "v" }, desc = "AI [N]ew Chat" },
    { "<leader>aa", "<cmd>CodeCompanionActions<cr>", mode = { "n", "v" }, desc = "AI [A]ction" },
    { "<leader>ai", "<cmd>CodeCompanion<cr>", mode = { "n", "v" }, desc = "AI [I]nline Edit" },
    { "ga", "<cmd>CodeCompanionChat Add<CR>", mode = { "v" }, desc = "AI [A]dd to Chat" },
    -- prompts
    { "<leader>ae", "<cmd>CodeCompanion /explain<cr>", mode = { "v" }, desc = "AI [E]xplain" },
  },
   config = function(_, opts)
    local codecompanion = require("codecompanion")
    codecompanion.setup(opts)

    -- Define diff highlight groups with red/green colors
    vim.cmd("hi! CodeCompanionDiffAdd guibg=#263b2b guifg=NONE ctermbg=DarkGreen ctermfg=NONE")
    vim.cmd("hi! CodeCompanionDiffDelete guibg=#3f2a2a guifg=NONE ctermbg=DarkRed ctermfg=NONE")
    vim.cmd("hi! CodeCompanionDiffText guibg=#35663e guifg=NONE ctermbg=Green ctermfg=NONE")
    vim.cmd("hi! CodeCompanionDiffTextDelete guibg=#6e3636 guifg=NONE ctermbg=Red ctermfg=NONE")

    -- Render inline edits as a side-by-side review without changing the file first.
    local helpers = require("codecompanion.helpers")
    local original_show_diff = helpers.show_diff
    helpers.show_diff = function(args)
      if not args.inline then
        return original_show_diff(args)
      end

      local api = vim.api
      local original_buf = args.bufnr
      local original_win = vim.fn.bufwinid(original_buf)
      if original_win == -1 then
        return original_show_diff(args)
      end

      local old_buf = api.nvim_create_buf(false, true)
      local new_buf = api.nvim_create_buf(false, true)
      api.nvim_buf_set_lines(old_buf, 0, -1, false, args.from_lines)
      api.nvim_buf_set_lines(new_buf, 0, -1, false, args.to_lines)
      for _, bufnr in ipairs({ old_buf, new_buf }) do
        vim.bo[bufnr].buftype = "nofile"
        vim.bo[bufnr].bufhidden = "wipe"
        vim.bo[bufnr].modifiable = false
        vim.bo[bufnr].swapfile = false
        vim.bo[bufnr].filetype = args.ft or vim.bo[original_buf].filetype
      end

      api.nvim_set_current_win(original_win)
      vim.cmd("vsplit")
      local new_win = api.nvim_get_current_win()
      api.nvim_win_set_buf(new_win, new_buf)
      api.nvim_set_current_win(original_win)
      api.nvim_win_set_buf(original_win, old_buf)

      for _, win in ipairs({ original_win, new_win }) do
        api.nvim_win_call(win, function()
          vim.cmd("diffthis")
          vim.wo.number = true
          vim.wo.relativenumber = false
        end)
      end

      local closed = false
      local function close_review()
        if closed then
          return
        end
        closed = true
        for _, win in ipairs({ original_win, new_win }) do
          if api.nvim_win_is_valid(win) then
            api.nvim_win_call(win, function()
              vim.cmd("diffoff")
            end)
          end
        end
        if api.nvim_win_is_valid(new_win) then
          api.nvim_win_close(new_win, true)
        end
        if api.nvim_win_is_valid(original_win) then
          api.nvim_win_set_buf(original_win, original_buf)
          api.nvim_set_current_win(original_win)
        end
        for _, bufnr in ipairs({ old_buf, new_buf }) do
          if api.nvim_buf_is_valid(bufnr) then
            api.nvim_buf_delete(bufnr, { force = true })
          end
        end
      end

      local function accept()
        if closed then
          return
        end
        close_review()
        api.nvim_buf_set_lines(original_buf, 0, -1, false, args.to_lines)
        args.keymaps.on_accept()
      end

      local function reject()
        if closed then
          return
        end
        close_review()
        args.keymaps.on_reject()
      end

      local function close_without_decision()
        reject()
      end

      -- CodeCompanion passes its own banner; use the compact symbols consistently.
      local banner = "↵ Accept | ⌫ Cancel | q Close"
      local function set_winbar(win)
        pcall(vim.api.nvim_set_option_value, "winbar", " " .. banner .. " ", { win = win })
      end
      set_winbar(original_win)
      set_winbar(new_win)
      for _, bufnr in ipairs({ old_buf, new_buf }) do
        vim.keymap.set("n", "<CR>", accept, { buffer = bufnr, silent = true, nowait = true, desc = "Accept change" })
        vim.keymap.set("n", "<BS>", reject, { buffer = bufnr, silent = true, nowait = true, desc = "Cancel change" })
        vim.keymap.set("n", "q", close_without_decision, { buffer = bufnr, silent = true, nowait = true, desc = "Reject and close diff" })
      end

      pcall(vim.api.nvim_set_option_value, "winhl", "DiffChange:CodeCompanionDiffDelete,DiffAdd:CodeCompanionDiffDelete,DiffDelete:CodeCompanionDiffDelete", { win = original_win })
      pcall(vim.api.nvim_set_option_value, "winhl", "DiffChange:CodeCompanionDiffAdd,DiffAdd:CodeCompanionDiffAdd,DiffDelete:CodeCompanionDiffAdd", { win = new_win })

      api.nvim_set_current_win(new_win)
      return true
    end

    codecompanion.inline = function(args)
      args = args or {}
      local bufnr = vim.api.nvim_get_current_buf()
      local context = require("codecompanion.utils.context").get(bufnr, args)

      local mode = vim.fn.mode()
      local is_visual = (args.range and args.range > 0) or (mode == "v" or mode == "V" or mode == "\22")

      if not is_visual then
        -- File-level edit (like VS Code / Copilot Edits): target the whole buffer so cursor position does not matter
        local total_lines = vim.api.nvim_buf_line_count(bufnr)
        local last_line = vim.api.nvim_buf_get_lines(bufnr, total_lines - 1, total_lines, false)[1] or ""
        context.is_visual = true
        context.is_normal = false
        context.start_line = 1
        context.start_col = 0
        context.end_line = total_lines
        context.end_col = #last_line
        context.lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        args.placement = "replace"
      end

      local inline = require("codecompanion.interactions.inline").new({
        buffer_context = context,
        placement = args.placement,
      })

      if inline then
        local user_prompt = args.args or ""
        if not user_prompt:find("#{buffer}", 1, true) then
          user_prompt = "#{buffer} " .. user_prompt
        end
        inline:prompt(user_prompt)
      end
    end
  end,
  opts = {
    adapters = {
      http = {
        openai_compatible = function()
          return require("codecompanion.adapters").extend("openai_compatible", {
            env = {
              url = "http://127.0.0.1:8090",
              chat_url = "/v1/chat/completions",
              models_endpoint = "/models",
              api_key = "llama",
            },
            schema = {
              model = {
                default = "qwen3-coder",
                choices = {
                  ["qwen3-coder"] = {},
                  ["gemma-4"] = {},
                  ["qwen7b"] = {},
                  ["zeta8b"] = {},
                  ["granite3b"] = {},
                  ["ornith"] = {},
                },
              },
            },
          })
        end,
      },
    },
    interactions = {
      background = {
        chat = {
          opts = {
            enabled = false,
          },
        },
      },
      inline = {
        adapter = "openai_compatible",
      },
      shared = {
        keymaps = {
          always_accept = {
            modes = { n = "g1" },
            description = "Always accept",
          },
          accept_change = {
            modes = { n = "<CR>" },
            description = "Accept change",
          },
          reject_change = {
            modes = { n = "gr" },
            description = "Reject change",
          },
        },
      },
       chat = {
         opts = {
           system_prompt = function(ctx)
             return [[Sos un tutor y mentor de programación enfocado en guiar a un estudiante en sus ejercicios de clase y aprendizaje de código.

Principios pedagógicos:
1. CONCEPTOS ANTES QUE CÓDIGO: No te limites a escupir una solución terminada. Explicá primero el POR QUÉ, la lógica algorítmica, las estructuras de datos y la complejidad temporal/espacial (Big-O).
2. GUÍA DE RAZONAMIENTO: Cuando el usuario tenga un error o duda, explicá la causa raíz técnica y guialo a entender cómo solucionarlo.
3. CÓDIGO LIMPIO E IDIOMÁTICO: Brindá ejemplos modulares, claros y bien comentados que sirvan de modelo de buenas prácticas.
4. TONO: Cálido, paciente, directo y apasionado por enseñar.]]
           end,
         },
         editor_context = {
           ["buffer"] = {
             opts = {
                default_params = "all",
             },
           },
         },
         slash_commands = {
          ["git_files"] = {
            description = "List git files",
            ---@param chat CodeCompanion.Chat
            callback = function(chat)
              local handle = io.popen("git ls-files")
              if handle ~= nil then
                local result = handle:read("*a")
                handle:close()
                chat:add_reference({ role = "user", content = result }, "git", "<git_files>")
              else
                return vim.notify("No git files available", vim.log.levels.INFO, { title = "CodeCompanion" })
              end
            end,
            opts = {
              contains_code = false,
            },
          },
        },
        keymaps = {
          send = {
            modes = { n = "<C-s>", i = "<C-s>" },
          },
          close = {
            modes = { n = "<C-c>", i = "<C-c>" },
          },
        },
        adapter = "openai_compatible",
        roles = {
          llm = function(adapter)
            return "AI (" .. adapter.formatted_name .. ")"
          end,
          user = "Vos",
        },
      },
    },
    display = {
      diff = {
        enabled = true,
        close_chat_at = 240,
        layout = "vertical",
        opts = { "internal", "filler", "closeoff", "algorithm:patience", "followwrap", "linematch:120" },
        provider = "default",
        threshold_for_chat = 6,
        word_highlights = { additions = true, deletions = true },
        window = {
          width = function()
            return math.min(120, vim.o.columns - 10)
          end,
          height = function()
            return vim.o.lines - 4
          end,
          opts = {
            number = true,
          },
        },
      },
      chat = {
        window = {
          position = "left",
        },
      },
    },
  },
}
