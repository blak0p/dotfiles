return {
  "sheymor21/unirunner.nvim",
  keys = {
    { "<leader>jr", "<cmd>UniRunner<CR>", desc = "Run project command" },
    { "<leader>js", "<cmd>UniRunnerSelect<CR>", desc = "Select project command" },
    { "<leader>jl", "<cmd>UniRunnerLast<CR>", desc = "Re-run last command" },
    { "<leader>jh", "<cmd>UniRunnerPanel<CR>", desc = "Toggle history panel" },
  },
  config = function()
    local UniRunner = require("unirunner")
    local runners = require("unirunner.runners")

    runners.register("go_work", {
      detect = function(root)
        return vim.fn.filereadable(root .. "/go.work") == 1
      end,
      get_commands = function(root)
        local commands = {}
        local work_content = vim.fn.readfile(root .. "/go.work")
        for _, line in ipairs(work_content) do
          local dir = line:match("^use%s+(.+)$")
          if dir then
            dir = vim.fn.trim(dir)
            if vim.fn.isdirectory(root .. "/" .. dir) == 1 then
              table.insert(commands, { name = "test:" .. dir, command = "go test ./" .. dir .. "/..." })
              table.insert(commands, { name = "test-v:" .. dir, command = "go test -v ./" .. dir .. "/..." })
              table.insert(commands, { name = "run:" .. dir, command = "go run ./" .. dir })
              table.insert(commands, { name = "build:" .. dir, command = "go build ./" .. dir })
            end
          end
        end
        return commands
      end,
    })

    UniRunner.setup({
      persist = true,
      working_dir = "root",
      root_markers = { "go.work", "go.mod", "package.json", "justfile", "Makefile", "Cargo.toml", ".git" },
      close_delay = 0,
      panel = {
        height = 30,
        max_history = 10,
        auto_follow = true,
      },
    })

    local sizes = {
      ["unirunner-live"] = { w = 0.85, h = 10 },
      ["unirunner-history"] = { w = 0.95, h = 0.97 },
      ["unirunner-panel"] = { w = 0.9, h = nil },
    }

    vim.api.nvim_create_autocmd("BufWinEnter", {
      group = vim.api.nvim_create_augroup("unirunner-float", { clear = true }),
      pattern = { "UniRunner*" },
      callback = function(ev)
        if vim.b[ev.buf]._unirunner_float then return end
        vim.b[ev.buf]._unirunner_float = true

        local ft = vim.bo[ev.buf].filetype
        local cfg = sizes[ft]
        if not cfg then return end

        vim.schedule(function()
          local wins = vim.api.nvim_list_wins()
          for _, win in ipairs(wins) do
            if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == ev.buf then
              local w = math.floor(vim.o.columns * cfg.w)
              local h = cfg.h and (cfg.h < 1 and math.floor(vim.o.lines * cfg.h) or cfg.h) or vim.api.nvim_win_get_height(win)
              local config = vim.api.nvim_win_get_config(win)
              if config.relative ~= "editor" then
                vim.api.nvim_win_set_config(win, {
                  relative = "editor",
                  width = w,
                  height = h,
                  row = math.floor((vim.o.lines - h) / 2),
                  col = math.floor((vim.o.columns - w) / 2),
                  border = "rounded",
                  style = "minimal",
                })
                vim.api.nvim_set_current_win(win)
              end
              break
            end
          end
        end)
      end,
    })
  end,
}
