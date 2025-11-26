---@diagnostic disable: undefined-global
local M = {}
local state = require("resu.state")
local config = require("resu.config").defaults
local diff = require("resu.diff")

local buf_nr = nil
local win_id = nil

local function get_status_icon(status)
  if status == state.Status.ACCEPTED then
    return "✓" -- or [A]
  elseif status == state.Status.DECLINED then
    return "✗" -- or [D]
  else
    return "•" -- or [P]
  end
end

function M.get_window_handle()
  return win_id
end

local function render()
  if not buf_nr or not vim.api.nvim_buf_is_valid(buf_nr) then
    return
  end

  local files = state.get_files()
  local lines = {}

  if #files == 0 then
    table.insert(lines, "No changes detected.")
  else
    for i, file in ipairs(files) do
      local icon = get_status_icon(file.status)
      local name = vim.fn.fnamemodify(file.path, ":t")
      local dir = vim.fn.fnamemodify(file.path, ":h")
      if dir == "." then
        dir = ""
      else
        dir = "(" .. dir .. ")"
      end

      local line = string.format(" %s %s %s", icon, name, dir)
      table.insert(lines, line)
    end
  end

  vim.api.nvim_buf_set_option(buf_nr, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf_nr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf_nr, "modifiable", false)

  -- Update cursor position to match current index
  local current_idx = state.get_current_index()
  if win_id and vim.api.nvim_win_is_valid(win_id) and #files > 0 then
    pcall(vim.api.nvim_win_set_cursor, win_id, { current_idx, 0 })
  end
end

function M.is_open()
  return win_id and vim.api.nvim_win_is_valid(win_id)
end

function M.close()
  if M.is_open() then
    vim.api.nvim_win_close(win_id, true)
    win_id = nil
    buf_nr = nil
    -- We don't necessarily close the editor window as the user might be working there.
    -- But we should clear highlights if closing the review session entirely.
    -- For now, let's just clear the sidebar.
  end
end

function M.open_editor(file_path)
  if not file_path then
    return
  end

  -- Check if we are already editing this file in a window to the right
  local target_win = nil

  -- Iterate windows to find if file is open
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= win_id then
      local buf = vim.api.nvim_win_get_buf(win)
      local name = vim.api.nvim_buf_get_name(buf)
      -- Simple check: if path ends with file_path (relative match)
      -- Robust check: fnamemodify both to absolute
      if name:match(vim.pesc(file_path) .. "$") then
        target_win = win
        break
      end
    end
  end

  if target_win then
    vim.api.nvim_set_current_win(target_win)
  else
    -- Open in new split to the right if sidebar is left
    vim.cmd("wincmd l")
    if vim.api.nvim_get_current_win() == win_id then
      -- If we didn't move, create new split
      vim.cmd("vnew")
    end
    vim.cmd("edit " .. vim.fn.fnameescape(file_path))
  end

  -- Render inline diff
  local buf = vim.api.nvim_get_current_buf()
  diff.render_inline(buf, file_path)
end

function M.open()
  if M.is_open() then
    vim.api.nvim_set_current_win(win_id)
    return
  end

  state.scan_changes()

  -- Create sidebar
  vim.cmd("topleft vnew")
  win_id = vim.api.nvim_get_current_win()
  buf_nr = vim.api.nvim_get_current_buf()

  vim.api.nvim_buf_set_name(buf_nr, "AI Review")
  vim.api.nvim_buf_set_option(buf_nr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf_nr, "swapfile", false)
  vim.api.nvim_buf_set_option(buf_nr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf_nr, "filetype", "resu-review")

  vim.api.nvim_win_set_width(win_id, config.window.width)
  vim.api.nvim_win_set_option(win_id, "wrap", false)
  vim.api.nvim_win_set_option(win_id, "cursorline", true)
  vim.api.nvim_win_set_option(win_id, "number", false)
  vim.api.nvim_win_set_option(win_id, "relativenumber", false)

  render()

  -- Trigger diff for first file
  local current = state.get_current_file()
  if current then
    M.open_editor(current.path)
    -- Return focus to sidebar
    if vim.api.nvim_win_is_valid(win_id) then
      vim.api.nvim_set_current_win(win_id)
    end
  end
end

function M.refresh()
  -- Sync current buffer with disk if needed
  local current = state.get_current_file()
  if current then
    local buf = vim.fn.bufnr(current.path)
    if buf ~= -1 and vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_call(buf, function()
        vim.cmd("checktime")
      end)
      -- Re-render diff immediately
      diff.render_inline(buf, current.path)
    end
  end

  state.scan_changes()
  if M.is_open() then
    vim.schedule(function()
      render()
    end)
  end
end

function M.toggle()
  if M.is_open() then
    M.close()
  else
    M.open()
  end
end

function M.update_selection()
  render()
  local current = state.get_current_file()
  if current then
    M.open_editor(current.path)
    -- Return focus to sidebar
    if vim.api.nvim_win_is_valid(win_id) then
      vim.api.nvim_set_current_win(win_id)
    end
  end
end

return M
