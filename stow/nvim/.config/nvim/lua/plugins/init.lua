return {
  -- Fast toasts (nvim-notify). timeout = 1500ms instead of default 5000ms
  {
    "rcarriga/nvim-notify",
    opts = {
      timeout = 1500,
      stages = "fade_in_slide_out",
      max_height = function() return 12 end,
      max_width = function() return 72 end,
      on_open = function(win)
        vim.api.nvim_win_set_option(win, "winblend", 10)
      end,
    },
    config = function(_, opts)
      local notify = require("notify")
      notify.setup(opts)
      vim.notify = notify
    end,
  },
  -- Noice for UI and centralized Commands
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    opts = {
      lsp = {
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
      },
      presets = {
        bottom_search = false,
        command_palette = true,
        long_message_to_split = true,
      },
    },
    dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify" },
  },
  -- Mason: adds its bin/ folder to PATH so installed binaries
  -- (tailwindcss-language-server, etc.) are found by lspconfig.
  {
    "mason-org/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonUninstall", "MasonUpdate", "MasonUninstallAll" },
    event = "VeryLazy",
    opts = {
      PATH = "prepend",
      max_concurrent_installers = 10,
      ui = {
        icons = {
          package_pending = " ",
          package_installed = " ",
          package_uninstalled = " ",
        },
      },
    },
  },
  -- Automatically installs missing LSP servers (one-time)
  -- NOTE: automatic_enable = false — server activation is handled
  -- DEFERRED by configs/lspconfig.lua (FileType autocmd after
  -- nvim fully opens). Otherwise mason-lspconfig would activate ALL
  -- servers on its load (VeryLazy), which blocks boot.
  {
    "williamboman/mason-lspconfig.nvim",
    event = "VeryLazy",
    dependencies = { "mason-org/mason.nvim", "neovim/nvim-lspconfig" },
    opts = {
      ensure_installed = {
        "html",
        "cssls",
        "tailwindcss",
        "prismals",
        "angularls",
        "ts_ls",
        "lua_ls",
        "eslint",
      },
      automatic_enable = false,
    },
  },
  -- Main LSP (everything is here now)
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  -- Your VS Code tools
  { "nvim-telescope/telescope.nvim", cmd = "Telescope" },
  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = {
      auto_refresh = true,
      focus = false,
      modes = {
        diagnostics = {
          auto_open = false,
          auto_refresh = true,
          focus = false,
          win = { position = "bottom", size = { height = 12 } },
        },
      },
      icons = {
        indent = {
          fold_open = " ",
          fold_closed = " ",
        },
      },
    },
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Workspace Diagnostics" },
      { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer Diagnostics" },
      { "<leader>cs", "<cmd>Trouble symbols toggle focus=false<cr>", desc = "Symbols" },
      { "<leader>cl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", desc = "LSP References" },
      { "<leader>xL", "<cmd>Trouble loclist toggle<cr>", desc = "Location List" },
      { "<leader>xQ", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix List" },
    },
  },
  { "nvim-tree/nvim-tree.lua",
    opts = {
      view = {
        adaptive_size = true,
      },
      filters = {
        dotfiles = false,
        git_ignored = false,
        custom = { ".git" },
      },
    },
  },

  -- GitHub Copilot (local, no download)
  {
    dir = vim.fn.stdpath("config") .. "/pack/github/start/copilot.vim",
    event = "InsertEnter",
    cmd = "Copilot",
    init = function()
      vim.g.copilot_no_tab_map = true
      vim.g.copilot_filetypes = { ["*"] = true, gitcommit = false, [".env"] = false }
    end,
    config = function()
      local map = vim.keymap.set
      map("i", "<M-l>", function() return vim.fn["copilot#Accept"]("") end, { expr = true, desc = "Copilot: Accept" })
      map("i", "<M-]>", "<Cmd>call copilot#Next()<CR>", { desc = "Copilot: Next" })
      map("i", "<M-[>", "<Cmd>call copilot#Previous()<CR>", { desc = "Copilot: Previous" })
      map("i", "<M-\\>", "<Cmd>call copilot#Suggest()<CR>", { desc = "Copilot: Suggest" })
      map("i", "<C-]>", "<Cmd>call copilot#Dismiss()<CR>", { desc = "Copilot: Dismiss" })
      map("i", "<M-Right>", "<Cmd>call copilot#AcceptWord()<CR>", { desc = "Copilot: Accept Word" })
      map("i", "<M-C-Right>", "<Cmd>call copilot#AcceptLine()<CR>", { desc = "Copilot: Accept Line" })
    end,
  },
  { "stevearc/conform.nvim", event = "BufWritePre", opts = require "configs.conform" },
  { "lewis6991/gitsigns.nvim", event = "User FilePost", opts = {} },
  { "kdheepak/lazygit.nvim", cmd = { "LazyGit", "LazyGitConfig", "LazyGitCurrentFile", "LazyGitFilter", "LazyGitFilterCurrentFile" }, dependencies = { "nvim-lua/plenary.nvim" } },
  { "mgierada/lazydocker.nvim", dependencies = { "akinsho/toggleterm.nvim" }, config = function() require("lazydocker").setup({}) end },
  { "trunk-io/neovim-trunk", dependencies = { "nvim-telescope/telescope.nvim" }, config = function() require("trunk").setup({ formatOnSave = true }) end },
  { "sindrets/diffview.nvim", cmd = { "DiffviewOpen", "DiffviewFileHistory" } },
}
