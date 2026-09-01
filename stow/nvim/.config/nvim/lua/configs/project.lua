-- Dynamic project root detection.
-- Employs 2 strategies:
--   1. traverses parent directories (find_up)          [fast]
--   2. searches downward with grep (rg / fd / find)    [subdirectories / monorepo]
local M = {}

local function hasfile(p) return vim.fn.filereadable(p) == 1 end
local function hasdir(p) return vim.fn.isdirectory(p) == 1 end
local function exists(p) return hasfile(p) or hasdir(p) end

--- Starting directory for detection: the active buffer's directory
--- if it's a real file, otherwise nvim's cwd.
---@return string
function M.start_dir()
  local f = vim.fn.expand("%:p")
  if f ~= "" and vim.fn.filereadable(f) == 1 then
    return vim.fn.fnamemodify(f, ":h")
  end
  return vim.fn.getcwd()
end

--- Traverses up from `start` until finding a directory containing one of `markers`.
---@param start string
---@param markers string[]
---@return string? path of the found directory, or nil
function M.find_up(start, markers)
  local dir = start
  local prev = ""
  while dir ~= prev do
    for _, m in ipairs(markers) do
      if exists(dir .. "/" .. m) then
        return dir
      end
    end
    prev = dir
    dir = vim.fn.fnamemodify(dir, ":h")
  end
  return nil
end

--- Searches downward with rg (fd / find) for the directory containing the closest
--- `pattern` file. Returns the absolute path of the directory, or nil.
---@param start string
---@param pattern string  glob pattern for filename, e.g. "package.json"
---@return string?
function M.find_down(start, pattern)
  local ignores = " -g '!**/node_modules/**' -g '!**/.git/**' -g '!**/dist/**' -g '!**/build/**' "
    .. "-g '!**/.next/**' -g '!**/.nuxt/**' -g '!**/Pods/**' -g '!**/.dart_tool/**' "

  local cmd
  if vim.fn.executable("rg") == 1 then
    cmd = string.format(
      "rg --files --hidden --no-ignore-vcs -g '%s' %s %s 2>/dev/null",
      pattern, ignores, vim.fn.shellescape(start)
    )
  elseif vim.fn.executable("fd") == 1 then
    cmd = string.format(
      "fd --files -g '%s' %s %s 2>/dev/null",
      pattern, ignores, vim.fn.shellescape(start)
    )
  else
    -- fallback: find + grep (slow but portable)
    cmd = string.format(
      "find %s -type f -name '%s' 2>/dev/null | grep -v '/node_modules/' | grep -v '/.git/'",
      vim.fn.shellescape(start), pattern
    )
  end

  local out = vim.fn.system(cmd)
  local base = start:gsub("/+$", "")
  local best, best_depth
  for _, raw in ipairs(vim.split(out, "\n")) do
    local line = vim.trim(raw)
    if line ~= "" then
      local abs = line:sub(1, 1) == "/" and line or (start .. "/" .. line)
      local rel = abs:sub(#base + 2)
      local _, n = rel:gsub("/", "")
      if not best or n < best_depth then
        best = abs
        best_depth = n
      end
    end
  end
  if best then
    return vim.fn.fnamemodify(best, ":h")
  end
  return nil
end

--- Node root: directory containing `package.json` (ancestor OR subdirectory).
function M.node_root()
  local start = M.start_dir()
  -- 1) Prefer the closest package.json from an ancestor.
  local up = M.find_up(start, { "package.json" })
  if up then return up end
  -- 2) Otherwise npm/yarn workspace (monorepo) from an ancestor.
  local ws = M.find_up(start, { "pnpm-workspace.yaml", "nx.json", "lerna.json", "yarn.lock" })
  if ws then return ws end
  -- 3) None above: search downward for the closest package.json.
  local down = M.find_down(start, "package.json")
  if down then return down end
  return start
end

--- Trunk root: `.trunk` / `trunk.yaml` directory, otherwise git root.
function M.trunk_root()
  local start = M.start_dir()
  local t1 = M.find_up(start, { ".trunk" })
  if t1 then return t1 end
  local t2 = M.find_up(start, { "trunk.yaml", "trunk.fmt.yaml" })
  if t2 then return t2 end
  -- Otherwise: git repository root (highest .git)
  local gitroot = M.find_up(start, { ".git" })
  if gitroot then return gitroot end
  -- Last resort: node root (so git / trunk run in the right place)
  return M.node_root()
end

return M