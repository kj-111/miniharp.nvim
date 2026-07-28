---@class MiniharpLog
local M = {}

---Whether informational messages are shown (warnings always are).
M.enabled = true

---@param msg string
---@param ... any format args
function M.info(msg, ...)
  if not M.enabled then return end
  vim.notify('miniharp: ' .. msg:format(...), vim.log.levels.INFO)
end

---@param msg string
---@param ... any format args
function M.warn(msg, ...) vim.notify('miniharp: ' .. msg:format(...), vim.log.levels.WARN) end

return M
