require("reminders.processor")
require("reminders.utils")
local reminders = {}
function reminders.setup(options)
	options = options or {}
	options.minute_interval = (options.minute_interval or 1) * 60 * 1000
	options.directory_path = options.directory_path

	InitializeFilePath(options.directory_path)

	InitializeRemindersFromFile()

	local timer = vim.loop.new_timer()

	local has_notify, notify = pcall(require, "notify")

	if has_notify then
		vim.notify = notify
	end

	local function on_timer()
		ProcessTimerCallback()
	end

	timer:start(options.minute_interval, options.minute_interval, vim.schedule_wrap(on_timer))

	vim.api.nvim_create_user_command("RemindMeEvery", function(opts)
		local minutes = Trim(opts.args)
		if minutes == "" then
			return
		end

		local reminderText = GetUserInput()

		if reminderText == "" then
			return
		end

		local reminder = { reminderMsg = reminderText, remindEvery = minutes, persistent = true }

		AddReminder(reminder)

		print("Added to your reminders every " .. minutes)
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

		local reminderText = GetUserInput()

		if reminderText == "" then
			return
		end
		local reminder = { reminderMsg = reminderText, remindAt = hour, persistent = true }

		AddReminder(reminder)

		print("Added to your daily reminders")
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

		local reminderText = GetUserInput()

		if reminderText == "" then
			return
		end
		local reminder = { reminderMsg = reminderText, remindAt = hour, persistent = false }

		AddReminder(reminder)

		print("\nAdded to your reminders")
	end, { nargs = "?" })

	vim.api.nvim_create_user_command("ReminderClose", function()
		if has_notify then
			require("notify").dismiss()
		end
	end, { desc = "Close notification" })
end

return reminders
