local utils = require("reminders.utils")

local M = {}
local reminders = {}
local filePath

function M.initialize_file_path(directory)
	if not utils.endswith(directory, "/") and not utils.endswith(directory, "\\") then
		directory = directory .. "/"
	end
	filePath = directory .. "reminders.json"
end

function M.initialize_reminders_from_file(default_category)
	if utils.file_exists(filePath) then
		reminders = vim.fn.json_decode(utils.read_all(filePath))
		for i = 1, #reminders do
			-- Migrate old schema: remindAt → reminderDate
			if reminders[i].reminderDate == nil then
				if reminders[i].remindAt ~= nil then
					reminders[i].reminderDate = utils.convert_to_epoch(reminders[i].remindAt)
					reminders[i].shownAt = reminders[i].reminderDate - 60
					reminders[i].remindAt = nil
				end
			end
			if reminders[i].index == nil then
				reminders[i].index = i
			end
			-- Migrate: add category if missing
			if reminders[i].category == nil then
				reminders[i].category = default_category or "personal"
			end
		end
	end
end

function M.add_reminder(reminder)
	if reminder.remindAt ~= nil then
		reminder.reminderDate = utils.convert_to_epoch(reminder.remindAt)
		reminder.shownAt = reminder.reminderDate - 60
		reminder.remindAt = nil
	end

	if reminder.remindEvery ~= nil then
		M.check_for_next_execution(reminder)
	end

	if reminder.remindIn ~= nil then
		reminder.reminderDate = os.time() + tonumber(reminder.remindIn) * 60
		reminder.shownAt = reminder.reminderDate - 60
		reminder.remindIn = nil
	end

	reminder.category = reminder.category or "personal"
	reminder.index = #reminders + 1
	table.insert(reminders, reminder)
	M.save_file()
end

function M.remove_reminder(index)
	if reminders[index] and reminders[index].index == index then
		table.remove(reminders, index)
	else
		for i = 1, #reminders do
			if reminders[i].index == index then
				table.remove(reminders, i)
				break
			end
		end
	end
	M.save_file()
end

function M.remove_all_reminders()
	reminders = {}
	M.save_file()
end

function M.get_reminders()
	return reminders
end

function M.time_to_show(reminder)
	return reminder.reminderDate ~= nil and reminder.reminderDate <= os.time()
end

function M.check_for_next_execution(reminder)
	if reminder.reminderDate == nil and reminder.remindEvery == nil then
		return
	end

	if
		reminder.remindEvery ~= nil and (reminder.reminderDate == nil or (reminder.shownAt >= reminder.reminderDate))
	then
		reminder.reminderDate = os.time() + tonumber(reminder.remindEvery) * 60
		if reminder.shownAt == nil then
			reminder.shownAt = os.time()
		end
	end

	if
		reminder.daily ~= nil
		and reminder.daily
		and (reminder.reminderDate == nil or (reminder.shownAt >= reminder.reminderDate))
	then
		reminder.reminderDate = reminder.reminderDate + 24 * 60 * 60

		while reminder.reminderDate < os.time() do
			reminder.reminderDate = reminder.reminderDate + 24 * 60 * 60
		end

		if reminder.shownAt == nil then
			reminder.shownAt = os.time()
		end
	end

	M.save_file()
end

function M.process_timer_callback()
	local anyWasTriggered = false

	for i = #reminders, 1, -1 do
		if M.time_to_show(reminders[i]) then
			vim.notify(reminders[i].reminderMsg, vim.log.levels.INFO, {
				title = "Reminders [Index:" .. tostring(i) .. "]",
				timeout = false,
			})

			if not reminders[i].persistent then
				table.remove(reminders, i)
			else
				reminders[i].shownAt = os.time()
				M.check_for_next_execution(reminders[i])
			end

			anyWasTriggered = true
		end
	end

	if anyWasTriggered then
		M.save_file()
	end

	return anyWasTriggered
end

function M.save_file()
	local file = io.open(filePath, "w")
	if file then
		io.output(file)
		io.write(vim.fn.json_encode(reminders))
		io.close(file)
	end
end

return M
