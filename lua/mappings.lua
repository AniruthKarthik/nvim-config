require "nvchad.mappings"

-- add yours here
local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")
-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>") i already have this

-- Smart ESC functionality
local function smart_close()
  -- Get current buffer info
  local buf_count = #vim.fn.getbufinfo({buflisted = 1})
  local win_count = #vim.api.nvim_list_wins()
  
  -- If there are multiple windows, close current window
  if win_count > 1 then
    vim.cmd('close')
  -- If there are multiple buffers, close current buffer
  elseif buf_count > 1 then
    vim.cmd('bdelete')
  -- If only one buffer and one window, quit nvim
  else
    -- Check if buffer is modified
    if vim.bo.modified then
      print("Buffer has unsaved changes. Use :q! to force quit or save first.")
      return
    end
    vim.cmd('quit')
  end
end

map("n", "<ESC>", smart_close, { desc = "Smart close: window -> buffer -> nvim" })
