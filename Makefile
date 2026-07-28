.PHONY: test lint

# isolate session files so tests never touch real state
test:
	XDG_STATE_HOME=$$(mktemp -d) nvim --headless --clean -c 'set rtp+=.' -l tests/run.lua

lint:
	stylua --check lua/ plugin/ tests/
