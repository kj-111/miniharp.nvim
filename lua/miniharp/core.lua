local state = require('miniharp.state')
local ui = require('miniharp.ui')
local utils = require('miniharp.utils')
local marks = require('miniharp.marks')

---@class MiniharpMarks
local M = {}

---@param entry MiniharpMark
local function add_mark(entry)
    table.insert(state.marks, entry)
    state.idx = #state.marks
end

---@param step integer
local function cycle(step)
    if #state.marks == 0 then
        return
    end

    local cursor = state.idx
    if cursor < 0 then
        cursor = 0
    end

    local attempts = #state.marks
    while attempts > 0 and #state.marks > 0 do
        local i = cursor + step
        if i > #state.marks then
            i = 1
        end
        if i < 1 then
            i = #state.marks
        end

        local ok, reason = marks.jump_to(i)
        if ok then
            ui.refresh()
            return
        end
        if reason ~= 'missing-file' then
            return
        end

        attempts = attempts - 1
        if step > 0 then
            cursor = i - 1
        else
            cursor = i
        end
    end

    ui.refresh()
end

-- ---- public API ----

---Toggle a file mark for current buffer.
function M.toggle_file()
    local file = utils.bufname()
    if file == '' then
        vim.notify(
            'miniharp: cannot mark an unnamed buffer',
            vim.log.levels.WARN
        )
        return
    end

    local i = marks.find(file)

    if i then
        marks.remove_at(i)
    else
        local l, c = utils.cursor()
        add_mark({ file = file, lnum = l, col = c })
    end

    ui.refresh()
end

---Update last position for a file.
---@param file string
---@param l integer
---@param c integer
function M.update_last_for_file(file, l, c)
    local i, m = marks.find(file)
    if i then
        m.lnum, m.col = l, c
    end
end

function M.next()
    cycle(1)
end

function M.prev()
    cycle(-1)
end

return M
