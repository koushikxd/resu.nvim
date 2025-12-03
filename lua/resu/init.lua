local M = {}

local config_module = require("resu.config")
local watcher = require("resu.watcher")
local diffview = require("resu.diffview")

local legacy_ui = nil
local legacy_diff = nil

local function get_legacy_ui()
  if not legacy_ui then
    legacy_ui = require("resu.ui")
  end
  return legacy_ui
end

local function get_legacy_diff()
  if not legacy_diff then
    legacy_diff = require("resu.diff")
  end
  return legacy_diff
end

local function use_diffview()
  return config_module.defaults.use_diffview and diffview.is_available()
end

function M.setup(opts)
  config_module.defaults = vim.tbl_deep_extend("force", config_module.defaults, opts or {})

  local dir = config_module.defaults.watch_dir or vim.fn.getcwd()

  if use_diffview() then
    diffview.setup()
    watcher.register_handler("diffview", diffview.on_file_change)
  end

  watcher.start(dir, function()
    if use_diffview() then
      diffview.update_files()
    else
      get_legacy_ui().refresh()
    end
  end)

  watcher.setup_autocmds()

  local maps = config_module.defaults.keymaps

  vim.keymap.set("n", maps.toggle, function()
    M.toggle()
  end, { silent = true, desc = "Resu: Toggle diff view" })

  vim.keymap.set("n", maps.accept, function()
    M.accept()
  end, { silent = true, desc = "Resu: Accept current file" })

  vim.keymap.set("n", maps.decline, function()
    M.decline()
  end, { silent = true, desc = "Resu: Decline current file" })

  vim.keymap.set("n", maps.accept_all, function()
    M.accept_all()
  end, { silent = true, desc = "Resu: Accept all changes" })

  vim.keymap.set("n", maps.decline_all, function()
    M.decline_all()
  end, { silent = true, desc = "Resu: Decline all changes" })

  vim.keymap.set("n", maps.refresh, function()
    M.refresh()
  end, { silent = true, desc = "Resu: Refresh view" })
end

function M.open()
  if use_diffview() then
    diffview.open()
  else
    get_legacy_ui().open()
  end
end

function M.close()
  if use_diffview() then
    diffview.close()
  else
    get_legacy_ui().close()
  end
end

function M.toggle()
  if use_diffview() then
    diffview.toggle()
  else
    get_legacy_ui().toggle()
  end
end

function M.refresh()
  if use_diffview() then
    diffview.update_files()
    watcher.reload_all_visible()
  else
    get_legacy_ui().refresh()
  end
  vim.notify("Resu: Refreshed", vim.log.levels.INFO)
end

function M.accept()
  if use_diffview() then
    local file = diffview.get_current_file()
    if file then
      if diffview.stage_file(file) then
        vim.notify("Resu: Staged " .. file, vim.log.levels.INFO)
      end
    else
      vim.notify("Resu: No file selected", vim.log.levels.WARN)
    end
  else
    local state = require("resu.state")
    local current = state.get_current_file()
    if current then
      local path = current.path
      local buf = vim.fn.bufnr(path)
      if buf ~= -1 and vim.api.nvim_buf_is_valid(buf) then
        get_legacy_diff().clear(buf)
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local f = io.open(path, "w")
        if f then
          f:write(table.concat(lines, "\n") .. "\n")
          f:close()
          vim.api.nvim_buf_set_option(buf, "modified", false)
        end
      end
      state.update_status(path, state.Status.ACCEPTED)
      vim.notify("Resu: Accepted " .. path, vim.log.levels.INFO)
      get_legacy_ui().update_selection()
    else
      vim.notify("Resu: No file selected", vim.log.levels.WARN)
    end
  end
end

