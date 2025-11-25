return {
  {
    "nvim-treesitter/nvim-treesitter",
    event = { "BufReadPre", "BufNewFile" },
    build = ":TSUpdate",
    dependencies = {
      "windwp/nvim-ts-autotag",
      "nvim-treesitter/nvim-treesitter-textobjects",
    },
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "vim", "lua", "vimdoc",
          "html", "css", "javascript", "typescript",
          "python", "java", "cpp", "c", "rust", "go"
        },
        highlight = { enable = true },
        indent = { enable = true },
        autotag = { enable = true },
      })
    end,
  },

  -- Install Mason
  {
    "williamboman/mason.nvim",
  },

  -- Install Mason LSP bridge
  {
    "williamboman/mason-lspconfig.nvim",
  },

  -- Install Neovim native LSP config
  {
    "neovim/nvim-lspconfig",
    config = function()
      require("configs.lspconfig")
    end,
  },
}

