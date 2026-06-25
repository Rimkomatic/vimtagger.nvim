local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local themes = require("telescope.themes")

--- Generic Telescope selector.
---@generic T
---@param title string
---@param items T[]
---@param opts? table
---@param callback fun(item: T|nil)
function M.select(title, items, opts, callback)
	opts = opts or {}

	pickers
		.new(themes.get_dropdown(opts.theme or {}), {
			prompt_title = title,
			finder = finders.new_table({
				results = items,
				entry_maker = function(item)
					local display = opts.format_item and opts.format_item(item) or tostring(item)

					return {
						value = item,
						display = display,
						ordinal = display,
					}
				end,
			}),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					local entry = action_state.get_selected_entry()

					actions.close(prompt_bufnr)

					callback(entry and entry.value or nil)
				end)

				return true
			end,
		})
		:find()
end

--- Telescope selector that allows creating a new value.
---@param title string
---@param items string[]
---@param callback fun(value: string|nil)
function M.select_or_create(title, items, callback)
	pickers
		.new(themes.get_dropdown(), {
			prompt_title = title,
			finder = finders.new_table({
				results = items,
			}),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					local picker = action_state.get_current_picker(prompt_bufnr)
					local prompt = picker:_get_prompt()

					local entry = action_state.get_selected_entry()

					actions.close(prompt_bufnr)

					if prompt ~= "" then
						if entry and prompt == entry.value then
							callback(entry.value)
						else
							callback(prompt)
						end
					elseif entry then
						callback(entry.value)
					else
						callback(nil)
					end
				end)

				return true
			end,
		})
		:find()
end

---@param items string[]
---@param on_delete fun(filepath: string)
---@param on_remap fun(filepath: string)
function M.doctor_missing_picker(items, on_delete, on_remap)
	pickers.new(themes.get_dropdown(), {
		prompt_title = "Tag Doctor: <CR> Remap | <C-x> or 'd' to Delete",
		finder = finders.new_table({ results = items }),
		sorter = conf.generic_sorter({}),
		attach_mappings = function(prompt_bufnr, map)
			
			-- ACTION: <CR> (Remap)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				if selection then
					actions.close(prompt_bufnr)
					on_remap(selection.value) 
				end
			end)

			-- We store the delete logic in a local variable so we can assign it to multiple keys
			local do_delete = function()
				local selection = action_state.get_selected_entry()
				if selection then
					actions.close(prompt_bufnr)
					on_delete(selection.value) 
				end
			end

			-- ACTION: <C-x> in Insert mode triggers delete
			map("i", "<C-x>", do_delete)
			
			-- ACTION: 'd' in Normal mode triggers delete
			map("n", "d", do_delete)

			return true
		end,
	}):find()
end

---@param items string[]
---@param on_select fun(new_filepath: string)
function M.doctor_remap_picker(items, on_select)
	pickers.new(themes.get_dropdown(), {
		prompt_title = "Select new file (or choose Delete)",
		finder = finders.new_table({ results = items }),
		sorter = conf.generic_sorter({}),
		attach_mappings = function(prompt_bufnr)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				if selection then
					actions.close(prompt_bufnr)
					on_select(selection.value) 
				end
			end)
			return true
		end,
	}):find()
end

M.setup = function() end

return M
