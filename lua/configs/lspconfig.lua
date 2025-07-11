local default_config = require("nvchad.configs.lspconfig")
local lspconfig = require("lspconfig")

local on_attach = default_config.on_attach
local capabilities = default_config.capabilities

-- List of language servers to set up
local servers = {
  clangd = {},         -- C/C++
  pyright = {},        -- Python
  html = {},           -- HTML
  cssls = {},          -- CSS
  lua_ls = {},         -- Lua
  jsonls = {},         -- JSON
  bashls = {},         -- Shell
  marksman = {},       -- Markdown
}

-- Set up each server with defaults + optional overrides
for name, config in pairs(servers) do
  local ok, server = pcall(function() return lspconfig[name] end)

  if ok and server and type(server.setup) == "function" then
    server.setup(vim.tbl_deep_extend("force", {
      on_attach = on_attach,
      capabilities = capabilities,
    }, config))
  else
    vim.notify("LSP `" .. name .. "` not found or has no setup() function", vim.log.levels.WARN)
  end
end

