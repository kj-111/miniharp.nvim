---@class MiniharpUI
local M = {}

local marks = require('miniharp.marks')
local state = require('miniharp.state')
local utils = require('miniharp.utils')
local log = require('miniharp.log')

local ns = vim.api.nvim_create_namespace('MiniharpUI')
local buf
local render, close
local default_width = 42
local default_height = 5

local function has_win(id) return id and vim.api.nvim_win_is_valid(id) end

local function has_buf(id) return id and vim.api.nvim_buf_is_valid(id) end

---@param compact? boolean -- pin style: no marker column, "1 name" rows
---@return string[], table
local function build_lines(compact)
  local lines = {}
  local current_file = ''
  local current_idx
  local meta = {
    rows = {},
    current_idx = nil,
  }

  if has_win(state.ui_origin_win) then
    local origin_buf = vim.api.nvim_win_get_buf(state.ui_origin_win)
    current_file = utils.bufname(origin_buf)
  else
    current_file = utils.bufname()
  end

  for i, m in ipairs(state.marks) do
    if m.file == current_file then
      current_idx = i
      break
    end
  end

  meta.current_idx = current_idx

  if #state.marks == 0 then
    lines[#lines + 1] = ''
  else
    for i, m in ipairs(state.marks) do
      local name = vim.fn.fnamemodify(m.file, ':t')
      local prefix = compact and string.format('%d ', i) or string.format('%d. ', i)
      local row = prefix .. name
      local row_meta = {
        index = i,
        line = #lines + 1,
        marker_start = 0,
        name_end = #row,
      }

      lines[#lines + 1] = row
      meta.rows[i] = row_meta
    end
  end

  return lines, meta
end

---@param target_buf integer
local function apply_highlights(target_buf, meta)
  vim.api.nvim_buf_clear_namespace(target_buf, ns, 0, -1)

  if #state.marks == 0 then return end

  for i, row in ipairs(meta.rows) do
    if meta.current_idx == i then
      vim.api.nvim_buf_set_extmark(target_buf, ns, row.line - 1, row.marker_start, {
        end_col = row.name_end,
        hl_group = 'String',
      })
    end
  end
end

---@param target_buf integer
---@param compact? boolean
---@return string[], table
local function set_lines(target_buf, compact)
  local lines, meta = build_lines(compact)
  vim.api.nvim_set_option_value('modifiable', true, { buf = target_buf })
  vim.api.nvim_buf_set_lines(target_buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = target_buf })
  apply_highlights(target_buf, meta)
  return lines, meta
end

---@return integer|nil
local function cursor_mark_index()
  if not has_win(state.ui_win) then return end

  local line = vim.api.nvim_win_get_cursor(state.ui_win)[1]
  local _, meta = build_lines()
  for _, row in ipairs(meta.rows) do
    if row.line == line then return row.index end
  end
end

---@param cursor integer[]
local function restore_cursor(cursor)
  if not has_win(state.ui_win) then return end

  local maxline = vim.api.nvim_buf_line_count(buf)
  pcall(vim.api.nvim_win_set_cursor, state.ui_win, { math.min(cursor[1], maxline), cursor[2] })
end

local function jump_to_cursor_mark()
  local index = cursor_mark_index()
  if not index then return end

  local ok = marks.jump_to(index)
  if not ok then
    render()
    return
  end

  close()
end

local function remove_cursor_mark()
  local index = cursor_mark_index()
  if not index then return end

  local cursor = vim.api.nvim_win_get_cursor(state.ui_win)
  local ok, removed = marks.remove_at(index)
  if ok then
    log.info('removed %s (%d left)', utils.pretty(removed.file), #state.marks)
    render()
    restore_cursor(cursor)
  end
end

---@param delta integer
local function move_cursor_mark(delta)
  local index = cursor_mark_index()
  if not index then return end

  local j = marks.move(index, delta)
  if not j then return end

  render()

  local _, meta = build_lines()
  local row = meta.rows[j]
  if row then pcall(vim.api.nvim_win_set_cursor, state.ui_win, { row.line, 0 }) end
end

local function position_window(lines)
  local width = default_width
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end

  width = math.min(width, math.max(1, vim.o.columns - 4))
  local height = math.min(default_height, math.max(1, vim.o.lines - 4))
  local row = math.max(1, math.floor((vim.o.lines - height) / 2) - 1)
  local col = math.max(0, math.floor((vim.o.columns - width) / 2))

  return width, height, row, col
end

render = function()
  if not has_buf(buf) then return end

  local lines = set_lines(buf)

  if has_win(state.ui_win) then
    local width, height, row, col = position_window(lines)
    vim.api.nvim_win_set_config(state.ui_win, {
      relative = 'editor',
      row = row,
      col = col,
      width = width,
      height = height,
    })
  end
end

close = function()
  local origin = state.ui_origin_win
  local ui_win = state.ui_win

  state.ui_win = nil
  state.ui_origin_win = nil

  if has_win(ui_win) then pcall(vim.api.nvim_win_close, ui_win, true) end

  if has_buf(buf) then pcall(vim.api.nvim_buf_delete, buf, { force = true }) end

  buf = nil
  if has_win(origin) then pcall(vim.api.nvim_set_current_win, origin) end
end

-- ---- pinned outline: a small non-focusable float that stays open ----

local pin_buf
local pin_augroup
-- shrink-to-fit: the window is exactly as wide as its longest row
local pin_min_width = 1

local function render_pin()
  if not has_buf(pin_buf) then return end

  local lines = set_lines(pin_buf, true)

  if not has_win(state.pin_win) then return end

  local width = pin_min_width
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  width = math.min(width, math.max(1, vim.o.columns - 4))
  local height = math.min(#lines, math.max(1, vim.o.lines - 4))

  vim.api.nvim_win_set_config(state.pin_win, {
    relative = 'editor',
    anchor = 'SW',
    row = math.max(1, vim.o.lines - 2),
    col = 0,
    width = width,
    height = height,
  })
end

local function close_pin()
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

  state.pin_win = vim.api.nvim_open_win(pin_buf, false, {
    relative = 'editor',
    anchor = 'SW',
    row = math.max(1, vim.o.lines - 2),
    col = 0,
    width = pin_min_width,
    height = 1,
    style = 'minimal',
    border = 'rounded',
    focusable = false,
    noautocmd = true,
  })

  local wo = vim.wo[state.pin_win]
  wo.wrap = false
  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = 'no'
  -- keep the outline unobtrusive: dimmed text, blended background
  wo.winblend = 30
  wo.winhighlight = 'NormalFloat:Comment'

  pin_augroup = vim.api.nvim_create_augroup('MiniharpPin', { clear = true })
  vim.api.nvim_create_autocmd({ 'BufEnter', 'VimResized' }, {
    group = pin_augroup,
    callback = render_pin,
    desc = 'miniharp: refresh pinned outline',
  })

  render_pin()
end

function M.is_pin_open() return has_win(state.pin_win) and has_buf(pin_buf) end

function M.toggle_pin()
  if M.is_pin_open() then
    close_pin()
    return
  end

  close_pin()
  open_pin()
end

function M.is_open() return has_win(state.ui_win) and has_buf(buf) end

function M.close()
  if not M.is_open() then return end
  close()
end

function M.refresh()
  if M.is_open() then render() end
  if M.is_pin_open() then render_pin() end
end

function M.open()
  if has_win(state.ui_win) then close() end

  state.ui_origin_win = vim.api.nvim_get_current_win()

  buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf })
  vim.api.nvim_set_option_value('filetype', 'miniharp', { buf = buf })
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = buf })

  local lines = build_lines()
  local width, height, row, col = position_window(lines)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    row = row,
    col = col,
    width = width,
    height = height,
    style = 'minimal',
    border = 'rounded',
    noautocmd = true,
  })

  state.ui_win = win

  local wo = vim.wo[win]
  wo.wrap = false
  wo.cursorline = true
  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = 'no'

  vim.keymap.set('n', 'q', close, {
    buffer = buf,
    silent = true,
    nowait = true,
    desc = 'miniharp: close list',
  })
  vim.keymap.set('n', 'l', jump_to_cursor_mark, {
    buffer = buf,
    silent = true,
    nowait = true,
    desc = 'miniharp: jump to mark under cursor',
  })
  vim.keymap.set('n', 'dd', remove_cursor_mark, {
    buffer = buf,
    silent = true,
    nowait = true,
    desc = 'miniharp: remove mark under cursor',
  })
  vim.keymap.set('n', '<C-j>', function() move_cursor_mark(1) end, {
    buffer = buf,
    silent = true,
    nowait = true,
    desc = 'miniharp: move mark down',
  })
  vim.keymap.set('n', '<C-k>', function() move_cursor_mark(-1) end, {
    buffer = buf,
    silent = true,
    nowait = true,
    desc = 'miniharp: move mark up',
  })
  render()
end

return M
