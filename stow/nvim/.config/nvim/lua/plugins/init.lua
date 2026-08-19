return {
  { "rcarriga/nvim-notify", config = function() vim.notify = require("notify") end },
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
  -- LSP Principal (Tout est ici maintenant)
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
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
    },
  },

  -- GitHub Copilot (local, pas de téléchargement)
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
