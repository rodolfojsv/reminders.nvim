-- Minimal init.lua for running tests with plenary.busted
-- Usage: nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

-- Add the plugin to the runtime path
local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
vim.opt.rtp:prepend(plugin_root)

-- Add tests directory to Lua path so helpers can be required
package.path = plugin_root .. "/tests/?.lua;" .. package.path

-- Find plenary in common locations
local plenary_path = nil

-- Check standard lazy.nvim location
local lazy_plenary = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"
if vim.fn.isdirectory(lazy_plenary) == 1 then
	plenary_path = lazy_plenary
end

-- Check packer location
if not plenary_path then
	local packer_plenary = vim.fn.stdpath("data") .. "/site/pack/packer/start/plenary.nvim"
	if vim.fn.isdirectory(packer_plenary) == 1 then
		plenary_path = packer_plenary
	end
end

-- Check if plenary passed via environment variable
if not plenary_path then
	local env_path = os.getenv("PLENARY_PATH")
	if env_path and vim.fn.isdirectory(env_path) == 1 then
		plenary_path = env_path
	end
end

if plenary_path then
	vim.opt.rtp:prepend(plenary_path)
else
	print("WARNING: plenary.nvim not found. Tests require plenary.nvim.")
	print("Set PLENARY_PATH env variable or install via your package manager.")
end
