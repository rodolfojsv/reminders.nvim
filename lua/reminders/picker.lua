local processor = require("reminders.processor")
local utils = require("reminders.utils")
local config = require("reminders.config")

local M = {}

--- Format a reminder's schedule as a human-readable string.
---@param r table
---@return string
function M.format_schedule(r)
	if r.persistent and r.daily then
		-- Daily reminder — show the time
		local t = os.date("*t", r.reminderDate)
		return string.format("Daily at %02d:%02d", t.hour, t.min)
	elseif r.persistent and r.remindEvery then
		return "Every " .. r.remindEvery .. "m"
	elseif r.reminderDate then
		local diff = r.reminderDate - os.time()
		if diff <= 0 then
			return "Now"
		elseif diff < 3600 then
			return "In " .. math.ceil(diff / 60) .. "m"
		else
			local h = math.floor(diff / 3600)
			local m = math.ceil((diff % 3600) / 60)
			return string.format("In %dh %dm", h, m)
		end
	end
	return ""
end

--- Category icon helper.
---@param category string
---@return string
local function cat_icon(category)
	if category == "work" then
		return "[W]"
	end
	return "[P]"
end

---------------------------------------------------------------------------
-- Fallback UI (vim.ui.select / vim.ui.input) — always available
---------------------------------------------------------------------------

local reminder_types = {
	{ label = "In X minutes", key = "in" },
	{ label = "At HH:MM", key = "at" },
	{ label = "Every X minutes", key = "every" },
	{ label = "Daily at HH:MM", key = "daily" },
}

local categories = { "work", "personal" }

--- Multi-step new-reminder flow using vim.ui.
local function new_reminder_fallback()
	-- Step 1: Type
	vim.ui.select(
		vim.tbl_map(function(t)
			return t.label
		end, reminder_types),
		{ prompt = "Reminder type:" },
		function(_, idx)
			if not idx then
				return
			end
			local chosen = reminder_types[idx]

			-- Step 2: Time value
			local time_prompt = ({
				["in"] = "Minutes from now: ",
				at = "Time (HH:MM): ",
				every = "Interval in minutes: ",
				daily = "Time (HH:MM): ",
			})[chosen.key]

			vim.ui.input({ prompt = time_prompt }, function(time_val)
				if not time_val or time_val == "" then
					return
				end

				-- Step 3: Category
				vim.ui.select(categories, { prompt = "Category:" }, function(cat)
					if not cat then
						cat = config.get().default_category
					end

					-- Step 4: Message
					vim.ui.input({ prompt = "Reminder message: " }, function(msg)
						if not msg or msg == "" then
							return
						end

						local reminder = { reminderMsg = msg, category = cat }

						if chosen.key == "in" then
							reminder.remindIn = time_val
							reminder.persistent = false
						elseif chosen.key == "at" then
							if not string.find(time_val, ":") then
								time_val = time_val .. ":00"
							end
							reminder.remindAt = time_val
							reminder.persistent = false
						elseif chosen.key == "every" then
							reminder.remindEvery = time_val
							reminder.persistent = true
							reminder.daily = false
						elseif chosen.key == "daily" then
							if not string.find(time_val, ":") then
								time_val = time_val .. ":00"
							end
							reminder.remindAt = time_val
							reminder.persistent = true
							reminder.daily = true
						end

						processor.add_reminder(reminder)
						print("\nReminder added: " .. msg)
					end)
				end)
			end)
		end
	)
end

---------------------------------------------------------------------------
-- Telescope-based UI
---------------------------------------------------------------------------

local function has_telescope()
	local ok, _ = pcall(require, "telescope")
	return ok
end

--- Telescope picker showing all active reminders.
local function list_reminders_telescope()
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	local reminders = processor.get_reminders()
	local entries = {}
	for i, r in ipairs(reminders) do
		table.insert(entries, {
			display = string.format(
				"%d  %s  %-12s  %s",
				i,
				cat_icon(r.category or "personal"),
				M.format_schedule(r),
				r.reminderMsg
			),
			ordinal = r.reminderMsg .. " " .. (r.category or ""),
			index = i,
			reminder = r,
		})
	end

	pickers
		.new({}, {
			prompt_title = "Reminders",
			finder = finders.new_table({
				results = entries,
				entry_maker = function(e)
					return {
						value = e,
						display = e.display,
						ordinal = e.ordinal,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(prompt_bufnr, map)
				-- <C-d> delete reminder
				map("i", "<C-d>", function()
					local entry = action_state.get_selected_entry()
					if entry then
						processor.remove_reminder(entry.value.index)
						actions.close(prompt_bufnr)
						vim.notify("Reminder deleted", vim.log.levels.INFO)
					end
				end)

				-- <C-t> toggle category
				map("i", "<C-t>", function()
					local entry = action_state.get_selected_entry()
					if entry then
						local r = entry.value.reminder
						r.category = r.category == "work" and "personal" or "work"
						processor.save_file()
						actions.close(prompt_bufnr)
						-- Re-open to refresh display
						M.list_reminders()
					end
				end)

				-- <CR> — close for now (edit can be added later)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
				end)

				return true
			end,
		})
		:find()
end

--- Fallback reminder list using vim.ui.select.
local function list_reminders_fallback()
	local reminders = processor.get_reminders()
	if #reminders == 0 then
		vim.notify("No active reminders", vim.log.levels.INFO)
		return
	end

	local items = {}
	for i, r in ipairs(reminders) do
		table.insert(
			items,
			string.format(
				"%d  %s  %-12s  %s",
				i,
				cat_icon(r.category or "personal"),
				M.format_schedule(r),
				r.reminderMsg
			)
		)
	end

	vim.ui.select(items, { prompt = "Reminders (select to delete):" }, function(_, idx)
		if not idx then
			return
		end
		vim.ui.select({ "Delete", "Toggle category", "Cancel" }, { prompt = "Action:" }, function(action)
			if action == "Delete" then
				processor.remove_reminder(idx)
				vim.notify("Reminder deleted", vim.log.levels.INFO)
			elseif action == "Toggle category" then
				local r = reminders[idx]
				r.category = r.category == "work" and "personal" or "work"
				processor.save_file()
				vim.notify("Category changed to " .. r.category, vim.log.levels.INFO)
			end
		end)
	end)
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function M.new_reminder()
	if has_telescope() then
		-- Telescope new-reminder could be fancier, but the multi-step flow
		-- works well with vim.ui since each step is sequential input.
		-- Use the fallback flow which chains vim.ui calls cleanly.
		new_reminder_fallback()
	else
		new_reminder_fallback()
	end
end

function M.list_reminders()
	if has_telescope() then
		list_reminders_telescope()
	else
		list_reminders_fallback()
	end
end

return M
