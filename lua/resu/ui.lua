---@module resu.ui
--- Handles the review panel UI and editor window management.
--- Creates a sidebar listing changed files and coordinates with diff module
--- to show inline changes in the editor split.
local M = {}
local state = require("resu.state")
local config = require("resu.config").defaults
local diff = require("resu.diff")

--- Window/buffer handles for the file list panel and editor
local buf_nr = nil
local win_id = nil
local _editor_win_id = nil

local function get_status_icon(status)
  if status == state.Status.ACCEPTED then
    return "✓"
  elseif status == state.Status.DECLINED then
    return "✗"
  else
    return "•"
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
    for _, file in ipairs(files) do
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

  local current_idx = state.get_current_index()
  if win_id and vim.api.nvim_win_is_valid(win_id) and #files > 0 then
    pcall(vim.api.nvim_win_set_cursor, win_id, { current_idx, 0 })
  end
end

function M.is_open()
  return win_id and vim.api.nvim_win_is_valid(win_id)
end

local function has_pending_files()
  local files = state.get_files()
  for _, file in ipairs(files) do
    if file.status == state.Status.PENDING then
      return true
    end
  end
  return false
end

local function do_close()
  diff.clear_all()

  if win_id and vim.api.nvim_win_is_valid(win_id) then
    vim.api.nvim_win_close(win_id, true)
  end
  win_id = nil
  buf_nr = nil
  _editor_win_id = nil
end

function M.close()
  if not M.is_open() then
    return
  end

  if has_pending_files() then
    vim.ui.select(
      { "Accept All", "Decline All", "Cancel" },
      { prompt = "You have pending changes. What would you like to do?" },
      function(choice)
        if choice == "Accept All" then
          require("resu").accept_all()
          do_close()
        elseif choice == "Decline All" then
          require("resu").decline_all()
          do_close()
        end
      end
    )
  else
    do_close()
  end
end

function M.open_editor(file_path)
  if not file_path then
    return
  end

  local target_win = nil

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= win_id then
      local buf = vim.api.nvim_win_get_buf(win)
      local name = vim.api.nvim_buf_get_name(buf)
      if name:match(vim.pesc(file_path) .. "$") then
        target_win = win
        break
      end
    end
  end

  if target_win then
    vim.api.nvim_set_current_win(target_win)
    _editor_win_id = target_win
  else
    vim.cmd("wincmd l")
    if vim.api.nvim_get_current_win() == win_id then
      vim.cmd("vnew")
    end
    vim.cmd("edit " .. vim.fn.fnameescape(file_path))
    _editor_win_id = vim.api.nvim_get_current_win()
  end

  local buf = vim.api.nvim_get_current_buf()

  local current_file = state.get_current_file()
  if current_file and current_file.status == state.Status.PENDING then
    diff.render_inline(buf, file_path)
  else
    diff.clear(buf)
  end
end

function M.open()
  if M.is_open() then
    vim.api.nvim_set_current_win(win_id)
    return
  end

  state.scan_changes()

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

  vim.api.nvim_create_autocmd("WinClosed", {
    buffer = buf_nr,
    once = true,
    callback = function()
      if has_pending_files() then
        vim.schedule(function()
          vim.ui.select(
            { "Accept All", "Decline All", "Leave as is" },
            { prompt = "You have pending changes. What would you like to do?" },
            function(choice)
              if choice == "Accept All" then
                require("resu").accept_all()
              elseif choice == "Decline All" then
                require("resu").decline_all()
              end
              diff.clear_all()
            end
          )
        end)
      else
        diff.clear_all()
      end
      win_id = nil
      buf_nr = nil
      _editor_win_id = nil
    end,
  })

  render()

  local current = state.get_current_file()
  if current then
    M.open_editor(current.path)
    if vim.api.nvim_win_is_valid(win_id) then
      vim.api.nvim_set_current_win(win_id)
    end
  end
end

local function force_reload_buffer(buf, file_path)
  if not buf or buf == -1 or not vim.api.nvim_buf_is_valid(buf) then
    return false
  end

  local file = io.open(file_path, "r")
  if not file then
    return false
  end

  local content = file:read("*a")
  file:close()

  local lines = vim.split(content, "\n", { plain = true })
  if lines[#lines] == "" then
    table.remove(lines)
  end

  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modified", false)

  return true
end

function M.refresh()
  if not M.is_open() then
    return
  end

  local files = state.get_files()
  for _, file in ipairs(files) do
    local buf = vim.fn.bufnr(file.path)
    if buf ~= -1 and vim.api.nvim_buf_is_valid(buf) then
      local full_path = vim.fn.fnamemodify(file.path, ":p")
      force_reload_buffer(buf, full_path)

      if file.status == state.Status.PENDING then
        diff.render_inline(buf, file.path)
      end
    end
  end

  state.scan_changes()
  vim.schedule(function()
    render()
  end)
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
    if vim.api.nvim_win_is_valid(win_id) then
      vim.api.nvim_set_current_win(win_id)
    end
  end
end

return M
