vim.g.base46_cache = vim.fn.stdpath "data" .. "/base46/"
vim.g.mapleader = " "

-- 1. Bootstrapping NvChad
local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system { "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath }
end
vim.opt.rtp:prepend(lazypath)

local lazy_config = require "configs.lazy"
require("lazy").setup({
  { "NvChad/NvChad", lazy = false, branch = "v2.5", import = "nvchad.plugins" },
  { import = "plugins" },
}, lazy_config)

-- 2. Load Theme and Options
dofile(vim.g.base46_cache .. "defaults")
dofile(vim.g.base46_cache .. "statusline")
require "options"
require "nvchad.autocmds"

-- 3.5 PROJECT DIAGNOSTICS SCANNER (registration only — setup() is called
-- after VimEnter so the initial scan never blocks Neovim's startup)
require("configs.diagnostics").setup()

-- 3.6 LSP SERVERS — deferred activation (after nvim fully opens)
-- Server config (vim.lsp.config) is already set at lspconfig plugin load time.
-- Here we only register the FileType autocmd that will enable each server
-- WHEN a buffer of the matching type is opened, never during boot.
-- NOTE: vim.defer_fn is reliable even in headless mode (unlike VimEnter),
-- and M.setup() is idempotent (augroup clear + guard).
-- IMPORTANT: we explicitly load the nvim-lspconfig plugin first
-- (lazy.nvim doesn't load it automatically), otherwise vim.lsp.config(name, ...)
-- creates entries WITHOUT cmd and servers can never start.
vim.defer_fn(function()
  local ok, err = pcall(function()
    require("lazy").load({ plugins = { "nvim-lspconfig", "mason.nvim", "mason-lspconfig.nvim" } })
    require("configs.lspconfig").setup()
  end)
  if not ok then
    vim.notify("LSP deferred setup error: " .. tostring(err), vim.log.levels.ERROR)
  end
end, 100)

-- 3. VISUAL ERROR CONFIGURATION (PROBLEMS) — VS CODE STYLE
--
-- Single source of truth here (the old duplicate in configs/lspconfig.lua
-- has been removed). "Error lens" style: the message displays at the END of
-- the CURRENT LINE only — like VS Code inline hints — to stay readable
-- without drowning the file under annotations. <leader>dv toggles
-- full display (all lines).
local diag_icons = { Error = "", Warn = "", Hint = "󰌵 ", Info = "" }

local function diagnostic_virtual_text(all_lines)
  return {
    prefix = "", -- icon is already in the gutter (signs)
    spacing = 2,
    virt_text_pos = "eol",
    current_line = not all_lines, -- false/nil = show all lines
    format = function(d)
      local code = d.user_data and d.user_data.lsp and d.user_data.lsp.code
      return code and ("%s [%s]"):format(d.message:gsub("\n", " "), code) or d.message:gsub("\n", " ")
    end,
  }
end

vim.diagnostic.config({
  virtual_text = diagnostic_virtual_text(false),
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = diag_icons.Error,
      [vim.diagnostic.severity.WARN] = diag_icons.Warn,
      [vim.diagnostic.severity.HINT] = diag_icons.Hint,
      [vim.diagnostic.severity.INFO] = diag_icons.Info,
    },
  },
  underline = true,
  update_in_insert = true, -- VS Code updates while typing
  severity_sort = true,
  float = {
    border = "rounded",
    source = true, -- show source (tsc, eslint, ts_ls…)
    header = "",
    prefix = "",
    format = function(d)
      local code = d.user_data and d.user_data.lsp and d.user_data.lsp.code
      return code and ("[%s] %s"):format(code, d.message) or d.message
    end,
  },
})

local show_all_inline = false
function _G.DiagnosticToggleInline()
  show_all_inline = not show_all_inline
  vim.diagnostic.config({ virtual_text = diagnostic_virtual_text(show_all_inline) })
  vim.notify(show_all_inline and "Diagnostics inline: ALL lines" or "Diagnostics inline: current line", vim.log.levels.INFO)
end

-- 4. FORCE KEYBINDS (CTRL+J for entire codebase)
local map = vim.keymap.set

vim.schedule(function()
  -- Sidebar & Search
  map("n", "<C-b>", "<cmd>NvimTreeToggle<CR>", { desc = "Sidebar" })
  map("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", { desc = "Explorer" })
  map("n", "<C-p>", "<cmd>Telescope find_files<CR>", { desc = "Find Files" })
  map({"n", "i", "v"}, "<C-S-p>", "<cmd>Telescope commands<CR>", { desc = "Command Palette" })
  map("n", "<C-f>", "<cmd>Telescope live_grep<CR>", { desc = "Search Project" })
  map({"n", "i", "v"}, "<C-S-f>", "<cmd>Telescope live_grep<CR>", { desc = "Search Project" })
  map("n", "<leader>gw", function() require("telescope").extensions.git_worktree.git_worktrees() end, { desc = "Search and switch Git Worktree" })
  map("n", "<C-s>", "<cmd>w<CR>", { desc = "Save" })
  map("i", "<C-s>", "<cmd>w<CR><ESC>", { desc = "Save" })

  -- Editing
  map({"n", "i", "v"}, "<C-z>", "<cmd>undo<CR>")
  map({"n", "i", "v"}, "<C-y>", "<cmd>redo<CR>")
  map({"n", "v"}, "<C-a>", "ggVG")
  
  -- Copy/Cut/Paste
  map("v", "<C-c>", '"+y')
  map("v", "<C-x>", '"+d')
  map({"n", "i", "v"}, "<C-v>", '"+p')

   -- ERRORS PANEL (WORKSPACE DIAGNOSTICS) — VS Code style
   -- NOTE: we display QUICKFIX (filled by the project scanner + live
   -- LSP diagnostics). Trouble's "diagnostics" mode only sees
   -- OPEN buffers, hence "No results" on errors from other files.
   map("n", "<C-j>", function()
     local ok = pcall(function()
       require("trouble").toggle({ mode = "qflist", focus = false })
     end)
     if not ok then
       vim.notify("trouble.nvim not loaded", vim.log.levels.ERROR)
     end
   end, { desc = "Project Problems (Workspace)" })
   map("n", "<leader>ds", "<cmd>DiagScan<CR>", { desc = "Scan Project Diagnostics" })
   map("n", "<leader>dc", "<cmd>DiagClear<CR>", { desc = "Clear Project Diagnostics" })

   -- NAVIGATION DIAGNOSTICS — style VS Code (F8 / Shift+F8)
   map("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, { desc = "Next error" })
   map("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, { desc = "Previous error" })
   map("n", "]e", function() vim.diagnostic.jump({ count = 1, severity = vim.diagnostic.severity.ERROR, float = true }) end, { desc = "Next error (severity=error)" })
   map("n", "[e", function() vim.diagnostic.jump({ count = -1, severity = vim.diagnostic.severity.ERROR, float = true }) end, { desc = "Previous error (severity=error)" })
   -- Detail of error under cursor + loclist
   map("n", "<leader>dd", vim.diagnostic.open_float, { desc = "Diagnostic detail" })
   map("n", "<leader>dl", vim.diagnostic.setloclist, { desc = "Diagnostics -> LocList" })
   -- Toggle inline display: current line <-> all lines
   map("n", "<leader>dv", "<cmd>lua _G.DiagnosticToggleInline()<CR>", { desc = "Toggle Diagnostics Inline" })

   -- HOVER AUTO: show diagnostic detail when cursor stops on a
   -- line that has one (equivalent of VS Code hover)
   vim.api.nvim_create_autocmd("CursorHold", {
     group = vim.api.nvim_create_augroup("DiagHoverAuto", { clear = true }),
     callback = function()
       local lnum = vim.fn.line(".") - 1
       if #vim.diagnostic.get(0, { lnum = lnum }) > 0 then
         pcall(vim.diagnostic.open_float, 0, { focus = false, scope = "line" })
       end
     end,
      desc = "Show diagnostic under cursor after idle delay",
   })

   -- Copy all text from Trouble panel with 'y'
   vim.api.nvim_create_autocmd("FileType", {
     pattern = "trouble",
     callback = function(args)
       vim.keymap.set("n", "y", "<cmd>%y+<CR>", { buffer = args.buf, silent = true, desc = "Copy all" })
     end,
   })
  
  -- LAZYGIT (Robust toggle + Ghost terminal cleanup)
  map("n", "<C-g>", function()
    local bufs = vim.api.nvim_list_bufs()
    local found = false
    for _, b in ipairs(bufs) do
      local ft = vim.bo[b].filetype
      if ft == "lazygit" or ft == "terminal" then
        vim.api.nvim_buf_delete(b, { force = true })
        found = true
      end
    end
    if not found then
      vim.cmd("LazyGit")
    end
  end, { desc = "Git UI Toggle" })

  -- LAZYDOCKER
  map("n", "<C-d>", function()
    require("lazydocker").open()
  end, { desc = "Docker UI Toggle" })

  -- TRUNK (TUI Diagnostic) — root detected dynamically
  -- Opens trunk in the directory containing .trunk / trunk.yaml, otherwise git root.
  local function open_trunk(cmd, title)
    local project = require "configs.project"
    local root = project.trunk_root()

    local Terminal = require("toggleterm.terminal").Terminal
    local trunk_tui = Terminal:new({
      cmd = cmd,
      dir = root,
      hidden = true,
      direction = "float",
      close_on_exit = false,
      float_opts = { border = "double", title = " 󰆏 " .. title .. " (y to copy) ", title_pos = "center" },
      -- Allow closing with 'q' once scan finishes
      on_open = function(term)
        vim.api.nvim_buf_set_keymap(term.bufnr, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true })
        vim.api.nvim_buf_set_keymap(term.bufnr, "n", "y", "<cmd>%y+<CR><cmd>lua vim.notify('Copied! 󰆏')<CR>", { noremap = true, silent = true })
      end,
    })
    trunk_tui:toggle()
  end

  map("n", "<C-t>", function()
    local project = require "configs.project"
    local root = project.trunk_root()
    -- Branch from detected root (not nvim's cwd)
    local branch = vim.fn.system("git -C " .. vim.fn.shellescape(root) .. " rev-parse --abbrev-ref HEAD 2>/dev/null"):gsub("%s+", "")
    local cmd = "trunk fmt && trunk check --show-existing"
    if branch == "main" or branch == "master" then
      cmd = "trunk fmt --all && trunk check --all --show-existing"
    end
    open_trunk(cmd, "Trunk Scan")
  end, { desc = "Trunk UI Toggle" })

  -- Dedicated shortcut to force check all files
  map("n", "<leader>ta", function()
    open_trunk("trunk fmt --all && trunk check --all --show-existing", "Trunk Check All")
  end, { desc = "Trunk Check All" })

  -- EMERGENCY : Force close current buffer (useful if stuck)
  map("n", "<C-k>", "<cmd>bd!<CR>", { desc = "Force Close Buffer" })

  -- Jump to definition VIA LSP (replaces tag search)
  -- Avoids "E433: No tags file" / "E426: Tag not found: xxx" errors
  map("n", "<C-]>", function()
    if #vim.lsp.get_clients({ bufnr = 0 }) > 0 then
      vim.lsp.buf.definition()
    else
      vim.notify(
        "No LSP server attached. Install via :MasonInstall or `npm i -g typescript typescript-language-server @tailwindcss/language-server vscode-langservers-extracted @prisma/language-server @angular/language-server` then restart nvim.",
        vim.log.levels.WARN
      )
    end
  end, { desc = "Go to definition (LSP)" })

  -- VS Code-like: Ctrl+Click on a symbol -> open its definition/file
  map("n", "<C-LeftMouse>", function()
    if #vim.lsp.get_clients({ bufnr = 0 }) > 0 then
      vim.lsp.buf.definition()
    else
      vim.notify("No LSP server attached to this buffer", vim.log.levels.WARN)
    end
  end, { desc = "Go to definition (Ctrl+Click)" })
  
  -- Tabs (Safe closing without E517 error)
  map("n", "<C-w>", function() 
    local success = pcall(function() require("nvchad.tabufline").close_buffer() end)
    if not success then
      pcall(function() vim.cmd("bd") end)
    end
  end, { desc = "Close Buffer" })

  -- MENU NVIM
  map("n", "<leader>m", "<cmd>Nvdash<CR>", { desc = "Show Nvim Menu (Dashboard)" })
  pcall(function()
    map("n", "<RightMouse>", function()
      vim.cmd.exec '"normal! \\<RightMouse>"'
      local options = vim.bo.ft == "NvimTree" and "nvimtree" or "default"
      require("menu").open(options, { mouse = true })
    end, { desc = "Open context menu" })
  end)
  
  -- FORMATTING (Shift + Alt + F)
  map("n", "<A-S-f>", function() 
    require("conform").format({ lsp_fallback = true }) 
    vim.notify("Formatting complete", vim.log.levels.INFO)
  end, { desc = "Format Code" })

  -- SCRIPTS RUNNER (auto-detects package.json scripts)
  map("n", "<leader>rr", function()
    require("configs.runner").pick()
  end, { desc = "Run Script (pick)" })

  map("n", "<leader>rt", function()
    require("configs.runner").run_test()
  end, { desc = "Run Tests" })

  map("n", "<leader>re", function()
    require("configs.runner").run_e2e()
  end, { desc = "Run E2E Tests" })

  map("n", "<leader>rl", function()
    require("configs.runner").run_lint()
  end, { desc = "Run Lint" })
end)
