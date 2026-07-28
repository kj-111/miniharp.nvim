---@class MiniharpUI
local M = {}

local marks = require('miniharp.marks')
local state = require('miniharp.state')
local utils = require('miniharp.utils')
local log = require('miniharp.log')

local pin_buf
local pin_augroup
local render

local function has_win(id) return id and vim.api.nvim_win_is_valid(id) end

local function has_buf(id) return id and vim.api.nvim_buf_is_valid(id) end

function M.is_pin_open() return has_win(state.pin_win) and has_buf(pin_buf) end

local function focused() return M.is_pin_open() and vim.api.nvim_get_current_win() == state.pin_win end

-- the file the outline stars: the origin window's buffer while the
-- outline itself has focus, the current buffer otherwise
local function current_file()
  if focused() and has_win(state.origin_win) then return utils.bufname(vim.api.nvim_win_get_buf(state.origin_win)) end
  return utils.bufname()
end

---@return integer|nil
local function current_index()
  local file = current_file()
  for i, m in ipairs(state.marks) do
    if m.file == file then return i end
  end
end

---Build the list rows; row n is always mark n.
---@return string[]
local function build_lines()
  if #state.marks == 0 then return { '' } end

  local current_idx = current_index()
  local lines = {}
  for i, m in ipairs(state.marks) do
    -- the current file shows a star where its number would be
    local id = current_idx == i and '*' or tostring(i)
    lines[i] = id .. ' ' .. vim.fn.fnamemodify(m.file, ':t')
  end
  return lines
end

render = function()
  if not has_buf(pin_buf) then return end

  local lines = build_lines()
  vim.api.nvim_set_option_value('modifiable', true, { buf = pin_buf })
  vim.api.nvim_buf_set_lines(pin_buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = pin_buf })

  if not has_win(state.pin_win) then return end

  -- shrink-to-fit: exactly as wide as the longest row
  local width = 1
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end

  -- glued to the bottom-right corner, directly above the statusline
  vim.api.nvim_win_set_config(state.pin_win, {
    relative = 'editor',
    anchor = 'SE',
    row = math.max(1, vim.o.lines - vim.o.cmdheight - (vim.o.laststatus == 0 and 0 or 1)),
    col = vim.o.columns,
    width = math.min(width, vim.o.columns),
    height = math.min(#lines, math.max(1, vim.o.lines - 4)),
  })
end

local function unfocus()
  if not focused() then return end

  if has_win(state.origin_win) then pcall(vim.api.nvim_set_current_win, state.origin_win) end
  state.origin_win = nil
  render()
end

---@return integer|nil
local function cursor_index()
  local line = vim.api.nvim_win_get_cursor(state.pin_win)[1]
  if state.marks[line] then return line end
end

local function jump_to_cursor_mark()
  local index = cursor_index()
  if not index then return end

  if marks.jump_to(index) then unfocus() end
  render()
end

local function remove_cursor_mark()
  local index = cursor_index()
  if not index then return end

  local ok, removed = marks.remove_at(index)
  if ok then
    log.info('removed %s (%d left)', utils.pretty(removed.file), #state.marks)
    render()
    local maxline = vim.api.nvim_buf_line_count(pin_buf)
    pcall(vim.api.nvim_win_set_cursor, state.pin_win, { math.min(index, maxline), 0 })
  end
end

---@param delta integer
local function move_cursor_mark(delta)
  local index = cursor_index()
  if not index then return end

  local j = marks.move(index, delta)
  if not j then return end

  render()
  pcall(vim.api.nvim_win_set_cursor, state.pin_win, { j, 0 })
end

local function close_pin()
  unfocus()

  if pin_augroup then
    pcall(vim.api.nvim_del_augroup_by_id, pin_augroup)
    pin_augroup = nil
  end

  if has_win(state.pin_win) then pcall(vim.api.nvim_win_close, state.pin_win, true) end
  state.pin_win = nil

  if has_buf(pin_buf) then pcall(vim.api.nvim_buf_delete, pin_buf, { force = true }) end
  pin_buf = nil
end

local function open_pin()
  pin_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value('modifiable', false, { buf = pin_buf })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = pin_buf })
  vim.api.nvim_set_option_value('filetype', 'miniharp', { buf = pin_buf })
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = pin_buf })

  -- placeholder geometry: render() below positions and sizes it.
  -- border only on the sides facing the editor (top + left), so the
  -- outline sits flush against the statusline and screen edge
  state.pin_win = vim.api.nvim_open_win(pin_buf, false, {
    relative = 'editor',
    row = 0,
    col = 0,
    width = 1,
    height = 1,
    style = 'minimal',
    border = { '┌', '─', '─', '', '', '', '', '│' },
    focusable = false,
    noautocmd = true,
  })

  local wo = vim.wo[state.pin_win]
  wo.wrap = false
  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = 'no'
  -- keep the outline unobtrusive: text and border in the dimmest
  -- standard group (opaque, so scrolling underneath never changes
  -- how it looks)
  wo.winhighlight = 'NormalFloat:NonText,FloatBorder:NonText'

  local function map(lhs, rhs, desc)
    vim.keymap.set('n', lhs, rhs, { buffer = pin_buf, silent = true, nowait = true, desc = 'miniharp: ' .. desc })
  end
  map('q', unfocus, 'back to editing')
  map('l', jump_to_cursor_mark, 'jump to mark under cursor')
  map('dd', remove_cursor_mark, 'remove mark under cursor')
  map('<C-j>', function() move_cursor_mark(1) end, 'move mark down')
  map('<C-k>', function() move_cursor_mark(-1) end, 'move mark up')

  pin_augroup = vim.api.nvim_create_augroup('MiniharpPin', { clear = true })
  vim.api.nvim_create_autocmd({ 'BufEnter', 'VimResized' }, {
    group = pin_augroup,
    callback = render,
    desc = 'miniharp: refresh outline',
  })

  render()
end

function M.toggle_pin()
  if M.is_pin_open() then
    close_pin()
    return
  end

  close_pin()
  open_pin()
end

---Enter the outline to interact with it (l, dd, <C-j>/<C-k>, q);
---opens it first when closed. Entering while inside leaves it again.
function M.focus_pin()
  if focused() then
    unfocus()
    return
  end

  if not M.is_pin_open() then open_pin() end

  state.origin_win = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(state.pin_win)
  pcall(vim.api.nvim_win_set_cursor, state.pin_win, { current_index() or 1, 0 })
  render()
end

function M.refresh() render() end

return M
