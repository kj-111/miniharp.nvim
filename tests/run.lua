-- End-to-end smoke test. Run with: make test
local miniharp = require('miniharp')
local state = require('miniharp.state')
local storage = require('miniharp.storage')
local ui = require('miniharp.ui')

local root = vim.fn.getcwd()

-- --clean skips plugin loading, so pull in the user command by hand
vim.cmd('source plugin/miniharp.lua')

local function feed(keys) vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), 'x', false) end

miniharp.setup()
assert(#state.marks == 0, 'expected a clean session, got ' .. #state.marks .. ' marks')

-- setup is idempotent: calling it again must not duplicate autocmds
miniharp.setup()
local autocmds = vim.api.nvim_get_autocmds({ group = 'Miniharp' })
assert(#autocmds == 3, 'expected 3 autocmds after a second setup, got ' .. #autocmds)

-- toggle on/off
vim.cmd('edit lua/miniharp/init.lua')
miniharp.toggle_file()
vim.cmd('edit lua/miniharp/core.lua')
miniharp.toggle_file()
assert(#state.marks == 2, 'expected 2 marks after toggling two files')
miniharp.toggle_file()
assert(#state.marks == 1, 'expected toggle to remove the current file mark')
miniharp.toggle_file()

-- toggle by path (e.g. from a file explorer like oil.nvim)
miniharp.toggle_file('lua/miniharp/marks.lua')
assert(#state.marks == 3, 'toggle_file(path) should add a mark for another file')
assert(vim.fn.fnamemodify(state.marks[3].file, ':t') == 'marks.lua', 'the path mark should point at marks.lua')
assert(state.marks[3].lnum == 1, 'a path mark starts at line 1')
miniharp.toggle_file('lua/miniharp/marks.lua')
assert(#state.marks == 2, 'toggle_file(path) should remove an existing mark')

-- direct jump
vim.cmd('edit lua/miniharp/ui.lua')
miniharp.jump(1)
assert(vim.fn.expand('%:t') == 'init.lua', 'jump(1) should open the first mark')
miniharp.jump(99) -- out of range: warns, no error

-- next/prev wrap around
miniharp.next()
assert(vim.fn.expand('%:t') == 'core.lua', 'next should move to mark 2')
miniharp.next()
assert(vim.fn.expand('%:t') == 'init.lua', 'next should wrap back to mark 1')
miniharp.prev()
assert(vim.fn.expand('%:t') == 'core.lua', 'prev should wrap to the last mark')

-- the menu: a centred float whose text is the list
miniharp.toggle_menu()
assert(ui.is_open(), 'toggle_menu should open the menu')
assert(vim.api.nvim_get_current_win() == state.menu_win, 'the menu takes focus')
local menu_buf = vim.api.nvim_win_get_buf(state.menu_win)
local lines = vim.api.nvim_buf_get_lines(menu_buf, 0, -1, false)
assert(#lines == 2, 'expected one line per mark, got ' .. #lines)
assert(lines[1] == 'lua/miniharp/init.lua', 'a line is just the path, got: ' .. lines[1])
assert(vim.api.nvim_win_get_cursor(state.menu_win)[1] == 2, 'cursor should start on the current file')
miniharp.toggle_menu()
assert(not ui.is_open(), 'toggle_menu should close the menu')
assert(#state.marks == 2, 'closing an untouched menu leaves the list alone')

-- editing the buffer edits the list: dd removes a mark
miniharp.toggle_menu()
vim.api.nvim_win_set_cursor(state.menu_win, { 1, 0 })
feed('dd')
feed('q')
assert(not ui.is_open(), 'q should close the menu')
assert(#state.marks == 1, 'a deleted line should drop its mark')
assert(vim.fn.fnamemodify(state.marks[1].file, ':t') == 'core.lua', 'the surviving mark should be core.lua')

-- a typed path adds a mark, blank lines are ignored
miniharp.toggle_menu()
menu_buf = vim.api.nvim_win_get_buf(state.menu_win)
vim.api.nvim_buf_set_lines(menu_buf, 0, -1, false, { 'lua/miniharp/init.lua', '', 'lua/miniharp/core.lua' })
feed('q')
assert(#state.marks == 2, 'a typed path should become a mark, got ' .. #state.marks)
assert(vim.fn.fnamemodify(state.marks[1].file, ':t') == 'init.lua', 'the typed path should be mark 1')
assert(state.marks[1].lnum == 1, 'a typed mark starts at line 1')

-- reordering is just moving lines around
miniharp.toggle_menu()
vim.api.nvim_win_set_cursor(state.menu_win, { 1, 0 })
feed('ddp')
feed('q')
assert(vim.fn.fnamemodify(state.marks[1].file, ':t') == 'core.lua', 'moving a line should reorder the marks')
assert(vim.fn.fnamemodify(state.marks[2].file, ':t') == 'init.lua', 'moving a line should reorder the marks')

-- l opens the file under the cursor and closes the menu
vim.cmd('edit lua/miniharp/ui.lua')
miniharp.toggle_menu()
vim.api.nvim_win_set_cursor(state.menu_win, { 1, 0 })
feed('l')
assert(not ui.is_open(), 'l should close the menu')
assert(vim.fn.expand('%:t') == 'core.lua', 'l should open the mark under the cursor')

-- <CR> does the same
vim.cmd('edit lua/miniharp/ui.lua')
vim.cmd('Miniharp menu')
assert(ui.is_open(), ':Miniharp menu should open the menu')
vim.api.nvim_win_set_cursor(state.menu_win, { 2, 0 })
feed('<CR>')
assert(not ui.is_open(), '<CR> should close the menu')
assert(vim.fn.expand('%:t') == 'init.lua', '<CR> should open the mark under the cursor')

-- user command
vim.cmd('Miniharp toggle')
assert(#state.marks == 1, ':Miniharp toggle should remove the mark')
vim.cmd('Miniharp toggle')
assert(#state.marks == 2, ':Miniharp toggle should add it back')

-- save/load round-trip
assert(storage.save())
state.marks = {}
assert(storage.load())
assert(#state.marks == 2, 'expected marks to survive a save/load round-trip')

-- DirChanged: marks swap per cwd and come back
local other = vim.fn.tempname()
vim.fn.mkdir(other, 'p')
vim.cmd('cd ' .. vim.fn.fnameescape(other))
assert(#state.marks == 0, 'a fresh cwd should start without marks')
vim.cmd('cd ' .. vim.fn.fnameescape(root))
assert(#state.marks == 2, 'returning to the project should restore its marks')

print('ALL OK')
