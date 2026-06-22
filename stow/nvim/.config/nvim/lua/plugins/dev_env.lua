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
  {
    "ThePrimeagen/git-worktree.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
    },
    config = function()
      require("git-worktree").setup({
        change_directory_command = "tcd",
        update_on_change = true,
        update_on_change_command = "e .",
        clearjumps_on_change = true,
      })
      require("telescope").load_extension("git_worktree")
    end,
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
