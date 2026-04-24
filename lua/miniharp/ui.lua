---@class MiniharpUI
local M = {}

local marks = require('miniharp.marks')
local state = require('miniharp.state')
local utils = require('miniharp.utils')

local ns = vim.api.nvim_create_namespace('MiniharpUI')
local win, buf
local render, close

local function has_win(id) return id and vim.api.nvim_win_is_valid(id) end

local function has_buf(id) return id and vim.api.nvim_buf_is_valid(id) end

local function split_path(path)
  local rel = utils.pretty(path)
  local dir = vim.fn.fnamemodify(rel, ':h')
  local name = vim.fn.fnamemodify(rel, ':t')
  if dir == '.' then dir = '' end
  return name, dir
end

---@return string[], table
local function build_lines()
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
      local marker = current_idx == i and '*' or ' '

      local name, dir = split_path(m.file)
      local prefix = string.format('%s %d. ', marker, i)
      local row = prefix .. name
      local row_meta = {
        index = i,
        line = #lines + 1,
        marker_start = 0,
        marker_end = 1,
        number_start = 2,
        number_end = #prefix,
        name_start = #prefix,
        name_end = #prefix + #name,
        dir_start = nil,
        dir_end = nil,
      }
      if dir ~= '' then
        row = row .. '  ' .. dir
        row_meta.dir_start = #prefix + #name + 2
        row_meta.dir_end = #row
      end

      lines[#lines + 1] = row
      meta.rows[i] = row_meta
    end
  end

  return lines, meta
end

local function apply_highlights(meta)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  if #state.marks == 0 then return end

  for i, row in ipairs(meta.rows) do
    if row.dir_start and row.dir_end then
      vim.api.nvim_buf_add_highlight(buf, ns, 'Comment', row.line - 1, row.dir_start, row.dir_end)
    end

    if meta.current_idx == i then
      vim.api.nvim_buf_add_highlight(buf, ns, 'String', row.line - 1, row.marker_start, row.marker_end)
      vim.api.nvim_buf_add_highlight(buf, ns, 'String', row.line - 1, row.number_start, row.number_end)
      vim.api.nvim_buf_add_highlight(buf, ns, 'String', row.line - 1, row.name_start, row.name_end)
    end
  end
end

---@return integer|nil
local function cursor_mark_index()
  if not has_win(win) then return end

  local line = vim.api.nvim_win_get_cursor(win)[1]
  local _, meta = build_lines()
  for _, row in ipairs(meta.rows) do
    if row.line == line then return row.index end
  end
end

---@param cursor integer[]
local function restore_cursor(cursor)
  if not has_win(win) then return end

  local maxline = vim.api.nvim_buf_line_count(buf)
  pcall(vim.api.nvim_win_set_cursor, win, { math.min(cursor[1], maxline), cursor[2] })
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

  local cursor = vim.api.nvim_win_get_cursor(win)
  local ok = marks.remove_at(index)
  if ok then
    render()
    restore_cursor(cursor)
  end
end

local function position_window(lines)
  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end

  width = math.min(width + 4, math.max(28, math.floor(vim.o.columns * 0.6)))
  local height = math.min(#lines, math.max(4, math.floor(vim.o.lines * 0.6)))
  local max_col = math.max(0, vim.o.columns - width)
  return width, height, 1, max_col
end

render = function()
  if not has_buf(buf) then return end

  local lines, meta = build_lines()
  vim.api.nvim_set_option_value('modifiable', true, { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
  apply_highlights(meta)

  if has_win(win) then
    local width, height, row, col = position_window(lines)
    vim.api.nvim_win_set_config(win, {
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

  state.ui_win = nil
  state.ui_origin_win = nil

  if has_win(win) then pcall(vim.api.nvim_win_close, win, true) end

  if has_buf(buf) then pcall(vim.api.nvim_buf_delete, buf, { force = true }) end

  win, buf = nil, nil
  if has_win(origin) then pcall(vim.api.nvim_set_current_win, origin) end
end

function M.is_open() return has_win(win) and has_buf(buf) end

function M.close()
  if not M.is_open() then return end
  close()
end

function M.refresh()
  if not has_win(win) or not has_buf(buf) then return end
  render()
end

function M.open()
  if has_win(win) then close() end

  state.ui_origin_win = vim.api.nvim_get_current_win()

  buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf })
  vim.api.nvim_set_option_value('filetype', 'miniharp', { buf = buf })
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = buf })

  local lines = build_lines()
  local width, height, row, col = position_window(lines)

  win = vim.api.nvim_open_win(buf, true, {
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
  wo.cursorline = false
  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = 'no'

  vim.keymap.set('n', 'q', close, {
    buffer = buf,
    silent = true,
    nowait = true,
    desc = 'miniharp: close list',
  })
  vim.keymap.set('n', '<Esc>', close, {
    buffer = buf,
    silent = true,
    nowait = true,
    desc = 'miniharp: close list',
  })
  vim.keymap.set('n', '<C-c>', close, {
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
  render()
end

return M
