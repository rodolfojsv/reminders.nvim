local M = {}

function M.get_user_input(prompt)
	local response = ""
	vim.ui.input({ prompt = prompt }, function(res)
		if res == nil then
			return
		end

		response = res
	end)
	return response
end

function M.trim(s)
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function M.split(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
		table.insert(t, str)
	end
	return t
end

function M.endswith(s, ending)
	return ending == "" or s:sub(-#ending) == ending
end

function M.read_all(file)
	local f = assert(io.open(file, "rb"))
	local content = f:read("*all")
	f:close()
	return content
end

function M.file_exists(name)
	local f = io.open(name, "r")
	if f ~= nil then
		io.close(f)
		return true
	else
		return false
	end
end

function M.convert_to_epoch(remindAt)
	local currentDate = os.date("*t")

	local hm = M.split(remindAt, ":")
	local reminderHour = tonumber(hm[1])
	local reminderMin = tonumber(hm[2])
	local epoch = os.time({
		year = currentDate.year,
		month = currentDate.month,
		day = currentDate.day,
		hour = reminderHour,
		min = reminderMin,
	})
	if epoch <= os.time() then
		epoch = epoch + 86400
	end
	return epoch
end

--- Parse category from a reminder message string.
--- If the message starts with a known category followed by " - ", extract it.
--- Otherwise returns the default category and the original message.
---@param text string
---@param default_category string
---@return string category, string message
function M.parse_category(text, default_category)
	local known = { work = true, personal = true }
	local cat, msg = text:match("^(%w+) %- (.+)$")
	if cat and known[cat:lower()] then
		return cat:lower(), msg
	end
	return default_category, text
end

return M
