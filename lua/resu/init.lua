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

  vim.api.nvim_create_autocmd("FileType", {
    pattern = "resu-review",
    callback = function(ev)
      local maps = config_module.defaults.keymaps
      local buf_opts = { buffer = ev.buf, silent = true, nowait = true }

      vim.keymap.set("n", maps.accept, function()
        M.accept()
      end, buf_opts)
      vim.keymap.set("n", maps.decline, function()
        M.decline()
      end, buf_opts)
      vim.keymap.set("n", maps.next, function()
        M.next()
      end, buf_opts)
      vim.keymap.set("n", maps.prev, function()
        M.prev()
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
    state.update_status(current.path, state.Status.ACCEPTED)

    local buf = vim.fn.bufnr(current.path)
    if buf ~= -1 and vim.api.nvim_buf_is_valid(buf) then
      diff.clear(buf)
    end

    vim.notify("Resu: Accepted " .. current.path, vim.log.levels.INFO)
    ui.refresh()
    M.next()
  else
    vim.notify("Resu: No file selected", vim.log.levels.WARN)
  end
end

function M.decline()
  local current = state.get_current_file()
  if current then
    state.update_status(current.path, state.Status.DECLINED)

    local cmd = "git show HEAD:" .. vim.fn.shellescape(current.path)
    local original_lines = vim.fn.systemlist(cmd)

    if vim.v.shell_error == 0 then
      local f = io.open(current.path, "w")
      if f then
        f:write(table.concat(original_lines, "\n"))
        f:close()

        local buf = vim.fn.bufnr(current.path)
        if buf ~= -1 and vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, original_lines)
          diff.clear(buf)
        end
        vim.notify("Resu: Reverted " .. current.path, vim.log.levels.INFO)
      else
        vim.notify("Resu: Failed to revert " .. current.path, vim.log.levels.ERROR)
      end
    else
      vim.notify("Resu: Could not revert (not in HEAD?)", vim.log.levels.WARN)
    end

    ui.refresh()
    M.next()
  end
end

function M.accept_all()
  local files = state.get_files()
  local count = 0
  for _, file in ipairs(files) do
    if file.status == state.Status.PENDING then
      state.update_status(file.path, state.Status.ACCEPTED)
      local buf = vim.fn.bufnr(file.path)
      if buf ~= -1 and vim.api.nvim_buf_is_valid(buf) then
        diff.clear(buf)
      end
      count = count + 1
    end
  end
  ui.refresh()
  vim.notify("Resu: Accepted all changes (" .. count .. " files)", vim.log.levels.INFO)
end

function M.decline_all()
  local files = state.get_files()
  local count = 0
  for _, file in ipairs(files) do
    if file.status == state.Status.PENDING then
      local cmd = "git show HEAD:" .. vim.fn.shellescape(file.path)
      local original_lines = vim.fn.systemlist(cmd)

      if vim.v.shell_error == 0 then
        local f = io.open(file.path, "w")
        if f then
          f:write(table.concat(original_lines, "\n"))
          f:close()

          local buf = vim.fn.bufnr(file.path)
          if buf ~= -1 and vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, original_lines)
            diff.clear(buf)
          end
        end
      end
      state.update_status(file.path, state.Status.DECLINED)
      count = count + 1
    end
  end
  ui.refresh()
  vim.notify("Resu: Declined all changes (" .. count .. " files)", vim.log.levels.INFO)
end

function M.reset()
  state.reset()
  diff.clear_all()
  reviewed_buffers = {}
  ui.refresh()
  vim.notify("Resu: State reset", vim.log.levels.INFO)
end

return M
