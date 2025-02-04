# reminders.nvim
Plugin to handle reminders in neovim 

Recommended to view notifications: rcarriga/nvim-notify

Features:

Handle one time reminders: Will trigger, notify and be forgotten about. 
Handle periodical reminders: They will get stored in a JSON file, this applies for a daily reminder or a every x minutes reminder

For this it is required to use 

```
  NOTE: it should be a path in which neovim can write in, the file will be created, it does not take in a file name
  require('reminders').setup { directory_path = '/pathtodirectory/' },
```

Install using lazy: 

```

  'rodolfojsv/reminders.nvim',

```


Commands included:

```
:RemindMeEvery x (in minutes) 
:RemindMeAt 12:35 (can only pass the hour and it will add :00 to the end)
:RemindMeIn 15 (remind me in 15 minutes)
:RemindMeDailyAt 12:35 (Same as before, but the previous one will just be executed one time, this one is daily)
:ReminderClose (close notification)
:ReminderRemoveAt 1 (Removes reminder at index 1, indexes are now shown as part of the title)
:ReminderRemoveAll
:ReminderFocusModeOff
:ReminderFocusModeOn
```


My keymaps: 
```
  vim.keymap.set('n', '<leader>rme', ':RemindMeEvery ', { desc = '[R]emind [M]e [E]very and type minutes' }),
  vim.keymap.set('n', '<leader>rma', ':RemindMeAt ', { desc = '[R]emind [M]e [A]t and type hour of day (24h)' }),
  vim.keymap.set('n', '<leader>rmi', ':RemindMeIn ', { desc = '[R]emind [M]e [I]n and type minutes' }),
  vim.keymap.set('n', '<leader>rmda', ':RemindMeDailyAt ', { desc = '[R]emind [M]e [D]aily [A]t and type hour of day (24h)' }),
  vim.keymap.set('n', '<leader>rmc', ':ReminderClose<CR>', { desc = '[R]e[m]inder [C]lose' }),
  vim.keymap.set('n', '<leader>rmrz', ':ReminderRemoveAll<CR>', { desc = '[R]e[m]inder [R]emove All' }),
  vim.keymap.set('n', '<leader>rmra', ':ReminderRemoveAt ', { desc = '[R]e[m]inder [R]emove [A]t' }),
  vim.keymap.set('n', '<leader>rmfo', ':ReminderFocusModeOff<CR>', { desc = '[R]e[m]inder [F]ocusMode [O]ff' }),
  vim.keymap.set('n', '<leader>rmfm', ':ReminderFocusModeOn<CR>', { desc = '[R]e[m]inder [F]ocus[M]ode On' }),
```

Creating default persistent reminders from your init source file: 

```
      local function load_reminders()
            reminders.AddReminder({
                reminderMsg = "Hydrate",
                remindEvery = "22",
                persistent = true,
                daily = false,
            })
            reminders.AddReminder({
                reminderMsg = "Scrum",
                remindAt = "9:28",
                persistent = true,
                daily = true,
            })
        end
```

To remove all reminders and reload your defaults you can do something similar to this: 

```
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
        vim.keymap.set('n', '<leader>rr', map_reload, { desc = 'reload reminders from source control' } )
```
