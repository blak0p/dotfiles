return {
  "obsidian-nvim/obsidian.nvim",
  opts = function(_, opts)
    local VAULTS = {
      { name = "Boveda", path = "/home/alejandro/dev/Boveda" },
      { name = "GitBook", path = "/var/home/alejandro/dev/Git-book" },
    }
    opts.workspaces = vim.list_extend(opts.workspaces or {}, VAULTS)

    local function pick_vault_and_open(cmd_name)
      local snacks = require("snacks")
      snacks.picker.select(VAULTS, {
        prompt = "Obsidian: Elegir Vault",
        format_item = function(v) return "📁 " .. v.name end,
      }, function(vault)
        if not vault then return end
        vim.cmd("ObsidianWorkspace " .. vault.name)
        vim.defer_fn(function()
          vim.cmd("Obsidian " .. cmd_name)
        end, 50)
      end)
    end

    vim.api.nvim_create_user_command("ObsidianAll", function(opts)
      pick_vault_and_open(opts.args == "" and "quick_switch" or opts.args)
    end, {
      nargs = "?",
      complete = function() return { "quick_switch", "search", "new", "today", "yesterday", "tomorrow", "dailies", "backlinks", "tags", "links", "template", "open", "rename", "paste_img", "toc" } end,
      desc = "Obsidian multi-vault: elige vault y ejecuta comando (default: quick_switch)",
    })

    vim.keymap.set("n", "<leader>ow", "<cmd>ObsidianAll<cr>", { desc = "Obsidian: Vault + Quick Switch (igual que :Obsidian)" })
    vim.keymap.set("n", "<leader>oW", "<cmd>ObsidianAll search<cr>", { desc = "Obsidian: Vault + Search (grep)" })
  end,
}