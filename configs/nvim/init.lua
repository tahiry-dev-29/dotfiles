vim.g.base46_cache = vim.fn.stdpath "data" .. "/base46/"
vim.g.mapleader = " "

-- Compatibility: vim.uv available since Neovim 0.10, fallback to vim.loop
vim.uv = vim.uv or vim.loop

-- 1. Bootstrapping NvChad
local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
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

-- 3.5 PROJECT DIAGNOSTICS SCANNER
require("configs.diagnostics").setup()

-- 3. CONFIGURATION DES ERREURS VISUELLES (PROBLEMS)
vim.diagnostic.config({
  virtual_text = {
    prefix = "■", -- More visible prefix
    spacing = 4,
  },
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
  float = {
    border = "rounded",
    source = "always",
    header = "",
    prefix = "",
  },
})

-- Icônes dans la marge
local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
for type, icon in pairs(signs) do
  local hl = "DiagnosticSign" .. type
  vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
end

-- 4. FORCER LES RACCOURCIS (CTRL+J pour TOUTE la codebase)
local map = vim.keymap.set

vim.schedule(function()
  -- Sidebar & Recherche
  map("n", "<C-b>", "<cmd>NvimTreeToggle<CR>", { desc = "Sidebar" })
  map("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", { desc = "Explorateur" })
  map("n", "<C-p>", "<cmd>Telescope find_files<CR>", { desc = "Find Files" })
  map({"n", "i", "v"}, "<C-S-p>", "<cmd>Telescope commands<CR>", { desc = "Command Palette" })
  map("n", "<C-f>", "<cmd>Telescope live_grep<CR>", { desc = "Search Project" })
  map({"n", "i", "v"}, "<C-S-f>", "<cmd>Telescope live_grep<CR>", { desc = "Search Project" })
  map("n", "<C-s>", "<cmd>w<CR>", { desc = "Save" })
  map("i", "<C-s>", "<cmd>w<CR><ESC>", { desc = "Save" })

  -- Edition
  map({"n", "i", "v"}, "<C-z>", "<cmd>undo<CR>")
  map({"n", "i", "v"}, "<C-y>", "<cmd>redo<CR>")
  map({"n", "v"}, "<C-a>", "ggVG")
  
  -- Copier/Couper/Coller
  map("v", "<C-c>", '"+y')
  map("v", "<C-x>", '"+d')
  map({"n", "i", "v"}, "<C-v>", '"+p')

   -- PANNEAU DES ERREURS (WORKSPACE DIAGNOSTICS)
   map("n", "<C-j>", "<cmd>Trouble diagnostics toggle<CR>", { desc = "Project Problems" })
   map("n", "<leader>ds", "<cmd>DiagScan<CR>", { desc = "Scan Project Diagnostics" })
   map("n", "<leader>dc", "<cmd>DiagClear<CR>", { desc = "Clear Project Diagnostics" })
  
  -- LAZYGIT (Toggle robuste + Nettoyage terminaux fantômes)
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

  -- TRUNK (TUI Diagnostic)
  map("n", "<C-t>", function()
    local Terminal = require("toggleterm.terminal").Terminal
    local trunk_tui = Terminal:new({ 
      cmd = "trunk check --show-existing", 
      hidden = true, 
      direction = "float",
      close_on_exit = false,
      float_opts = { border = "double" },
      -- Permet de fermer avec 'q' une fois le scan fini
      on_open = function(term)
        vim.api.nvim_buf_set_keymap(term.bufnr, "n", "q", "<cmd>close<CR>", {noremap = true, silent = true})
      end,
    })
    trunk_tui:toggle()
  end, { desc = "Trunk UI Toggle" })

  -- EMERGENCY : Force close current buffer (useful if stuck)
  map("n", "<C-k>", "<cmd>bd!<CR>", { desc = "Force Close Buffer" })
  
  -- Tabs (Safe closing without E517 error)
  map("n", "<C-w>", function() 
    local success = pcall(function() require("nvchad.tabufline").close_buffer() end)
    if not success then
      pcall(function() vim.cmd("bd") end)
    end
  end, { desc = "Close Buffer" })

  -- MENU NVIM
  map("n", "<leader>m", "<cmd>Nvdash<CR>", { desc = "Afficher le Menu Nvim (Dashboard)" })
  pcall(function()
    map("n", "<RightMouse>", function()
      vim.cmd.exec '"normal! \\<RightMouse>"'
      local options = vim.bo.ft == "NvimTree" and "nvimtree" or "default"
      require("menu").open(options, { mouse = true })
    end, { desc = "Ouvrir le menu contextuel" })
  end)
  
  -- FORMATAGE (Shift + Alt + F)
  map("n", "<A-S-f>", function() 
    require("conform").format({ lsp_fallback = true }) 
    vim.notify("Formatting complete", vim.log.levels.INFO)
  end, { desc = "Format Code" })
end)
