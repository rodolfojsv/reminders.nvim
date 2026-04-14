local helpers = require("tests.helpers")

describe("reminders.jira", function()
	local jira, config
	local tmp_dir

	before_each(function()
		helpers.reset_modules()
		tmp_dir = helpers.tmp_dir()

		config = require("reminders.config")
		config.setup({
			directory_path = tmp_dir,
			jira = {
				enabled = true,
				bin = "jira",
				host = "https://mycompany.atlassian.net",
				exclude_statuses = { "Done", "Closed" },
				refresh_interval_minutes = 15,
			},
		})

		jira = require("reminders.jira")
	end)

	after_each(function()
		helpers.rm_dir(tmp_dir)
	end)

	describe("parse_output", function()
		it("parses tab-separated CLI output", function()
			local output = "PROJ-1\tStory\tIn Progress\tHigh\tBuild the widget\n"
				.. "PROJ-2\tBug\tOpen\tMedium\tFix the thing\n"

			local issues = jira.parse_output(output)
			assert.are.equal(2, #issues)
			assert.are.equal("PROJ-1", issues[1].key)
			assert.are.equal("Story", issues[1].type)
			assert.are.equal("In Progress", issues[1].status)
			assert.are.equal("High", issues[1].priority)
			assert.are.equal("Build the widget", issues[1].summary)
			assert.are.equal("PROJ-2", issues[2].key)
			assert.are.equal("Bug", issues[2].type)
		end)

		it("returns empty table for empty output", function()
			assert.are.same({}, jira.parse_output(""))
			assert.are.same({}, jira.parse_output(nil))
		end)

		it("skips blank lines", function()
			local output = "PROJ-1\tStory\tOpen\tHigh\tDo stuff\n\n\n"
			local issues = jira.parse_output(output)
			assert.are.equal(1, #issues)
		end)

		it("handles lines with fewer columns gracefully", function()
			local output = "PROJ-1\tStory\tOpen\n"
			local issues = jira.parse_output(output)
			assert.are.equal(1, #issues)
			assert.are.equal("PROJ-1", issues[1].key)
			assert.are.equal("Open", issues[1].status)
			assert.are.equal("", issues[1].priority)
		end)

		it("trims whitespace from fields", function()
			local output = "  PROJ-1  \t  Story  \t  Open  \t  High  \t  Trim me  \n"
			local issues = jira.parse_output(output)
			assert.are.equal("PROJ-1", issues[1].key)
			assert.are.equal("Trim me", issues[1].summary)
		end)
	end)

	describe("issue_url", function()
		it("builds correct browse URL", function()
			local url = jira.issue_url("PROJ-123")
			assert.are.equal("https://mycompany.atlassian.net/browse/PROJ-123", url)
		end)

		it("strips trailing slash from host", function()
			helpers.reset_modules()
			config = require("reminders.config")
			config.setup({
				directory_path = tmp_dir,
				jira = { enabled = true, host = "https://mycompany.atlassian.net/" },
			})
			jira = require("reminders.jira")

			local url = jira.issue_url("PROJ-1")
			assert.are.equal("https://mycompany.atlassian.net/browse/PROJ-1", url)
		end)

		it("returns nil when host is not configured", function()
			helpers.reset_modules()
			config = require("reminders.config")
			config.setup({
				directory_path = tmp_dir,
				jira = { enabled = true, host = "" },
			})
			jira = require("reminders.jira")

			assert.is_nil(jira.issue_url("PROJ-1"))
		end)
	end)

	describe("priority_icon", function()
		it("returns correct icons for known priorities", function()
			assert.are.equal("🔴", jira.priority_icon("Highest"))
			assert.are.equal("🟠", jira.priority_icon("High"))
			assert.are.equal("🟡", jira.priority_icon("Medium"))
			assert.are.equal("🟢", jira.priority_icon("Low"))
			assert.are.equal("⚪", jira.priority_icon("Lowest"))
		end)

		it("returns default icon for unknown priority", function()
			assert.are.equal("⚪", jira.priority_icon("Critical"))
			assert.are.equal("⚪", jira.priority_icon(""))
		end)
	end)

	describe("get_briefing_data", function()
		it("returns nil when jira is disabled", function()
			helpers.reset_modules()
			config = require("reminders.config")
			config.setup({
				directory_path = tmp_dir,
				jira = { enabled = false },
			})
			jira = require("reminders.jira")

			assert.is_nil(jira.get_briefing_data())
		end)

		it("loads from disk cache", function()
			local cache_path = tmp_dir .. "/jira_cache.json"
			local cache_data = {
				updated_at = os.time(),
				date = os.date("%Y-%m-%d"),
				issues = {
					{ key = "PROJ-1", type = "Story", status = "Open", priority = "High", summary = "Cached issue" },
				},
			}
			local f = io.open(cache_path, "w")
			f:write(vim.fn.json_encode(cache_data))
			f:close()

			local data = jira.get_briefing_data()
			assert.is_not_nil(data)
			assert.are.equal(1, #data)
			assert.are.equal("Cached issue", data[1].summary)
		end)

		it("ignores stale cache from a different day", function()
			local cache_path = tmp_dir .. "/jira_cache.json"
			local cache_data = {
				updated_at = os.time() - 86400,
				date = "1999-01-01",
				issues = {
					{ key = "PROJ-1", type = "Story", status = "Open", priority = "High", summary = "Old" },
				},
			}
			local f = io.open(cache_path, "w")
			f:write(vim.fn.json_encode(cache_data))
			f:close()

			-- Suppress notifications from CLI errors
			local original_notify = vim.notify
			vim.notify = function() end

			local data = jira.get_briefing_data()
			-- Stale cache ignored, fresh fetch will fail (no real CLI), so nil
			assert.is_nil(data)

			vim.notify = original_notify
		end)
	end)
end)
