---@class Miniharp
local M = {}

local state = require('miniharp.state')
local utils = require('miniharp.utils')
local core = require('miniharp.core')
local storage = require('miniharp.storage')
local ui = require('miniharp.ui')
local log = require('miniharp.log')

local function is_missing_session(err) return err and string.find(err, 'no session file for cwd', 1, true) end

-- Track last cursor pos for marked files when leaving a buffer
local function ensure_position_tracking()
  vim.api.nvim_create_autocmd('BufLeave', {
    group = state.augroup,
    callback = function(args)
      local file = utils.bufname(args.buf)
      if file == '' then return end
      local l, c = utils.cursor(0)
      core.update_last_for_file(file, l, c)
    end,
    desc = 'miniharp: remember last position for file marks',
  })
end

local function ensure_persist_on_exit()
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = state.augroup,
    callback = function() storage.save() end,
    desc = 'miniharp: save marks session for cwd',
  })
end

local function ensure_dirchange()
  vim.api.nvim_create_autocmd('DirChanged', {
    group = state.augroup,
    callback = function()
      local new_cwd = utils.norm(vim.fn.getcwd())
      local old_cwd = state.cwd
      if old_cwd == new_cwd then return end

      local ok, err = storage.save(old_cwd)
      if not ok then
        -- keep the old session active so marks aren't lost; a later save can retry
        log.warn(
          'save failed for %s - %s (keeping current marks)',
          vim.fn.fnamemodify(old_cwd, ':~:.'),
          err or 'unknown error'
        )
        return
      end

      state.marks = {}
      state.idx = 0
      ui.refresh()

      ok, err = storage.load(new_cwd)
      if ok then
        if #state.marks > 0 then
          log.info('restored %d mark(s) for %s', #state.marks, vim.fn.fnamemodify(new_cwd, ':~'))
        end
      elseif not is_missing_session(err) then
        log.warn('%s', err or 'unknown error')
      end

      state.cwd = new_cwd
    end,
    desc = 'miniharp: handle marks on DirChanged',
  })
end

M.toggle_file = core.toggle_file
M.next = core.next
M.prev = core.prev
M.jump = core.jump

---Toggle the outline: a small float glued to the bottom-right that stays open.
function M.toggle_pin() ui.toggle_pin() end

---Enter the outline to interact with it (l, dd, <C-j>/<C-k>, q);
---opens it first when closed. Entering while inside leaves it again.
function M.focus_pin() ui.focus_pin() end

---@class MiniharpOpts
---@field notify? boolean -- show info notifications for add/remove/jump/restore (default: true)
---@field pin? boolean -- open the pinned outline on startup (default: false)

---Setup miniharp.
---@param opts? MiniharpOpts
function M.setup(opts)
  opts = opts or {}
  if opts.notify ~= nil then log.enabled = opts.notify end

  -- clear = true keeps setup idempotent: re-running replaces the autocmds
  state.augroup = vim.api.nvim_create_augroup('Miniharp', { clear = true })

  ensure_position_tracking()

  if opts.pin then
    local open_pin = function()
      if not ui.is_pin_open() then ui.toggle_pin() end
    end
    if vim.v.vim_did_enter == 1 then
      open_pin()
    else
      vim.api.nvim_create_autocmd('VimEnter', {
        group = state.augroup,
        once = true,
        callback = open_pin,
        desc = 'miniharp: open outline on startup',
      })
    end
  end

  local ok, err = storage.load()
  if ok then
    if #state.marks > 0 then log.info('restored %d mark(s) for cwd', #state.marks) end
  elseif not is_missing_session(err) then
    log.warn('%s', err or 'unknown error')
  end

  ensure_persist_on_exit()
  ensure_dirchange()
end

return M
