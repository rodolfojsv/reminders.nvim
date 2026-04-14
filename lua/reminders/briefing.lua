local processor = require("reminders.processor")
local config = require("reminders.config")
local picker = require("reminders.picker")

local M = {}

local briefing_buf = nil
local briefing_win = nil
--- Maps line numbers (1-indexed) to action URLs for <CR> interaction.
local line_actions = {}

--- Get a greeting based on the time of day.
---@return string
local function get_greeting()
	local hour = tonumber(os.date("%H"))
	if hour < 12 then
		return "Good Morning"
	elseif hour < 17 then
		return "Good Afternoon"
	else
		return "Good Evening"
	end
end

--- Build the lines of text for the briefing modal.
---@return string[], table<number, string> lines and line_action_map
local function build_lines()
	local cfg = config.get()
	local lines = {}
	local actions = {}

	-- Greeting
	if cfg.briefing.greeting then
		local user = cfg.briefing.name or "User"
		local greeting = get_greeting() .. ", " .. user
		local date_str = os.date("%A, %B %d %Y")
		table.insert(lines, "")
		table.insert(lines, string.rep(" ", 20) .. greeting)
		table.insert(lines, string.rep(" ", 20) .. date_str)
		table.insert(lines, "")
	end

	-- Iterate configured sections
	local sections = cfg.briefing.sections or { "jira", "reminders", "personal" }
	local section_renderers = {
		jira = function()
			return M.render_jira_section()
		end,
		reminders = function()
			return M.render_reminders_section()
		end,
		personal = function()
			return M.render_personal_section()
		end,
	}

	for _, section_name in ipairs(sections) do
		local renderer = section_renderers[section_name]
		if renderer then
			local section_lines, section_actions = renderer()
			if section_lines and #section_lines > 0 then
				-- Separator
				table.insert(lines, string.rep("─", 60))
				for j, l in ipairs(section_lines) do
					table.insert(lines, l)
					-- If the section returned actions, map line number to URL
					if section_actions and section_actions[j] then
						actions[#lines] = section_actions[j]
					end
				end
			end
		end
	end

	-- Footer
	table.insert(lines, "")
	table.insert(lines, string.rep("─", 60))
	table.insert(lines, "  Press <Esc> or q to close          :ReminderBriefing")
	table.insert(lines, "")

	return lines, actions
end

--- Render the work reminders section.
---@return string[]|nil
function M.render_reminders_section()
	local reminders = processor.get_reminders()
	local work_reminders = {}
	for _, r in ipairs(reminders) do
		if r.category == "work" then
			table.insert(work_reminders, r)
		end
	end

	if #work_reminders == 0 then
		return nil
	end

	local lines = {}
	table.insert(lines, "  WORK REMINDERS")
	for _, r in ipairs(work_reminders) do
		local schedule = picker.format_schedule(r)
		table.insert(lines, "  ⏰ " .. schedule .. " — " .. r.reminderMsg)
	end
	return lines
end

--- Render the personal reminders section.
---@return string[]|nil
function M.render_personal_section()
	local reminders = processor.get_reminders()
	local personal_reminders = {}
	for _, r in ipairs(reminders) do
		if r.category == "personal" then
			table.insert(personal_reminders, r)
		end
	end

	if #personal_reminders == 0 then
		return nil
	end

	local lines = {}
	table.insert(lines, "  PERSONAL")
	for _, r in ipairs(personal_reminders) do
		local schedule = picker.format_schedule(r)
		table.insert(lines, "  📌 " .. schedule .. " — " .. r.reminderMsg)
	end
	return lines
end

--- Render the calendar section from enabled integrations.
---@return string[]|nil, table|nil lines and line-to-action map
function M.render_calendar_section()
	-- Calendar integrations removed; kept as no-op for custom section configs.
	return nil
end

--- Render the Jira section from jira-cli.
---@return string[]|nil, table|nil lines and line-to-action map
function M.render_jira_section()
	local cfg = config.get()
	if not cfg.jira.enabled then
		return nil
	end

	local ok, jira = pcall(require, "reminders.jira")
	if not ok then
		return nil
	end

	local issues = jira.get_briefing_data()
	if not issues then
		return nil
	end

	local lines = {}
	local line_action_map = {}
	table.insert(lines, "  JIRA ISSUES (" .. #issues .. ")")
	for _, issue in ipairs(issues) do
		local icon = jira.priority_icon(issue.priority)
		local line = string.format("  %s %-12s [%-11s] %s", icon, issue.key, issue.status, issue.summary)
		table.insert(lines, line)
		local url = jira.issue_url(issue.key)
		if url then
			line_action_map[#lines] = url
		end
	end
	return lines, line_action_map
end

--- Placeholder: Outlook section (removed).
---@return string[]|nil
function M.render_outlook_section()
	return nil
end

--- Check whether the briefing has any content worth showing.
---@return boolean
function M.has_content()
	local reminders = processor.get_reminders()
	for _, r in ipairs(reminders) do
		if r.category == "work" then
			return true
		end
	end

	local cfg = config.get()
	if cfg.jira.enabled then
		return true
	end

	return false
end

--- Reposition and resize the briefing window to stay centered.
local function reposition()
	if not briefing_win or not vim.api.nvim_win_is_valid(briefing_win) then
		return
	end
	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)
	vim.api.nvim_win_set_config(briefing_win, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
	})
end

local resize_augroup = vim.api.nvim_create_augroup("RemindersBriefingResize", { clear = true })

--- Close the briefing modal.
function M.close()
	vim.api.nvim_clear_autocmds({ group = resize_augroup })
	if briefing_win and vim.api.nvim_win_is_valid(briefing_win) then
		vim.api.nvim_win_close(briefing_win, true)
	end
	if briefing_buf and vim.api.nvim_buf_is_valid(briefing_buf) then
		vim.api.nvim_buf_delete(briefing_buf, { force = true })
	end
	briefing_win = nil
	briefing_buf = nil
end

--- Open the briefing modal.
function M.open()
	-- Close any existing briefing first
	M.close()

	local lines, actions = build_lines()
	line_actions = actions or {}

	-- Create buffer
	briefing_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(briefing_buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(briefing_buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(briefing_buf, "swapfile", false)
	vim.api.nvim_buf_set_option(briefing_buf, "filetype", "reminders-briefing")

	-- Set content
	vim.api.nvim_buf_set_lines(briefing_buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(briefing_buf, "modifiable", false)

	-- Calculate window dimensions
	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	-- Open floating window
	briefing_win = vim.api.nvim_open_win(briefing_buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " Reminders Briefing ",
		title_pos = "center",
	})

	-- Reposition on terminal resize
	vim.api.nvim_clear_autocmds({ group = resize_augroup })
	vim.api.nvim_create_autocmd("VimResized", {
		group = resize_augroup,
		callback = reposition,
	})

	-- Keymaps to close
	local close_keys = { "q", "<Esc>" }
	for _, key in ipairs(close_keys) do
		vim.api.nvim_buf_set_keymap(briefing_buf, "n", key, "", {
			noremap = true,
			silent = true,
			callback = function()
				M.close()
			end,
		})
	end

	-- <CR> to open action URL (join link, issue URL, etc.)
	vim.api.nvim_buf_set_keymap(briefing_buf, "n", "<CR>", "", {
		noremap = true,
		silent = true,
		callback = function()
			local line_nr = vim.api.nvim_win_get_cursor(0)[1]
			local url = line_actions[line_nr]
			if url then
				vim.fn.setreg("+", url)
				if vim.fn.has("win32") == 1 then
					vim.fn.system('start "" "' .. url .. '"')
				elseif vim.fn.has("mac") == 1 then
					vim.fn.system("open " .. vim.fn.shellescape(url))
				else
					vim.fn.system("xdg-open " .. vim.fn.shellescape(url))
				end
				vim.notify("Opened: " .. url, vim.log.levels.INFO)
			end
		end,
	})
end

return M
