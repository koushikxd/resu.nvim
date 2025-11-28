---@module resu.diff
--- Renders inline diffs using extmarks (virtual text).
--- Compares current buffer content against baseline (saved snapshot or git HEAD).
--- Deleted lines appear as virtual lines above, added lines get background highlight.
local M = {}

local ns_id = vim.api.nvim_create_namespace("resu_inline_diff")

vim.api.nvim_set_hl(0, "ResuDiffAdd", { bg = "#1e3a1e", fg = "#a6e3a1" })
vim.api.nvim_set_hl(0, "ResuDiffDelete", { bg = "#3d1f1f", fg = "#f38ba8" })

--- Track active buffers and their diff data for cleanup
local active_buffers = {}
local buffer_hunks = {}
local buffer_original = {}

function M.get_namespace()
  return ns_id
end

function M.get_active_buffers()
  return active_buffers
end

function M.get_hunks(buf)
  return buffer_hunks[buf] or {}
end

function M.get_original_lines(buf)
  return buffer_original[buf] or {}
end

--- Main diff rendering function. Gets original content from baseline or git HEAD,
--- computes hunks using vim.diff, then renders with extmarks.
function M.render_inline(buf, file_path)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  if not file_path then
    return
  end

  local state = require("resu.state")
  local baseline_content = state.get_baseline_content(file_path)

  local original_text
  local original_lines
  if baseline_content then
    original_text = baseline_content
    original_lines = vim.split(baseline_content, "\n", { plain = true })
    if original_lines[#original_lines] == "" then
      table.remove(original_lines)
    end
  else
    local cmd = "git show HEAD:" .. vim.fn.shellescape(file_path)
    original_lines = vim.fn.systemlist(cmd)
    if vim.v.shell_error ~= 0 then
      original_lines = {}
    end
    original_text = table.concat(original_lines, "\n")
  end

  local current_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local current_text = table.concat(current_lines, "\n")

  --- vim.diff returns indices: { start_a, count_a, start_b, count_b } for each hunk
  local raw_hunks = vim.diff(original_text, current_text, { result_type = "indices" })

  if not raw_hunks then
    return
  end

  M.clear(buf)

  buffer_original[buf] = original_lines
  active_buffers[buf] = file_path

  local hunks = {}
  for _, hunk in ipairs(raw_hunks) do
    local start_a, count_a, start_b, count_b = unpack(hunk)

    local old_lines = {}
    for i = 0, count_a - 1 do
      local line_idx = start_a + i
      if original_lines[line_idx] then
        table.insert(old_lines, original_lines[line_idx])
      end
    end

    local new_lines = {}
    for i = 0, count_b - 1 do
      local line_idx = start_b + i
      if current_lines[line_idx] then
        table.insert(new_lines, current_lines[line_idx])
      end
    end

    table.insert(hunks, {
      start_old = start_a,
      count_old = count_a,
      start_new = start_b,
      count_new = count_b,
      old_lines = old_lines,
      new_lines = new_lines,
    })
  end
  buffer_hunks[buf] = hunks

  for _, hunk in ipairs(hunks) do
    if hunk.count_old > 0 then
      local deleted_lines = {}
      for _, line in ipairs(hunk.old_lines) do
        table.insert(deleted_lines, { { line, "ResuDiffDelete" } })
      end

      local virt_line_pos = math.max(0, hunk.start_new - 1)
      vim.api.nvim_buf_set_extmark(buf, ns_id, virt_line_pos, 0, {
        virt_lines = deleted_lines,
        virt_lines_above = true,
      })
    end

    if hunk.count_new > 0 then
      for i = 0, hunk.count_new - 1 do
        local line_idx = hunk.start_new + i - 1
        if line_idx >= 0 and line_idx < #current_lines then
          vim.api.nvim_buf_set_extmark(buf, ns_id, line_idx, 0, {
            line_hl_group = "ResuDiffAdd",
            priority = 200,
          })
        end
      end
    end
  end
end

function M.get_hunks_in_range(buf, start_line, end_line)
  local hunks = buffer_hunks[buf] or {}
  local matching = {}

  for i, hunk in ipairs(hunks) do
    local hunk_start = hunk.start_new
    local hunk_end = hunk.start_new + hunk.count_new - 1
    if hunk.count_new == 0 then
      hunk_end = hunk_start
    end

    if not (end_line < hunk_start or start_line > hunk_end) then
      table.insert(matching, { index = i, hunk = hunk })
    end
  end

  return matching
end

function M.apply_partial_accept(buf, start_line, end_line)
  local hunks = buffer_hunks[buf] or {}
  local original_lines = buffer_original[buf] or {}

  if #hunks == 0 then
    return false
  end

  local matching = M.get_hunks_in_range(buf, start_line, end_line)
  if #matching == 0 then
    return false
  end

  local current_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local result_lines = {}
  local processed_ranges = {}

  for _, m in ipairs(matching) do
    local hunk = m.hunk
    local hunk_start = hunk.start_new
    local hunk_end = hunk.start_new + hunk.count_new - 1

    for line_num = hunk_start, hunk_end do
      if line_num >= start_line and line_num <= end_line then
        processed_ranges[line_num] = "keep"
      else
        processed_ranges[line_num] = "revert"
      end
    end
  end

  local revert_insertions = {}

  for line_num, action in pairs(processed_ranges) do
    if action == "revert" then
      for _, m in ipairs(matching) do
        local hunk = m.hunk
        if line_num >= hunk.start_new and line_num < hunk.start_new + hunk.count_new then
          local offset_in_hunk = line_num - hunk.start_new
          local old_line_idx = hunk.start_old + offset_in_hunk
          if old_line_idx <= #original_lines and original_lines[old_line_idx] then
            revert_insertions[line_num] = original_lines[old_line_idx]
          end
          break
        end
      end
    end
  end

  for i, line in ipairs(current_lines) do
    if processed_ranges[i] == "revert" then
      if revert_insertions[i] then
        table.insert(result_lines, revert_insertions[i])
      end
    else
      table.insert(result_lines, line)
    end
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, result_lines)

  local new_hunks = {}
  for i, hunk in ipairs(hunks) do
    local dominated = false
    for _, m in ipairs(matching) do
      if m.index == i then
        local hunk_start = hunk.start_new
        local hunk_end = hunk.start_new + hunk.count_new - 1
        if start_line <= hunk_start and end_line >= hunk_end then
          dominated = true
        end
        break
      end
    end
    if not dominated then
      table.insert(new_hunks, hunk)
    end
  end
  buffer_hunks[buf] = new_hunks

  M.refresh_display(buf)
  return true
