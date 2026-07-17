local M = {}

function M.find_root()
  local cwd = vim.fn.getcwd()
  local prev = ""
  local dir = cwd
  while dir ~= prev do
    if vim.fn.filereadable(dir .. "/package.json") == 1 then
      return dir
    end
    prev = dir
    dir = vim.fn.fnamemodify(dir, ":h")
  end
  return cwd
end

function M.detect_runner()
  local root = M.find_root()
  if vim.fn.filereadable(root .. "/bun.lock") == 1
    or vim.fn.filereadable(root .. "/bun.lockb") == 1 then
    return "bun"
  end
  if vim.fn.filereadable(root .. "/pnpm-lock.yaml") == 1 then
    return "pnpm"
  end
  if vim.fn.filereadable(root .. "/yarn.lock") == 1 then
    return "yarn"
  end
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
    vim.notify("No package.json or scripts found", vim.log.levels.WARN)
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
