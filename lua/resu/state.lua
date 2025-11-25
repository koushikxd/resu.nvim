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

function M.add_or_update_file(path)
  local found = false
  for _, file in ipairs(state.files) do
    if file.path == path then
      file.timestamp = os.time()
      -- Reset status to pending on update? Or keep as is?
      -- Usually if a file changes again, it needs review again.
      file.status = M.Status.PENDING
      found = true
      break
    end
  end

  if not found then
    table.insert(state.files, {
      path = path,
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
