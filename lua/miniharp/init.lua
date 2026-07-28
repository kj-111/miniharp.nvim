---@class Miniharp
local M = {}

local state = require('miniharp.state')
local utils = require('miniharp.utils')
local core = require('miniharp.core')
local storage = require('miniharp.storage')
local ui = require('miniharp.ui')
local log = require('miniharp.log')

local function is_missing_session(err) return err and string.find(err, 'no session file for cwd', 1, true) end

-- Create (or reuse) the plugin augroup
local function ensure_group()
  if state.augroup then return end
  state.augroup = vim.api.nvim_create_augroup('Miniharp', { clear = true })
end

-- Track last cursor pos for marked files when leaving a buffer
local function ensure_position_tracking()
  ensure_group()
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
  ensure_group()
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = state.augroup,
    callback = function() storage.save() end,
    desc = 'miniharp: save marks session for cwd',
  })
end

local function ensure_dirchange()
  ensure_group()
  vim.api.nvim_create_autocmd('DirChanged', {
    group = state.augroup,
    callback = function()
      local new_cwd = utils.norm(vim.fn.getcwd())
      local old_cwd = state.cwd
      if old_cwd == new_cwd then return end

      local ok, err = storage.save(old_cwd)
      if not ok then
        -- keep the old session active so marks aren't lost; a later save can retry
        log.warn('save failed for %s - %s (keeping current marks)', vim.fn.fnamemodify(old_cwd, ':~:.'), err or 'unknown error')
        return
      end

      state.marks = {}
      state.idx = 0
      ui.refresh()

      ok, err = storage.load(new_cwd)
      if ok then
        if #state.marks > 0 then log.info('restored %d mark(s) for %s', #state.marks, vim.fn.fnamemodify(new_cwd, ':~')) end
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

function M.show_list()
  if ui.is_open() then
    ui.close()
    return
  end

  ui.open({})
end

---@class MiniharpOpts
---@field notify? boolean -- show info notifications for add/remove/jump/restore (default: true)

---Setup miniharp.
---@param opts? MiniharpOpts
function M.setup(opts)
  opts = opts or {}
  if opts.notify ~= nil then log.enabled = opts.notify end

  ensure_position_tracking()

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
