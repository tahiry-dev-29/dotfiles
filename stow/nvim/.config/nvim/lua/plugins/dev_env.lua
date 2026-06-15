return {
  -- Git : Statut et Graphe
  {
    "lewis6991/gitsigns.nvim",
    event = "User FilePost",
    opts = {},
  },
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory" }
  },

  -- Auto-completion & Auto-import (Integrated in NvChad)
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    opts = function()
      return require "nvchad.configs.cmp"
    end,
  }
}
