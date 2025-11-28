local M = {}

M.defaults = {
  watch_dir = nil,
  ignored_files = {
    "%.git/",
    "node_modules/",
    "dist/",
    "build/",
    "%.DS_Store",
    "%.swp",
  },
  auto_stage = false,
  view_mode = "split",
  window = {
    position = "left",
    width = 30,
    border = "rounded",
  },
  keymaps = {
    accept = "<leader>ra",
    decline = "<leader>rd",
    next = "n",
    prev = "N",
    quit = "q",
  },
}

return M
