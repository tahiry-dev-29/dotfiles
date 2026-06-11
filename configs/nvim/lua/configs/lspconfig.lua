-- Configuration globale des diagnostics
vim.diagnostic.config({
  virtual_text = {
    prefix = "●",
    spacing = 4,
  },
  signs = true,
  underline = true,
  update_in_insert = true,
  severity_sort = true,
})

-- Configuration moderne via vim.lsp.config
local servers = { "html", "cssls", "angularls", "tailwindcss", "prismals", "dartls" }

for _, name in ipairs(servers) do
  vim.lsp.config(name, {
    cmd = { name, "--stdio" }, -- Typo fixed: { name, "--stdio" }
    root_markers = { "nx.json", "angular.json", "next.config.js", "next.config.mjs", "vite.config.ts", "tsconfig.base.json", "tsconfig.json", ".git", "package.json" },
  })
  vim.lsp.enable(name)
end

-- Configuration de ESLint
vim.lsp.config("eslint", {
  settings = {
    workingDirectories = { mode = "auto" },
    experimental = { useFlatConfig = true },
    run = "onSave",
  },
  on_attach = function(client, bufnr)
    vim.api.nvim_create_autocmd("BufWritePre", {
      buffer = bufnr,
      command = "EslintFixAll",
    })
  end,
})
vim.lsp.enable("eslint")

-- Configuration de TypeScript
vim.lsp.config("ts_ls", {
  root_markers = { "nx.json", "angular.json", "next.config.js", "next.config.mjs", "vite.config.ts", "tsconfig.base.json", "tsconfig.json", ".git", "package.json" },
  settings = {
    typescript = {
      tsserver = { useSeparateDiagnosticsServer = true },
    },
  },
})
vim.lsp.enable("ts_ls")
