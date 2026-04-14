local helpers = require("tests.helpers")

describe("reminders.utils", function()
	local utils

	before_each(function()
		helpers.reset_modules()
		utils = require("reminders.utils")
	end)

	describe("trim", function()
		it("removes leading whitespace", function()
			assert.are.equal("hello", utils.trim("   hello"))
		end)

		it("removes trailing whitespace", function()
			assert.are.equal("hello", utils.trim("hello   "))
		end)

		it("removes both leading and trailing whitespace", function()
			assert.are.equal("hello world", utils.trim("  hello world  "))
		end)

		it("returns empty string for empty input", function()
			assert.are.equal("", utils.trim(""))
		end)

		it("returns empty string for whitespace-only input", function()
			assert.are.equal("", utils.trim("   "))
		end)
	end)

	describe("split", function()
		it("splits by whitespace by default", function()
			local result = utils.split("hello world foo")
			assert.are.same({ "hello", "world", "foo" }, result)
		end)

		it("splits by custom separator", function()
			local result = utils.split("14:30", ":")
			assert.are.same({ "14", "30" }, result)
		end)

		it("handles single element", function()
			local result = utils.split("hello")
			assert.are.same({ "hello" }, result)
		end)

		it("handles multiple colons", function()
			local result = utils.split("a:b:c", ":")
			assert.are.same({ "a", "b", "c" }, result)
		end)
	end)

	describe("endswith", function()
		it("returns true when string ends with suffix", function()
			assert.is_true(utils.endswith("hello.lua", ".lua"))
		end)

		it("returns false when string does not end with suffix", function()
			assert.is_false(utils.endswith("hello.lua", ".py"))
		end)

		it("returns true for empty ending", function()
			assert.is_true(utils.endswith("anything", ""))
		end)

		it("handles path separators", function()
			assert.is_true(utils.endswith("C:\\path\\to\\dir\\", "\\"))
			assert.is_true(utils.endswith("/path/to/dir/", "/"))
		end)
	end)

	describe("file_exists", function()
		it("returns true for an existing file", function()
			local tmp = vim.fn.tempname()
			local f = io.open(tmp, "w")
			f:write("test")
			f:close()
			assert.is_true(utils.file_exists(tmp))
			os.remove(tmp)
		end)

		it("returns false for a non-existent file", function()
			assert.is_false(utils.file_exists("/tmp/nonexistent_file_" .. os.time()))
		end)
	end)

	describe("read_all", function()
		it("reads entire file content", function()
			local tmp = vim.fn.tempname()
			local f = io.open(tmp, "w")
			f:write("hello world")
			f:close()
			assert.are.equal("hello world", utils.read_all(tmp))
			os.remove(tmp)
		end)
	end)

	describe("convert_to_epoch", function()
		it("returns a timestamp for today if the time has not passed yet", function()
			-- Use 23:59 which is almost certainly in the future during test runs
			local epoch = utils.convert_to_epoch("23:59")
			local t = os.date("*t", epoch)
			assert.are.equal(23, t.hour)
			assert.are.equal(59, t.min)
			local now = os.date("*t")
			assert.are.equal(now.year, t.year)
			assert.are.equal(now.month, t.month)
			assert.are.equal(now.day, t.day)
		end)

		it("rolls over to tomorrow if the time has already passed", function()
			-- Use 00:00 which is always in the past (unless run exactly at midnight)
			local epoch = utils.convert_to_epoch("0:00")
			local t = os.date("*t", epoch)
			assert.are.equal(0, t.hour)
			assert.are.equal(0, t.min)
			-- Should be tomorrow
			local tomorrow = os.time() + 86400
			local expected = os.date("*t", tomorrow)
			assert.are.equal(expected.year, t.year)
			assert.are.equal(expected.month, t.month)
			assert.are.equal(expected.day, t.day)
		end)

		it("handles single-digit hour", function()
			local epoch = utils.convert_to_epoch("23:05")
			local t = os.date("*t", epoch)
			assert.are.equal(23, t.hour)
			assert.are.equal(5, t.min)
		end)
	end)

	describe("parse_category", function()
		it("extracts work category", function()
			local cat, msg = utils.parse_category("work - Review PR #412", "personal")
			assert.are.equal("work", cat)
			assert.are.equal("Review PR #412", msg)
		end)

		it("extracts personal category", function()
			local cat, msg = utils.parse_category("personal - Gym session", "personal")
			assert.are.equal("personal", cat)
			assert.are.equal("Gym session", msg)
		end)

		it("is case-insensitive for category names", function()
			local cat, msg = utils.parse_category("Work - Important meeting", "personal")
			assert.are.equal("work", cat)
			assert.are.equal("Important meeting", msg)
		end)

		it("returns default for unknown category", function()
			local cat, msg = utils.parse_category("urgent - Fix bug", "personal")
			assert.are.equal("personal", cat)
			assert.are.equal("urgent - Fix bug", msg)
		end)

		it("returns default when no separator present", function()
			local cat, msg = utils.parse_category("Just a plain message", "personal")
			assert.are.equal("personal", cat)
			assert.are.equal("Just a plain message", msg)
		end)

		it("returns default when separator but no category word", function()
			local cat, msg = utils.parse_category("- something", "work")
			assert.are.equal("work", cat)
			assert.are.equal("- something", msg)
		end)

		it("uses provided default_category", function()
			local cat, msg = utils.parse_category("No category here", "work")
			assert.are.equal("work", cat)
			assert.are.equal("No category here", msg)
		end)
	end)

	describe("get_user_input", function()
		it("returns user input from vim.ui.input", function()
			-- vim.ui.input calls callback synchronously in test env
			local original = vim.ui.input
			vim.ui.input = function(opts, cb)
				cb("test response")
			end

			local result = utils.get_user_input("Enter: ")
			assert.are.equal("test response", result)

			vim.ui.input = original
		end)

		it("returns empty string when user cancels", function()
			local original = vim.ui.input
			vim.ui.input = function(opts, cb)
				cb(nil)
			end

			local result = utils.get_user_input("Enter: ")
			assert.are.equal("", result)

			vim.ui.input = original
		end)
	end)
end)
