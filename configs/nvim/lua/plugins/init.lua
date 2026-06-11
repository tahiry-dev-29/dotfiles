return {
  { "rcarriga/nvim-notify", config = function() vim.notify = require("notify") end },
  -- Noice pour UI et Commandes centralisées
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
  -- LSP Principal (Tout est ici maintenant)
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  -- Treesitter pour les couleurs
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = { "html", "css", "typescript", "angular", "lua", "prisma", "dart", "json", "scss" },
      highlight = { enable = true },
    },
  },

  -- Vos outils VS Code
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
    } 
  },
  { "stevearc/conform.nvim", event = "BufWritePre", opts = require "configs.conform" },
  { "lewis6991/gitsigns.nvim", event = "User FilePost", opts = {} },
  { "kdheepak/lazygit.nvim", cmd = { "LazyGit", "LazyGitConfig", "LazyGitCurrentFile", "LazyGitFilter", "LazyGitFilterCurrentFile" }, dependencies = { "nvim-lua/plenary.nvim" } },
  { "mgierada/lazydocker.nvim", dependencies = { "akinsho/toggleterm.nvim" }, config = function() require("lazydocker").setup({}) end },
  { "trunk-io/neovim-trunk", dependencies = { "nvim-telescope/telescope.nvim" }, config = function() require("trunk").setup({ formatOnSave = true }) end },
  { "sindrets/diffview.nvim", cmd = { "DiffviewOpen", "DiffviewFileHistory" } },
}
