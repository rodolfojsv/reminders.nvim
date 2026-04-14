--- Test helper: provides utilities shared across test files.
--- Loaded by each spec file before tests run.

local H = {}

--- Create a temporary directory for test JSON files.
--- Returns the path (with trailing separator).
function H.tmp_dir()
	local dir = vim.fn.tempname() .. "_reminders_test"
	vim.fn.mkdir(dir, "p")
	return dir
end

--- Remove a directory tree.
function H.rm_dir(dir)
	if dir and vim.fn.isdirectory(dir) == 1 then
		vim.fn.delete(dir, "rf")
	end
end

--- Write a JSON file at the given path.
function H.write_json(path, data)
	local file = io.open(path, "w")
	if file then
		file:write(vim.fn.json_encode(data))
		file:close()
	end
end

--- Read and decode a JSON file.
function H.read_json(path)
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local content = f:read("*all")
	f:close()
	return vim.fn.json_decode(content)
end

--- Reset all cached modules so tests get fresh state.
function H.reset_modules()
	package.loaded["reminders"] = nil
	package.loaded["reminders.config"] = nil
	package.loaded["reminders.processor"] = nil
	package.loaded["reminders.utils"] = nil
	package.loaded["reminders.commands"] = nil
	package.loaded["reminders.picker"] = nil
	package.loaded["reminders.briefing"] = nil
	package.loaded["reminders.jira"] = nil
end

return H
