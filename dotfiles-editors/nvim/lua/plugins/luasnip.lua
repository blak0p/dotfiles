return {
  "L3MON4D3/LuaSnip",
  lazy = true,
  build = "make install_jsregexp",
  dependencies = { "rafamadriz/friendly-snippets" },
  opts = {
    history = true,
    delete_check_events = "TextChanged",
  },
}
