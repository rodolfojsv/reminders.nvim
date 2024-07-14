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
:RemindMeDailyAt 12:35 (Same as before, but the previous one will just be executed one time, this one is daily)
:ReminderClose (close notification)
:ReminderRemoveAt 1 (Removes reminder at index 1, indexes are now shown as part of the title)
:ReminderRemoveAll
```


My keymaps: 
```
  vim.keymap.set('n', '<leader>rme', ':RemindMeEvery ', { desc = '[R]emind [M]e [E]very and type minutes' }),
  vim.keymap.set('n', '<leader>rma', ':RemindMeAt ', { desc = '[R]emind [M]e [A]t and type hour of day (24h)' }),
  vim.keymap.set('n', '<leader>rmda', ':RemindMeDailyAt ', { desc = '[R]emind [M]e [D]aily [A]t and type hour of day (24h)' }),
  vim.keymap.set('n', '<leader>rmc', ':ReminderClose<CR>', { desc = '[R]e[m]inder [C]lose' }),
  vim.keymap.set('n', '<leader>rmrz', ':ReminderRemoveAll<CR>', { desc = '[R]e[m]inder [R]emove All' }),
  vim.keymap.set('n', '<leader>rmra', ':ReminderRemoveAt ', { desc = '[R]e[m]inder [R]emove [A]t' }),
```
