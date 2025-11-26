---@diagnostic disable: undefined-global
local M = {}

local config_module = require("resu.config")
local state = require("resu.state")
local watcher = require("resu.watcher")
local ui = require("resu.ui")
local diff = require("resu.diff")

-- Public API

function M.setup(opts)
  config_module.defaults = vim.tbl_deep_extend("force", config_module.defaults, opts or {})

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
        M.open_current_file()
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

    -- "Accepting" in inline mode means we clear the diffs (virt text)
    -- and consider the changes "merged" (i.e., we keep the file as is).
    -- We DO NOT git add.

    -- Find buffer if open
    local buf = vim.fn.bufnr(current.path)
    if buf ~= -1 and vim.api.nvim_buf_is_valid(buf) then
      diff.clear(buf)
    end

    -- We might want to keep the file in the list as "Accepted"
    -- until manually refreshed or reset.
    ui.refresh()
    M.next()
  end
end

function M.decline()
  local current = state.get_current_file()
  if current then
    state.update_status(current.path, state.Status.DECLINED)

    -- "Declining" means we revert the file to HEAD.
    -- This effectively undoes the changes made by the AI tool.
    local cmd = "git show HEAD:" .. vim.fn.shellescape(current.path)
    local original_lines = vim.fn.systemlist(cmd)

    if vim.v.shell_error == 0 then
      -- Write original content back to file
      local f = io.open(current.path, "w")
      if f then
        f:write(table.concat(original_lines, "\n"))
        f:close()

        -- Reload buffer if open
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
      -- Maybe it was a new file? If so, delete it?
      -- If git show fails, it might not exist in HEAD.
      -- We should probably delete it if it's untracked/new.
      -- For safety, let's just warn for now or try to delete if empty.
      vim.notify("Resu: Could not revert (not in HEAD?)", vim.log.levels.WARN)
    end

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
