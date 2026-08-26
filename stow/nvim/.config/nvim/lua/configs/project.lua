-- Détection dynamique de la racine de projet.
-- Embarque 2 stratégies :
--   1. remonte les répertoires parents (find_up)       [rapide]
--   2. cherche vers le bas avec un grep (rg / fd / find) [sous-dossiers / monorepo]
local M = {}

local function hasfile(p) return vim.fn.filereadable(p) == 1 end
local function hasdir(p) return vim.fn.isdirectory(p) == 1 end
local function exists(p) return hasfile(p) or hasdir(p) end

--- Dossier de départ de la détection : celui du buffer actif (le fichier ouvert)
--- si c'est un vrai fichier, sinon le cwd de nvim.
---@return string
function M.start_dir()
  local f = vim.fn.expand("%:p")
  if f ~= "" and vim.fn.filereadable(f) == 1 then
    return vim.fn.fnamemodify(f, ":h")
  end
  return vim.fn.getcwd()
end

--- Remonte de `start` jusqu'à trouver un dossier contenant un de `markers`.
---@param start string
---@param markers string[]
---@return string? chemin du dossier trouvé, sinon nil
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

--- Cherche vers le bas avec rg (fd / find) le dossier contenant le plus proche
--- fichier `pattern`. Retourne le chemin absolu du dossier, sinon nil.
---@param start string
---@param pattern string  motif glob du nom de fichier, ex: "package.json"
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
    -- fallback : find + grep (lent mais portable)
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

--- Racine Node : dossier contenant le `package.json` (ancêtre OU sous-dossier).
function M.node_root()
  local start = M.start_dir()
  -- 1) Privilégier le plus proche package.json d'un ancêtre.
  local up = M.find_up(start, { "package.json" })
  if up then return up end
  -- 2) Sinon espace de travail npm/yarn (monorepo) d'un ancêtre.
  local ws = M.find_up(start, { "pnpm-workspace.yaml", "nx.json", "lerna.json", "yarn.lock" })
  if ws then return ws end
  -- 3) Aucun en hauteur : chercher vers le bas le package.json le plus proche.
  local down = M.find_down(start, "package.json")
  if down then return down end
  return start
end

--- Racine Trunk : dossier `.trunk` / `trunk.yaml`, sinon racine git.
function M.trunk_root()
  local start = M.start_dir()
  local t1 = M.find_up(start, { ".trunk" })
  if t1 then return t1 end
  local t2 = M.find_up(start, { "trunk.yaml", "trunk.fmt.yaml" })
  if t2 then return t2 end
  -- Sinon : racine du dépôt git (.git le plus haut)
  local gitroot = M.find_up(start, { ".git" })
  if gitroot then return gitroot end
  -- Dernier recours : racine node (pour que git / trunk s'exécutent au bon endroit)
  return M.node_root()
end

return M