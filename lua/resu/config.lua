---@module resu.config
--- Default configuration values for Resu.
--- Users override these via require("resu").setup({ ... })
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
    width = 25,
    border = "rounded",
  },
  keymaps = {
    accept = "<leader>ra",
    decline = "<leader>rd",
    next = "<C-j>",
    prev = "<C-k>",
    quit = "q",
  },
}

return M