function M.decline()
  if use_diffview() then
    local file = diffview.get_current_file()
    if file then
      if diffview.revert_file(file) then
        vim.notify("Resu: Reverted " .. file, vim.log.levels.INFO)
      end
    else
      vim.notify("Resu: No file selected", vim.log.levels.WARN)
    end
  else
    local state = require("resu.state")
    local current = state.get_current_file()
    if current then
      local path = current.path
      local cmd = "git show HEAD:" .. vim.fn.shellescape(path)
      local original_lines = vim.fn.systemlist(cmd)
      if vim.v.shell_error ~= 0 then
        vim.notify("Resu: Could not revert (not in HEAD)", vim.log.levels.WARN)
        return
      end

      local f = io.open(path, "w")
      if f then
        f:write(table.concat(original_lines, "\n"))
        f:close()

        local buf = vim.fn.bufnr(path)
        if buf ~= -1 and vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, original_lines)
          vim.api.nvim_buf_set_option(buf, "modified", false)
          vim.api.nvim_buf_call(buf, function()
            vim.cmd("silent! checktime")
          end)
          get_legacy_diff().clear(buf)
        end
        state.update_status(path, state.Status.DECLINED)
        vim.notify("Resu: Reverted " .. path, vim.log.levels.INFO)
        get_legacy_ui().update_selection()
      else
        vim.notify("Resu: Failed to revert " .. path, vim.log.levels.ERROR)
      end
    end
  end
end

function M.accept_all()
  if use_diffview() then
    diffview.stage_all()
    vim.notify("Resu: Staged all changes", vim.log.levels.INFO)
  else
    local state = require("resu.state")
    local files = state.get_files()
    local count = 0
    local skipped = 0
    for _, file in ipairs(files) do
      if file.status == state.Status.PENDING then
        local buf = vim.fn.bufnr(file.path)
        if buf ~= -1 and vim.api.nvim_buf_is_valid(buf) then
          local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
          local f = io.open(file.path, "w")
          if f then
            f:write(table.concat(lines, "\n") .. "\n")
            f:close()
            vim.api.nvim_buf_set_option(buf, "modified", false)
            get_legacy_diff().clear(buf)
            state.update_status(file.path, state.Status.ACCEPTED)
            count = count + 1
          else
            skipped = skipped + 1
          end
        else
          skipped = skipped + 1
        end
      end
    end
    get_legacy_ui().update_selection()
    if skipped > 0 then
      vim.notify(
        "Resu: Accepted " .. count .. " files, skipped " .. skipped .. " (no buffer or write failed)",
        vim.log.levels.WARN
      )
    else
      vim.notify("Resu: Accepted all changes (" .. count .. " files)", vim.log.levels.INFO)
    end
  end
end

function M.decline_all()
  if use_diffview() then
    local choice = vim.fn.confirm("Revert ALL changes? This cannot be undone.", "&Yes\n&No", 2)
    if choice == 1 then
      diffview.revert_all()
      vim.notify("Resu: Reverted all changes", vim.log.levels.INFO)
    end
  else
    local state = require("resu.state")
    local files = state.get_files()
    local count = 0
    local skipped = 0
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
              vim.api.nvim_buf_set_option(buf, "modified", false)
              get_legacy_diff().clear(buf)
            end
            state.update_status(file.path, state.Status.DECLINED)
            count = count + 1
          else
            skipped = skipped + 1
          end
        else
          skipped = skipped + 1
        end
      end
    end
    get_legacy_ui().update_selection()
    if skipped > 0 then
      vim.notify(
        "Resu: Declined " .. count .. " files, skipped " .. skipped .. " (not in HEAD or write failed)",
        vim.log.levels.WARN
      )
    else
      vim.notify("Resu: Declined all changes (" .. count .. " files)", vim.log.levels.INFO)
    end
  end
end

function M.reset()
  if use_diffview() then
    diffview.close()
  else
    local state = require("resu.state")
    state.reset()
    state.clear_persistent_state()
    get_legacy_diff().clear_all()
    get_legacy_ui().refresh()
  end
  vim.notify("Resu: State reset", vim.log.levels.INFO)
end

function M.next()
  if not use_diffview() then
    local state = require("resu.state")
    if state.next_file() then
      get_legacy_ui().update_selection()
    end
  end
end

function M.prev()
  if not use_diffview() then
    local state = require("resu.state")
    if state.prev_file() then
      get_legacy_ui().update_selection()
    end
  end
end

return M
