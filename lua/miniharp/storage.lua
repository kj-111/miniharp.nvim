---@class MiniharpStorage
local M = {}

local state = require('miniharp.state')
local utils = require('miniharp.utils')

-- Compute a session file path for a given cwd.
---@param cwd? string
---@return string path
local function session_path(cwd)
  local key = vim.fn.sha256(utils.norm(cwd or state.cwd or vim.fn.getcwd()))
  return vim.fn.stdpath('state') .. '/miniharp/sessions/session-' .. key .. '.json'
end

---Save current marks for the cwd into stdpath('state'|'data')/miniharp/sessions.
---@param cwd? string
---@return boolean ok, string? err
function M.save(cwd)
  local path = session_path(cwd)
  local payload = {
    version = 2,
    marks = state.marks or {},
  }

  local ok, json = pcall(vim.json.encode, payload)
  if not ok then return false, 'JSON encode failed' end

  local mk_ok, made = pcall(vim.fn.mkdir, vim.fn.fnamemodify(path, ':h'), 'p')
  if not mk_ok or made ~= 1 then return false, ('could not create %s'):format(vim.fn.fnamemodify(path, ':h')) end

  local lines = vim.split(json, '\n', { plain = true })
  local w_ok, res = pcall(vim.fn.writefile, lines, path)
  if not w_ok then return false, ('write failed: %s'):format(res or path) end
  -- writefile signals some failures via a -1 return instead of an error
  if res ~= 0 then return false, ('write failed: %s'):format(path) end

  return true
end

---Load marks for the cwd, replacing current state if a session file exists.
---@param cwd? string
---@return boolean ok, string? err
function M.load(cwd)
  local path = session_path(cwd)
  if vim.fn.filereadable(path) ~= 1 then return false, 'no session file for cwd' end

  local ok_read, content = pcall(function() return table.concat(vim.fn.readfile(path), '\n') end)
  if not ok_read then return false, 'read failed' end

  local ok_json, data = pcall(vim.json.decode, content)
  if not ok_json or type(data) ~= 'table' then return false, 'JSON decode failed' end

  local restored = {}
  if type(data.marks) == 'table' then
    for _, m in ipairs(data.marks) do
      if m and type(m.file) == 'string' and tonumber(m.lnum) and tonumber(m.col) then
        table.insert(restored, {
          file = utils.norm(m.file),
          lnum = tonumber(m.lnum) or 1,
          col = tonumber(m.col) or 0,
        })
      end
    end
  end

  state.marks = restored
  state.idx = 0

  return true
end

return M
