local M = {}

M.Status = {
  PENDING = "pending",
  ACCEPTED = "accepted",
  DECLINED = "declined",
}

local state = {
  files = {},
  current_idx = 1,
}

local persistent_state = {}
local state_file_path = nil
local baselines_dir = nil

local function get_state_file_path()
  if not state_file_path then
    state_file_path = vim.fn.stdpath("data") .. "/resu_state.json"
  end
  return state_file_path
end

local function get_baselines_dir()
  if not baselines_dir then
    baselines_dir = vim.fn.stdpath("data") .. "/resu_baselines"
  end
  return baselines_dir
end

local function get_project_key()
  return vim.fn.getcwd()
end

local function compute_file_hash(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local content = file:read("*a")
  file:close()

  local hash = 0
  for i = 1, #content do
    hash = (hash * 31 + string.byte(content, i)) % 2147483647
  end
  return tostring(hash)
end

local function get_baseline_path(project, file_path)
  local safe_project = project:gsub("[^%w]", "_")
  local safe_file = file_path:gsub("[^%w.]", "_")
  return get_baselines_dir() .. "/" .. safe_project .. "/" .. safe_file
end

local function save_baseline_content(project, file_path)
  local baseline_path = get_baseline_path(project, file_path)
  local dir = vim.fn.fnamemodify(baseline_path, ":h")
  vim.fn.mkdir(dir, "p")

  local source = io.open(file_path, "r")
  if not source then
    return false
  end
  local content = source:read("*a")
  source:close()

  local dest = io.open(baseline_path, "w")
  if not dest then
    return false
  end
  dest:write(content)
  dest:close()
  return true
end

local function delete_baseline_content(project, file_path)
  local baseline_path = get_baseline_path(project, file_path)
  os.remove(baseline_path)
end

function M.get_baseline_content(file_path)
  local project = get_project_key()
  if not persistent_state[project] or not persistent_state[project][file_path] then
    return nil
  end

  local baseline_path = get_baseline_path(project, file_path)
  local file = io.open(baseline_path, "r")
  if not file then
    return nil
  end
  local content = file:read("*a")
  file:close()
  return content
end

function M.load_persistent_state()
  local path = get_state_file_path()
  local file = io.open(path, "r")
  if not file then
    persistent_state = {}
    return
  end

  local content = file:read("*a")
  file:close()

  local ok, decoded = pcall(vim.fn.json_decode, content)
  if ok and type(decoded) == "table" then
    persistent_state = decoded
  else
    persistent_state = {}
  end
end

function M.save_persistent_state()
  local path = get_state_file_path()
  local dir = vim.fn.fnamemodify(path, ":h")
  vim.fn.mkdir(dir, "p")

  local file = io.open(path, "w")
  if not file then
    return false
  end

  local ok, encoded = pcall(vim.fn.json_encode, persistent_state)
  if ok then
    file:write(encoded)
  end
  file:close()
  return ok
end

local function is_file_already_handled(path)
  local project = get_project_key()
  if not persistent_state[project] then
    return false
  end

  local file_state = persistent_state[project][path]
  if not file_state then
    return false
  end

  local current_hash = compute_file_hash(path)
  if not current_hash then
    return false
  end

  return file_state.hash == current_hash
end

local function save_file_state(path, status)
  local project = get_project_key()
  if not persistent_state[project] then
    persistent_state[project] = {}
  end

  local hash = compute_file_hash(path)
  if hash then
    save_baseline_content(project, path)
    persistent_state[project][path] = {
      hash = hash,
      status = status,
    }
    M.save_persistent_state()
  end
end

local function cleanup_committed_files(modified_files_set)
  local project = get_project_key()
  if not persistent_state[project] then
    return
  end

  local to_remove = {}
  for file_path, _ in pairs(persistent_state[project]) do
    if not modified_files_set[file_path] then
      table.insert(to_remove, file_path)
    end
  end

  for _, file_path in ipairs(to_remove) do
    delete_baseline_content(project, file_path)
    persistent_state[project][file_path] = nil
  end

  if #to_remove > 0 then
    M.save_persistent_state()
  end
end

function M.reset()
  state.files = {}
  state.current_idx = 1
end

function M.get_files()
  return state.files
end

function M.set_files(files)
  state.files = files
  if state.current_idx > #state.files then
    state.current_idx = math.max(1, #state.files)
  end
end

function M.scan_changes()
  M.load_persistent_state()

  local modified_cmd = "git diff --name-only"
  local modified_files = vim.fn.systemlist(modified_cmd)

  local untracked_cmd = "git ls-files --others --exclude-standard"
  local untracked_files = vim.fn.systemlist(untracked_cmd)

  local modified_set = {}
  for _, file in ipairs(modified_files) do
    if file ~= "" then
      modified_set[file] = true
    end
  end
  for _, file in ipairs(untracked_files) do
    if file ~= "" then
      modified_set[file] = true
    end
  end

  cleanup_committed_files(modified_set)

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
        if vim.fn.filereadable(file) == 1 then
          if not is_file_already_handled(file) then
            local status = existing_status[file] or M.Status.PENDING
            table.insert(new_files, {
              path = file,
              status = status,
              timestamp = os.time(),
            })
          end
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
  local cwd = vim.fn.getcwd()
  local rel_path = path
  if path:sub(1, #cwd) == cwd then
    rel_path = path:sub(#cwd + 2)
  end

  local project = get_project_key()
  if persistent_state[project] and persistent_state[project][rel_path] then
    persistent_state[project][rel_path] = nil
    M.save_persistent_state()
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
  if #state.files == 0 then
    return false
  end
  if state.current_idx < #state.files then
    state.current_idx = state.current_idx + 1
  else
    state.current_idx = 1
  end
  return true
end

function M.prev_file()
  if #state.files == 0 then
    return false
  end
  if state.current_idx > 1 then
    state.current_idx = state.current_idx - 1
  else
    state.current_idx = #state.files
  end
  return true
end

function M.update_status(path, status)
  for i, file in ipairs(state.files) do
    if file.path == path then
      file.status = status
      if status == M.Status.ACCEPTED or status == M.Status.DECLINED then
        save_file_state(path, status)
        table.remove(state.files, i)
        if state.current_idx > #state.files then
          state.current_idx = math.max(1, #state.files)
        end
      end
      return true
    end
  end
  return false
end

function M.clear_persistent_state()
  local project = get_project_key()
  if persistent_state[project] then
    for file_path, _ in pairs(persistent_state[project]) do
      delete_baseline_content(project, file_path)
    end
  end
  persistent_state[project] = nil
  M.save_persistent_state()
end

return M
