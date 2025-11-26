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

local function render()
  if not buf_nr or not vim.api.nvim_buf_is_valid(buf_nr) then
    return
  end

  local files = state.get_files()
  local lines = {}
  local highlights = {} -- { {line, col_start, col_end, hl_group} }

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

      -- Add highlighting for status
      local hl_group = "Comment"
      if file.status == state.Status.ACCEPTED then
        hl_group = "String" -- Green-ish usually
      elseif file.status == state.Status.DECLINED then
        hl_group = "Error" -- Red-ish
      elseif file.status == state.Status.PENDING then
        hl_group = "WarningMsg" -- Orange/Yellow usually
      end

      -- Determine highlight range for icon
      -- Icon is at index 2 (1-based) in string " I Name"
      -- Lua strings 1-based, nvim_buf_add_highlight 0-based
      -- line i-1
      -- col start 1, col end 2

      -- We'll just highlight the whole line for now or the icon
      -- Let's use a namespace/add_highlight later if we want fancy colors.
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
    diff.close()
  end
end

function M.open()
  if M.is_open() then
    -- Focus it?
    vim.api.nvim_set_current_win(win_id)
    return
  end

  -- Create a side split
  vim.cmd("topleft vnew")
  win_id = vim.api.nvim_get_current_win()
  buf_nr = vim.api.nvim_get_current_buf()

  -- Configure buffer
  vim.api.nvim_buf_set_name(buf_nr, "AI Review")
  vim.api.nvim_buf_set_option(buf_nr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf_nr, "swapfile", false)
  vim.api.nvim_buf_set_option(buf_nr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf_nr, "filetype", "resu-review")

  -- Configure window
  vim.api.nvim_win_set_width(win_id, config.window.width)
  vim.api.nvim_win_set_option(win_id, "wrap", false)
  vim.api.nvim_win_set_option(win_id, "cursorline", true)
  vim.api.nvim_win_set_option(win_id, "number", false)
  vim.api.nvim_win_set_option(win_id, "relativenumber", false)

  -- Initial render
  render()

  -- Trigger diff for first file if available
  local current = state.get_current_file()
  if current then
    diff.open(current.path)
    -- Switch back to review window only if in same tab
    if vim.api.nvim_win_is_valid(win_id) then
      if vim.api.nvim_win_get_tabpage(win_id) == vim.api.nvim_get_current_tabpage() then
        vim.api.nvim_set_current_win(win_id)
      end
    end
  end
end

function M.refresh()
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
  render() -- Moves cursor
  local current = state.get_current_file()
  if current then
    diff.open(current.path)
    -- Keep focus on list only if in same tab
    if win_id and vim.api.nvim_win_is_valid(win_id) then
      if vim.api.nvim_win_get_tabpage(win_id) == vim.api.nvim_get_current_tabpage() then
        vim.api.nvim_set_current_win(win_id)
      end
    end
  end
end

return M
