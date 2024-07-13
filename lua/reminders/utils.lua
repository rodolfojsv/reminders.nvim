function GetUserInput()
	local response = ""
	vim.ui.input({ prompt = "What is the reminder: " }, function(res)
		if res == nil then
			return
		end

		response = res
	end)
	return response
end

function Trim(s)
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function Split(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
		table.insert(t, str)
	end
	return t
end

function string:endswith(ending)
	return ending == "" or self:sub(-#ending) == ending
end

function ReadAll(file)
	local f = assert(io.open(file, "rb"))
	local content = f:read("*all")
	f:close()
	return content
end

function FileExists(name)
	local f = io.open(name, "r")
	if f ~= nil then
		io.close(f)
		return true
	else
		return false
	end
end