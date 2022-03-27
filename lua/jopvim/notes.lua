local cache = require('jopvim.cache')

local M = {}
M.get_tmp_note_path = function(id)
  return cache.get_cacheFileName(id .. ".jop.md")
end

M.save_note_to_local = function(id, str)
  local path = M.get_tmp_note_path(id)
  cache.save_to_cache(path, str)
  return path
end

return M
