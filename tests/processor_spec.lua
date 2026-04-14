local helpers = require("tests.helpers")

describe("reminders.processor", function()
	local processor
	local tmp_dir

	before_each(function()
		helpers.reset_modules()
		tmp_dir = helpers.tmp_dir()
		processor = require("reminders.processor")
		processor.initialize_file_path(tmp_dir)
	end)

	after_each(function()
		helpers.rm_dir(tmp_dir)
	end)

	describe("initialize_file_path", function()
		it("appends separator if missing", function()
			-- Verify by adding a reminder and checking the file exists
			processor.initialize_file_path(tmp_dir)
			processor.add_reminder({
				reminderMsg = "test",
				remindIn = "10",
				persistent = false,
			})
			local json_path = tmp_dir .. "/reminders.json"
			-- File should exist at the constructed path
			local f = io.open(json_path, "r")
			assert.is_not_nil(f)
			if f then
				f:close()
			end
		end)

		it("handles trailing slash", function()
			processor.initialize_file_path(tmp_dir .. "/")
			processor.add_reminder({
				reminderMsg = "test",
				remindIn = "5",
				persistent = false,
			})
			local json_path = tmp_dir .. "/reminders.json"
			local f = io.open(json_path, "r")
			assert.is_not_nil(f)
			if f then
				f:close()
			end
		end)

		it("handles trailing backslash (Windows)", function()
			processor.initialize_file_path(tmp_dir .. "\\")
			processor.add_reminder({
				reminderMsg = "test",
				remindIn = "5",
				persistent = false,
			})
			-- Should not double-separate
			local reminders = processor.get_reminders()
			assert.are.equal(1, #reminders)
		end)
	end)

	describe("add_reminder", function()
		it("adds a reminder with remindIn", function()
			local before = os.time()
			processor.add_reminder({
				reminderMsg = "Test reminder",
				remindIn = "30",
				persistent = false,
			})

			local reminders = processor.get_reminders()
			assert.are.equal(1, #reminders)
			assert.are.equal("Test reminder", reminders[1].reminderMsg)
			assert.is_nil(reminders[1].remindIn) -- converted to reminderDate
			assert.is_true(reminders[1].reminderDate >= before + 30 * 60)
			assert.is_true(reminders[1].reminderDate <= os.time() + 30 * 60)
		end)

		it("adds a reminder with remindAt", function()
			processor.add_reminder({
				reminderMsg = "Meeting",
				remindAt = "14:30",
				persistent = false,
			})

			local reminders = processor.get_reminders()
			assert.are.equal(1, #reminders)
			assert.is_nil(reminders[1].remindAt) -- converted
			local t = os.date("*t", reminders[1].reminderDate)
			assert.are.equal(14, t.hour)
			assert.are.equal(30, t.min)
		end)

		it("adds a recurring reminder with remindEvery", function()
			processor.add_reminder({
				reminderMsg = "Hydrate",
				remindEvery = "30",
				persistent = true,
				daily = false,
			})

			local reminders = processor.get_reminders()
			assert.are.equal(1, #reminders)
			assert.is_true(reminders[1].persistent)
			assert.are.equal("30", reminders[1].remindEvery)
			assert.is_not_nil(reminders[1].reminderDate)
		end)

		it("assigns default category when not specified", function()
			processor.add_reminder({
				reminderMsg = "No category",
				remindIn = "10",
				persistent = false,
			})

			local reminders = processor.get_reminders()
			assert.are.equal("personal", reminders[1].category)
		end)

		it("preserves explicit category", function()
			processor.add_reminder({
				reminderMsg = "Work task",
				remindIn = "10",
				persistent = false,
				category = "work",
			})

			local reminders = processor.get_reminders()
			assert.are.equal("work", reminders[1].category)
		end)

		it("assigns sequential index values", function()
			processor.add_reminder({ reminderMsg = "First", remindIn = "10", persistent = false })
			processor.add_reminder({ reminderMsg = "Second", remindIn = "20", persistent = false })
			processor.add_reminder({ reminderMsg = "Third", remindIn = "30", persistent = false })

			local reminders = processor.get_reminders()
			assert.are.equal(1, reminders[1].index)
			assert.are.equal(2, reminders[2].index)
			assert.are.equal(3, reminders[3].index)
		end)

		it("persists to JSON file", function()
			processor.add_reminder({
				reminderMsg = "Persist me",
				remindIn = "10",
				persistent = false,
			})

			local data = helpers.read_json(tmp_dir .. "/reminders.json")
			assert.is_not_nil(data)
			assert.are.equal(1, #data)
			assert.are.equal("Persist me", data[1].reminderMsg)
		end)
	end)

	describe("remove_reminder", function()
		it("removes a reminder by matching index", function()
			processor.add_reminder({ reminderMsg = "A", remindIn = "10", persistent = false })
			processor.add_reminder({ reminderMsg = "B", remindIn = "20", persistent = false })

			processor.remove_reminder(1)

			local reminders = processor.get_reminders()
			assert.are.equal(1, #reminders)
			assert.are.equal("B", reminders[1].reminderMsg)
		end)

		it("removes by searching index field when position doesn't match", function()
			processor.add_reminder({ reminderMsg = "A", remindIn = "10", persistent = false })
			processor.add_reminder({ reminderMsg = "B", remindIn = "20", persistent = false })
			processor.add_reminder({ reminderMsg = "C", remindIn = "30", persistent = false })

			-- Remove first, now B is at position 1 but has index=2
			processor.remove_reminder(1)
			-- Now remove the one with index=3 (C)
			processor.remove_reminder(3)

			local reminders = processor.get_reminders()
			assert.are.equal(1, #reminders)
			assert.are.equal("B", reminders[1].reminderMsg)
		end)

		it("persists changes after removal", function()
			processor.add_reminder({ reminderMsg = "A", remindIn = "10", persistent = false })
			processor.add_reminder({ reminderMsg = "B", remindIn = "20", persistent = false })

			processor.remove_reminder(1)

			local data = helpers.read_json(tmp_dir .. "/reminders.json")
			assert.are.equal(1, #data)
		end)
	end)

	describe("remove_all_reminders", function()
		it("clears all reminders", function()
			processor.add_reminder({ reminderMsg = "A", remindIn = "10", persistent = false })
			processor.add_reminder({ reminderMsg = "B", remindIn = "20", persistent = false })

			processor.remove_all_reminders()

			assert.are.equal(0, #processor.get_reminders())
		end)

		it("persists empty array", function()
			processor.add_reminder({ reminderMsg = "A", remindIn = "10", persistent = false })
			processor.remove_all_reminders()

			local data = helpers.read_json(tmp_dir .. "/reminders.json")
			assert.are.same({}, data)
		end)
	end)

	describe("time_to_show", function()
		it("returns true when reminderDate is in the past", function()
			local reminder = { reminderDate = os.time() - 60 }
			assert.is_true(processor.time_to_show(reminder))
		end)

		it("returns true when reminderDate is now", function()
			local reminder = { reminderDate = os.time() }
			assert.is_true(processor.time_to_show(reminder))
		end)

		it("returns false when reminderDate is in the future", function()
			local reminder = { reminderDate = os.time() + 3600 }
			assert.is_false(processor.time_to_show(reminder))
		end)

		it("returns false when reminderDate is nil", function()
			local reminder = {}
			assert.is_false(processor.time_to_show(reminder))
		end)
	end)

	describe("check_for_next_execution", function()
		it("reschedules recurring reminder", function()
			local now = os.time()
			local reminder = {
				reminderMsg = "Recurring",
				remindEvery = "30",
				reminderDate = now - 60,
				shownAt = now,
				persistent = true,
			}

			processor.check_for_next_execution(reminder)

			assert.is_true(reminder.reminderDate > now)
			assert.is_true(reminder.reminderDate <= now + 30 * 60 + 1)
		end)

		it("reschedules daily reminder to next day", function()
			local now = os.time()
			local reminder = {
				reminderMsg = "Daily",
				daily = true,
				reminderDate = now - 60,
				shownAt = now,
				persistent = true,
			}

			processor.check_for_next_execution(reminder)

			-- Should be at least 23 hours in the future
			assert.is_true(reminder.reminderDate > now)
		end)

		it("skips rescheduling when both reminderDate and remindEvery are nil", function()
			local reminder = { reminderMsg = "Nothing" }
			-- Should not error
			processor.check_for_next_execution(reminder)
			assert.is_nil(reminder.reminderDate)
		end)
	end)

	describe("initialize_reminders_from_file", function()
		it("loads reminders from existing JSON", function()
			local json_path = tmp_dir .. "/reminders.json"
			helpers.write_json(json_path, {
				{
					reminderMsg = "Saved reminder",
					reminderDate = os.time() + 3600,
					shownAt = os.time() - 60,
					persistent = false,
					index = 1,
				},
			})

			processor.initialize_reminders_from_file("personal")

			local reminders = processor.get_reminders()
			assert.are.equal(1, #reminders)
			assert.are.equal("Saved reminder", reminders[1].reminderMsg)
		end)

		it("migrates old remindAt schema to reminderDate", function()
			local json_path = tmp_dir .. "/reminders.json"
			helpers.write_json(json_path, {
				{
					reminderMsg = "Old format",
					remindAt = "14:30",
					persistent = false,
				},
			})

			processor.initialize_reminders_from_file("personal")

			local reminders = processor.get_reminders()
			assert.is_not_nil(reminders[1].reminderDate)
			assert.is_nil(reminders[1].remindAt)
		end)

		it("adds missing index field", function()
			local json_path = tmp_dir .. "/reminders.json"
			helpers.write_json(json_path, {
				{ reminderMsg = "No index", reminderDate = os.time() + 3600, persistent = false },
			})

			processor.initialize_reminders_from_file("personal")

			local reminders = processor.get_reminders()
			assert.are.equal(1, reminders[1].index)
		end)

		it("adds missing category field with default", function()
			local json_path = tmp_dir .. "/reminders.json"
			helpers.write_json(json_path, {
				{
					reminderMsg = "No category",
					reminderDate = os.time() + 3600,
					persistent = false,
					index = 1,
				},
			})

			processor.initialize_reminders_from_file("work")

			local reminders = processor.get_reminders()
			assert.are.equal("work", reminders[1].category)
		end)

		it("preserves existing category during migration", function()
			local json_path = tmp_dir .. "/reminders.json"
			helpers.write_json(json_path, {
				{
					reminderMsg = "Has category",
					reminderDate = os.time() + 3600,
					persistent = false,
					index = 1,
					category = "work",
				},
			})

			processor.initialize_reminders_from_file("personal")

			local reminders = processor.get_reminders()
			assert.are.equal("work", reminders[1].category)
		end)

		it("handles empty JSON file gracefully", function()
			local json_path = tmp_dir .. "/reminders.json"
			helpers.write_json(json_path, {})

			processor.initialize_reminders_from_file("personal")

			assert.are.equal(0, #processor.get_reminders())
		end)

		it("handles non-existent file gracefully", function()
			-- Don't create any file
			processor.initialize_reminders_from_file("personal")
			assert.are.equal(0, #processor.get_reminders())
		end)
	end)

	describe("process_timer_callback", function()
		it("fires due reminders and removes non-persistent ones", function()
			local notified = {}
			local original_notify = vim.notify
			vim.notify = function(msg, level, opts)
				table.insert(notified, { msg = msg, level = level, opts = opts })
			end

			processor.add_reminder({
				reminderMsg = "Due now",
				remindIn = "0",
				persistent = false,
			})
			-- Force reminderDate to be in the past
			local reminders = processor.get_reminders()
			reminders[1].reminderDate = os.time() - 10

			local triggered = processor.process_timer_callback()

			assert.is_true(triggered)
			assert.are.equal(1, #notified)
			assert.are.equal("Due now", notified[1].msg)
			-- Reminder should be removed (non-persistent)
			assert.are.equal(0, #processor.get_reminders())

			vim.notify = original_notify
		end)

		it("keeps persistent reminders after firing", function()
			local original_notify = vim.notify
			vim.notify = function() end

			processor.add_reminder({
				reminderMsg = "Recurring",
				remindEvery = "30",
				persistent = true,
				daily = false,
			})
			local reminders = processor.get_reminders()
			reminders[1].reminderDate = os.time() - 10

			processor.process_timer_callback()

			-- Should still be there
			assert.are.equal(1, #processor.get_reminders())

			vim.notify = original_notify
		end)

		it("returns false when no reminders are due", function()
			processor.add_reminder({
				reminderMsg = "Future",
				remindIn = "60",
				persistent = false,
			})

			local triggered = processor.process_timer_callback()
			assert.is_false(triggered)
		end)

		it("returns false when no reminders exist", function()
			local triggered = processor.process_timer_callback()
			assert.is_false(triggered)
		end)
	end)

	describe("save_file", function()
		it("writes valid JSON that can be re-read", function()
			processor.add_reminder({
				reminderMsg = "Roundtrip test",
				remindIn = "10",
				persistent = false,
				category = "work",
			})

			-- Re-initialize from file to verify roundtrip
			helpers.reset_modules()
			processor = require("reminders.processor")
			processor.initialize_file_path(tmp_dir)
			processor.initialize_reminders_from_file("personal")

			local reminders = processor.get_reminders()
			assert.are.equal(1, #reminders)
			assert.are.equal("Roundtrip test", reminders[1].reminderMsg)
			assert.are.equal("work", reminders[1].category)
		end)
	end)
end)
