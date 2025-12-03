local M = {}

local is_open = false
local diffview_available = nil

local function check_diffview()
  if diffview_available == nil then
    diffview_available = pcall(require, "diffview")
  end
  return diffview_available
end

local function is_git_ignored(filepath)
  vim.fn.system("git check-ignore -q " .. vim.fn.shellescape(filepath))
  return vim.v.shell_error == 0
end

function M.is_available()
  return check_diffview()
end

function M.is_open()
  return is_open
end

function M.open()
  if not check_diffview() then
    vim.notify("Resu: diffview.nvim not installed", vim.log.levels.WARN)
    return false
  end

  if is_open then
    M.update_files()
    return true
  end

  vim.cmd("DiffviewOpen --imply-local")
  is_open = true
  return true
end

function M.close()
  if not check_diffview() or not is_open then
    return
  end

  vim.cmd("DiffviewClose")
  is_open = false
end

function M.toggle()
  if is_open then
    M.close()
  else
    M.open()
  end
end

function M.update_files()
  if not check_diffview() or not is_open then
    return
  end

  pcall(function()
    local lib = require("diffview.lib")
    local view = lib.get_current_view()
    if view then
      view:update_files()
    end
  end)
end

function M.on_file_change(filepath, _)
  if not is_open then
    return
  end

  local is_in_dot_git_dir = filepath:match("/%.git/") or filepath:match("^%.git/")
  if not is_in_dot_git_dir and not is_git_ignored(filepath) then
    M.update_files()
  end
end

function M.setup()
  if not check_diffview() then
    return
  end

  vim.api.nvim_create_autocmd("User", {
    pattern = "DiffviewViewOpened",
    callback = function()
      is_open = true
    end,
  })

  vim.api.nvim_create_autocmd("User", {
    pattern = "DiffviewViewClosed",
    callback = function()
      is_open = false
    end,
  })

  vim.api.nvim_create_autocmd("User", {
    pattern = "DiffviewDiffBufRead",
    callback = function()
      vim.opt_local.foldenable = false
      vim.opt_local.foldlevel = 99
    end,
  })

  vim.api.nvim_create_autocmd("FocusGained", {
    callback = function()
      if is_open then
        M.update_files()
      end
    end,
  })
end

function M.stage_file(filepath)
  if not filepath then
    return false
  end

  local result = vim.fn.system("git add " .. vim.fn.shellescape(filepath))
  if vim.v.shell_error ~= 0 then
    vim.notify("Resu: Failed to stage " .. filepath, vim.log.levels.ERROR)
    return false
  end

  M.update_files()
  return true
end

function M.revert_file(filepath)
  if not filepath then
    return false
  end

  local is_untracked = vim.fn.system("git ls-files --others --exclude-standard " .. vim.fn.shellescape(filepath))
  if vim.trim(is_untracked) ~= "" then
    os.remove(filepath)
    local buf = vim.fn.bufnr(filepath)
    if buf ~= -1 and vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  else
    vim.fn.system("git checkout -- " .. vim.fn.shellescape(filepath))
    if vim.v.shell_error ~= 0 then
      vim.notify("Resu: Failed to revert " .. filepath, vim.log.levels.ERROR)
      return false
    end

    local buf = vim.fn.bufnr(filepath)
    if buf ~= -1 and vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_call(buf, function()
        vim.cmd("silent! e!")
      end)
    end
  end

  M.update_files()
  return true
end

function M.get_current_file()
  if not check_diffview() or not is_open then
    return nil
  end

  local ok, lib = pcall(require, "diffview.lib")
  if not ok then
    return nil
  end

  local view = lib.get_current_view()
  if not view then
    return nil
  end

  local file = view.panel:get_item_at_cursor()
  if file and file.path then
    return file.path
  end

  return nil
end

function M.stage_all()
  vim.fn.system("git add -A")
  M.update_files()
end

function M.revert_all()
  vim.fn.system("git checkout -- .")
  vim.fn.system("git clean -fd")
  M.update_files()
end

return M
