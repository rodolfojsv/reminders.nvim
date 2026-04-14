--- Jira integration via the jira-cli tool (https://github.com/ankitpokhrel/jira-cli).
--- Shells out to the `jira` command to fetch issues assigned to the current user.

local config = require("reminders.config")
local utils = require("reminders.utils")

local M = {}

--- Cached issues from last fetch.
local cached_issues = {}
--- Last fetch timestamp.
local last_fetch = 0
--- Whether the disk cache has been loaded this session.
local disk_cache_loaded = false

local CACHE_FILE = "jira_cache.json"

--- Get the jira config section.
---@return table
local function get_jira_config()
	return config.get().jira
end

--- Get the full path to the cache file.
---@return string
local function cache_path()
	local dir = config.get().directory_path
	if not utils.endswith(dir, "/") and not utils.endswith(dir, "\\") then
		dir = dir .. "/"
	end
	return dir .. CACHE_FILE
end

--- Persist current cached issues to disk.
local function save_cache()
	local path = cache_path()
	local data = {
		updated_at = os.time(),
		date = os.date("%Y-%m-%d"),
		issues = cached_issues,
	}
	local ok, json = pcall(vim.fn.json_encode, data)
	if not ok then
		return
	end
	local f = io.open(path, "w")
	if f then
		f:write(json)
		f:close()
	end
end

--- Load cached issues from disk (only today's data).
---@return boolean loaded
local function load_cache()
	if disk_cache_loaded then
		return #cached_issues > 0
	end
	disk_cache_loaded = true

	local path = cache_path()
	if not utils.file_exists(path) then
		return false
	end
	local content = utils.read_all(path)
	if not content or content == "" then
		return false
	end
	local ok, data = pcall(vim.fn.json_decode, content)
	if not ok or not data then
		return false
	end
	if data.date ~= os.date("%Y-%m-%d") then
		return false
	end
	if data.issues and #data.issues > 0 then
		cached_issues = data.issues
		last_fetch = data.updated_at or 0
		return true
	end
	return false
end

--- Build the jira CLI command arguments for listing issues.
---@return string[] args
local function build_list_args()
	local jira_cfg = get_jira_config()
	local bin = jira_cfg.bin or "jira"

	local args = {
		bin, "issue", "list",
		"--plain", "--no-headers", "--no-truncate",
		"--columns", "key,type,status,priority,summary",
	}

	-- Use custom JQL if provided, otherwise query all assigned issues
	if jira_cfg.jql and jira_cfg.jql ~= "" then
		table.insert(args, "--jql")
		table.insert(args, jira_cfg.jql)
	else
		table.insert(args, "--jql")
		table.insert(args, "assignee=currentUser() AND resolution=Unresolved")
	end

	return args
end

--- Parse tab-separated output from jira CLI into issue tables.
---@param output string Raw CLI stdout
---@return table[] issues
function M.parse_output(output)
	if not output or output == "" then
		return {}
	end

	local issues = {}
	for line in output:gmatch("[^\r\n]+") do
		line = vim.trim(line)
		if line ~= "" then
			-- Columns: KEY, TYPE, STATUS, PRIORITY, SUMMARY (tab-separated)
			local parts = utils.split(line, "\t")
			if #parts >= 5 then
				table.insert(issues, {
					key = vim.trim(parts[1]),
					type = vim.trim(parts[2]),
					status = vim.trim(parts[3]),
					priority = vim.trim(parts[4]),
					summary = vim.trim(parts[5]),
				})
			elseif #parts >= 3 then
				-- Fallback: at least key, type, status
				table.insert(issues, {
					key = vim.trim(parts[1]),
					type = vim.trim(parts[2]),
					status = vim.trim(parts[3]),
					priority = parts[4] and vim.trim(parts[4]) or "",
					summary = parts[5] and vim.trim(parts[5]) or "",
				})
			end
		end
	end

	return issues
end

--- Build the browse URL for an issue.
---@param issue_key string e.g. "PROJ-123"
---@return string|nil url
function M.issue_url(issue_key)
	local jira_cfg = get_jira_config()
	local host = jira_cfg.host
	if not host or host == "" then
		return nil
	end
	-- Ensure no trailing slash
	host = host:gsub("/$", "")
	return host .. "/browse/" .. issue_key
end

--- Fetch issues from Jira CLI.
---@param force boolean|nil Force refresh ignoring cache interval
---@return table[] issues
function M.fetch(force)
	local jira_cfg = get_jira_config()
	local now = os.time()

	-- Respect cache / refresh interval
	if not force and last_fetch > 0 then
		local interval_sec = (jira_cfg.refresh_interval_minutes or 15) * 60
		if (now - last_fetch) < interval_sec then
			return cached_issues
		end
	end

	local args = build_list_args()
	local result = vim.system(args, { text = true, timeout = 30000 }):wait()

	if result.code ~= 0 then
		-- Non-zero may just mean "no results" — check stderr
		if result.stderr and result.stderr:find("No result found") then
			cached_issues = {}
			last_fetch = now
			save_cache()
			return cached_issues
		end
		-- Actual error
		if result.stderr and result.stderr ~= "" then
			vim.notify("Jira CLI error: " .. vim.trim(result.stderr), vim.log.levels.WARN)
		end
		return cached_issues
	end

	local issues = M.parse_output(result.stdout)

	-- Filter excluded statuses
	local exclude = {}
	for _, s in ipairs(jira_cfg.exclude_statuses or {}) do
		exclude[s:lower()] = true
	end
	if next(exclude) then
		local filtered = {}
		for _, issue in ipairs(issues) do
			if not exclude[issue.status:lower()] then
				table.insert(filtered, issue)
			end
		end
		issues = filtered
	end

	cached_issues = issues
	last_fetch = now
	save_cache()
	return issues
end

--- Get issues, loading from disk cache if needed.
---@return table[] issues
function M.get_issues()
	if #cached_issues == 0 then
		load_cache()
	end
	return M.fetch(false)
end

--- Get briefing data for the Jira section.
---@return table[]|nil issues
function M.get_briefing_data()
	if not get_jira_config().enabled then
		return nil
	end
	local issues = M.get_issues()
	if #issues == 0 then
		return nil
	end
	return issues
end

--- Refresh issues (for manual command).
function M.refresh()
	M.fetch(true)
end

--- Get a priority icon for display.
---@param priority string
---@return string
function M.priority_icon(priority)
	local icons = {
		highest = "🔴",
		high = "🟠",
		medium = "🟡",
		low = "🟢",
		lowest = "⚪",
	}
	return icons[priority:lower()] or "⚪"
end

return M
