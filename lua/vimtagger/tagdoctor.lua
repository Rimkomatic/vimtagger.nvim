local state = require("vimtagger.state")
local ui = require("vimtagger.ui")

local plugin_opts = {}

local run_silent_diagnostic = function()
	local current_state = state.get_state()
	local missing_count = 0

	for filepath, _ in pairs(current_state.forward) do
		if not vim.uv.fs_stat(filepath) then
			missing_count = missing_count + 1
		end
	end

	if missing_count > 0 then
		vim.notify(
			"Vimtagger: " .. missing_count .. " orphaned files detected. Run :TagDoctor to resolve.",
			vim.log.levels.WARN
		)
	end
end

local open_doctor_ui

local delete_orphaned_file = function(filepath)
	local current_state = state.get_state()
	local tags = current_state.forward[filepath]

	if not tags then
		return
	end

	for tag, _ in pairs(tags) do
		current_state.inverted[tag][filepath] = nil
		if next(current_state.inverted[tag]) == nil then
			current_state.inverted[tag] = nil
		end
	end

	current_state.forward[filepath] = nil
	state.dump_state()
	print("Vimtagger: Purged " .. filepath)

	vim.schedule(open_doctor_ui)
end

local open_remap_picker = function(old_filepath)
	local all_files = vim.fn.systemlist("git ls-files --cached --others --exclude-standard")
	if vim.v.shell_error ~= 0 then
		all_files = vim.fn.systemlist("find . -type f -not -path '*/\\.git/*'")
	end

	local untagged_files = {}
	local DELETE_OPTION = "[ DELETE THESE ORPHANED TAGS ]"
	table.insert(untagged_files, DELETE_OPTION)

	local current_state = state.get_state()

	for _, file in ipairs(all_files) do
		local abs_path = vim.fn.fnamemodify(file, ":p")

		local real_path = vim.uv.fs_realpath(abs_path)

		if real_path and not current_state.forward[real_path] then
			table.insert(untagged_files, real_path)
		end
	end

	ui.doctor_remap_picker(untagged_files, function(selected_value)
		if selected_value == DELETE_OPTION then
			delete_orphaned_file(old_filepath)
			return
		end

		local new_filepath = selected_value

		current_state.forward[new_filepath] = current_state.forward[old_filepath]
		current_state.forward[old_filepath] = nil

		for tag, _ in pairs(current_state.forward[new_filepath]) do
			current_state.inverted[tag][old_filepath] = nil
			current_state.inverted[tag][new_filepath] = true
		end

		state.dump_state()
		print("Vimtagger: Remapped tags to " .. vim.fn.fnamemodify(new_filepath, ":t"))

		vim.schedule(open_doctor_ui)
	end)
end

open_doctor_ui = function()
	local current_state = state.get_state()
	local missing_files = {}

	for filepath, _ in pairs(current_state.forward) do
		if not vim.uv.fs_stat(filepath) then
			table.insert(missing_files, filepath)
		end
	end

	if #missing_files == 0 then
		print("Vimtagger: All orphaned files resolved!")
		return
	end

	ui.doctor_missing_picker(missing_files, delete_orphaned_file, open_remap_picker)
end

local M = {}

M.setup = function(opts)
	plugin_opts = opts or {}

	vim.api.nvim_create_user_command("TagDoctor", function()
		if plugin_opts.is_vimtagger_initiated() then
			open_doctor_ui()
		end
	end, {})

	vim.api.nvim_create_autocmd("VimEnter", {
		callback = function()
			vim.defer_fn(function()
				if plugin_opts.is_vimtagger_initiated() and next(state.state.forward) ~= nil then
					run_silent_diagnostic()
				end
			end, 1000)
		end,
	})
end

return M
