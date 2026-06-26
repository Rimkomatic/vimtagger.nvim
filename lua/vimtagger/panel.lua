local state = require("vimtagger.state")

local M = {}

local bufnr = nil
local winid = nil
local line_map = {}

local current_tab = 1
local show_help = false

local function set_block_hl(new_group, target_group, fallback_group)
	local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = target_group, link = false })
	if ok and hl and hl.fg then
		local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
		local bg = normal.bg or 0x1e1e2e
		vim.api.nvim_set_hl(0, new_group, { fg = bg, bg = hl.fg, default = true })
	else
		vim.api.nvim_set_hl(0, new_group, { link = fallback_group, default = true })
	end
end

local function setup_highlights()
	set_block_hl("VimtaggerHeader", "Keyword", "IncSearch")
	set_block_hl("VimtaggerTabActive", "String", "PmenuSel")

	vim.api.nvim_set_hl(0, "VimtaggerTabInactive", { link = "Comment", default = true })
	vim.api.nvim_set_hl(0, "VimtaggerKey", { link = "Special", default = true })
	vim.api.nvim_set_hl(0, "VimtaggerLink", { link = "Comment", italic = true, default = true })
	vim.api.nvim_set_hl(0, "VimtaggerTree", { link = "Comment", default = true })
	vim.api.nvim_set_hl(0, "VimtaggerIconTag", { link = "Statement", default = true })
	vim.api.nvim_set_hl(0, "VimtaggerIconFile", { link = "String", default = true })
	vim.api.nvim_set_hl(0, "VimtaggerText", { link = "Normal", default = true })
	vim.api.nvim_set_hl(0, "VimtaggerMuted", { link = "Comment", default = true })
end

local function get_window_opts()
	local screen_w = vim.o.columns
	local screen_h = vim.o.lines
	local width = math.floor(screen_w * 0.75)
	local height = math.floor(screen_h * 0.75)
	local row = math.floor((screen_h - height) / 2)
	local col = math.floor((screen_w - width) / 2)

	return {
		relative = "editor",
		row = row,
		col = col,
		width = width,
		height = height,
		style = "minimal",
		border = "none",
	}
end

local function remove_link(filepath, tagname)
	local current_state = state.get_state()

	if current_state.forward[filepath] then
		current_state.forward[filepath][tagname] = nil
		if next(current_state.forward[filepath]) == nil then
			current_state.forward[filepath] = nil
		end
	end

	if current_state.inverted[tagname] then
		current_state.inverted[tagname][filepath] = nil
		if next(current_state.inverted[tagname]) == nil then
			current_state.inverted[tagname] = nil
		end
	end
end

