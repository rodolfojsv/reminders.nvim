local M = {}

M.defaults = {
	-- Core
	directory_path = nil,
	minute_interval = 1,
	default_category = "personal",

	-- Briefing
	briefing = {
		on_startup = false,
		greeting = true,
		name = nil,
		sections = { "jira", "reminders", "personal" },
	},

	-- Jira (via jira-cli)
	jira = {
		enabled = false,
		bin = "jira",
		host = "",
		jql = "",
		exclude_statuses = { "Done", "Closed" },
		refresh_interval_minutes = 15,
	},

	-- Picker
	picker = {
		backend = "telescope",
	},
}

M.options = {}

function M.setup(user_opts)
	M.options = vim.tbl_deep_extend("force", {}, M.defaults, user_opts or {})
end

function M.get()
	return M.options
end

return M
