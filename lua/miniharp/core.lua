local state = require('miniharp.state')
local ui = require('miniharp.ui')
local utils = require('miniharp.utils')
local marks = require('miniharp.marks')
local log = require('miniharp.log')

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
    log.info('no marks yet, use toggle_file to add one')
    return
  end

  local cursor = state.idx
  if cursor < 0 then cursor = 0 end

  local attempts = #state.marks
  while attempts > 0 and #state.marks > 0 do
    local i = cursor + step
    if i > #state.marks then i = 1 end
    if i < 1 then i = #state.marks end

    local ok, reason = marks.jump_to(i)
    if ok then
      ui.refresh()
      return
    end
    if reason ~= 'missing-file' then return end

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

---Toggle a file mark for the current buffer, or for `file` when given.
---@param file? string
function M.toggle_file(file)
  file = file and utils.norm(file) or utils.bufname()
  if file == '' then
    log.warn('cannot mark an unnamed buffer')
    return
  end

  local i = marks.find(file)

  if i then
    marks.remove_at(i)
    log.info('removed %s (%d left)', utils.pretty(file), #state.marks)
  else
    local l, c = 1, 0
    if file == utils.bufname() then
      l, c = utils.cursor()
    end
    add_mark({ file = file, lnum = l, col = c })
    log.info('added %s as mark %d', utils.pretty(file), #state.marks)
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

function M.next() cycle(1) end

function M.prev() cycle(-1) end

---Jump directly to mark #i.
---@param i integer
function M.jump(i)
  if type(i) ~= 'number' or i < 1 or i % 1 ~= 0 then
    log.warn('jump expects a positive mark number')
    return
  end

  if marks.jump_to(i) then ui.refresh() end
end

return M
