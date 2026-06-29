return {
  "nvim-neotest/neotest",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
  },
  opts = function(_, opts)
    -- Force lazy.nvim to load nvim-treesitter so that the package paths
    -- are populated when neotest spawns its headless subprocesses.
    require("lazy").load({ plugins = { "nvim-treesitter" } })

    -- Configure neotest-golang options to remove "-race" flag
    -- since CGO is disabled (CGO_ENABLED=0) in your system.
    opts.adapters = opts.adapters or {}
    opts.adapters["neotest-golang"] = vim.tbl_deep_extend("force", opts.adapters["neotest-golang"] or {}, {
      go_test_args = {
        "-v",
        "-count=1",
        "-timeout=60s",
      },
    })
  end,
}
