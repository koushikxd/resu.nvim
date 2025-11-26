local M = {}

local config_module = require("resu.config")
local state = require("resu.state")
local watcher = require("resu.watcher")
local ui = require("resu.ui")
local diff = require("resu.diff")

-- Public API

function M.setup(opts)
  config_module.defaults = vim.tbl_deep_extend("force", config_module.defaults, opts or {})

  -- Start watcher automatically if configured?
  -- For now, we start watcher when the user opens the review or explicitly starts it.
  -- Or we can start it on setup. The requirements say "Watch directories (default: cwd)".
  -- It's probably better to start watching immediately so we catch changes even before opening UI.

  local dir = config_module.defaults.watch_dir or vim.fn.getcwd()
  watcher.start(dir, function()
    -- On update
    ui.refresh()
  end)

  -- Register keymaps for the review buffer via autocmd
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "resu-review",
    callback = function(ev)
      local maps = config_module.defaults.keymaps
      local opts = { buffer = ev.buf, silent = true }

      vim.keymap.set("n", maps.accept, function()
        M.accept()
      end, opts)
      vim.keymap.set("n", maps.decline, function()
        M.decline()
      end, opts)
      vim.keymap.set("n", maps.next, function()
        M.next()
      end, opts)
      vim.keymap.set("n", maps.prev, function()
        M.prev()
      end, opts)
      vim.keymap.set("n", maps.refresh, function()
        M.refresh()
      end, opts)
      vim.keymap.set("n", maps.quit, function()
        M.close()
      end, opts)

      -- Navigation with standard keys
      vim.keymap.set("n", "<CR>", function()
        M.open_current_diff()
      end, opts)
      vim.keymap.set("n", "j", function()
        M.next()
      end, opts)
      vim.keymap.set("n", "k", function()
        M.prev()
      end, opts)
    end,
  })
end

function M.open()
  ui.open()
end

function M.close()
  ui.close()
end

function M.toggle()
  ui.toggle()
end

function M.refresh()
  -- Force re-scan or just refresh UI?
  -- Watcher handles updates, but maybe user wants manual refresh
  ui.refresh()
  vim.notify("Resu: Refreshed", vim.log.levels.INFO)
end

function M.next()
  if state.next_file() then
    ui.update_selection()
  end
end

function M.prev()
  if state.prev_file() then
    ui.update_selection()
  end
end

function M.open_current_diff()
  local current = state.get_current_file()
  if current then
    diff.open(current.path)
  end
end

function M.accept()
  local current = state.get_current_file()
  if current then
    state.update_status(current.path, state.Status.ACCEPTED)
    if config_module.defaults.auto_stage then
      vim.fn.system("git add " .. vim.fn.shellescape(current.path))
    end
    ui.refresh()
    M.next()
  end
end

function M.decline()
  local current = state.get_current_file()
  if current then
    state.update_status(current.path, state.Status.DECLINED)
    ui.refresh()
    M.next()
  end
end

function M.reset()
  state.reset()
  ui.refresh()
  vim.notify("Resu: State reset", vim.log.levels.INFO)
end

return M
