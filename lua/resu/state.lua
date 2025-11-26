local M = {}

-- Enum for file status
M.Status = {
  PENDING = "pending",
  ACCEPTED = "accepted",
  DECLINED = "declined",
}

-- Internal state
local state = {
  files = {}, -- List of { path = "...", status = "...", timestamp = 12345 }
  current_idx = 1, -- Current selected file index
}

function M.reset()
  state.files = {}
  state.current_idx = 1
end

function M.get_files()
  return state.files
end

function M.set_files(files)
  state.files = files
  -- Ensure current index is valid
  if state.current_idx > #state.files then
    state.current_idx = math.max(1, #state.files)
  end
end

function M.scan_changes()
  -- Get modified files
  local modified_cmd = "git diff --name-only"
  local modified_files = vim.fn.systemlist(modified_cmd)

  -- Get untracked files
  local untracked_cmd = "git ls-files --others --exclude-standard"
  local untracked_files = vim.fn.systemlist(untracked_cmd)

  -- Combine and deduplicate
  local existing_status = {}
  for _, file in ipairs(state.files) do
    existing_status[file.path] = file.status
  end

  local new_files = {}
  local seen = {}

  local function add(list)
    if not list then
      return
    end
    for _, file in ipairs(list) do
      if file ~= "" and not seen[file] then
        -- Check if file exists
        if vim.fn.filereadable(file) == 1 then
          local status = existing_status[file] or M.Status.PENDING

          table.insert(new_files, {
            path = file,
            status = status,
            timestamp = os.time(),
          })
          seen[file] = true
        end
      end
    end
  end

  add(modified_files)
  add(untracked_files)

  state.files = new_files
  if state.current_idx > #state.files then
    state.current_idx = math.max(1, #state.files)
  end
  if state.current_idx == 0 and #state.files > 0 then
    state.current_idx = 1
  end
end

function M.add_or_update_file(path)
  -- Convert absolute path to relative if needed, or just rely on scan
  local cwd = vim.fn.getcwd()
  local rel_path = path
  if path:sub(1, #cwd) == cwd then
    rel_path = path:sub(#cwd + 2)
  end

  local found = false
  for _, file in ipairs(state.files) do
    if file.path == rel_path then
      file.timestamp = os.time()
      file.status = M.Status.PENDING
      found = true
      break
    end
  end

  if not found then
    table.insert(state.files, {
      path = rel_path,
      status = M.Status.PENDING,
      timestamp = os.time(),
    })
  end
end

function M.get_current_file()
  if #state.files == 0 then
    return nil
  end
  return state.files[state.current_idx]
end

function M.get_current_index()
  return state.current_idx
end

function M.set_current_index(idx)
  if idx >= 1 and idx <= #state.files then
    state.current_idx = idx
  end
end

function M.next_file()
  if state.current_idx < #state.files then
    state.current_idx = state.current_idx + 1
    return true
  end
  return false
end

function M.prev_file()
  if state.current_idx > 1 then
    state.current_idx = state.current_idx - 1
    return true
  end
  return false
end

function M.update_status(path, status)
  for _, file in ipairs(state.files) do
    if file.path == path then
      file.status = status
      return true
    end
  end
  return false
end

return M
