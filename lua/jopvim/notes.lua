local cache = require('jopvim.cache')

local M = {}
M.getTmpNotePath = function(id)
  return cache.getCacheFileName(id .. ".jop.md")
end

M.saveNoteToLocal = function(id, str)
  local path = M.getTmpNotePath(id)
  cache.saveToCache(path, str)
  return path
end

return M
