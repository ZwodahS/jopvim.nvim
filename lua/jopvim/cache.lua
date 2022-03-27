local util = require("jopvim.util")
local M = {}

M.get_cache_file_name = function(filename)
  return util.joinPath(vim.fn.stdpath("cache"), "jop", filename)
end

M.get_cache = function(filename, decode_json)
  local path = M.get_cache_file_name(filename)
  local f = io.open(path, "r")
  if f == nil then
      return nil
  end
  local t = f:read("*all")
  if decode_json ~= true then
    return t
  end

  local j = vim.fn.json_decode(t)
  return j
end

M.save_to_cache = function(path, str)
  local f = io.open(path, "w")
  if f == nil then
    return
  end
  io.output(f)
  io.write(str)
  io.close(f)
end

return M
