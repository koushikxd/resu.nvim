---@diagnostic disable: undefined-global
local M = {}

local ns_id = vim.api.nvim_create_namespace("resu_inline_diff")

-- Highlight Groups (Link these to standard groups or define custom ones)
-- Red/Green backgrounds often depend on colorscheme.
-- Using 'DiffAdd' and 'DiffDelete' is safest, but we can force colors if needed.
vim.api.nvim_set_hl(0, "ResuDiffAdd", { link = "DiffAdd", default = true })
vim.api.nvim_set_hl(0, "ResuDiffDelete", { link = "DiffDelete", default = true })
-- For virtual lines (deleted code), we want it to look like "ghost" text
vim.api.nvim_set_hl(0, "ResuVirtualDelete", { link = "Comment", default = true })

function M.render_inline(buf, file_path)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  if not file_path then
    return
  end

  -- 1. Get Original Content (HEAD)
  local cmd = "git show HEAD:" .. vim.fn.shellescape(file_path)
  local original_lines = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    -- New file? Or error. If new file, original is empty.
    original_lines = {}
  end
  local original_text = table.concat(original_lines, "\n")

  -- 2. Get Current Buffer Content
  local current_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local current_text = table.concat(current_lines, "\n")

  -- 3. Calculate Diff
  -- result_type = "indices" returns a list of hunks
  -- Each hunk: { start_a, count_a, start_b, count_b }
  -- a = original, b = current
  local hunks = vim.diff(original_text, current_text, { result_type = "indices" })

  if not hunks then
    return
  end

  -- 4. Clear existing diff highlights
  M.clear(buf)

  -- 5. Apply Highlights & Virtual Text
  for _, hunk in ipairs(hunks) do
    local start_a, count_a, start_b, count_b = unpack(hunk)
    -- start_a, start_b are 1-based line numbers.
    -- count_a: number of lines removed from original
    -- count_b: number of lines added to current

    -- Handle DELETIONS (Lines present in original but missing in current)
    if count_a > 0 then
      -- We want to show these deleted lines as "virtual lines"
      -- attached to the line *before* where they would be, or at the current position.

      -- Extract the deleted lines from original_lines
      local deleted_lines = {}
      for i = 0, count_a - 1 do
        local line_idx = start_a + i
        -- indices are 1-based
        local content = original_lines[line_idx]
        if content then
          -- Each element in virt_lines is a "line" (list of chunks).
          -- Each chunk is { text, highlight_group }.
          -- We explicitly wrap the chunk in a table to form a line.
          table.insert(deleted_lines, { { content, "ResuDiffDelete" } })
        end
      end

      -- Insert point in current buffer:
      -- start_b is the first added line. If count_b is 0, it's an insertion point.
      -- We usually attach virt_lines to start_b - 1 (0-based).
      -- But if start_b is 1, we attach to line 0.

      local virt_line_pos = start_b - 1
      -- Ensure within bounds (attach to EOF if needed, but virt_lines handles that usually)

      -- Use virt_lines_above if possible to simulate natural flow
      vim.api.nvim_buf_set_extmark(buf, ns_id, virt_line_pos, 0, {
        virt_lines = deleted_lines,
        virt_lines_above = true,
      })
    end

    -- Handle ADDITIONS (Lines present in current but not in original)
    if count_b > 0 then
      for i = 0, count_b - 1 do
        local line_idx = start_b + i - 1 -- 0-based index for buffer
        -- Highlight the line green
        if line_idx >= 0 and line_idx < #current_lines then
          vim.api.nvim_buf_add_highlight(buf, ns_id, "ResuDiffAdd", line_idx, 0, -1)
        end
      end
    end
  end
end

function M.clear(buf)
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
  end
end

return M
