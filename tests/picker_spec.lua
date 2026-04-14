local helpers = require("tests.helpers")

describe("reminders.picker", function()
	local picker, processor, config
	local tmp_dir

	before_each(function()
		helpers.reset_modules()
		tmp_dir = helpers.tmp_dir()

		config = require("reminders.config")
		config.setup({ directory_path = tmp_dir, default_category = "personal" })

		processor = require("reminders.processor")
		processor.initialize_file_path(tmp_dir)

		picker = require("reminders.picker")
	end)

	after_each(function()
		helpers.rm_dir(tmp_dir)
	end)

	describe("format_schedule", function()
		it("formats daily reminder", function()
			local t = os.date("*t")
			t.hour = 9
			t.min = 30
			local reminder = {
				persistent = true,
				daily = true,
				reminderDate = os.time(t),
			}
			assert.are.equal("Daily at 09:30", picker.format_schedule(reminder))
		end)

		it("formats recurring every-N-minutes reminder", function()
			local reminder = {
				persistent = true,
				remindEvery = "30",
				reminderDate = os.time() + 1800,
			}
			assert.are.equal("Every 30m", picker.format_schedule(reminder))
		end)

		it("formats future one-shot as relative time (minutes)", function()
			local reminder = {
				persistent = false,
				reminderDate = os.time() + 1500, -- 25 min
			}
			local result = picker.format_schedule(reminder)
			assert.is_truthy(result:match("^In %d+m$"))
		end)

		it("formats future one-shot as hours + minutes", function()
			local reminder = {
				persistent = false,
				reminderDate = os.time() + 7500, -- ~2h 5m
			}
			local result = picker.format_schedule(reminder)
			assert.is_truthy(result:match("^In %d+h %d+m$"))
		end)

		it("formats past reminder as Now", function()
			local reminder = {
				persistent = false,
				reminderDate = os.time() - 60,
			}
			assert.are.equal("Now", picker.format_schedule(reminder))
		end)

		it("returns empty string for reminder with no date", function()
			local reminder = {}
			assert.are.equal("", picker.format_schedule(reminder))
		end)
	end)

	describe("new_reminder (fallback flow)", function()
		it("creates an 'In X minutes' reminder through the multi-step UI", function()
			local select_call = 0
			local input_call = 0
			local original_select = vim.ui.select
			local original_input = vim.ui.input

			vim.ui.select = function(items, opts, cb)
				select_call = select_call + 1
				if select_call == 1 then
					-- Step 1: select type "In X minutes" (index 1)
					cb(items[1], 1)
				elseif select_call == 2 then
					-- Step 3: select category "work"
					cb("work")
				end
			end

			vim.ui.input = function(opts, cb)
				input_call = input_call + 1
				if input_call == 1 then
					-- Step 2: enter time value
					cb("30")
				elseif input_call == 2 then
					-- Step 4: enter message
					cb("Test reminder")
				end
			end

			picker.new_reminder()

			local reminders = processor.get_reminders()
			assert.are.equal(1, #reminders)
			assert.are.equal("Test reminder", reminders[1].reminderMsg)
			assert.are.equal("work", reminders[1].category)
			assert.is_false(reminders[1].persistent)

			vim.ui.select = original_select
			vim.ui.input = original_input
		end)

		it("creates an 'Every X minutes' reminder", function()
			local select_call = 0
			local input_call = 0
			local original_select = vim.ui.select
			local original_input = vim.ui.input

			vim.ui.select = function(items, opts, cb)
				select_call = select_call + 1
				if select_call == 1 then
					-- Select "Every X minutes" (index 3)
					cb(items[3], 3)
				elseif select_call == 2 then
					-- Category
					cb("personal")
				end
			end

			vim.ui.input = function(opts, cb)
				input_call = input_call + 1
				if input_call == 1 then
					cb("45")
				elseif input_call == 2 then
					cb("Stretch break")
				end
			end

			picker.new_reminder()

			local reminders = processor.get_reminders()
			assert.are.equal(1, #reminders)
			assert.are.equal("Stretch break", reminders[1].reminderMsg)
			assert.is_true(reminders[1].persistent)
			assert.are.equal("45", reminders[1].remindEvery)

			vim.ui.select = original_select
			vim.ui.input = original_input
		end)

		it("aborts when user cancels type selection", function()
			local original_select = vim.ui.select
			vim.ui.select = function(items, opts, cb)
				cb(nil, nil) -- cancel
			end

			picker.new_reminder()
			assert.are.equal(0, #processor.get_reminders())

			vim.ui.select = original_select
		end)

		it("aborts when user cancels time input", function()
			local step = 0
			local original_select = vim.ui.select
			local original_input = vim.ui.input

			vim.ui.select = function(items, opts, cb)
				step = step + 1
				cb(items[1], 1)
			end

			vim.ui.input = function(opts, cb)
				cb(nil) -- cancel
			end

			picker.new_reminder()
			assert.are.equal(0, #processor.get_reminders())

			vim.ui.select = original_select
			vim.ui.input = original_input
		end)
	end)

	describe("list_reminders (fallback flow)", function()
		it("shows notification when no reminders exist", function()
			local notified = false
			local original_notify = vim.notify
			vim.notify = function(msg)
				if msg == "No active reminders" then
					notified = true
				end
			end

			-- Force fallback (no telescope)
			local orig_pcall_telescope = package.loaded["telescope"]
			package.loaded["telescope"] = nil

			picker.list_reminders()
			assert.is_true(notified)

			vim.notify = original_notify
			package.loaded["telescope"] = orig_pcall_telescope
		end)
	end)
end)
