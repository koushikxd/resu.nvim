local M = {}

M.defaults = {
  use_diffview = true,
  hot_reload = true,
  debounce_ms = 100,
  watch_dir = nil,
  ignored_files = {
    "%.git/",
    "node_modules/",
    "dist/",
    "build/",
    "%.DS_Store",
    "%.swp",
  },
  keymaps = {
    toggle = "<leader>rt",
    accept = "<leader>ra",
    decline = "<leader>rd",
    accept_all = "<leader>rA",
    decline_all = "<leader>rD",
    refresh = "<leader>rr",
    quit = "q",
  },
}

return M
