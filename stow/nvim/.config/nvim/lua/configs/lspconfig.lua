-- NB : la configuration visuelle des diagnostics (virtual_text, signs,
-- float…) est centralisée dans init.lua — section 3 — pour éviter tout
-- conflit entre deux vim.diagnostic.config.

-- =====================================================================
-- IMPORTANT : capabilities de completion pour nvim-cmp.
-- Neovim applique cette config `*` à TOUS les serveurs LSP. Sans ça,
-- la source `nvim_lsp` de nvim-cmp n'annonce pas les capacités attendues
-- et aucune autocomplétion LSP n'apparaît en mode insert.
-- =====================================================================
local capabilities = require("cmp_nvim_lsp").default_capabilities()

vim.lsp.config("*", {
  capabilities = capabilities,
  -- Désactive les semantic tokens (évite des rafraîchissements parasites)
  on_init = function(client)
    if client.supports_method and client:supports_method("textDocument/semanticTokens") then
      client.server_capabilities.semanticTokensProvider = nil
    end
  end,
})

-- Fallback : permet à typescript-language-server de trouver `tsserver`
-- (et aux autres outils) quand le projet n'a pas de `typescript` local.
local npm_root = vim.fn.system("npm root -g"):gsub("%s+", "")
if npm_root ~= "" and vim.fn.isdirectory(npm_root) == 1 then
  local node_path = vim.env.NODE_PATH or ""
  if not node_path:find(npm_root, 1, true) then
    vim.env.NODE_PATH = (node_path == "" and npm_root) or (npm_root .. ":" .. node_path)
  end
end

-- Racines de projet partagées (JS/TS/Angular/Nx)
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

-- NOTE : on ne touche PAS au champ `cmd` des serveurs. Les binaires réels
-- sont (installés via Mason ou npm -g) :
--   html        -> vscode-html-language-server --stdio
--   cssls       -> vscode-css-language-server --stdio
--   tailwindcss -> tailwindcss-language-server --stdio
--   prismals    -> prisma-language-server --stdio
--   angularls   -> ngserver --stdio ...
--   dartls      -> dart language-server --protocol=lsp
-- L'ancien `cmd = { name, "--stdio" }` faisait échouer le démarrage de
-- chaque serveur (d'où l'absence d'autocomplétion et les erreurs E433/E426).
local servers = { "html", "cssls", "tailwindcss", "prismals" }

-- Filetypes par serveur (pour activation différée via FileType)
local server_filetypes = {
  html = { "html", "templ" },
  cssls = { "css", "scss", "sass", "less" },
  tailwindcss = { "html", "css", "scss", "sass", "less", "tsx", "jsx", "ts", "js", "vue", "svelte", "astro" },
  prismals = { "prisma" },
}

-- On enregistre uniquement la CONFIGURATION des serveurs (léger, pas de
-- démarrage de processus). L'activation réelle (vim.lsp.enable) est différée
-- via un autocmd FileType/BufReadPost dans M.setup(), donc après l'ouverture
-- complète de Neovim, jamais pendant le boot.
for _, name in ipairs(servers) do
  vim.lsp.config(name, { root_markers = root_markers })
end

-- Angular : ne s'attache que si le projet a un angular.json (sinon ngserver
-- tournerait inutilement sur chaque projet TS / Next / Nx non-Angular)
vim.lsp.config("angularls", { root_markers = { "angular.json" } })

-- Dart (Flutter) : garde sa racine native `pubspec.yaml`
vim.lsp.config("dartls", {})
server_filetypes.dartls = { "dart" }

-- Configuration de TypeScript / JavaScript
vim.lsp.config("ts_ls", {
  root_markers = root_markers,
  settings = {
    typescript = {
      tsserver = { useSeparateDiagnosticsServer = true },
    },
  },
})
server_filetypes.ts_ls = { "typescript", "javascript", "typescriptreact", "javascriptreact" }

-- Angular : activé sur les templates/TS des projets Angular
server_filetypes.angularls = { "typescript", "javascript", "html", "angular" }

-- Configuration de ESLint (LSP, binaire : vscode-eslint-language-server)
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
-- ACTIVATION DIFFÉRÉE DES SERVEURS LSP
--
-- Pourquoi : `vim.lsp.enable()` au chargement du fichier force Neovim à
-- tenter de démarrer chaque serveur dès qu'un buffer du type correspondant
-- est ouvert pendant le boot. Cela bloque l'UI, ralentit l'ouverture et
-- peut crasher si un binaire est manquant.
--
-- À la place, on installe un autocmd FileType qui n'active le serveur
-- QU'APRÈS l'ouverture complète de Neovim (VimEnter + defer). L'activation
-- est idempotente : si un buffer du bon type est déjà chargé, on l'attache
-- immédiatement, sinon on attend le prochain FileType.
-- =====================================================================

local M = {}

local enabled_servers = {} -- garde-fou : n'active un serveur qu'une fois

-- Active TOUS les serveurs LSP configurés, sans condition de projet.
local function enable_server(server)
  if enabled_servers[server] then return end
  pcall(vim.lsp.enable, server)
  enabled_servers[server] = true
  -- Neovim ne re-déclenche l'attachement des buffers existants que si
  -- vim_did_enter/did_filetype (pas garantis en headless). On force
  -- donc l'exécution de l'autocmd d'attachement de vim.lsp.enable.
  pcall(function()
    vim.cmd.doautoall("nvim.lsp.enable FileType")
  end)
end

function M.setup()
  -- ACTIVE ALL : tous les serveurs démarrent automatiquement après le boot,
  -- peu importe le projet ou le fichier ouvert. Chaque serveur ne s'attachera
  -- de lui-même qu'aux buffers dont le filetype correspond (comportement
  -- natif de vim.lsp.enable), donc aucun processus inutile par fichier.
  for server in pairs(server_filetypes) do
    enable_server(server)
  end

  -- Filet de sécurité : si un serveur était ajouté plus tard (ou échec au
  -- boot), tout FileType déclenche une nouvelle tentative d'activation.
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("LspDeferredAttach", { clear = true }),
    callback = function()
      for server in pairs(server_filetypes) do
        enable_server(server)
      end
    end,
    desc = "Ré-essaie d'activer les serveurs LSP non encore activés",
  })
end

return M
