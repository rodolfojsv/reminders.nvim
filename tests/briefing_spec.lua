local helpers = require("tests.helpers")

describe("reminders.briefing", function()
	local briefing, processor, config
	local tmp_dir

	before_each(function()
		helpers.reset_modules()
		tmp_dir = helpers.tmp_dir()

		config = require("reminders.config")
		config.setup({
			directory_path = tmp_dir,
			default_category = "personal",
			briefing = {
				on_startup = true,
				greeting = true,
				sections = { "jira", "reminders", "personal" },
			},
		})

		processor = require("reminders.processor")
		processor.initialize_file_path(tmp_dir)

		briefing = require("reminders.briefing")
	end)

	after_each(function()
		-- Close any open briefing window
		pcall(function()
			briefing.close()
		end)
		helpers.rm_dir(tmp_dir)
	end)

	describe("has_content", function()
		it("returns false when no reminders exist", function()
			assert.is_false(briefing.has_content())
		end)

		it("returns false when only personal reminders exist", function()
			processor.add_reminder({
				reminderMsg = "Personal task",
				remindIn = "30",
				persistent = false,
				category = "personal",
			})
			-- has_content checks for work reminders or enabled integrations
			-- personal reminders alone don't count (they show in personal section,
			-- but briefing is primarily work-oriented)
			assert.is_false(briefing.has_content())
		end)

		it("returns true when work reminders exist", function()
			processor.add_reminder({
				reminderMsg = "Work task",
				remindIn = "30",
				persistent = false,
				category = "work",
			})
			assert.is_true(briefing.has_content())
		end)

		it("returns true when jira is enabled", function()
			helpers.reset_modules()
			config = require("reminders.config")
			config.setup({
				directory_path = tmp_dir,
				jira = { enabled = true },
			})
			processor = require("reminders.processor")
			processor.initialize_file_path(tmp_dir)
			briefing = require("reminders.briefing")

			assert.is_true(briefing.has_content())
		end)
	end)

	describe("render_reminders_section", function()
		it("returns nil when no work reminders exist", function()
			assert.is_nil(briefing.render_reminders_section())
		end)

		it("returns nil when only personal reminders exist", function()
			processor.add_reminder({
				reminderMsg = "Personal",
				remindIn = "30",
				persistent = false,
				category = "personal",
			})
			assert.is_nil(briefing.render_reminders_section())
		end)

		it("returns lines for work reminders", function()
			processor.add_reminder({
				reminderMsg = "Work task",
				remindIn = "30",
				persistent = false,
				category = "work",
			})

			local lines = briefing.render_reminders_section()
			assert.is_not_nil(lines)
			assert.is_true(#lines >= 2) -- header + at least 1 reminder
			assert.are.equal("  WORK REMINDERS", lines[1])
			assert.is_truthy(lines[2]:find("Work task"))
		end)

		it("includes only work reminders, not personal", function()
			processor.add_reminder({
				reminderMsg = "Work task",
				remindIn = "30",
				persistent = false,
				category = "work",
			})
			processor.add_reminder({
				reminderMsg = "Personal task",
				remindIn = "30",
				persistent = false,
				category = "personal",
			})

			local lines = briefing.render_reminders_section()
			-- Header + 1 work reminder = 2 lines
			assert.are.equal(2, #lines)
			assert.is_truthy(lines[2]:find("Work task"))
		end)
	end)

	describe("render_calendar_section", function()
		it("returns nil when integrations are disabled", function()
			assert.is_nil(briefing.render_calendar_section())
		end)
	end)

	describe("render_personal_section", function()
		it("returns nil when no personal reminders exist", function()
			assert.is_nil(briefing.render_personal_section())
		end)

		it("returns nil when only work reminders exist", function()
			processor.add_reminder({
				reminderMsg = "Work stuff",
				remindIn = "30",
				persistent = false,
				category = "work",
			})
			assert.is_nil(briefing.render_personal_section())
		end)

		it("returns lines for personal reminders", function()
			processor.add_reminder({
				reminderMsg = "Buy groceries",
				remindIn = "30",
				persistent = false,
				category = "personal",
			})

			local lines = briefing.render_personal_section()
			assert.is_not_nil(lines)
			assert.is_true(#lines >= 2)
			assert.are.equal("  PERSONAL", lines[1])
			assert.is_truthy(lines[2]:find("Buy groceries"))
		end)

		it("includes only personal reminders, not work", function()
			processor.add_reminder({
				reminderMsg = "Personal thing",
				remindIn = "30",
				persistent = false,
				category = "personal",
			})
			processor.add_reminder({
				reminderMsg = "Work thing",
				remindIn = "30",
				persistent = false,
				category = "work",
			})

			local lines = briefing.render_personal_section()
			assert.are.equal(2, #lines)
			assert.is_truthy(lines[2]:find("Personal thing"))
		end)
	end)

	describe("render_jira_section", function()
		it("returns nil when jira is disabled", function()
			assert.is_nil(briefing.render_jira_section())
		end)
	end)

	describe("open / close", function()
		it("opens a floating window", function()
			-- Add a work reminder so there's content
			processor.add_reminder({
				reminderMsg = "Test briefing",
				remindIn = "30",
				persistent = false,
				category = "work",
			})

			briefing.open()

			-- Check that a floating window was created
			local wins = vim.api.nvim_list_wins()
			local found_float = false
			for _, win in ipairs(wins) do
				local win_config = vim.api.nvim_win_get_config(win)
				if win_config.relative and win_config.relative ~= "" then
					found_float = true
					break
				end
			end
			assert.is_true(found_float)

			briefing.close()
		end)

		it("closes the floating window", function()
			processor.add_reminder({
				reminderMsg = "Test briefing",
				remindIn = "30",
				persistent = false,
				category = "work",
			})

			briefing.open()
			briefing.close()

			-- After close, no floating windows should remain from us
			local wins = vim.api.nvim_list_wins()
			local found_float = false
			for _, win in ipairs(wins) do
				local win_config = vim.api.nvim_win_get_config(win)
				if win_config.relative and win_config.relative ~= "" then
					found_float = true
					break
				end
			end
			assert.is_false(found_float)
		end)

		it("can be opened multiple times without error", function()
			processor.add_reminder({
				reminderMsg = "Test",
				remindIn = "30",
				persistent = false,
				category = "work",
			})

			briefing.open()
			briefing.open() -- should close first, then reopen
			briefing.close()
		end)

		it("close is safe when not open", function()
			-- Should not error
			briefing.close()
		end)

		it("modal buffer has correct filetype", function()
			processor.add_reminder({
				reminderMsg = "Test",
				remindIn = "30",
				persistent = false,
				category = "work",
			})

			briefing.open()

			local buf = vim.api.nvim_get_current_buf()
			assert.are.equal("reminders-briefing", vim.api.nvim_buf_get_option(buf, "filetype"))
			assert.are.equal("nofile", vim.api.nvim_buf_get_option(buf, "buftype"))
			assert.is_false(vim.api.nvim_buf_get_option(buf, "modifiable"))

			briefing.close()
		end)

		it("modal content includes greeting with configured name", function()
			-- Re-setup with a custom name
			helpers.reset_modules()
			config = require("reminders.config")
			config.setup({
				directory_path = tmp_dir,
				briefing = { greeting = true, name = "Rodolfo" },
			})
			processor = require("reminders.processor")
			processor.initialize_file_path(tmp_dir)
			briefing = require("reminders.briefing")

			processor.add_reminder({
				reminderMsg = "Work item",
				remindIn = "30",
				persistent = false,
				category = "work",
			})

			briefing.open()

			local buf = vim.api.nvim_get_current_buf()
			local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			local content = table.concat(lines, "\n")

			assert.is_truthy(content:find("Rodolfo"))

			briefing.close()
		end)

		it("modal content uses 'User' when name not configured", function()
			processor.add_reminder({
				reminderMsg = "Work item",
				remindIn = "30",
				persistent = false,
				category = "work",
			})

			briefing.open()

			local buf = vim.api.nvim_get_current_buf()
			local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			local content = table.concat(lines, "\n")

			-- Should contain one of the greeting variants with "User"
			local has_greeting = content:find("Good Morning, User")
				or content:find("Good Afternoon, User")
				or content:find("Good Evening, User")
			assert.is_truthy(has_greeting)

			briefing.close()
		end)

		it("modal content includes work reminders", function()
			processor.add_reminder({
				reminderMsg = "Review PR #412",
				remindIn = "30",
				persistent = false,
				category = "work",
			})

			briefing.open()

			local buf = vim.api.nvim_get_current_buf()
			local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			local content = table.concat(lines, "\n")

			assert.is_truthy(content:find("WORK REMINDERS"))
			assert.is_truthy(content:find("Review PR #412"))

			briefing.close()
		end)

		it("modal content includes footer", function()
			processor.add_reminder({
				reminderMsg = "Test",
				remindIn = "30",
				persistent = false,
				category = "work",
			})

			briefing.open()

			local buf = vim.api.nvim_get_current_buf()
			local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			local content = table.concat(lines, "\n")

			assert.is_truthy(content:find(":ReminderBriefing"))
			assert.is_truthy(content:find("Press <Esc> or q to close"))

			briefing.close()
		end)
	end)
end)
