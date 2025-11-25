require("nvchad.configs.lspconfig").defaults()

require("mason").setup()

require("mason-lspconfig").setup {
  ensure_installed = { "hls", "pylsp" },
}

vim.lsp.enable("all")

vim.lsp.config('hls', {})

vim.lsp.config('pylsp', {
  settings = {
    pylsp = {
      plugins = {
        -- 🔧 Formatter
        black = { enabled = true },

        -- 🚫 Disable annoying style warnings
        pycodestyle = { enabled = false },
        mccabe = { enabled = false },

        -- ✅ Keep essential error checking
        pyflakes = { enabled = true },

        -- 🧠 Optional: type checking for real errors
        pylsp_mypy = { enabled = true, live_mode = false },

        -- 🧩 Disable rope noise if not needed
        rope_completion = { enabled = false },
        rope_autoimport = { enabled = false },
      },
    },
  },
})

