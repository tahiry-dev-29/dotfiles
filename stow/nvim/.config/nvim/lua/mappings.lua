local M = {}

M.general = {
  n = {
    -- 1. VS Code: Sidebar/Explorer
    ["<C-b>"] = { "<cmd>NvimTreeToggle<CR>", "VS Code: Toggle Sidebar" },
    ["<leader>e"] = { "<cmd>NvimTreeToggle<CR>", "Toggle Explorer" },
    ["<C-n>"] = { "<cmd>NvimTreeToggle<CR>", "Toggle Explorer" },
    
    -- 2. VS Code: Find Files
    ["<C-p>"] = { "<cmd>Telescope find_files<CR>", "VS Code: Find Files" },
    
    -- 3. VS Code: Search in Project
    ["<C-f>"] = { "<cmd>Telescope live_grep<CR>", "VS Code: Global Search" },
    ["<C-S-f>"] = { "<cmd>Telescope live_grep<CR>", "VS Code: Global Search" },
    
    -- 4. VS Code: Command Palette
    ["<C-S-p>"] = { "<cmd>Telescope commands<CR>", "VS Code Palette" },
    ["<leader>cp"] = { "<cmd>Telescope commands<CR>", "Command Palette" },
    
    -- 5. VS Code: Save
    ["<C-s>"] = { "<cmd>w<CR>", "VS Code: Save" },
    
    -- 6. VS Code: Problems Panel
    ["<C-j>"] = { "<cmd>Trouble diagnostics toggle<CR>", "VS Code: Problems" },
    
    -- 7. VS Code: Close Tab
    ["<C-w>"] = {
      function()
        require("nvchad.tabufline").close_buffer()
      end,
      "VS Code: Close Tab",
    },

    -- 8. VS Code: Format Code (Shift+Alt+F)
    ["<A-S-f>"] = {
      function()
        require("conform").format { lsp_fallback = true }
      end,
      "VS Code: Format Code",
    },
  },

  i = {
    ["<C-s>"] = { "<cmd>w<CR><ESC>", "VS Code: Save" },
  },

  v = {
    ["<C-c>"] = { '"+y', "VS Code: Copy to clipboard" },
  },
}

return M
