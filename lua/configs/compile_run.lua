
local M = {}
local state = {
	win = nil,
	buf = nil,
	job_id = nil,
	visible = false,
}

local function toggle_window()
	if state.visible then
		if state.win and vim.api.nvim_win_is_valid(state.win) then
			vim.api.nvim_win_hide(state.win)
		end
		state.visible = false
	else
		if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
			local width = math.floor(vim.o.columns * 0.8)
			local height = math.min(20, vim.o.lines - 4)
			local row = math.floor((vim.o.lines - height) / 2)
			local col = math.floor((vim.o.columns - width) / 2)
			state.win = vim.api.nvim_open_win(state.buf, true, {
				relative = "editor",
				width = width,
				height = height,
				row = row,
				col = col,
				style = "minimal",
				border = "rounded",
				focusable = true,
			})
			state.visible = true
		else
			vim.notify("No active output buffer to show", vim.log.levels.WARN)
		end
	end
end

local function quit_process()
	-- Stop the job if it's running
	if state.job_id and vim.fn.jobwait({ state.job_id }, 0)[1] == -1 then
		vim.fn.jobstop(state.job_id)
	end
	-- Close the window if it's open
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		vim.api.nvim_win_close(state.win, true)
	end
	-- Reset state
	state = { win = nil, buf = nil, job_id = nil, visible = false }
end

function M.compile_and_run()
	-- If we're in the output window, toggle it
	if vim.bo.filetype == "output" then
		toggle_window()
		return
	end

	-- Ignore other non-code buffers
	if vim.bo.filetype == "log" then
		vim.notify("CompileRun: Ignored buffer of filetype '" .. vim.bo.filetype .. "'", vim.log.levels.INFO)
		return
	end

	-- If job already running, just toggle the output window
	if state.job_id and vim.fn.jobwait({ state.job_id }, 0)[1] == -1 then
		toggle_window()
		return
	end

	local ext = vim.fn.expand("%:e")
	local filetype = vim.bo.filetype
	local file = vim.fn.expand("%:p")
	local name = vim.fn.expand("%:t:r")

	local cmd = ({
		c = string.format("gcc %s -o %s && ./%s", file, name, name),
		cpp = string.format("g++ %s -o %s && ./%s", file, name, name),
		py = "python3 " .. file,
		java = string.format("javac %s && java %s", file, name),
		rs = string.format("rustc %s && ./%s", file, name),
		sh = "bash " .. file,
		lua = "lua " .. file,
	})[ext]

	if not cmd and (filetype == "audio" or filetype == "video" or ext == "mp4") then
		vim.fn.jobstart("mpv " .. vim.fn.shellescape(file), { detach = true })
		return
	elseif not cmd and (filetype == "png" or filetype == "jpg" or filetype == "jpeg") then
		vim.fn.jobstart("mpv " .. vim.fn.shellescape(file) .. " --keep-open --ontop", { detach = true })
		return
	elseif not cmd then
		vim.notify("Unsupported filetype: " .. ext .. " (" .. filetype .. ")", vim.log.levels.WARN)
		return
	end

	-- Setup buffer
	state.buf = vim.api.nvim_create_buf(false, true)
	state.visible = true
	state.job_id = nil
	local buf = state.buf

	if vim.api.nvim_buf_is_valid(buf) then
		vim.api.nvim_buf_set_option(buf, "filetype", "output")
		vim.api.nvim_buf_set_option(buf, "modifiable", false)
	end

	-- Window UI
	local width = math.floor(vim.o.columns * 0.8)
	local height = math.min(20, vim.o.lines - 4)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	state.win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		focusable = true,
	})

	-- Start job
	state.job_id = vim.fn.jobstart(cmd, {
		on_stdout = function(_, data)
			if not (data and vim.api.nvim_buf_is_valid(buf)) then
				return
			end
			vim.api.nvim_buf_set_option(buf, "modifiable", true)
			vim.api.nvim_buf_set_lines(
				buf,
				-1,
				-1,
				false,
				vim.tbl_filter(function(l)
					return l ~= ""
				end, data)
			)
			vim.api.nvim_buf_set_option(buf, "modifiable", false)
		end,
		on_stderr = function(_, data)
			if not (data and vim.api.nvim_buf_is_valid(buf)) then
				return
			end
			vim.api.nvim_buf_set_option(buf, "modifiable", true)
			for _, line in ipairs(data) do
				if line ~= "" then
					vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "ERROR: " .. line })
				end
			end
			vim.api.nvim_buf_set_option(buf, "modifiable", false)
		end,
		on_exit = function(_, code)
			if vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_set_option(buf, "modifiable", true)
				vim.api.nvim_buf_set_lines(buf, -1, -1, false, {
					"",
					"[Process exited with code " .. code .. "]",
					"[Press q to close | <leader>rr to toggle]",
				})
				vim.api.nvim_buf_set_option(buf, "modifiable", false)
			end
		end,
	})

	-- Keymaps (conditionally applied)
	if vim.api.nvim_buf_is_valid(buf) then
		local opts = { buffer = buf, silent = true }

		-- Window resize keymaps
		vim.keymap.set("n", "<C-Up>", function()
			if state.win and vim.api.nvim_win_is_valid(state.win) then
				vim.api.nvim_win_set_height(state.win, vim.api.nvim_win_get_height(state.win) - 1)
			end
		end, opts)

		vim.keymap.set("n", "<C-Down>", function()
			if state.win and vim.api.nvim_win_is_valid(state.win) then
				vim.api.nvim_win_set_height(state.win, vim.api.nvim_win_get_height(state.win) + 1)
			end
		end, opts)

		vim.keymap.set("n", "<C-Left>", function()
			if state.win and vim.api.nvim_win_is_valid(state.win) then
				vim.api.nvim_win_set_width(state.win, vim.api.nvim_win_get_width(state.win) - 2)
			end
		end, opts)

		vim.keymap.set("n", "<C-Right>", function()
			if state.win and vim.api.nvim_win_is_valid(state.win) then
				vim.api.nvim_win_set_width(state.win, vim.api.nvim_win_get_width(state.win) + 2)
			end
		end, opts)

		-- Quit keymap - kills process and closes window
		vim.keymap.set("n", "q", quit_process, opts)
	end
