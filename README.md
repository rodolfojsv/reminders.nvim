# reminders.nvim
Plugin to handle reminders in neovim 

Recommended to view notifications: rcarriga/nvim-notify

## Features

- **One-time reminders** — trigger, notify, and be forgotten about
- **Periodic reminders** — stored in a JSON file (daily or every X minutes)
- **Briefing modal** — a startup dashboard showing your reminders and Jira issues
- **Jira integration** — pull assigned issues via [jira-cli](https://github.com/ankitpokhrel/jira-cli) and display them in the briefing
- **Telescope picker** — create and manage reminders through a picker UI
- **Categories** — organize reminders as `work` or `personal`

## Installation

Install using lazy:

```lua
  'rodolfojsv/reminders.nvim',
```

## Setup

```lua
require('reminders').setup {
  -- Required: path where the reminder JSON file will be stored (directory only, no file name)
  directory_path = '/pathtodirectory/',

  -- Default category for new reminders ("personal" or "work")
  default_category = "personal",

  -- Briefing modal settings
  briefing = {
    on_startup = false,       -- open briefing automatically when Neovim starts
    greeting = true,          -- show greeting with time of day
    name = "Your Name",       -- name shown in the greeting
    sections = { "jira", "reminders", "personal" },  -- order and visibility of sections
  },

  -- Jira integration (requires jira-cli: https://github.com/ankitpokhrel/jira-cli)
  -- Run `jira init` before enabling this feature
  jira = {
    enabled = false,
    bin = "jira",             -- path to jira-cli binary
    host = "",                -- e.g. "https://yourcompany.atlassian.net"
    jql = "",                 -- custom JQL query (optional)
    exclude_statuses = { "Done", "Closed" },
    refresh_interval_minutes = 15,
  },

  -- Picker backend
  picker = {
    backend = "telescope",
  },
}
```

## Commands

```
:RemindMeEvery x            Remind every x minutes
:RemindMeAt 12:35           Remind at a specific time (24h format)
:RemindMeIn 15              Remind in 15 minutes
:RemindMeDailyAt 12:35      Daily reminder at a specific time
:ReminderClose              Close the current notification
:ReminderRemoveAt 1         Remove reminder at index 1
:ReminderRemoveAll          Remove all reminders
:ReminderFocusModeOn        Suppress notifications
:ReminderFocusModeOff       Resume notifications
:ReminderNew                Create a new reminder via picker UI
:ReminderList               View and manage active reminders
:ReminderBriefing           Open the briefing modal
:ReminderJiraRefresh        Refresh Jira issues from CLI
```

When creating a reminder, you can prefix the message with a category:
```
work - Deploy the release
personal - Buy groceries
```

## Keymaps

```lua
vim.keymap.set('n', '<leader>rme', ':RemindMeEvery ', { desc = '[R]emind [M]e [E]very and type minutes' })
vim.keymap.set('n', '<leader>rma', ':RemindMeAt ', { desc = '[R]emind [M]e [A]t and type hour of day (24h)' })
vim.keymap.set('n', '<leader>rmi', ':RemindMeIn ', { desc = '[R]emind [M]e [I]n and type minutes' })
vim.keymap.set('n', '<leader>rmda', ':RemindMeDailyAt ', { desc = '[R]emind [M]e [D]aily [A]t and type hour of day (24h)' })
vim.keymap.set('n', '<leader>rmc', ':ReminderClose<CR>', { desc = '[R]e[m]inder [C]lose' })
vim.keymap.set('n', '<leader>rmrz', ':ReminderRemoveAll<CR>', { desc = '[R]e[m]inder [R]emove All' })
vim.keymap.set('n', '<leader>rmra', ':ReminderRemoveAt ', { desc = '[R]e[m]inder [R]emove [A]t' })
vim.keymap.set('n', '<leader>rmfo', ':ReminderFocusModeOff<CR>', { desc = '[R]e[m]inder [F]ocusMode [O]ff' })
vim.keymap.set('n', '<leader>rmfm', ':ReminderFocusModeOn<CR>', { desc = '[R]e[m]inder [F]ocus[M]ode On' })
vim.keymap.set('n', '<leader>rmb', ':ReminderBriefing<CR>', { desc = '[R]e[m]inder [B]riefing' })
vim.keymap.set('n', '<leader>rmn', ':ReminderNew<CR>', { desc = '[R]e[m]inder [N]ew' })
vim.keymap.set('n', '<leader>rml', ':ReminderList<CR>', { desc = '[R]e[m]inder [L]ist' })
```

## Briefing

The briefing is a floating modal that shows a summary of your day. Open it with `:ReminderBriefing` or set `briefing.on_startup = true` to open it automatically.

Inside the briefing:
- Press `<CR>` on a Jira issue to open it in your browser
- Press `q` or `<Esc>` to close

## Jira Integration

Requires [jira-cli](https://github.com/ankitpokhrel/jira-cli). Run `jira init` once to authenticate, then enable in your config:

```lua
jira = {
  enabled = true,
  host = "https://yourcompany.atlassian.net",
},
```

Use `:ReminderJiraRefresh` to manually refresh issues. Issues auto-refresh based on `refresh_interval_minutes`.

## Creating Default Persistent Reminders

You can define defaults in your init file:

```lua
local function load_reminders()
  reminders.AddReminder({
    reminderMsg = "Hydrate",
    remindEvery = "22",
    persistent = true,
    daily = false,
    category = "personal",
  })
  reminders.AddReminder({
    reminderMsg = "Scrum",
    remindAt = "9:28",
    persistent = true,
    daily = true,
    category = "work",
  })
end
```

To remove all reminders and reload your defaults:

```lua
-- if there is no reminder file then create one with default events
if vim.fn.filereadable(reminder_json_file) ~= 1 then
  load_reminders()
end

-- function to reload default events
local function map_reload()
  reminders.RemoveAllReminders()
  load_reminders()
end

-- keymap to reload reminders file from source
vim.keymap.set('n', '<leader>rr', map_reload, { desc = 'reload reminders from source control' })
```
