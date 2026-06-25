local vimtagger = require("vimtagger")

local create_file = function(path)
	if vim.uv.fs_stat(path) then
		print("file exists")
	else
		vim.fn.writefile("", path, "b")
	end
end

local get_encoded_filename = function()
	return vim.fn.sha256(vim.fn.getcwd())
end

local init_dir = function()
	if vim.uv.fs_stat(vimtagger.config.directory) ~= nil then
		if vimtagger.is_vimtagger_initiated() then
			print("Already a vimtagger directory")
		else
			create_file(vimtagger.get_file())
			print("Initiaded vimtagger")
		end
	else
		vim.uv.fs_mkdir(vimtagger.config.directory, tonumber("755", 8))
		create_file(vimtagger.get_file())
		print("Initiaded vimtagger")
	end

	return false
end

local delete_dir = function()
	if vimtagger.is_vimtagger_initiated() then
		if vim.uv.fs_stat(vimtagger.get_file()) ~= nil then
			vim.uv.fs_unlink(vimtagger.get_file())
			print("Deleted Tags")
		else
			print("Not a vimtagger directory")
		end
	else
		print("Not a vimtagger directory")
	end

	return false
end

local M = {}

function M.hello()
	print("Hello from my plugin!")
end

M.setup = function()
	vim.api.nvim_create_user_command("GetSHA", function()
		print(get_encoded_filename())
	end, {})

	vim.api.nvim_create_user_command("VimtaggerInit", function()
		init_dir()
	end, {})

	vim.api.nvim_create_user_command("VimtaggerDelete", function()
		delete_dir()
	end, {})

	vim.api.nvim_create_user_command("CheckFile", function(opts)
		create_file(opts.args)
	end, {
		nargs = 1,
	})
end

return M
