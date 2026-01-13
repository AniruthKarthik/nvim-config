local nvlsp = require "nvchad.configs.lspconfig"

local on_attach = nvlsp.on_attach
local on_init = nvlsp.on_init
local capabilities = nvlsp.capabilities

require("mason").setup()

require("mason-lspconfig").setup {
  ensure_installed = { "pylsp", "clangd" },
}

local servers = { "pylsp", "clangd" }

for _, lsp in ipairs(servers) do
  local opts = {
    on_attach = on_attach,
    on_init = on_init,
    capabilities = capabilities,
  }

  if lsp == "clangd" then
    opts.cmd = {
      "clangd",
      "--offset-encoding=utf-16",
    }
  end

  if lsp == "pylsp" then
    opts.settings = {
      pylsp = {
        plugins = {
          -- 🔧 Formatter
          black = { enabled = true },
          autopep8 = { enabled = false },
          yapf = { enabled = false },

          -- 🚫 Disable style linters
          pylint = { enabled = false },
          flake8 = { enabled = false },
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
    }
  end

  -- Native Neovim 0.11+ LSP setup
  vim.lsp.config(lsp, opts)
  vim.lsp.enable(lsp)
end

-- Configure diagnostics to show errors and underlines
vim.diagnostic.config({
  virtual_text = {
    prefix = "●",
  },
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})

