local M = {}

M.defaults = {
  -- Directory to watch (nil means current working directory)
  watch_dir = nil,
  -- List of patterns to ignore
  ignored_files = {
    "%.git/",
    "node_modules/",
    "dist/",
    "build/",
    "%.DS_Store",
    "%.swp",
  },
  -- Whether to auto-stage accepted files using git add
  auto_stage = false,
  -- View mode: 'split' or 'unified' (for native diff)
  view_mode = "split",
  -- Window configuration for the sidebar
  window = {
    position = "left",
    width = 35,
    border = "rounded",
  },
  -- Keymaps for the review buffer
  keymaps = {
    accept = "<leader>ra",
    decline = "<leader>rd",
    next = "<leader>rn",
    prev = "<leader>rp",
    refresh = "<leader>rr",
    quit = "<leader>rq",
  },
}

return M
