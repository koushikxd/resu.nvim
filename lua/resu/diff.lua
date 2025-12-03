local M = {}

local ns_id = vim.api.nvim_create_namespace("resu_inline_diff")

vim.api.nvim_set_hl(0, "ResuDiffAdd", { bg = "#1e3a1e", fg = "#a6e3a1" })
vim.api.nvim_set_hl(0, "ResuDiffDelete", { bg = "#3d1f1f", fg = "#f38ba8" })

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

function M.render_inline(buf, file_path)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  if not file_path then
    return
  end

  local cmd = "git show HEAD:" .. vim.fn.shellescape(file_path)
  local original_lines = vim.fn.systemlist(cmd)
  local original_text

  if vim.v.shell_error ~= 0 then
    original_lines = {}
    original_text = ""
  else
    original_text = table.concat(original_lines, "\n")
  end

  local current_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local current_text = table.concat(current_lines, "\n")

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
