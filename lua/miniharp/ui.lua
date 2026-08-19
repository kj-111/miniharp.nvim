---@class MiniharpUI
local M = {}

local marks = require('miniharp.marks')
local state = require('miniharp.state')
local utils = require('miniharp.utils')

local ns = vim.api.nvim_create_namespace('miniharp')

local menu_buf
local menu_augroup
local origin_win
local closing = false

local function has_win(id) return id and vim.api.nvim_win_is_valid(id) end

local function has_buf(id) return id and vim.api.nvim_buf_is_valid(id) end

function M.is_open() return has_win(state.menu_win) and has_buf(menu_buf) end

---Read the list back out of the buffer; the text is the source of truth.
local function sync()
  if not has_buf(menu_buf) then return end

  local previous = state.marks[state.idx]
  local next_marks, seen = {}, {}

  for _, line in ipairs(vim.api.nvim_buf_get_lines(menu_buf, 0, -1, false)) do
    local path = vim.trim(line)
    if path ~= '' then
      local file = utils.norm(path)
      if not seen[file] then
        seen[file] = true
        -- an existing mark keeps its remembered position, a typed one starts at the top
        local _, mark = marks.find(file)
        next_marks[#next_marks + 1] = mark or { file = file, lnum = 1, col = 0 }
      end
    end
  end

  state.marks = next_marks

  state.idx = 0
  if previous then
    for i, m in ipairs(next_marks) do
      if m.file == previous.file then
        state.idx = i
        break
      end
    end
  end

  vim.api.nvim_set_option_value('modified', false, { buf = menu_buf })
end

local function resize()
  if not M.is_open() then return end

  local lines = vim.api.nvim_buf_get_lines(menu_buf, 0, -1, false)
  local width = 30
  for _, line in ipairs(lines) do
    -- +3 for the number column and a column of slack for the cursor
    width = math.max(width, vim.fn.strdisplaywidth(line) + 3)
  end
  width = math.min(width, math.max(20, vim.o.columns - 4))
  local height = math.min(#lines, math.max(1, vim.o.lines - 6))

  vim.api.nvim_win_set_config(state.menu_win, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
  })
end

local function close()
  if closing then return end
  closing = true

  sync()

  if menu_augroup then
    pcall(vim.api.nvim_del_augroup_by_id, menu_augroup)
    menu_augroup = nil
  end

  if has_win(state.menu_win) then pcall(vim.api.nvim_win_close, state.menu_win, true) end
  state.menu_win = nil

  if has_buf(menu_buf) then pcall(vim.api.nvim_buf_delete, menu_buf, { force = true }) end
  menu_buf = nil

  if has_win(origin_win) then pcall(vim.api.nvim_set_current_win, origin_win) end
  origin_win = nil

  closing = false
end

---Close the menu and open whatever file the cursor sits on.
local function open_under_cursor()
  local path = vim.trim(vim.api.nvim_get_current_line())
  close()

  if path == '' then return end
  local i = marks.find(utils.norm(path))
  if i then marks.jump_to(i) end
end

local function open()
  origin_win = vim.api.nvim_get_current_win()

  -- the file the menu stars: the one we were editing when it opened
  local current = utils.bufname()
  local lines, current_row = {}, nil
  for i, m in ipairs(state.marks) do
    lines[i] = utils.pretty(m.file)
    if m.file == current then current_row = i end
  end

  menu_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(menu_buf, 'miniharp')
  vim.api.nvim_buf_set_lines(menu_buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = menu_buf })
  vim.api.nvim_set_option_value('filetype', 'miniharp', { buf = menu_buf })
  -- acwrite so a reflexive :w syncs instead of erroring on the fake name
  vim.api.nvim_set_option_value('buftype', 'acwrite', { buf = menu_buf })
  vim.api.nvim_set_option_value('modified', false, { buf = menu_buf })

  -- placeholder geometry: resize() below centres and sizes it
  state.menu_win = vim.api.nvim_open_win(menu_buf, true, {
    relative = 'editor',
    row = 0,
    col = 0,
    width = 1,
    height = 1,
    style = 'minimal',
    border = 'rounded',
    title = ' miniharp ',
    title_pos = 'center',
  })

  -- style = 'minimal' already clears the rest of the gutter and decorations
  local wo = vim.wo[state.menu_win]
  wo.wrap = false
  -- the line numbers are the mark numbers jump(i) takes
  wo.number = true
  wo.numberwidth = 2

  -- the current file's number is highlighted; re-set because a colorscheme clears links
  vim.api.nvim_set_hl(0, 'MiniharpCurrent', { link = 'Title', default = true })

  local function map(lhs, rhs, desc)
    vim.keymap.set('n', lhs, rhs, { buffer = menu_buf, silent = true, nowait = true, desc = 'miniharp: ' .. desc })
  end
  map('<CR>', open_under_cursor, 'open the file under the cursor')
  map('q', close, 'close the menu')
  map('<Esc>', close, 'close the menu')

  menu_augroup = vim.api.nvim_create_augroup('MiniharpMenu', { clear = true })
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'VimResized' }, {
    group = menu_augroup,
    buffer = menu_buf,
    callback = resize,
    desc = 'miniharp: keep the menu fitted to the list',
  })
  vim.api.nvim_create_autocmd('BufWriteCmd', {
    group = menu_augroup,
    buffer = menu_buf,
    callback = sync,
    desc = 'miniharp: :w applies the edited list',
  })
  vim.api.nvim_create_autocmd('BufLeave', {
    group = menu_augroup,
    buffer = menu_buf,
    callback = close,
    desc = 'miniharp: leaving the menu applies and closes it',
  })

  resize()

  if current_row then
    pcall(vim.api.nvim_win_set_cursor, state.menu_win, { current_row, 0 })
    vim.api.nvim_buf_set_extmark(menu_buf, ns, current_row - 1, 0, { number_hl_group = 'MiniharpCurrent' })
  end
end

---Toggle the mark list: a centred float you edit like any other buffer.
---The text is applied when it closes.
function M.toggle()
  if M.is_open() then
    close()
    return
  end

  open()
end

return M
