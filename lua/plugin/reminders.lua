vim.api.nvim_create_user_command("RemindMeEvery", function(opts)
	local minutes = Trim(opts.args)
	if minutes == "" then
		return
	end

	local reminderText = GetUserInput("What is the reminder: ")

	if reminderText == "" then
		return
	end

	local reminder = { reminderMsg = reminderText, remindEvery = minutes, persistent = true, daily = false }

	AddReminder(reminder)

	print("\nAdded to your reminders every " .. minutes .. " minutes")
end, { nargs = "?" })

vim.api.nvim_create_user_command("RemindMeDailyAt", function(opts)
	local hour = Trim(opts.args)
	if hour == "" then
		return
	end
	-- if the parameter does not contain : then we add 00
	if not string.find(opts.args, ":") then
		hour = hour .. ":00"
	end

	local reminderText = GetUserInput("What is the reminder: ")

	if reminderText == "" then
		return
	end
	local reminder = { reminderMsg = reminderText, remindAt = hour, persistent = true, daily = true }

	AddReminder(reminder)

	print("\nAdded to your daily reminders")
end, { nargs = "?" })

vim.api.nvim_create_user_command("RemindMeAt", function(opts)
	local hour = Trim(opts.args)
	if hour == "" then
		return
	end
	-- if the parameter does not contain : then we add 00
	if not string.find(opts.args, ":") then
		hour = hour .. ":00"
	end

	local reminderText = GetUserInput("What is the reminder: ")

	if reminderText == "" then
		return
	end
	local reminder = { reminderMsg = reminderText, remindAt = hour, persistent = false }

	AddReminder(reminder)

	print("\nAdded to your reminders")
end, { nargs = "?" })

vim.api.nvim_create_user_command("ReminderClose", function()
	if HasNotify() then
		require("notify").dismiss()
		RestartTimer()
	end
end, { desc = "Close notification" })

vim.api.nvim_create_user_command("ReminderRemoveAt", function(opts)
	local index = Trim(opts.args)
	if index == "" or index == nil then
		return
	end
	RemoveReminder(tonumber(index))
end, { desc = "Remove reminder at index", nargs = "?" })

vim.api.nvim_create_user_command("ReminderRemoveAll", function()
	RemoveAllReminders()
end, { desc = "Remove reminder at index" })
