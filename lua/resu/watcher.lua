-- File system watcher using libuv
-- Monitors directory for changes and triggers hot reload

local M = {}

local uv = vim.loop or vim.uv
local config = require("resu.config").defaults

local handle = nil
local debounce_timer = nil
local on_change_handlers = {}

local function debounce(fn, delay)
  return function(...)
    local args = { ... }
    if debounce_timer then
      if not uv.is_closing(debounce_timer) then
        uv.timer_stop(debounce_timer)
        uv.close(debounce_timer)
      end
    end
    debounce_timer = uv.new_timer()
    uv.timer_start(debounce_timer, delay, 0, function()
      if debounce_timer and not uv.is_closing(debounce_timer) then
        uv.timer_stop(debounce_timer)
        uv.close(debounce_timer)
      end
      debounce_timer = nil
      vim.schedule(function()
        fn(unpack(args))
      end)
    end)
  end
end

function M.register_handler(name, handler)
  on_change_handlers[name] = handler
end

function M.unregister_handler(name)
  on_change_handlers[name] = nil
end

local function is_ignored(path)
  for _, pattern in ipairs(config.ignored_files) do
    if path:match(pattern) then
      return true
    end
  end
  return false
end

local function should_check()
  local mode = vim.api.nvim_get_mode().mode
  return not (mode:match("[cR!s]") or vim.fn.getcmdwintype() ~= "")
end

local function should_reload_buffer(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
  local modified = vim.api.nvim_get_option_value("modified", { buf = buf })
  local is_real_file = name ~= "" and not name:match("^%w+://")
  return is_real_file and buftype == "" and not modified
end

local function get_visible_buffers()
  local visible = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    visible[vim.api.nvim_win_get_buf(win)] = true
  end
  return visible
end

local function find_buffer_by_filepath(filepath)
  local visible_buffers = get_visible_buffers()
  for buf, _ in pairs(visible_buffers) do
    if vim.api.nvim_buf_get_name(buf) == filepath then
      return buf
    end
  end
  return nil
end

local function hot_reload_buffer(filepath)
  if not should_check() then
    return
  end

  local buf = find_buffer_by_filepath(filepath)
  if buf and should_reload_buffer(buf) then
    vim.cmd("checktime " .. buf)
  end
end

local function process_change(err, filename, events, watch_dir)
  if err then
    return
  end

  if not filename or is_ignored(filename) then
    return
  end

  local full_path = watch_dir .. "/" .. filename

  if config.hot_reload then
    hot_reload_buffer(full_path)
  end

  for _, handler in pairs(on_change_handlers) do
    pcall(handler, full_path, events)
  end
end

function M.start(dir, on_update)
  if handle then
    M.stop()
  end

  dir = dir or vim.fn.getcwd()
  local delay = config.debounce_ms or 100

  if on_update then
    M.register_handler("default", on_update)
  end

  handle = uv.new_fs_event()
  if not handle then
    return false
  end

  local on_change = debounce(function(err, filename, events)
    process_change(err, filename, events, dir)
  end, delay)

  local ok, err = handle:start(dir, { recursive = true }, vim.schedule_wrap(on_change))
  if ok ~= 0 then
    vim.notify("Resu: Failed to start watcher - " .. (err or "unknown error"), vim.log.levels.ERROR)
    return false
  end

  return true
end

function M.stop()
  if handle then
    if not uv.is_closing(handle) then
      handle:stop()
      uv.close(handle)
    end
    handle = nil
  end

  if debounce_timer then
    if not uv.is_closing(debounce_timer) then
      uv.timer_stop(debounce_timer)
      uv.close(debounce_timer)
    end
    debounce_timer = nil
  end
end

function M.setup_autocmds()
  local group = vim.api.nvim_create_augroup("resu_hot_reload", { clear = true })

  vim.api.nvim_create_autocmd({ "FocusGained", "TermLeave", "BufEnter", "WinEnter", "CursorHold", "CursorHoldI" }, {
    group = group,
    callback = function()
      if not config.hot_reload then
        return
      end

      if should_check() then
        vim.cmd("checktime")
      end
    end,
  })
end

function M.reload_all_visible()
  if not should_check() then
    return
  end

  local visible_buffers = get_visible_buffers()
  for buf, _ in pairs(visible_buffers) do
    if should_reload_buffer(buf) then
      vim.cmd("checktime " .. buf)
    end
  end
end

return M