end

-- Create user command
vim.api.nvim_create_user_command("CompileRun", M.compile_and_run, {})

return M

-- local vim = vim
--
-- -- Create the module table
-- local M = {}
--
-- function M.compile_and_run()
-- 	local original_ext = vim.fn.expand("%:e") -- Keep this for other specific extensions if needed
-- 	local current_filetype = vim.bo.filetype -- Get the current buffer's filetype (e.g., "audio", "video")
-- 	local file = vim.fn.expand("%:p")
-- 	local filename = vim.fn.expand("%:t:r")
-- 	local cmd = ""
--
-- 	if original_ext == "c" then
-- 		cmd = string.format("gcc %s -o %s && ./%s", file, filename, filename)
-- 	elseif original_ext == "cpp" then
-- 		cmd = string.format("g++ %s -o %s && ./%s", file, filename, filename)
-- 	elseif original_ext == "py" then
-- 		cmd = string.format("python3 %s", file)
-- 	elseif original_ext == "java" then
-- 		cmd = string.format("javac %s && java %s", file, filename)
-- 	elseif original_ext == "rs" then
-- 		cmd = string.format("rustc %s && ./%s", file, filename)
-- 	elseif original_ext == "sh" then
-- 		cmd = string.format("bash %s", file)
-- 	elseif original_ext == "lua" then
-- 		cmd = string.format("lua %s", file)
-- 	elseif current_filetype == "video" then
-- 		cmd = string.format("mpv %s", vim.fn.shellescape(file))
-- 		vim.fn.jobstart(cmd, { detach = true })
-- 		return
-- 	elseif current_filetype == "audio" then
-- 		cmd = string.format("mpv %s", vim.fn.shellescape(file))
-- 		vim.fn.jobstart(cmd, { detach = true })
-- 		return
-- 	elseif current_filetype == "png" or current_filetype == "jpg" or current_filetype == "jpeg" then
-- 		cmd = string.format("mpv %s --keep-open --ontop", vim.fn.shellescape(file))
-- 		vim.fn.jobstart(cmd, { detach = true })
-- 		return
-- 	else
-- 		vim.notify(
-- 			"Unsupported filetype: " .. original_ext .. " (Detected as: " .. current_filetype .. ")",
-- 			vim.log.levels.WARN
-- 		)
-- 		return
-- 	end
--
-- 	local buf = vim.api.nvim_create_buf(false, true)
-- 	local output_lines = {}
-- 	local job_id = nil -- Store the job ID so we can kill it later
--
-- 	vim.api.nvim_buf_set_option(buf, "filetype", "output")
-- 	vim.api.nvim_buf_set_option(buf, "modifiable", false)
--
-- 	local width = math.floor(vim.o.columns * 0.8)
-- 	local height = math.min(20, vim.o.lines - 4)
-- 	local row = math.floor((vim.o.lines - height) / 2)
-- 	local col = math.floor((vim.o.columns - width) / 2)
--
-- 	local win = vim.api.nvim_open_win(buf, true, {
-- 		relative = "editor",
-- 		width = width,
-- 		height = height,
-- 		row = row,
-- 		col = col,
-- 		style = "minimal",
-- 		border = "rounded",
-- 		focusable = true,
-- 	})
--
-- 	-- Start the job and stream output
-- 	job_id = vim.fn.jobstart(cmd, {
-- 		on_stdout = function(_, data)
-- 			if data then
-- 				-- Make buffer modifiable temporarily
-- 				vim.api.nvim_buf_set_option(buf, "modifiable", true)
-- 				for _, line in ipairs(data) do
-- 					if line ~= "" then
-- 						table.insert(output_lines, line)
-- 						vim.api.nvim_buf_set_lines(buf, -1, -1, false, { line })
-- 					end
-- 				end
-- 				-- Make buffer non-modifiable again
-- 				vim.api.nvim_buf_set_option(buf, "modifiable", false)
-- 			end
-- 		end,
-- 		on_stderr = function(_, data)
-- 			if data then
-- 				-- Make buffer modifiable temporarily
-- 				vim.api.nvim_buf_set_option(buf, "modifiable", true)
-- 				for _, line in ipairs(data) do
-- 					if line ~= "" then
-- 						table.insert(output_lines, "ERROR: " .. line)
-- 						vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "ERROR: " .. line })
-- 					end
-- 				end
-- 				-- Make buffer non-modifiable again
-- 				vim.api.nvim_buf_set_option(buf, "modifiable", false)
-- 			end
-- 		end,
-- 		on_exit = function(_, code)
-- 			-- Make buffer modifiable temporarily
-- 			vim.api.nvim_buf_set_option(buf, "modifiable", true)
-- 			vim.api.nvim_buf_set_lines(
-- 				buf,
-- 				-1,
-- 				-1,
-- 				false,
-- 				{ "", "[Process exited with code " .. code .. "]", "[Press q to close]" }
-- 			)
-- 			-- Make buffer non-modifiable again
-- 			vim.api.nvim_buf_set_option(buf, "modifiable", false)
-- 		end,
-- 	})
--
-- 	-- Function to close window and kill process if needed
-- 	local function close_and_cleanup()
-- 		-- Kill the job if it's still running
-- 		if job_id and vim.fn.jobwait({ job_id }, 0)[1] == -1 then
-- 			vim.fn.jobstop(job_id)
-- 			vim.notify("Stopped running process (job ID: " .. job_id .. ")", vim.log.levels.INFO)
-- 		end
-- 		-- Close the window
-- 		if vim.api.nvim_win_is_valid(win) then
-- 			vim.api.nvim_win_close(win, true)
-- 		end
-- 	end
--
-- 	-- Close on `q` with cleanup
-- 	vim.keymap.set("n", "q", close_and_cleanup, { buffer = buf, nowait = true, silent = true })
--
-- 	-- Also cleanup when the window is closed by other means (like :q, <C-w>c, etc.)
-- 	vim.api.nvim_create_autocmd("WinClosed", {
-- 		pattern = tostring(win),
-- 		once = true,
-- 		callback = function()
-- 			if job_id and vim.fn.jobwait({ job_id }, 0)[1] == -1 then
-- 				vim.fn.jobstop(job_id)
-- 				vim.notify("Stopped running process (job ID: " .. job_id .. ")", vim.log.levels.INFO)
-- 			end
-- 		end,
-- 	})
--
-- 	-- Resize keys
-- 	local function resize_win(delta_w, delta_h)
-- 		if not vim.api.nvim_win_is_valid(win) then
-- 			vim.notify("Resize: window is invalid. ID: " .. tostring(win), vim.log.levels.INFO)
-- 			return
-- 		end
-- 		local config = vim.api.nvim_win_get_config(win)
-- 		if type(config) ~= "table" then
-- 			vim.notify(
-- 				"Resize: nvim_win_get_config returned type: "
-- 					.. type(config)
-- 					.. " value: "
-- 					.. tostring(config)
-- 					.. ". ID: "
-- 					.. tostring(win),
-- 				vim.log.levels.ERROR
-- 			)
-- 			return
-- 		end
-- 		config.width = math.max(10, config.width + delta_w)
-- 		config.height = math.max(5, config.height + delta_h)
-- 		vim.api.nvim_win_set_config(win, config) -- Fixed: use 'config' not 'win_config'
-- 	end
--
-- 	vim.keymap.set("n", "<C-Up>", function()
-- 		resize_win(0, -1)
-- 	end, { buffer = buf })
-- 	vim.keymap.set("n", "<C-Down>", function()
-- 		resize_win(0, 1)
-- 	end, { buffer = buf })
-- 	vim.keymap.set("n", "<C-Left>", function()
-- 		resize_win(-1, 0)
-- 	end, { buffer = buf })
-- 	vim.keymap.set("n", "<C-Right>", function()
-- 		resize_win(1, 0)
-- 	end, { buffer = buf })
-- end
--
-- -- 3. You can still create the user command, now referencing the function from M
-- vim.api.nvim_create_user_command("CompileRun", M.compile_and_run, {})
--
-- -- 4. CRUCIAL: Return the module table `M`
-- return M

