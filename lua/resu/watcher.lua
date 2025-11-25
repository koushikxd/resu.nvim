---@diagnostic disable: undefined-global
local M = {}
local uv = vim.loop or vim.uv
local state = require("resu.state")
local config = require("resu.config").defaults

local handle = nil
local callback_fn = nil

-- Helper to check if file should be ignored
local function is_ignored(path)
  for _, pattern in ipairs(config.ignored_files) do
    if path:match(pattern) then
      return true
    end
  end
  return false
end

-- Debounce function
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

-- Internal processing function
local function process_change(err, filename, _)
  if err then
    return
  end

  if not filename or is_ignored(filename) then
    return
  end

  -- Update state
  state.add_or_update_file(filename)

  -- Trigger UI refresh
  if callback_fn then
    callback_fn()
  end
end

-- Debounced handler
local on_change = debounce(process_change, 100)

function M.start(dir, on_update)
  if handle then
    M.stop()
  end

  dir = dir or vim.fn.getcwd()
  callback_fn = on_update

  handle = uv.new_fs_event()

  -- Watch recursively if supported by the OS/libuv version
  -- flags: recursive = true
  -- Note: We don't strictly need vim.schedule_wrap here because on_change (debounce)
  -- handles the thread safety via vim.schedule inside.
  uv.fs_event_start(handle, dir, { recursive = true }, function(err, filename, events)
    on_change(err, filename, events)
  end)

  -- vim.notify("Resu: Started watching " .. dir, vim.log.levels.INFO)
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