end

function M.apply_partial_decline(buf, start_line, end_line)
  local hunks = buffer_hunks[buf] or {}
  local original_lines = buffer_original[buf] or {}

  if #hunks == 0 then
    return false
  end

  local matching = M.get_hunks_in_range(buf, start_line, end_line)
  if #matching == 0 then
    return false
  end

  local current_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local result_lines = {}

  local lines_to_replace = {}
  for _, m in ipairs(matching) do
    local hunk = m.hunk
    local hunk_start = hunk.start_new
    local hunk_end = hunk.start_new + hunk.count_new - 1

    for line_num = hunk_start, hunk_end do
      if line_num >= start_line and line_num <= end_line then
        lines_to_replace[line_num] = true
      end
    end
  end

  local old_lines_to_insert = {}
  for _, m in ipairs(matching) do
    local hunk = m.hunk
    local hunk_start = hunk.start_new

    local all_selected = true
    for i = 0, hunk.count_new - 1 do
      if not lines_to_replace[hunk_start + i] then
        all_selected = false
        break
      end
    end

    if all_selected then
      old_lines_to_insert[hunk_start] = hunk.old_lines
    end
  end

  local i = 1
  while i <= #current_lines do
    if old_lines_to_insert[i] then
      for _, old_line in ipairs(old_lines_to_insert[i]) do
        table.insert(result_lines, old_line)
      end
      local hunk_size = 0
      for _, m in ipairs(matching) do
        if m.hunk.start_new == i then
          hunk_size = m.hunk.count_new
          break
        end
      end
      i = i + hunk_size
    elseif lines_to_replace[i] then
      i = i + 1
    else
      table.insert(result_lines, current_lines[i])
      i = i + 1
    end
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, result_lines)

  local new_hunks = {}
  for idx, hunk in ipairs(hunks) do
    local is_matching = false
    for _, m in ipairs(matching) do
      if m.index == idx then
        is_matching = true
        break
      end
    end
    if not is_matching then
      table.insert(new_hunks, hunk)
    end
  end
  buffer_hunks[buf] = new_hunks

  M.refresh_display(buf)
  return true
end

function M.refresh_display(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

  local hunks = buffer_hunks[buf] or {}
  local current_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  for _, hunk in ipairs(hunks) do
    if hunk.count_old > 0 then
      local deleted_lines = {}
      for _, line in ipairs(hunk.old_lines) do
        table.insert(deleted_lines, { { line, "ResuDiffDelete" } })
      end

      local virt_line_pos = math.max(0, hunk.start_new - 1)
      vim.api.nvim_buf_set_extmark(buf, ns_id, virt_line_pos, 0, {
        virt_lines = deleted_lines,
        virt_lines_above = true,
      })
    end

    if hunk.count_new > 0 then
      for i = 0, hunk.count_new - 1 do
        local line_idx = hunk.start_new + i - 1
        if line_idx >= 0 and line_idx < #current_lines then
          vim.api.nvim_buf_set_extmark(buf, ns_id, line_idx, 0, {
            line_hl_group = "ResuDiffAdd",
            priority = 200,
          })
        end
      end
    end
  end
end

function M.has_pending_hunks(buf)
  local hunks = buffer_hunks[buf] or {}
  return #hunks > 0
end

function M.clear(buf)
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
  end
  buffer_hunks[buf] = nil
  buffer_original[buf] = nil
  active_buffers[buf] = nil
end

function M.clear_all()
  for buf, _ in pairs(active_buffers) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
    end
  end
  buffer_hunks = {}
  buffer_original = {}
  active_buffers = {}
end

return M
