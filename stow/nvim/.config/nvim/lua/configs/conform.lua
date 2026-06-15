local options = {
  formatters_by_ft = {
    javascript = { "prettierd" },
    typescript = { "prettierd" },
    angular = { "prettierd" },
    html = { "prettierd" },
    css = { "prettierd" },
    scss = { "prettierd" },
    json = { "prettierd" },
    prisma = { "prettierd" },
  },
  format_on_save = { timeout_ms = 500, lsp_fallback = true },
}
return options