-- -- File: ~/.config/nvim/lua/configs/compile_run.lua
-- -- NOTE: Put this file in configs/ folder, NOT custom/configs/
--
-- local M = {}
--
-- -- Function to get the appropriate compile/run command based on file extension
-- local function get_run_command(filepath, filename, filetype)
--   local commands = {
--     python = string.format("python3 '%s'", filepath),
--     c = string.format("gcc '%s' -o /tmp/%s_out && /tmp/%s_out", filepath, filename, filename),
--     cpp = string.format("g++ '%s' -o /tmp/%s_out && /tmp/%s_out", filepath, filename, filename),
--     javascript = string.format("node '%s'", filepath),
--     java = string.format("cd '%s' && javac '%s' && java '%s'", 
--            vim.fn.fnamemodify(filepath, ":h"), 
--            vim.fn.fnamemodify(filepath, ":t"), 
--            filename),
--     go = string.format("go run '%s'", filepath),
--     rust = string.format("cd '%s' && rustc '%s' -o /tmp/%s_out && /tmp/%s_out", 
--            vim.fn.fnamemodify(filepath, ":h"), 
--            vim.fn.fnamemodify(filepath, ":t"), 
--            filename, filename),
--     lua = string.format("lua '%s'", filepath),
--     sh = string.format("bash '%s'", filepath),
--     ruby = string.format("ruby '%s'", filepath),
--   }
--
--   return commands[filetype]
-- end
--
-- -- Function to compile and run the current file
-- function M.compile_and_run()
--   local filepath = vim.fn.expand("%:p")
--   local filename = vim.fn.expand("%:t:r")
--   local filetype = vim.bo.filetype
--
--   -- Check if file is saved
--   if vim.bo.modified then
--     vim.cmd("write")
--   end
--
--   -- Check if file exists
--   if filepath == "" or not vim.fn.filereadable(filepath) then
--     vim.notify("No file to run or file doesn't exist!", vim.log.levels.ERROR)
--     return
--   end
--
--   local command = get_run_command(filepath, filename, filetype)
--
--   if not command then
--     vim.notify("Unsupported file type: " .. filetype, vim.log.levels.ERROR)
--     return
--   end
--
--   -- Create the terminal command
--   local term_cmd = string.format(
--     "echo 'Running: %s' && echo '=================' && %s && echo '' && echo 'Press any key to continue...' && read -n 1",
--     filepath,
--     command
--   )
--
--   -- Open in new terminal (works on most Linux systems)
--   local terminal_commands = {
--     -- Try different terminal emulators
--     string.format("gnome-terminal -- bash -c \"%s\"", term_cmd),
--     string.format("konsole -e bash -c \"%s\"", term_cmd),
--     string.format("xterm -e bash -c \"%s\"", term_cmd),
--     string.format("alacritty -e bash -c \"%s\"", term_cmd),
--     string.format("kitty bash -c \"%s\"", term_cmd),
--     string.format("wezterm start bash -c \"%s\"", term_cmd),
--   }
--
--   -- Try each terminal command until one works
--   local success = false
--   for _, cmd in ipairs(terminal_commands) do  -- FIXED: was "*, cmd" should be "_, cmd"
--     if os.execute("command -v " .. cmd:match("^(%S+)") .. " > /dev/null 2>&1") == 0 then
--       os.execute(cmd .. " &")
--       success = true
--       break
--     end
--   end
--
--   if not success then
--     -- Fallback: run in nvim terminal
--     vim.cmd("split")
--     vim.cmd("terminal " .. command)
--     vim.cmd("startinsert")
--   end
-- end
--
-- return M
