local helpers = require("tests.helpers")

describe("reminders.config", function()
	local config

	before_each(function()
		helpers.reset_modules()
		config = require("reminders.config")
	end)

	describe("defaults", function()
		it("has expected default_category", function()
			assert.are.equal("personal", config.defaults.default_category)
		end)

		it("has expected minute_interval", function()
			assert.are.equal(1, config.defaults.minute_interval)
		end)

		it("has briefing on_startup disabled by default", function()
			assert.is_false(config.defaults.briefing.on_startup)
		end)

		it("has jira disabled by default", function()
			assert.is_false(config.defaults.jira.enabled)
		end)

		it("has picker backend as telescope", function()
			assert.are.equal("telescope", config.defaults.picker.backend)
		end)

		it("has jira bin default to jira", function()
			assert.are.equal("jira", config.defaults.jira.bin)
		end)
	end)

	describe("setup", function()
		it("merges user options with defaults", function()
			config.setup({
				directory_path = "/tmp/test",
				default_category = "work",
			})
			local cfg = config.get()
			assert.are.equal("/tmp/test", cfg.directory_path)
			assert.are.equal("work", cfg.default_category)
		end)

		it("preserves defaults for unspecified options", function()
			config.setup({ directory_path = "/tmp/test" })
			local cfg = config.get()
			assert.are.equal(1, cfg.minute_interval)
			assert.are.equal("personal", cfg.default_category)
			assert.is_false(cfg.briefing.on_startup)
		end)

		it("deep merges nested options", function()
			config.setup({
				briefing = { on_startup = true },
			})
			local cfg = config.get()
			assert.is_true(cfg.briefing.on_startup)
			-- Other briefing keys preserved
			assert.is_true(cfg.briefing.greeting)
			assert.are.same({ "jira", "reminders", "personal" }, cfg.briefing.sections)
		end)

		it("deep merges jira options", function()
			config.setup({
				jira = {
					enabled = true,
					host = "https://test.atlassian.net",
				},
			})
			local cfg = config.get()
			assert.is_true(cfg.jira.enabled)
			assert.are.equal("https://test.atlassian.net", cfg.jira.host)
			-- Defaults preserved
			assert.are.equal("jira", cfg.jira.bin)
			assert.are.same({ "Done", "Closed" }, cfg.jira.exclude_statuses)
		end)

		it("handles empty options", function()
			config.setup({})
			local cfg = config.get()
			assert.are.equal("personal", cfg.default_category)
		end)

		it("handles nil options", function()
			config.setup(nil)
			local cfg = config.get()
			assert.are.equal("personal", cfg.default_category)
		end)
	end)

	describe("get", function()
		it("returns empty table before setup", function()
			-- Before setup, options is {}
			local cfg = config.get()
			assert.are.same({}, cfg)
		end)

		it("returns configured options after setup", function()
			config.setup({ directory_path = "/test" })
			local cfg = config.get()
			assert.are.equal("/test", cfg.directory_path)
		end)
	end)
end)
