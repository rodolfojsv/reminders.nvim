local reminders = {}
local filePath

function InitializeFilePath(directory)
	if not directory:endswith("/") then
		directory = directory .. "/"
	end
	filePath = directory .. "reminders.json"
end

function InitializeRemindersFromFile()
	if FileExists(filePath) then
		reminders = vim.fn.json_decode(ReadAll(filePath))

		-- For old reminders that were poorly designed
		for i = 1, #reminders do
			if reminders[i].remindAt ~= nil then
				reminders[i].remindDate = ConvertToEpoch(reminders[i].remindAt)
				reminders[i].remindAt = nil
			end
		end
	end
end

function AddReminder(reminder)
	if reminder.remindAt ~= nil then
		reminder.remindDate = ConvertToEpoch(reminder.remindAt)
		reminder.remindAt = nil
	end

	if reminder.remindEvery ~= nil then
		CheckForNextExecution(reminder)
	end

	table.insert(reminders, reminder)
	SaveFile()
end

function TimeToShow(reminder)
	return reminder.remindDate <= os.time()
end

function CheckForNextExecution(reminder)
	if reminder.remindEvery ~= nil and reminder.remindDate == nil then
		reminder.remindDate = os.time() + tonumber(reminder.remindEvery) * 60
	end

	if reminder.daily ~= nil and reminder.daily and reminder.remindDate == nil then
		reminder.reminderDate = reminder.reminderDate + 24 * 60 * 60
	end
end

function ProcessTimerCallback()
	local anyWasTriggered = false

	for i = 1, #reminders do
		CheckForNextExecution(reminders[i])

		if TimeToShow(reminders[i]) then
			vim.notify(reminders[i].reminderMsg, vim.log.levels.INFO, {
				title = "Reminders [Index:" .. tostring(i) .. "]",
				timeout = false,
			})

			if not reminders[i].persistent then
				table.remove(reminders, i)
			else
				if reminders[i].remindEvery ~= nil then
					reminders[i].remindDate = nil
					CheckForNextExecution(reminders[i])
					reminders[i].shownAt = os.time()
				end
			end

			anyWasTriggered = true
		end
	end

	if anyWasTriggered then
		SaveFile()
	end

	return anyWasTriggered
end

function SaveFile()
	local file = io.open(filePath, "w")
	io.output(file)
	io.write(vim.fn.json_encode(reminders))
	io.close(file)
end
