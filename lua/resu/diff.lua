local M = {}
local config = require("resu.config").defaults

local function is_diffview_installed()
  local ok, _ = pcall(require, "diffview")
  return ok
end

function M.open(file_path)
  if not file_path then return end

  if is_diffview_installed() then
    -- Use Diffview.nvim
    -- We want to open diff for a specific file against HEAD usually
    vim.cmd("DiffviewOpen --selected-file=" .. vim.fn.fnameescape(file_path))
  else
    -- Fallback: Native diff
    -- 1. Open the modified file
    vim.cmd("edit " .. vim.fn.fnameescape(file_path))
    local win_curr = vim.api.nvim_get_current_win()
    
    -- 2. Get the git root to construct relative path for git show if needed, 
    -- or just assume cwd if simpler. Let's try to show HEAD version.
    -- This is a bit complex to implement robustly without a library, 
    -- but let's try a simple vertical split with HEAD version.
    
    local relative_path = vim.fn.fnamemodify(file_path, ":.")
    local cmd = "git show HEAD:" .. vim.fn.shellescape(relative_path)
    local content = vim.fn.systemlist(cmd)
    
    if vim.v.shell_error == 0 then
      vim.cmd("vnew")
      local buf = vim.api.nvim_get_current_buf()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
      vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
      vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
      vim.api.nvim_buf_set_name(buf, "Original: " .. relative_path)
      
      -- Set filetype to match original
      local ft = vim.filetype.match({ filename = file_path })
      if ft then
        vim.api.nvim_buf_set_option(buf, "filetype", ft)
      end
      
      vim.cmd("diffthis")
      vim.api.nvim_set_current_win(win_curr)
      vim.cmd("diffthis")
    else
      -- Not a git repo or error, just open the file
      vim.notify("Resu: Could not open diff (not a git repo?), opening file instead.", vim.log.levels.INFO)
    end
  end
end

function M.close()
  if is_diffview_installed() then
    vim.cmd("DiffviewClose")
  else
    -- Turn off diff mode
    vim.cmd("diffoff!")
    -- Close the scratch buffer if we created one? 
    -- It's hard to track which one without state, but diffoff is a good start.
    -- The user can close the split manually if needed, or we can try to close other windows.
    -- For now, just diffoff.
  end
end

return M

