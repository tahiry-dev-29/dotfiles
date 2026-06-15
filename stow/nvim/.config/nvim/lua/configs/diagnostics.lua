-- Project-wide diagnostics scanner (VSCode-style Problems panel)
local M = {}

local ns = vim.api.nvim_create_namespace("project_diagnostics")
local scan_timer = nil
local is_scanning = false

--- Detect available project scanners from config files
function M.detect_scanners()
  local cwd = vim.fn.getcwd()
  local scanners = {}
  local runner = vim.fn.executable("bunx") == 1 and "bunx" or "npx"

  -- TypeScript
  if vim.fn.filereadable(cwd .. "/tsconfig.json") == 1 then
    table.insert(scanners, {
      name = "tsc",
      cmd = { runner, "tsc", "--noEmit", "--pretty", "false" },
      parser = M.parse_tsc,
    })
  end

  -- ESLint (flat or legacy config)
  local eslint_files = {
    "eslint.config.js", "eslint.config.mjs", "eslint.config.ts",
    ".eslintrc.json", ".eslintrc.js", ".eslintrc.yml",
  }
  for _, f in ipairs(eslint_files) do
    if vim.fn.filereadable(cwd .. "/" .. f) == 1 then
      table.insert(scanners, {
        name = "eslint",
        cmd = { runner, "eslint", ".", "--format", "unix", "--quiet" },
        parser = M.parse_eslint,
      })
      break
    end
  end

  -- Dart / Flutter
  if vim.fn.filereadable(cwd .. "/pubspec.yaml") == 1 then
    table.insert(scanners, {
      name = "dart",
      cmd = { "dart", "analyze", "--format", "machine" },
      parser = M.parse_dart,
    })
  end

  -- Trunk (General purpose TUI diagnostics)
  if vim.fn.isdirectory(cwd .. "/.trunk") == 1 then
    table.insert(scanners, {
      name = "trunk",
      cmd = { "trunk", "check", "--format", "json", "--quiet" },
      parser = M.parse_trunk,
    })
  end

  -- Angular (ng lint via ESLint — only if no standalone eslint config)
  if vim.fn.filereadable(cwd .. "/angular.json") == 1
    and #vim.tbl_filter(function(s) return s.name == "eslint" end, scanners) == 0
  then
    table.insert(scanners, {
      name = "ng-lint",
      cmd = { runner, "ng", "lint", "--format", "prose" },
      parser = M.parse_ng_lint,
    })
  end

  return scanners
end

--
-- PARSERS: each returns { [abs_filename] = { diagnostic, ... } }
--

--- tsc output: src/file.ts(12,5): error TS2345: message
function M.parse_tsc(output)
  local results = {}
  for _, line in ipairs(vim.split(output, "\n")) do
    local file, row, col, sev, code, msg =
      line:match("^(.+)%((%d+),(%d+)%): (%w+) (TS%d+): (.+)$")
    if file then
      local abs = vim.fn.fnamemodify(file, ":p")
      results[abs] = results[abs] or {}
      table.insert(results[abs], {
        lnum = tonumber(row) - 1,
        col = tonumber(col) - 1,
        severity = sev == "error"
          and vim.diagnostic.severity.ERROR
          or vim.diagnostic.severity.WARN,
        message = msg,
        source = "tsc",
        code = code,
      })
    end
  end
  return results
end

--- eslint unix format: /path/file.ts:12:5: msg [severity/rule]
function M.parse_eslint(output)
  local results = {}
  for _, line in ipairs(vim.split(output, "\n")) do
    local file, row, col, msg = line:match("^(.+):(%d+):(%d+): (.+)$")
    if file and file ~= "" and not line:match("^%d+ problem") then
      local abs = vim.fn.fnamemodify(file, ":p")
      local severity = vim.diagnostic.severity.WARN
      if msg:match("%[Error") then
        severity = vim.diagnostic.severity.ERROR
      end
      results[abs] = results[abs] or {}
      table.insert(results[abs], {
        lnum = tonumber(row) - 1,
        col = tonumber(col) - 1,
        severity = severity,
        message = msg,
        source = "eslint",
      })
    end
  end
  return results
end

--- dart analyze machine: SEVERITY|TYPE|CODE|file|line|col|length|message
function M.parse_dart(output)
  local results = {}
  local sev_map = {
    ERROR   = vim.diagnostic.severity.ERROR,
    WARNING = vim.diagnostic.severity.WARN,
    INFO    = vim.diagnostic.severity.INFO,
  }
  for _, line in ipairs(vim.split(output, "\n")) do
    local sev, _, code, file, row, col, _, msg =
      line:match("^(%w+)|(%w+)|(%w+)|(.+)|(%d+)|(%d+)|(%d+)|(.+)$")
    if file then
      local abs = vim.fn.fnamemodify(file, ":p")
      results[abs] = results[abs] or {}
      table.insert(results[abs], {
        lnum = tonumber(row) - 1,
        col = tonumber(col) - 1,
        severity = sev_map[sev] or vim.diagnostic.severity.HINT,
        message = msg,
        source = "dart",
        code = code,
      })
    end
  end
  return results
end

