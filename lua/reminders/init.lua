require("reminders.processor")
require("reminders.utils")
require("plugin.reminders")
local reminders = {}

reminders.AddReminder = AddReminder
reminders.RemoveAllReminders = RemoveAllReminders

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

	function HasNotify()
		return has_notify
	end

	local function on_timer()
		if ProcessTimerCallback() then
			timer:stop()
		end
	end

	timer:start(options.minute_interval, options.minute_interval, vim.schedule_wrap(on_timer))

	function RestartTimer()
		timer:again()
	end

	function StopTimer()
		timer:stop()
	end
end

return reminders
