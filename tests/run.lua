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

-- toggle on/off
vim.cmd('edit lua/miniharp/init.lua')
miniharp.toggle_file()
vim.cmd('edit lua/miniharp/core.lua')
miniharp.toggle_file()
assert(#state.marks == 2, 'expected 2 marks after toggling two files')
miniharp.toggle_file()
assert(#state.marks == 1, 'expected toggle to remove the current file mark')
miniharp.toggle_file()

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

-- list toggling, dd to remove, l to jump
miniharp.show_list()
assert(ui.is_open(), 'list should be open')
miniharp.show_list()
assert(not ui.is_open(), 'list should toggle closed')
miniharp.show_list()
vim.api.nvim_win_set_cursor(state.ui_win, { 1, 0 })
feed('dd')
assert(#state.marks == 1, 'dd in the list should remove a mark')
feed('l')
assert(not ui.is_open(), 'l should jump and close the list')
assert(vim.fn.expand('%:t') == 'core.lua', 'l should open the mark under the cursor')

-- reorder with <C-j>/<C-k>
vim.cmd('edit lua/miniharp/init.lua')
miniharp.toggle_file()
assert(#state.marks == 2, 'expected 2 marks before reordering')
assert(vim.fn.fnamemodify(state.marks[1].file, ':t') == 'core.lua', 'core.lua should start as mark 1')
miniharp.show_list()
vim.api.nvim_win_set_cursor(state.ui_win, { 1, 0 })
feed('<C-j>')
assert(vim.fn.fnamemodify(state.marks[2].file, ':t') == 'core.lua', 'C-j should move the mark down')
feed('<C-k>')
assert(vim.fn.fnamemodify(state.marks[1].file, ':t') == 'core.lua', 'C-k should move the mark back up')
feed('<C-k>') -- at the top edge: no-op
assert(vim.fn.fnamemodify(state.marks[1].file, ':t') == 'core.lua', 'C-k at the top should do nothing')
miniharp.show_list()
vim.cmd('edit lua/miniharp/init.lua')
miniharp.toggle_file()
vim.cmd('edit lua/miniharp/core.lua')

-- user command
vim.cmd('Miniharp toggle')
assert(#state.marks == 0, ':Miniharp toggle should remove the mark')
vim.cmd('Miniharp toggle')

-- pinned outline: stays open, follows the current buffer, live-updates
miniharp.toggle_pin()
assert(ui.is_pin_open(), 'pin should be open')
local pin_buf = vim.api.nvim_win_get_buf(state.pin_win)
local pin_lines = vim.api.nvim_buf_get_lines(pin_buf, 0, -1, false)
assert(pin_lines[1] == '* core.lua', 'current file shows a star instead of its number, got: ' .. pin_lines[1])
vim.cmd('edit lua/miniharp/marks.lua')
miniharp.toggle_file()
pin_lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(state.pin_win), 0, -1, false)
assert(#pin_lines == 2, 'pin should live-update after adding a mark')
assert(pin_lines[1] == '1 core.lua', 'non-current file keeps its number, got: ' .. pin_lines[1])
assert(pin_lines[2] == '* marks.lua', 'the new current mark shows the star, got: ' .. pin_lines[2])
miniharp.toggle_file()
vim.cmd('edit lua/miniharp/core.lua')
miniharp.toggle_pin()
assert(not ui.is_pin_open(), 'pin should toggle closed')

-- save/load round-trip
assert(storage.save())
state.marks = {}
assert(storage.load())
assert(#state.marks == 1, 'expected marks to survive a save/load round-trip')

-- DirChanged: marks swap per cwd and come back
local other = vim.fn.tempname()
vim.fn.mkdir(other, 'p')
vim.cmd('cd ' .. vim.fn.fnameescape(other))
assert(#state.marks == 0, 'a fresh cwd should start without marks')
vim.cmd('cd ' .. vim.fn.fnameescape(root))
assert(#state.marks == 1, 'returning to the project should restore its marks')

print('ALL OK')
