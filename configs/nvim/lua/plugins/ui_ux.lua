return {
  -- Coloration (Treesitter)
  {
    "nvim-treesitter/nvim-treesitter",
    event = { "BufReadPost", "BufNewFile" },
    build = ":TSUpdate",
    init = function() require("nvim-treesitter.install").prefer_git = false end,
    opts = {
      ensure_installed = { "html", "css", "typescript", "angular", "lua", "prisma", "dart", "json", "scss", "javascript" },
      auto_install = true,
      highlight = { enable = true },
      indent = { enable = true },
    },
    config = function(_, opts)
      local status, ts_configs = pcall(require, "nvim-treesitter.configs")
      if status then ts_configs.setup(opts) end
    end,
  },

  -- Panneau "Problems" comme VS Code
  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = {},
  },

  -- Formattage (Prettier)
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    opts = {
      formatters_by_ft = {
        javascript = { "prettierd" },
        typescript = { "prettierd" },
        angular = { "prettierd" },
        html = { "prettierd" },
        css = { "prettierd" },
        prisma = { "prettierd" },
      },
      format_on_save = { timeout_ms = 500, lsp_fallback = true },
    },
  },

  -- Recherche Telescope
  {
    "nvim-telescope/telescope.nvim",
    opts = {
      defaults = {
        vimgrep_arguments = { "rg", "--color=never", "--no-heading", "--with-filename", "--line-number", "--column", "--smart-case", "--hidden" },
      },
      pickers = {
        find_files = {
          hidden = true,
        },
        live_grep = {
          additional_args = function(opts)
            return { "--hidden" }
          end,
        },
      },
    },
  }
}
