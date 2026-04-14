local config = require("reminders.config")
local processor = require("reminders.processor")
local commands = require("reminders.commands")

local M = {}
local timer = nil
local has_notify = false

M.add_reminder = processor.add_reminder
M.remove_all_reminders = processor.remove_all_reminders

-- Backward compat aliases
M.AddReminder = processor.add_reminder
M.RemoveAllReminders = processor.remove_all_reminders

function M.has_notify_fn()
	return has_notify
end

function M.restart_timer()
	if timer then
		timer:again()
	end
end

function M.stop_timer()
	if timer then
		timer:stop()
	end
end

function M.setup(options)
	options = options or {}
	config.setup(options)

	local cfg = config.get()
	local interval_ms = (cfg.minute_interval or 1) * 60 * 1000

	processor.initialize_file_path(cfg.directory_path)
	processor.initialize_reminders_from_file(cfg.default_category)

	timer = vim.loop.new_timer()

	local ok, notify = pcall(require, "notify")
	if ok then
		vim.notify = notify
		has_notify = true
	end

	local function on_timer()
		if processor.process_timer_callback() then
			timer:stop()
		end
	end

	timer:start(interval_ms, interval_ms, vim.schedule_wrap(on_timer))

	-- Register all user commands
	commands.register(M.has_notify_fn, M.restart_timer, M.stop_timer)

	-- Startup briefing autocmd
	if cfg.briefing and cfg.briefing.on_startup then
		vim.api.nvim_create_autocmd("VimEnter", {
			callback = function()
				-- Defer to let dashboard or other startup plugins render first
				vim.defer_fn(function()
					local briefing = require("reminders.briefing")
					if briefing.has_content() then
						briefing.open()
					end
				end, 200)
			end,
			once = true,
		})
	end
end

return M
