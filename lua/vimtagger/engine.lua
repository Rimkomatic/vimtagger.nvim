local state = require("vimtagger.state")
local plugin_opts = {}
local ui = require("vimtagger.ui")

local add_tag = function(tagname)
	local filename = vim.api.nvim_buf_get_name(0)

	if require("vimtagger").is_vimtagger_initiated() and next(state.get_state().forward) == nil then
		state.read_state()
	end

	if not state.state.forward[filename] then
		state.state.forward[filename] = {}
	end

	if not state.state.inverted[tagname] then
		state.state.inverted[tagname] = {}
	end

	state.state.forward[filename][tagname] = true
	state.state.inverted[tagname][filename] = true
	state.dump_state()
end

-- TODO:
local remove_tag = function(tagname)
	if plugin_opts.is_vimtagger_initiated() and next(state.get_state().forward) == nil then
		state.read_state()
	end

	local filename = vim.api.nvim_buf_get_name(0)
	local current_state = state.get_state()

	if not current_state.forward[filename] or not current_state.forward[filename][tagname] then
		print("Tag '" .. tagname .. "' not found on current file.")
		return
	end

	current_state.forward[filename][tagname] = nil
	current_state.inverted[tagname][filename] = nil

	if next(current_state.forward[filename]) == nil then
		current_state.forward[filename] = nil
	end

	if next(current_state.inverted[tagname]) == nil then
		current_state.inverted[tagname] = nil
	end

	state.dump_state()
	print("Removed tag: " .. tagname)
end

local get_all_project_tags = function()
	local current_state = state.get_state()
	local all_tags = {}

	for tag, _ in pairs(current_state.inverted) do
		table.insert(all_tags, tag)
	end

	table.sort(all_tags)
	return all_tags
end

local get_current_file_tags = function()
	local current_state = state.get_state()
	local filename = vim.api.nvim_buf_get_name(0)
	local file_tags = {}

	if current_state.forward[filename] then
		for tag, _ in pairs(current_state.forward[filename]) do
			table.insert(file_tags, tag)
		end
	end

	table.sort(file_tags)
	return file_tags
end

local get_available_tags_for_file = function()
	local current_state = state.get_state()
	local filename = vim.api.nvim_buf_get_name(0)
	local available_tags = {}

	for tag, _ in pairs(current_state.inverted) do
		if not current_state.forward[filename] or not current_state.forward[filename][tag] then
			table.insert(available_tags, tag)
		end
	end

	table.sort(available_tags)
	return available_tags
end

local M = {}

M.setup = function(opts)
	plugin_opts = opts

	vim.api.nvim_create_user_command("ReadTaggerfile", function()
		if opts.is_vimtagger_initiated() then
			state.read_state()
			print(vim.inspect(state.get_state()))
		else
			print("vimtagger not initiaded")
		end
	end, {})

	vim.api.nvim_create_user_command("TagAdd", function()
		if not opts.is_vimtagger_initiated() then
			print("vimtagger not initiated")
			return
		end
		if next(state.get_state().forward) == nil then
			state.read_state()
		end
		local available_tags = get_available_tags_for_file()

		ui.select_or_create("Add Tag", available_tags, function(selected_tag)
			if selected_tag and selected_tag ~= "" then
				add_tag(selected_tag)
			end
		end)
	end, {})

	vim.api.nvim_create_user_command("TagRemove", function()
		if not opts.is_vimtagger_initiated() then
			print("vimtagger not initiated")
			return
		end

		if next(state.get_state().forward) == nil then
			state.read_state()
		end

		local file_tags = get_current_file_tags()

		if #file_tags == 0 then
			print("No tags to remove on current file.")
			return
		end

		ui.select("Remove Tag", file_tags, {}, function(selected_tag)
			if selected_tag then
				remove_tag(selected_tag)
			end
		end)
	end, {})
end

return M
