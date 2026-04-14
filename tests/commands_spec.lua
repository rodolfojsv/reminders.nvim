local helpers = require("tests.helpers")

describe("reminders.commands", function()
	local commands, processor, config
	local tmp_dir

	before_each(function()
		helpers.reset_modules()
		tmp_dir = helpers.tmp_dir()

		config = require("reminders.config")
		config.setup({ directory_path = tmp_dir, default_category = "personal" })

		processor = require("reminders.processor")
		processor.initialize_file_path(tmp_dir)

		commands = require("reminders.commands")

		-- Delete commands if they exist from prior tests
		pcall(vim.api.nvim_del_user_command, "RemindMeEvery")
		pcall(vim.api.nvim_del_user_command, "RemindMeDailyAt")
		pcall(vim.api.nvim_del_user_command, "RemindMeAt")
		pcall(vim.api.nvim_del_user_command, "RemindMeIn")
		pcall(vim.api.nvim_del_user_command, "ReminderClose")
		pcall(vim.api.nvim_del_user_command, "ReminderRemoveAt")
		pcall(vim.api.nvim_del_user_command, "ReminderRemoveAll")
		pcall(vim.api.nvim_del_user_command, "ReminderFocusModeOn")
		pcall(vim.api.nvim_del_user_command, "ReminderFocusModeOff")
		pcall(vim.api.nvim_del_user_command, "ReminderNew")
		pcall(vim.api.nvim_del_user_command, "ReminderList")
		pcall(vim.api.nvim_del_user_command, "ReminderBriefing")
		pcall(vim.api.nvim_del_user_command, "ReminderJiraRefresh")

		commands.register(
			function() return false end,
			function() end,
			function() end
		)
	end)

	after_each(function()
		helpers.rm_dir(tmp_dir)
	end)

	describe("register", function()
		it("creates all expected user commands", function()
			local expected = {
				"RemindMeEvery",
				"RemindMeDailyAt",
				"RemindMeAt",
				"RemindMeIn",
				"ReminderClose",
				"ReminderRemoveAt",
				"ReminderRemoveAll",
				"ReminderFocusModeOn",
				"ReminderFocusModeOff",
				"ReminderNew",
				"ReminderList",
				"ReminderBriefing",
				"ReminderJiraRefresh",
			}

			local cmds = vim.api.nvim_get_commands({})
			for _, name in ipairs(expected) do
				assert.is_not_nil(cmds[name], "Expected command " .. name .. " to be registered")
			end
		end)
	end)

	describe("RemindMeIn", function()
		it("creates a timed reminder with category parsing", function()
			-- Mock vim.ui.input to provide reminder text
			local original_input = vim.ui.input
			vim.ui.input = function(opts, cb)
				cb("work - Review PR #412")
			end

			vim.cmd("RemindMeIn 30")

			local reminders = processor.get_reminders()
			assert.are.equal(1, #reminders)
			assert.are.equal("Review PR #412", reminders[1].reminderMsg)
			assert.are.equal("work", reminders[1].category)
			assert.is_false(reminders[1].persistent)

			vim.ui.input = original_input
		end)

		it("uses default category when none specified", function()
			local original_input = vim.ui.input
			vim.ui.input = function(opts, cb)
				cb("Just a message")
			end

			vim.cmd("RemindMeIn 15")

			local reminders = processor.get_reminders()
			assert.are.equal("personal", reminders[1].category)
			assert.are.equal("Just a message", reminders[1].reminderMsg)

			vim.ui.input = original_input
		end)

		it("does nothing when no minutes provided", function()
			vim.cmd("RemindMeIn")
			assert.are.equal(0, #processor.get_reminders())
		end)

		it("does nothing when user cancels input", function()
			local original_input = vim.ui.input
			vim.ui.input = function(opts, cb)
				cb(nil)
			end

			vim.cmd("RemindMeIn 30")
			assert.are.equal(0, #processor.get_reminders())

			vim.ui.input = original_input
		end)
	end)

	describe("RemindMeEvery", function()
		it("creates a persistent recurring reminder", function()
			local original_input = vim.ui.input
			vim.ui.input = function(opts, cb)
				cb("Hydrate")
			end

			vim.cmd("RemindMeEvery 30")

			local reminders = processor.get_reminders()
			assert.are.equal(1, #reminders)
			assert.are.equal("Hydrate", reminders[1].reminderMsg)
			assert.is_true(reminders[1].persistent)
			assert.is_false(reminders[1].daily)
			assert.are.equal("30", reminders[1].remindEvery)

			vim.ui.input = original_input
		end)
	end)

	describe("RemindMeAt", function()
		it("creates a one-time reminder at specified hour", function()
			local original_input = vim.ui.input
			vim.ui.input = function(opts, cb)
				cb("Meeting")
			end

			vim.cmd("RemindMeAt 14:30")

			local reminders = processor.get_reminders()
			assert.are.equal(1, #reminders)
			assert.is_false(reminders[1].persistent)
			local t = os.date("*t", reminders[1].reminderDate)
			assert.are.equal(14, t.hour)
			assert.are.equal(30, t.min)

			vim.ui.input = original_input
		end)

		it("appends :00 when no colon in time", function()
			local original_input = vim.ui.input
			vim.ui.input = function(opts, cb)
				cb("Meeting")
			end

			vim.cmd("RemindMeAt 14")

			local reminders = processor.get_reminders()
			local t = os.date("*t", reminders[1].reminderDate)
			assert.are.equal(14, t.hour)
			assert.are.equal(0, t.min)

			vim.ui.input = original_input
		end)
	end)

	describe("RemindMeDailyAt", function()
		it("creates a persistent daily reminder", function()
			local original_input = vim.ui.input
			vim.ui.input = function(opts, cb)
				cb("Standup")
			end

			vim.cmd("RemindMeDailyAt 09:00")

			local reminders = processor.get_reminders()
			assert.are.equal(1, #reminders)
			assert.is_true(reminders[1].persistent)
			assert.is_true(reminders[1].daily)

			vim.ui.input = original_input
		end)
	end)

	describe("ReminderRemoveAll", function()
		it("clears all reminders", function()
			local original_input = vim.ui.input
			vim.ui.input = function(opts, cb)
				cb("test")
			end

			vim.cmd("RemindMeIn 30")
			vim.cmd("RemindMeIn 60")
			assert.are.equal(2, #processor.get_reminders())

			vim.cmd("ReminderRemoveAll")
			assert.are.equal(0, #processor.get_reminders())

			vim.ui.input = original_input
		end)
	end)

	describe("ReminderRemoveAt", function()
		it("removes a specific reminder by index", function()
			local original_input = vim.ui.input
			vim.ui.input = function(opts, cb)
				cb("test")
			end

			vim.cmd("RemindMeIn 30")
			vim.cmd("RemindMeIn 60")

			vim.cmd("ReminderRemoveAt 1")
			assert.are.equal(1, #processor.get_reminders())

			vim.ui.input = original_input
		end)
	end)

	describe("focus mode", function()
		it("calls stop_timer_fn on FocusModeOn", function()
			local stopped = false
			pcall(vim.api.nvim_del_user_command, "ReminderFocusModeOn")
			pcall(vim.api.nvim_del_user_command, "ReminderFocusModeOff")

			-- Re-register with trackable functions
			helpers.reset_modules()
			config = require("reminders.config")
			config.setup({ directory_path = tmp_dir })
			processor = require("reminders.processor")
			processor.initialize_file_path(tmp_dir)
			commands = require("reminders.commands")

			-- Clean up all commands first
			for _, cmd in ipairs({
				"RemindMeEvery", "RemindMeDailyAt", "RemindMeAt", "RemindMeIn",
				"ReminderClose", "ReminderRemoveAt", "ReminderRemoveAll",
				"ReminderFocusModeOn", "ReminderFocusModeOff",
				"ReminderNew", "ReminderList", "ReminderBriefing",
				"ReminderMsAuth", "ReminderMsRefresh",
			}) do
				pcall(vim.api.nvim_del_user_command, cmd)
			end

			commands.register(
				function() return false end,
				function() end,
				function() stopped = true end
			)

			vim.cmd("ReminderFocusModeOn")
			assert.is_true(stopped)
		end)

		it("calls restart_timer_fn on FocusModeOff", function()
			local restarted = false
			-- Clean up and re-register
			for _, cmd in ipairs({
				"RemindMeEvery", "RemindMeDailyAt", "RemindMeAt", "RemindMeIn",
				"ReminderClose", "ReminderRemoveAt", "ReminderRemoveAll",
				"ReminderFocusModeOn", "ReminderFocusModeOff",
				"ReminderNew", "ReminderList", "ReminderBriefing",
				"ReminderMsAuth", "ReminderMsRefresh",
			}) do
				pcall(vim.api.nvim_del_user_command, cmd)
			end

			helpers.reset_modules()
			config = require("reminders.config")
			config.setup({ directory_path = tmp_dir })
			processor = require("reminders.processor")
			processor.initialize_file_path(tmp_dir)
			commands = require("reminders.commands")

			commands.register(
				function() return false end,
				function() restarted = true end,
				function() end
			)

			vim.cmd("ReminderFocusModeOff")
			assert.is_true(restarted)
		end)
	end)
end)
