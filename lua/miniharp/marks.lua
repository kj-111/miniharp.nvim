local state = require('miniharp.state')
local utils = require('miniharp.utils')
local log = require('miniharp.log')

local uv = vim.uv or vim.loop

local M = {}

---@param file string
---@return integer|nil, MiniharpMark|nil
function M.find(file)
  for i, m in ipairs(state.marks) do
    if m.file == file then return i, m end
  end
end

---@param i integer
function M.remove_at(i)
  if not state.marks[i] then return end

  table.remove(state.marks, i)

  if state.idx > i then
    state.idx = state.idx - 1
  elseif state.idx == i then
    state.idx = math.min(i, #state.marks)
  end
end

---@param i integer
---@return boolean, string?
function M.jump_to(i)
  local mark = state.marks[i]
  if not mark then
    log.warn('no mark #%s', tostring(i))
    return false, 'missing-mark'
  end

  if not uv.fs_stat(mark.file) then
    M.remove_at(i)
    log.warn('removed missing mark %s', utils.pretty(mark.file))
    return false, 'missing-file'
  end

  state.idx = i

  if utils.bufname() ~= mark.file then vim.cmd('edit ' .. vim.fn.fnameescape(mark.file)) end

  local maxline = vim.api.nvim_buf_line_count(0)
  pcall(vim.api.nvim_win_set_cursor, 0, { math.min(mark.lnum, maxline), mark.col })

  return true
end

return M
