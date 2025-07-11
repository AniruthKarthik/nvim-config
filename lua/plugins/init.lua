-- ~/.config/nvim/lua/plugins/init.lua

return {
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        "clangd",
        "pyright",
        "tsserver",               -- still needed for ts_ls
        "lua-language-server",
        "html",
        "cssls",
        "jsonls",
        "bash-language-server",
        "marksman",
      },
    },
  },
}

