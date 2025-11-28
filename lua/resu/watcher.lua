---@module resu.watcher
--- Watches the filesystem for changes using libuv's fs_event.
--- Triggers UI refresh when files are modified by external tools (e.g., AI agents).
local M = {}
local uv = vim.loop or vim.uv
local state = require("resu.state")
local config = require("resu.config").defaults

local handle = nil
local callback_fn = nil

local function is_ignored(path)
  for _, pattern in ipairs(config.ignored_files) do
    if path:match(pattern) then
      return true
    end
  end
  return false
end

--- Debounce to avoid processing rapid successive file changes (e.g., multiple saves)
local function debounce(func, wait)
  local timer_id = nil
  return function(...)
    local args = { ... }
    if timer_id then
      uv.timer_stop(timer_id)
      if not uv.is_closing(timer_id) then
        uv.close(timer_id)
      end
    end
    timer_id = uv.new_timer()
    uv.timer_start(timer_id, wait, 0, function()
      if timer_id and not uv.is_closing(timer_id) then
        uv.timer_stop(timer_id)
        uv.close(timer_id)
      end
      timer_id = nil
      vim.schedule(function()
        func(unpack(args))
      end)
    end)
  end
end

local function process_change(err, filename, _)
  if err then
    return
  end

  if not filename or is_ignored(filename) then
    return
  end

  state.add_or_update_file(filename)

  if callback_fn then
    callback_fn()
  end
end

local on_change = debounce(process_change, 100)

function M.start(dir, on_update)
  if handle then
    M.stop()
  end

  dir = dir or vim.fn.getcwd()
  callback_fn = on_update

  handle = uv.new_fs_event()

  uv.fs_event_start(handle, dir, { recursive = true }, function(err, filename, events)
    on_change(err, filename, events)
  end)
end

function M.stop()
  if handle then
    uv.fs_event_stop(handle)
    if not uv.is_closing(handle) then
      uv.close(handle)
    end
    handle = nil
  end
end

return M