--- ng lint prose: ERROR: file:line:col - message
function M.parse_ng_lint(output)
  local results = {}
  for _, line in ipairs(vim.split(output, "\n")) do
    local sev, file, row, col, msg =
      line:match("^(%w+): (.+):(%d+):(%d+) %- (.+)$")
    if file then
      local abs = vim.fn.fnamemodify(file, ":p")
      results[abs] = results[abs] or {}
      table.insert(results[abs], {
        lnum = tonumber(row) - 1,
        col = tonumber(col) - 1,
        severity = sev == "ERROR"
          and vim.diagnostic.severity.ERROR
          or vim.diagnostic.severity.WARN,
        message = msg,
        source = "ng-lint",
      })
    end
  end
  return results
end

--
-- CORE ENGINE
--

--- Push parsed results into vim.diagnostic
local function apply_diagnostics(all_results)
  -- Wipe previous scanner namespace from all buffers
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    vim.diagnostic.set(ns, bufnr, {})
  end

  local counts = { e = 0, w = 0, i = 0 }

  for filename, diags in pairs(all_results) do
    -- Register the file as a buffer (no content loaded)
    local bufnr = vim.fn.bufadd(filename)

    -- Inject scanner diagnostics even on loaded buffers (multi-source display)
    vim.diagnostic.set(ns, bufnr, diags)

    -- Always count for the summary notification
    for _, d in ipairs(diags) do
      if d.severity == vim.diagnostic.severity.ERROR then
        counts.e = counts.e + 1
      elseif d.severity == vim.diagnostic.severity.WARN then
        counts.w = counts.w + 1
      else
        counts.i = counts.i + 1
      end
    end
  end

  return counts
end

--- trunk output: file:line:col: message [linter/rule]
function M.parse_trunk(output)
  local results = {}
  for _, line in ipairs(vim.split(output, "\n")) do
    local file, row, col, msg = line:match("^(.+):(%d+):(%d+): (.+)$")
    if file then
      local abs = vim.fn.fnamemodify(file, ":p")
      results[abs] = results[abs] or {}
      table.insert(results[abs], {
        lnum = tonumber(row) - 1,
        col = tonumber(col) - 1,
        severity = msg:match("error") and vim.diagnostic.severity.ERROR or vim.diagnostic.severity.WARN,
        message = msg,
        source = "trunk",
      })
    end
  end
  return results
end

--- Run every detected scanner async and merge results
function M.scan()
  if is_scanning then return end

  local scanners = M.detect_scanners()
  if #scanners == 0 then
    vim.notify("🔍 No project scanners detected (no tsconfig / eslint / pubspec)", vim.log.levels.INFO)
    return
  end

  is_scanning = true
  local all_results = {}
  local completed = 0
  local names = vim.tbl_map(function(s) return s.name end, scanners)

  vim.notify(
    string.format("🔍 Scanning: %s …", table.concat(names, ", ")),
    vim.log.levels.INFO
  )

  for _, scanner in ipairs(scanners) do
    vim.system(
      scanner.cmd,
      { text = true, cwd = vim.fn.getcwd() },
      function(result)
        local output = (result.stdout or "") .. (result.stderr or "")
        local parsed = scanner.parser(output)

        vim.schedule(function()
          for file, diags in pairs(parsed) do
            all_results[file] = all_results[file] or {}
            vim.list_extend(all_results[file], diags)
          end

          completed = completed + 1

          if completed == #scanners then
            is_scanning = false
            local c = apply_diagnostics(all_results)
            local total = c.e + c.w + c.i

            if total == 0 then
              vim.notify("✅ No project issues!", vim.log.levels.INFO)
            else
              vim.notify(
                string.format("📋 Project —  %d   %d   %d", c.e, c.w, c.i),
                vim.log.levels.WARN
              )
              -- Auto-open Trouble panel on results
              vim.cmd("Trouble diagnostics open")
            end
          end
        end)
      end
    )
  end
end

--- Debounced scan (waits 2s after last save)
function M.scan_debounced()
  if scan_timer then scan_timer:stop() end
  scan_timer = vim.defer_fn(function()
    M.scan()
  end, 2000)
end

--- Initialize autocommands, user commands, and keymaps
function M.setup()
  local group = vim.api.nvim_create_augroup("ProjectDiagnostics", { clear = true })

  -- User commands
  vim.api.nvim_create_user_command("DiagScan", function()
    M.scan()
  end, { desc = "Scan project diagnostics" })

  vim.api.nvim_create_user_command("DiagClear", function()
    if scan_timer then scan_timer:stop() end
    is_scanning = false
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      vim.diagnostic.set(ns, bufnr, {})
    end
    vim.notify("🧹 Project diagnostics cleared", vim.log.levels.INFO)
  end, { desc = "Clear project diagnostics" })

  -- Auto-scan on save (debounced)
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = {
      "*.ts", "*.js", "*.tsx", "*.jsx",
      "*.html", "*.css", "*.scss",
      "*.dart", "*.prisma",
    },
    callback = function()
      M.scan_debounced()
    end,
    desc = "Auto-scan diagnostics on save",
  })

  -- Initial scan 3s after Neovim starts (let LSP attach first)
  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    once = true,
    callback = function()
      vim.defer_fn(function()
        M.scan()
      end, 3000)
    end,
    desc = "Initial project diagnostics scan",
  })
end

return M
