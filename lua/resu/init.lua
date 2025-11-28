local M = {}

local config_module = require("resu.config")
local state = require("resu.state")
local watcher = require("resu.watcher")
local ui = require("resu.ui")
local diff = require("resu.diff")

local reviewed_buffers = {}

local function setup_editor_keymaps(buf)
  if reviewed_buffers[buf] then
    return
  end
  reviewed_buffers[buf] = true

  local maps = config_module.defaults.keymaps
  local opts = { buffer = buf, silent = true, nowait = true }

  vim.keymap.set("n", maps.accept, function()
    M.accept()
  end, opts)

  vim.keymap.set("n", maps.decline, function()
    M.decline()
  end, opts)
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

function M.setup(opts)
  config_module.defaults = vim.tbl_deep_extend("force", config_module.defaults, opts or {})

  local dir = config_module.defaults.watch_dir or vim.fn.getcwd()
  watcher.start(dir, function()
    ui.refresh()
  end)

  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      if ui.is_open() and has_pending_files() then
        local choice = vim.fn.confirm(
          "Resu: You have pending changes. What would you like to do?",
          "&Accept All\n&Decline All\n&Cancel",
          3
        )
        if choice == 1 then
          M.accept_all()
        elseif choice == 2 then
          M.decline_all()
        elseif choice == 3 then
          vim.cmd("throw 'Resu: Exit cancelled'")
        end
      end
    end,
  })

  local maps = config_module.defaults.keymaps

  vim.keymap.set("n", maps.next, function()
    if ui.is_open() then
      M.next()
    end
  end, { silent = true, desc = "Resu: Next file" })

  vim.keymap.set("n", maps.prev, function()
    if ui.is_open() then
      M.prev()
    end
  end, { silent = true, desc = "Resu: Previous file" })

  vim.api.nvim_create_autocmd("FileType", {
    pattern = "resu-review",
    callback = function(ev)
      local buf_opts = { buffer = ev.buf, silent = true, nowait = true }

      vim.keymap.set("n", maps.accept, function()
        M.accept()
      end, buf_opts)
      vim.keymap.set("n", maps.decline, function()
        M.decline()
      end, buf_opts)
      vim.keymap.set("n", maps.quit, function()
        M.close()
      end, buf_opts)
      vim.keymap.set("n", "<CR>", function()
        M.open_current_file()
      end, buf_opts)
      vim.keymap.set("n", "j", function()
        M.next()
      end, buf_opts)
      vim.keymap.set("n", "k", function()
        M.prev()
      end, buf_opts)
    end,
  })
end

function M.register_editor_buffer(buf)
  setup_editor_keymaps(buf)
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

function M.open_current_file()
  local current = state.get_current_file()
  if current then
    ui.open_editor(current.path)
  end
end

function M.accept()
  local current = state.get_current_file()
  if current then
    local path = current.path
    local buf = vim.fn.bufnr(path)
    if buf ~= -1 and vim.api.nvim_buf_is_valid(buf) then
      diff.clear(buf)
    end

    state.update_status(path, state.Status.ACCEPTED)
    vim.notify("Resu: Accepted " .. path, vim.log.levels.INFO)
    ui.update_selection()
  else
    vim.notify("Resu: No file selected", vim.log.levels.WARN)
  end
end

function M.decline()
  local current = state.get_current_file()
  if current then
    local path = current.path
    local cmd = "git show HEAD:" .. vim.fn.shellescape(path)
    local original_lines = vim.fn.systemlist(cmd)

    if vim.v.shell_error == 0 then
      local f = io.open(path, "w")
      if f then
        f:write(table.concat(original_lines, "\n"))
        f:close()

        local buf = vim.fn.bufnr(path)
        if buf ~= -1 and vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, original_lines)
          diff.clear(buf)
        end
        state.update_status(path, state.Status.DECLINED)
        vim.notify("Resu: Reverted " .. path, vim.log.levels.INFO)
        ui.update_selection()
      else
        vim.notify("Resu: Failed to revert " .. path, vim.log.levels.ERROR)
      end
    else
      vim.notify("Resu: Could not revert (not in HEAD?)", vim.log.levels.WARN)
    end
  end
end

function M.accept_all()
  local files = state.get_files()
  local paths = {}
  for _, file in ipairs(files) do
    if file.status == state.Status.PENDING then
      table.insert(paths, file.path)
    end
  end

  local count = 0
  for _, path in ipairs(paths) do
    local buf = vim.fn.bufnr(path)
    if buf ~= -1 and vim.api.nvim_buf_is_valid(buf) then
      diff.clear(buf)
    end
    state.update_status(path, state.Status.ACCEPTED)
    count = count + 1
  end

  ui.update_selection()
  vim.notify("Resu: Accepted all changes (" .. count .. " files)", vim.log.levels.INFO)
end

function M.decline_all()
  local files = state.get_files()
  local paths = {}
  for _, file in ipairs(files) do
    if file.status == state.Status.PENDING then
      table.insert(paths, file.path)
    end
  end

  local count = 0
  for _, path in ipairs(paths) do
    local cmd = "git show HEAD:" .. vim.fn.shellescape(path)
    local original_lines = vim.fn.systemlist(cmd)

    if vim.v.shell_error == 0 then
      local f = io.open(path, "w")
      if f then
        f:write(table.concat(original_lines, "\n"))
        f:close()

        local buf = vim.fn.bufnr(path)
        if buf ~= -1 and vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, original_lines)
          diff.clear(buf)
        end
      end
    end
    state.update_status(path, state.Status.DECLINED)
    count = count + 1
  end

  ui.update_selection()
  vim.notify("Resu: Declined all changes (" .. count .. " files)", vim.log.levels.INFO)
end

function M.reset()
  state.reset()
  state.clear_persistent_state()
  diff.clear_all()
  reviewed_buffers = {}
  ui.refresh()
  vim.notify("Resu: State reset", vim.log.levels.INFO)
end

return M
