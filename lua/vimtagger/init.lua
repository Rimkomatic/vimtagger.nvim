local M = {}

M.config = {
	directory = vim.fn.stdpath("data") .. "/vimtagger",
}

function M.get_file()
	return M.config.directory .. "/" .. vim.fn.sha256(vim.fn.getcwd()) .. ".json"
end

M.is_vimtagger_initiated = function()
	return vim.uv.fs_stat(M.get_file()) ~= nil
end

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	if M.is_vimtagger_initiated() then
		require("vimtagger.state").read_state()
	end

	require("vimtagger.state").setup()
	require("vimtagger.ui").setup()
	require("vimtagger.filesystem").setup()
	require("vimtagger.engine").setup({
		is_vimtagger_initiated = M.is_vimtagger_initiated,
	})
	require("vimtagger.tagdoctor").setup({
		is_vimtagger_initiated = M.is_vimtagger_initiated,
	})
	require("vimtagger.search").setup({
		is_vimtagger_initiated = M.is_vimtagger_initiated,
	})

	require("vimtagger.panel").setup({
		is_vimtagger_initiated = function()
			return true
		end,
	})
end

return M
