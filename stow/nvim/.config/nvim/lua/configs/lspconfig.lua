-- NOTE: visual diagnostic configuration (virtual_text, signs,
-- float…) is centralized in init.lua — section 3 — to avoid any
-- conflict between two vim.diagnostic.config.

-- =====================================================================
-- IMPORTANT: completion capabilities for nvim-cmp.
-- Neovim applies this config `*` to ALL LSP servers. Without it,
-- the `nvim_lsp` source in nvim-cmp doesn't announce expected capabilities
-- and no LSP autocompletion appears in insert mode.
-- =====================================================================
local capabilities = require("cmp_nvim_lsp").default_capabilities()

vim.lsp.config("*", {
  capabilities = capabilities,
  -- Disables semantic tokens (avoids spurious refreshes)
  on_init = function(client)
    if client.supports_method and client:supports_method("textDocument/semanticTokens") then
      client.server_capabilities.semanticTokensProvider = nil
    end
  end,
})

-- Fallback: allows typescript-language-server to find `tsserver`
-- (and other tools) when the project doesn't have a local `typescript`.
local npm_root = vim.fn.system("npm root -g"):gsub("%s+", "")
if npm_root ~= "" and vim.fn.isdirectory(npm_root) == 1 then
  local node_path = vim.env.NODE_PATH or ""
  if not node_path:find(npm_root, 1, true) then
    vim.env.NODE_PATH = (node_path == "" and npm_root) or (npm_root .. ":" .. node_path)
  end
end

-- Shared project roots (JS/TS/Angular/Nx)
local root_markers = {
  "nx.json",
  "angular.json",
  "next.config.js",
  "next.config.mjs",
  "vite.config.ts",
  "tsconfig.base.json",
  "tsconfig.json",
  ".git",
  "package.json",
}

-- NOTE: we do NOT touch the `cmd` field of servers. The actual binaries
-- are (installed via Mason or npm -g):
--   html        -> vscode-html-language-server --stdio
--   cssls       -> vscode-css-language-server --stdio
--   tailwindcss -> tailwindcss-language-server --stdio
--   prismals    -> prisma-language-server --stdio
--   angularls   -> ngserver --stdio ...
--   dartls      -> dart language-server --protocol=lsp
-- The old `cmd = { name, "--stdio" }` caused server startup to fail
-- (hence missing autocompletion and E433/E426 errors).
local servers = { "html", "cssls", "tailwindcss", "prismals" }

-- Filetypes per server (for deferred FileType activation)
local server_filetypes = {
  html = { "html", "templ" },
  cssls = { "css", "scss", "sass", "less" },
  tailwindcss = { "html", "css", "scss", "sass", "less", "tsx", "jsx", "ts", "js", "vue", "svelte", "astro" },
  prismals = { "prisma" },
}

-- We only register the SERVER CONFIGURATION (lightweight, no
-- process startup). Actual activation (vim.lsp.enable) is deferred
-- via a FileType/BufReadPost autocmd in M.setup(), so after Neovim
-- fully opens, never during boot.
for _, name in ipairs(servers) do
  vim.lsp.config(name, { root_markers = root_markers })
end

-- Angular: only attaches if the project has angular.json (otherwise ngserver
-- would run pointlessly on every non-Angular TS / Next / Nx project)
vim.lsp.config("angularls", { root_markers = { "angular.json" } })

-- Dart (Flutter): keeps its native root `pubspec.yaml`
vim.lsp.config("dartls", {})
server_filetypes.dartls = { "dart" }

-- TypeScript / JavaScript configuration
vim.lsp.config("ts_ls", {
  root_markers = root_markers,
  settings = {
    typescript = {
      tsserver = { useSeparateDiagnosticsServer = true },
    },
  },
})
server_filetypes.ts_ls = { "typescript", "javascript", "typescriptreact", "javascriptreact" }

-- Angular: enabled for Angular project templates/TS
server_filetypes.angularls = { "typescript", "javascript", "html", "angular" }

-- ESLint configuration (LSP, binary: vscode-eslint-language-server)
vim.lsp.config("eslint", {
  settings = {
    workingDirectories = { mode = "auto" },
    experimental = { useFlatConfig = true },
    run = "onSave",
  },
  on_attach = function(_, bufnr)
    vim.api.nvim_create_autocmd("BufWritePre", {
      buffer = bufnr,
      command = "EslintFixAll",
    })
  end,
})
if vim.fn.executable("vscode-eslint-language-server") == 1 then
  server_filetypes.eslint = { "typescript", "javascript", "typescriptreact", "javascriptreact", "vue", "svelte" }
end

-- =====================================================================
-- DEFERRED LSP SERVER ACTIVATION
--
-- Why: `vim.lsp.enable()` at file load forces Neovim to try starting
-- each server as soon as a buffer of the matching type is opened during
-- boot. This blocks the UI, slows opening, and can crash if a binary
-- is missing.
--
-- Instead, we install a FileType autocmd that only enables the server
-- AFTER Neovim fully opens (VimEnter + defer). Activation is
-- idempotent: if a buffer of the right type is already loaded, we
-- attach immediately, otherwise we wait for the next FileType.
-- =====================================================================

local M = {}

local enabled_servers = {} -- guard: only enable a server once

-- Enables ALL configured LSP servers, no project condition.
local function enable_server(server)
  if enabled_servers[server] then return end
  pcall(vim.lsp.enable, server)
  enabled_servers[server] = true
  -- Neovim only re-triggers attachment for existing buffers if
  -- vim_did_enter/did_filetype (not guaranteed in headless). So we
  -- force execution of vim.lsp.enable's attachment autocmd.
  pcall(function()
    vim.cmd.doautoall("nvim.lsp.enable FileType")
  end)
end

function M.setup()
  -- ENABLE ALL: all servers start automatically after boot,
  -- regardless of the project or open file. Each server will only
  -- attach to buffers whose filetype matches (native behavior of
  -- vim.lsp.enable), so no unnecessary processes per file.
  for server in pairs(server_filetypes) do
    enable_server(server)
  end

  -- Safety net: if a server is added later (or failed at boot),
  -- every FileType triggers a new activation attempt.
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("LspDeferredAttach", { clear = true }),
    callback = function()
      for server in pairs(server_filetypes) do
        enable_server(server)
      end
    end,
    desc = "Retry activating LSP servers not yet enabled",
  })
end

return M
