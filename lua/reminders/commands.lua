local processor = require("reminders.processor")
local utils = require("reminders.utils")
local config = require("reminders.config")

local M = {}

--- Extract category from reminder text using the "category - message" syntax.
---@param text string
---@return string category, string message
local function parse_reminder_text(text)
	return utils.parse_category(text, config.get().default_category)
end

function M.register(has_notify_fn, restart_timer_fn, stop_timer_fn)
	vim.api.nvim_create_user_command("RemindMeEvery", function(opts)
		local minutes = utils.trim(opts.args)
		if minutes == "" then
			return
		end

		local reminderText = utils.get_user_input("What is the reminder: ")
		if reminderText == "" then
			return
		end

		local category, msg = parse_reminder_text(reminderText)
		local reminder = {
			reminderMsg = msg,
			remindEvery = minutes,
			persistent = true,
			daily = false,
			category = category,
		}

		processor.add_reminder(reminder)
		print("\nAdded to your reminders every " .. minutes .. " minutes")
	end, { nargs = "?" })

	vim.api.nvim_create_user_command("RemindMeDailyAt", function(opts)
		local hour = utils.trim(opts.args)
		if hour == "" then
			return
		end
		if not string.find(opts.args, ":") then
			hour = hour .. ":00"
		end

		local reminderText = utils.get_user_input("What is the reminder: ")
		if reminderText == "" then
			return
		end

		local category, msg = parse_reminder_text(reminderText)
		local reminder = {
			reminderMsg = msg,
			remindAt = hour,
			persistent = true,
			daily = true,
			category = category,
		}

		processor.add_reminder(reminder)
		print("\nAdded to your daily reminders")
	end, { nargs = "?" })

	vim.api.nvim_create_user_command("RemindMeAt", function(opts)
		local hour = utils.trim(opts.args)
		if hour == "" then
			return
		end
		if not string.find(opts.args, ":") then
			hour = hour .. ":00"
		end

		local reminderText = utils.get_user_input("What is the reminder: ")
		if reminderText == "" then
			return
		end

		local category, msg = parse_reminder_text(reminderText)
		local reminder = {
			reminderMsg = msg,
			remindAt = hour,
			persistent = false,
			category = category,
		}

		processor.add_reminder(reminder)
		print("\nAdded to your reminders")
	end, { nargs = "?" })

	vim.api.nvim_create_user_command("RemindMeIn", function(opts)
		local minutes = utils.trim(opts.args)
		if minutes == "" then
			return
		end

		local reminderText = utils.get_user_input("What is the reminder: ")
		if reminderText == "" then
			return
		end

		local category, msg = parse_reminder_text(reminderText)
		local reminder = {
			reminderMsg = msg,
			remindIn = minutes,
			persistent = false,
			category = category,
		}

		processor.add_reminder(reminder)
		print("\nAdded to your reminders")
	end, { nargs = "?" })

	vim.api.nvim_create_user_command("ReminderClose", function()
		if has_notify_fn() then
			require("notify").dismiss()
			restart_timer_fn()
		end
	end, { desc = "Close notification" })

	vim.api.nvim_create_user_command("ReminderRemoveAt", function(opts)
		local index = utils.trim(opts.args)
		if index == "" or index == nil then
			return
		end
		processor.remove_reminder(tonumber(index))
	end, { desc = "Remove reminder at index", nargs = "?" })

	vim.api.nvim_create_user_command("ReminderRemoveAll", function()
		processor.remove_all_reminders()
	end, { desc = "Remove all reminders" })

	vim.api.nvim_create_user_command("ReminderFocusModeOn", function()
		stop_timer_fn()
	end, { desc = "Enable focus mode (suppress notifications)" })

	vim.api.nvim_create_user_command("ReminderFocusModeOff", function()
		restart_timer_fn()
	end, { desc = "Disable focus mode (resume notifications)" })

	-- New commands (Phase 1+2)
	vim.api.nvim_create_user_command("ReminderNew", function()
		require("reminders.picker").new_reminder()
	end, { desc = "Create a new reminder via picker UI" })

	vim.api.nvim_create_user_command("ReminderList", function()
		require("reminders.picker").list_reminders()
	end, { desc = "View and manage active reminders" })

	vim.api.nvim_create_user_command("ReminderBriefing", function()
		require("reminders.briefing").open()
	end, { desc = "Open the startup briefing modal" })

	-- Jira
	vim.api.nvim_create_user_command("ReminderJiraRefresh", function()
		local ok, jira = pcall(require, "reminders.jira")
		if ok then
			jira.refresh()
			vim.notify("Jira issues refreshed", vim.log.levels.INFO)
		else
			vim.notify("Jira module not available", vim.log.levels.ERROR)
		end
	end, { desc = "Refresh Jira issues from CLI" })
end

return M
