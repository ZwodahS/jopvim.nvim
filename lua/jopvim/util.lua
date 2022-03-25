local M = {}

local path_sep = vim.loop.os_uname().sysname == "Windows" and "\\" or "/"
M.joinPath = function(...)
  return table.concat(vim.tbl_flatten({ ... }), path_sep)
end

M.getRootDir = function()
  return M.joinPath(vim.fn.stdpath("cache"), "jop")
end

return M
