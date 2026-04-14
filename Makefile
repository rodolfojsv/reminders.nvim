.PHONY: test test-utils test-config test-processor test-commands test-picker test-briefing test-jira

MINIMAL_INIT = tests/minimal_init.lua

# Run all tests
test:
	nvim --headless -u $(MINIMAL_INIT) -c "PlenaryBustedDirectory tests/ {minimal_init = '$(MINIMAL_INIT)'}"

# Run individual test suites
test-utils:
	nvim --headless -u $(MINIMAL_INIT) -c "PlenaryBustedFile tests/utils_spec.lua"

test-config:
	nvim --headless -u $(MINIMAL_INIT) -c "PlenaryBustedFile tests/config_spec.lua"

test-processor:
	nvim --headless -u $(MINIMAL_INIT) -c "PlenaryBustedFile tests/processor_spec.lua"

test-commands:
	nvim --headless -u $(MINIMAL_INIT) -c "PlenaryBustedFile tests/commands_spec.lua"

test-picker:
	nvim --headless -u $(MINIMAL_INIT) -c "PlenaryBustedFile tests/picker_spec.lua"

test-briefing:
	nvim --headless -u $(MINIMAL_INIT) -c "PlenaryBustedFile tests/briefing_spec.lua"

test-jira:
	nvim --headless -u $(MINIMAL_INIT) -c "PlenaryBustedFile tests/jira_spec.lua"
