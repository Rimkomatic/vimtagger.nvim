local state = require("vimtagger.state")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values

local M = {}

M.search_tagged_files = function()
	local current_state = state.get_state()
	local results = {}

	for filepath, _ in pairs(current_state.forward) do
		table.insert(results, filepath)
	end

	if #results == 0 then
		print("Vimtagger: No tagged files found.")
		return
	end

	pickers
		.new({}, {
			prompt_title = "Search Tags (Format: ##tagname  phrase)",
			finder = finders.new_table({
				results = results,
				entry_maker = function(filepath)
					local tags = current_state.forward[filepath]

					local tag_list = {}
					local hash_tag_list = {}

					for tag, _ in pairs(tags) do
						table.insert(tag_list, tag)
						table.insert(hash_tag_list, tag)
					end
					table.sort(tag_list)

					local tag_prefix = "[" .. table.concat(tag_list, ", ") .. "]"
					local file_suffix = " " .. vim.fn.fnamemodify(filepath, ":.")

					local display_str = tag_prefix .. file_suffix
					local ordinal_str = table.concat(hash_tag_list, " ") .. "  " .. filepath

					return {
						value = filepath,
						display = function()
							return display_str, {
								{ { 0, #tag_prefix }, "TelescopeResultsIdentifier" },
							}
						end,
						ordinal = ordinal_str,
						path = filepath,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			previewer = conf.file_previewer({}),
		})
		:find()
end

M.setup = function(opts)
	local plugin_opts = opts or {}

	vim.api.nvim_create_autocmd("FileType", {
		pattern = "TelescopePrompt",
		callback = function()
			vim.fn.matchadd("TelescopeResultsIdentifier", [[##\S\+]])
		end,
	})

	vim.api.nvim_create_user_command("TagSearch", function()
		if plugin_opts.is_vimtagger_initiated() then
			M.search_tagged_files()
		else
			print("vimtagger not initiated")
		end
	end, {})
end

return M