local function render()
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	vim.bo[bufnr].modifiable = true

	local current_state = state.get_state()
	local lines_text = {}
	local lines_hls = {}
	line_map = {}

	local win_width = vim.api.nvim_win_get_width(winid)

	local function add_line(chunks, meta)
		local full_text = ""
		local hls = {}
		for _, chunk in ipairs(chunks) do
			local text, hl = chunk[1], chunk[2]
			local start_col = #full_text
			full_text = full_text .. text
			if hl then
				table.insert(hls, { hl_group = hl, start_col = start_col, end_col = #full_text })
			end
		end
		table.insert(lines_text, full_text)
		local row = #lines_text
		lines_hls[row] = hls
		if meta then
			line_map[row] = meta
		end
	end

	local function add_centered_line(chunks)
		local len = 0
		for _, chunk in ipairs(chunks) do
			len = len + vim.fn.strdisplaywidth(chunk[1])
		end
		local pad = math.floor((win_width - len) / 2)

		local padded_chunks = {}
		if pad > 0 then
			table.insert(padded_chunks, { string.rep(" ", pad), "Normal" })
		end
		for _, chunk in ipairs(chunks) do
			table.insert(padded_chunks, chunk)
		end

		add_line(padded_chunks)
	end

	add_line({ { "", "" } })
	add_centered_line({ { " vimtagger.nvim ", "VimtaggerHeader" } })
	add_centered_line({ { "press ", "VimtaggerMuted" }, { "g?", "VimtaggerKey" }, { " for help", "VimtaggerMuted" } })
	add_line({ { "", "" } })

	local t1_hl = current_tab == 1 and "VimtaggerTabActive" or "VimtaggerTabInactive"
	local t2_hl = current_tab == 2 and "VimtaggerTabActive" or "VimtaggerTabInactive"

	add_line({
		{ "  " },
		{ " (1) Files ", t1_hl },
		{ " " },
		{ " (2) Tags ", t2_hl },
	})
	add_line({ { "", "" } })

	if show_help then
		add_line({ { "  Help Menu", "VimtaggerTabActive" } })
		add_line({ { "  d", "VimtaggerKey" }, { "  Delete the item under the cursor", "VimtaggerText" } })
		add_line({ { "  e", "VimtaggerKey" }, { "  Rename the tag under the cursor", "VimtaggerText" } })
		add_line({ { "  1", "VimtaggerKey" }, { "  Switch to Files view", "VimtaggerText" } })
		add_line({ { "  2", "VimtaggerKey" }, { "  Switch to Tags view", "VimtaggerText" } })
		add_line({ { "  q", "VimtaggerKey" }, { "  Close the manager", "VimtaggerText" } })
		add_line({ { "  g?", "VimtaggerKey" }, { " Toggle this help menu", "VimtaggerText" } })
	elseif current_tab == 1 then
		local files = {}
		for filepath, _ in pairs(current_state.forward) do
			table.insert(files, filepath)
		end
		table.sort(files)

		if #files == 0 then
			add_line({ { "  (No files tracked)", "VimtaggerMuted" } })
		else
			for _, filepath in ipairs(files) do
				local file_tags = {}
				for tag, _ in pairs(current_state.forward[filepath]) do
					table.insert(file_tags, tag)
				end
				table.sort(file_tags)

				local filename = vim.fn.fnamemodify(filepath, ":t")
				local rel_dir = vim.fn.fnamemodify(filepath, ":.:h")
				if rel_dir == "." then
					rel_dir = ""
				else
					rel_dir = rel_dir .. "/"
				end

				add_line({
					{ "   ", "VimtaggerIconFile" },
					{ rel_dir, "VimtaggerMuted" },
					{ filename, "VimtaggerText" },
				}, { type = "file", path = filepath })

				for i, tag in ipairs(file_tags) do
					local tree_char = (i == #file_tags) and "└─ " or "├─ "
					add_line({
						{ "    " .. tree_char, "VimtaggerTree" },
						{ "󰓹 ", "VimtaggerIconTag" },
						{ tag, "VimtaggerText" },
					}, { type = "tag_from_file", path = filepath, tag = tag })
				end
			end
		end
	elseif current_tab == 2 then
		local tags = {}
		for tag, _ in pairs(current_state.inverted) do
			table.insert(tags, tag)
		end
		table.sort(tags)

		if #tags == 0 then
			add_line({ { "  (No tags exist)", "VimtaggerMuted" } })
		else
			for _, tag in ipairs(tags) do
				local tag_files = {}
				for filepath, _ in pairs(current_state.inverted[tag]) do
					table.insert(tag_files, filepath)
				end
				table.sort(tag_files)

				add_line({
					{ "  󰓹 ", "VimtaggerIconTag" },
					{ tag, "VimtaggerText" },
					{ " (" .. #tag_files .. ")", "VimtaggerMuted" },
				}, { type = "tag", tag = tag })

				for i, filepath in ipairs(tag_files) do
					local tree_char = (i == #tag_files) and "└─ " or "├─ "
					local filename = vim.fn.fnamemodify(filepath, ":t")

					add_line({
						{ "    " .. tree_char, "VimtaggerTree" },
						{ " ", "VimtaggerIconFile" },
						{ filename, "VimtaggerText" },
					}, { type = "file_from_tag", path = filepath, tag = tag })
				end
			end
		end
	end

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines_text)
	local ns_id = vim.api.nvim_create_namespace("vimtagger_ui")
	vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

	for row, hls in pairs(lines_hls) do
		for _, hl in ipairs(hls) do
			vim.api.nvim_buf_add_highlight(bufnr, ns_id, hl.hl_group, row - 1, hl.start_col, hl.end_col)
		end
	end

	vim.bo[bufnr].modifiable = false
end

local function handle_rename()
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
	local item = line_map[cursor_line]

	if not item then
		return
	end

	local old_tag = nil
	if item.type == "tag" or item.type == "tag_from_file" then
		old_tag = item.tag
	else
		print("Vimtagger: Please place your cursor on a tag to rename it.")
		return
	end

	-- Prompt the user for the new tag name
	vim.ui.input({ prompt = "Rename tag '" .. old_tag .. "' to: " }, function(new_tag)
		-- Validate input
		if not new_tag or new_tag == "" or new_tag == old_tag then
			return
		end

		local current_state = state.get_state()

		if not current_state.inverted[new_tag] then
			current_state.inverted[new_tag] = {}
		end

		local linked_files = current_state.inverted[old_tag] or {}
		for filepath, _ in pairs(linked_files) do
			if current_state.forward[filepath] then
				current_state.forward[filepath][old_tag] = nil
				current_state.forward[filepath][new_tag] = true
			end
			current_state.inverted[new_tag][filepath] = true
		end

		current_state.inverted[old_tag] = nil

		state.dump_state()
		print("Vimtagger: Renamed tag '" .. old_tag .. "' to '" .. new_tag .. "'")

		vim.schedule(render)
	end)
end

local function handle_delete()
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
	local item = line_map[cursor_line]

	if not item then
		return
	end

	local current_state = state.get_state()

	if item.type == "file" then
		local file_tags = current_state.forward[item.path] or {}
		current_state.forward[item.path] = nil
		for tag, _ in pairs(file_tags) do
			if current_state.inverted[tag] then
				current_state.inverted[tag][item.path] = nil
				if next(current_state.inverted[tag]) == nil then
					current_state.inverted[tag] = nil
				end
			end
		end
		print("Vimtagger: Purged file " .. vim.fn.fnamemodify(item.path, ":t"))
	elseif item.type == "tag" then
		current_state.inverted[item.tag] = nil
		for filepath, file_tags in pairs(current_state.forward) do
			file_tags[item.tag] = nil
			if next(file_tags) == nil then
				current_state.forward[filepath] = nil
			end
		end
		print("Vimtagger: Purged tag '" .. item.tag .. "'")
	elseif item.type == "tag_from_file" or item.type == "file_from_tag" then
		remove_link(item.path, item.tag)
		print("Vimtagger: Unlinked '" .. item.tag .. "' from " .. vim.fn.fnamemodify(item.path, ":t"))
	end

	state.dump_state()
	render()
end

M.toggle_pane = function()
	if winid and vim.api.nvim_win_is_valid(winid) then
		vim.api.nvim_win_close(winid, true)
		return
	end

	if next(state.get_state().forward) == nil then
		state.read_state()
	end

	setup_highlights()

	bufnr = vim.api.nvim_create_buf(false, true)

	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].filetype = "vimtagger"

	winid = vim.api.nvim_open_win(bufnr, true, get_window_opts())

	vim.wo[winid].wrap = false
	vim.wo[winid].cursorline = true
	vim.wo[winid].number = false
	vim.wo[winid].relativenumber = false
	vim.wo[winid].signcolumn = "no"

	local map_opts = { buffer = bufnr, silent = true, noremap = true }
	vim.keymap.set("n", "q", ":close<CR>", map_opts)
	vim.keymap.set("n", "<Esc>", ":close<CR>", map_opts)

	vim.keymap.set("n", "d", handle_delete, map_opts)
	vim.keymap.set("n", "e", handle_rename, map_opts)

	vim.keymap.set("n", "1", function()
		current_tab = 1
		show_help = false
		render()
	end, map_opts)
	vim.keymap.set("n", "2", function()
		current_tab = 2
		show_help = false
		render()
	end, map_opts)
	vim.keymap.set("n", "g?", function()
		show_help = not show_help
		render()
	end, map_opts)

	render()
end

M.setup = function(opts)
	local plugin_opts = opts or {}

	vim.api.nvim_create_user_command("TagTogglePane", function()
		if plugin_opts.is_vimtagger_initiated() then
			M.toggle_pane()
		else
			print("vimtagger not initiated")
		end
	end, {})
end

return M
