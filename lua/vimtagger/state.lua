local vimtagger = require("vimtagger")

local M = {}

M.dump_state = function()
	local json = vim.json.encode(M.state.forward)

	vim.fn.writefile({ json }, vimtagger.get_file())
end

M.read_state = function()
	local content = table.concat(vim.fn.readfile(vimtagger.get_file()), "\n")

	local ok, decoded = pcall(vim.json.decode, content)

	if ok and decoded then
		M.state.forward = decoded
		M.state.inverted = M.build_inverted(M.state.forward)
	else
		M.state.forward = {}
		M.state.inverted = {}
	end
end

M.build_inverted = function(forward)
	local inverted = {}

	if not forward then
		return inverted
	end

	for filepath, tags in pairs(forward) do
		for tag, _ in pairs(tags) do
			if not inverted[tag] then
				inverted[tag] = {}
			end
			inverted[tag][filepath] = true
		end
	end

	return inverted
end

M.state = {
	forward = {},
	inverted = {},
}

M.get_state = function()
	return M.state
end

M.set_state = function(new_state)
	M.state = new_state
	M.dump_state()
end

M.setup = function() end

return M
