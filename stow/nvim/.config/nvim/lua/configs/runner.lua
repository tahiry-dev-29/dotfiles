local M = {}

local project = require "configs.project"

--- Node root: detected dynamically (ancestor + downward rg search).
function M.find_root()
  return project.node_root()
end

function M.detect_runner()
  local start = project.start_dir()
  -- Lockfiles may be at the monorepo root (above).
  local b = project.find_up(start, { "bun.lockb", "bun.lock" })
  if b then return "bun" end
  local p = project.find_up(start, { "pnpm-lock.yaml" })
  if p then return "pnpm" end
  local y = project.find_up(start, { "yarn.lock" })
  if y then return "yarn" end
  return "npm"
end

function M.get_scripts()
  local root = M.find_root()
  local pkg_path = root .. "/package.json"
  if vim.fn.filereadable(pkg_path) ~= 1 then return nil end
  local lines = vim.fn.readfile(pkg_path)
  local ok, data = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok or not data or not data.scripts then return nil end
  return data.scripts
end

function M.run(script_name, title)
  if not script_name or script_name == "" then
    vim.notify("No script name provided", vim.log.levels.WARN)
    return
  end
  local runner = M.detect_runner()
  local cmd = string.format("%s run %s", runner, script_name)
  local root = M.find_root()
  local Terminal = require("toggleterm.terminal").Terminal
  local term = Terminal:new({
    cmd = cmd,
    dir = root,
    hidden = true,
    direction = "float",
    close_on_exit = false,
    float_opts = {
      border = "double",
      title = " " .. (title or script_name) .. " (y to copy) ",
      title_pos = "center",
    },
    on_open = function(t)
      vim.api.nvim_buf_set_keymap(t.bufnr, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true })
      vim.api.nvim_buf_set_keymap(t.bufnr, "n", "y", "<cmd>%y+<CR><cmd>lua vim.notify('Copied! 󰆏')<CR>", { noremap = true, silent = true })
    end,
  })
  term:toggle()
end

function M.run_test()
  M.run("test", "Test")
end

function M.run_e2e()
  M.run("e2e", "E2E")
end

function M.run_lint()
  M.run("lint", "Lint")
end

function M.pick()
  local scripts = M.get_scripts()
  if not scripts then
    -- No package.json: launch the auto diagnostics scanner (DiagScan)
    -- instead of a dead-end toast, and notify the user.
    local root = M.find_root()
    local ok_diag = pcall(require, "configs.diagnostics")
    vim.notify(
      "No package.json (root: " .. root .. "). Launching auto diagnostics scanner…",
      vim.log.levels.INFO
    )
    if ok_diag then
      vim.schedule(function()
        require("configs.diagnostics").scan()
      end)
    end
    return
  end
  local items = {}
  for name, cmd in pairs(scripts) do
    table.insert(items, { name = name, cmd = cmd })
  end
  table.sort(items, function(a, b) return a.name < b.name end)

  local has_telescope = pcall(require, "telescope")
  if not has_telescope then
    vim.ui.select(items, {
      prompt = "Run Script",
      format_item = function(item) return item.name .. " (" .. item.cmd .. ")" end,
    }, function(choice)
      if choice then M.run(choice.name, choice.name) end
    end)
    return
  end

  local actions = require("telescope.actions")
  local state = require("telescope.actions.state")
  local entry_maker = function(entry)
    return {
      value = entry.name,
      display = entry.name .. " (" .. entry.cmd .. ")",
      ordinal = entry.name .. " " .. entry.cmd,
    }
  end
  require("telescope.pickers").new({}, {
    prompt_title = "Run Script",
    finder = require("telescope.finders").new_table({ results = items, entry_maker = entry_maker }),
    sorter = require("telescope.sorters").get_generic_fuzzy_sorter(),
    attach_mappings = function(prompt_bufnr, map)
      local function run()
        local selection = state.get_selected_entry()
        actions.close(prompt_bufnr)
        if selection then M.run(selection.value, selection.value) end
      end
      map("i", "<CR>", run)
      map("n", "<CR>", run)
      return true
    end,
  }):find()
end

return M
