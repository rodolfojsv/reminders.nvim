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
	end
end

function AddReminder(reminder)
	local currentDate = os.date("*t")
	local reminderDate = tostring(currentDate.year)
		.. "-"
		.. tostring(currentDate.month)
		.. "-"
		.. tostring(currentDate.day)
		.. "Z"
		.. reminder.remindAt

	if not reminder.remindEvery == nil then
		CheckForNextExecution(reminder)
	end
	table.insert(reminders, reminder)

	SaveFile()
end

function TimeToShow(reminder)
	local currentDate = os.date("*t")

	local hm = Split(reminder.remindAt, ":")

	local reminderHour = tonumber(hm[1])
	local reminderMin = tonumber(hm[2])

	local hasNotShownToday = reminder.shownAt == nil
		or (not reminder.shownAt == nil and reminder.shownAt < currentDate.day)
	return ((currentDate.hour == reminderHour and currentDate.min >= reminderMin) or currentDate.hour > reminderHour)
		and (hasNotShownToday or reminder.remindEvery ~= nil)
end

function CheckForNextExecution(reminder)
	if reminder.remindEvery == nil then
		return
	end

	local currentDate = os.date("*t")
	if reminder.remindAt == nil then
		local minutesToDisplay = currentDate.min + tonumber(reminder.remindEvery)
		local hour = currentDate.hour

		while minutesToDisplay >= 60 do
			hour = hour + 1
			minutesToDisplay = minutesToDisplay - 60
		end

		if minutesToDisplay <= 9 and minutesToDisplay >= 0 then
			reminder.remindAt = tostring(hour) .. ":0" .. tostring(minutesToDisplay)
		else
			reminder.remindAt = tostring(hour) .. ":" .. tostring(minutesToDisplay)
		end
	end
end

function ProcessTimerCallback()
	local anyWasTriggered = false

	for i = 1, #reminders do
		CheckForNextExecution(reminders[i])

		if TimeToShow(reminders[i]) then
			vim.notify(reminders[i].reminderMsg, vim.log.levels.INFO, {
				title = "Reminders",
				timeout = false,
				on_close = function() end,
			})

			local currentDate = os.date("*t")

			if not reminders[i].persistent then
				table.remove(reminders, i)
			else
				if reminders[i].remindEvery ~= nil then
					reminders[i].remindAt = nil
					CheckForNextExecution(reminders[i])
					reminders[i].shownAt = currentDate.day
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
