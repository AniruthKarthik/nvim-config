require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- Smart tab function to exit brackets/quotes or use normal tab
local function smart_tab()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  
  -- Get the character at cursor position
  local char_at_cursor = line:sub(col + 1, col + 1)
  
  -- Characters we want to exit from
  local exit_chars = { '"', "'", ")", "}", ">", "]" }
  
  -- Check if cursor is right before one of these characters
  for _, char in ipairs(exit_chars) do
    if char_at_cursor == char then
      -- Move cursor one position to the right (exit the bracket/quote)
      vim.api.nvim_win_set_cursor(0, {vim.api.nvim_win_get_cursor(0)[1], col + 1})
      return
    end
  end
  
  -- If not exiting, use normal tab behavior
  -- Check if we're in insert mode and there's text before cursor for indentation
  local before_cursor = line:sub(1, col)
  if before_cursor:match("^%s*$") then
    -- If only whitespace before cursor, insert tab for indentation
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Tab>", true, false, true), "n", false)
  else
    -- If there's text before cursor, try to trigger completion or insert tab
    -- You can customize this behavior based on your completion setup
    local has_cmp, cmp = pcall(require, "cmp")
    if has_cmp and cmp.visible() then
      cmp.select_next_item()
    else
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Tab>", true, false, true), "n", false)
    end
  end
end

-- Map Tab to smart_tab function in insert mode
map("i", "<Tab>", smart_tab, { desc = "Smart tab - exit brackets/quotes or normal tab" })

-- Optional: Map Shift+Tab for reverse completion navigation if you use completion
map("i", "<S-Tab>", function()
  local has_cmp, cmp = pcall(require, "cmp")
  if has_cmp and cmp.visible() then
    cmp.select_prev_item()
  else
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<S-Tab>", true, false, true), "n", false)
  end
end, { desc = "Reverse tab completion" })

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
