local Path = require('plenary.path')
local api = require('jopvim.api')
local index = require('jopvim.index')
local notes = require('jopvim.notes')
local util = require('jopvim.util')

local M = {}

local function splitNoteData(fileData)
  local metadata = {}
  local body = {}
  local lNo = 1
  if (fileData[1]:find('```', 1, true) == 1) then -- if start with ``` then we treat it as metadata
    lNo = 2
    while (fileData[lNo]:find('```', 1, true) ~= 1) do
      local line = fileData[lNo]
      local index = line:find(':', 1, true)
      if index ~= nil then
        metadata[line:sub(1, index-1)] = line:sub(index + 1, #line)
      end
      lNo = lNo + 1
    end
    lNo = lNo + 1
  end
  for i=lNo,#fileData,1 do
    table.insert(body, fileData[i])
  end
  return metadata, table.concat(body, "\n")
end

local _JOPLIN_WHITELIST_NOTES_METADATA = {
  "title", "is_todo"
}

M.saveFile = function()
  local id = vim.fn.fnamemodify(vim.fn.expand('%:t:r'), ":r")
  if id ~= nil then
    local path = notes.getTmpNotePath(id)
    local f= io.open(path, "r")
    if f == nil then
      return
    end
    -- read the file
    local fileData = {}
    for line in f:lines() do
      fileData[#fileData + 1] = line
    end
    -- get the metadata
    local metadata, body = splitNoteData(fileData)
    local note = { body = body }
    for _, key in ipairs(_JOPLIN_WHITELIST_NOTES_METADATA) do
      if metadata[key] ~= nil then
        note[key] = metadata[key]
      end
    end
    api.updateNote(id, note)
    index.refreshNote(id, note)
  end
end

local downloadNote = function(id)
  local note = api.getNote(id, 'body,title,is_todo')

  if note == nil then return nil end

  local data = {'```'}
  table.insert(data, 'title:'..note.title)
  table.insert(data, 'is_todo:'..note.is_todo)
  table.insert(data, '```')
  table.insert(data, note.body)

  local path = notes.saveNoteToLocal(id, table.concat(data, "\n"))
  return path
end

M.openNote = function(id)
  local path = downloadNote(id)
  print(id)
  if path ~= nil then vim.cmd("edit" .. path) end
end

M.create_note = function(fid, open_note)
  local nid = api.createNote(fid)
  if nid == nil then return end
  if open_note == true then M.openNote(nid) end
end

M.setup = function(cfg)
  conf.setup(cfg)
  -- create the tmp directory if does not exists
  local rootDir = Path:new(util.getRootDir())
  if not rootDir:exists() then
    rootDir:mkdir()
  end
  -- set up autocmd
  vim.cmd([[
    autocmd BufWritePost *.jop.md lua require('jopvim').saveFile()
    command! JopvimUpdateIndex lua require('jopvim.index').update()
  ]])
end
return M
