local curl = require('plenary.curl')
local json = require('plenary.json')
local Path = require('plenary.path')

local M = {}

local _JOPLIN_WHITELIST_NOTES_METADATA = {
  "title"
}

_JOPLIN_CFG = {
  token_path = nil,
  token = nil,
  url = 'localhost',
  port = '41184'
}

local path_sep = vim.loop.os_uname().sysname == "Windows" and "\\" or "/"
local function path_join(...)
  return table.concat(vim.tbl_flatten({ ... }), path_sep)
end

local function getCacheFileName(filename)
  return path_join(vim.fn.stdpath("cache"), "jop", filename)
end

local function getRootdir()
  return path_join(vim.fn.stdpath("cache"), "jop")
end

local function getLocalFilePath(id)
  return getCacheFileName(id .. ".jop.md")
end

local function getCache(filename, decode_json)
  local path = getCacheFileName(filename)
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

local function saveToCache(path, str)
  local f = io.open(path, "w")
  if f == nil then
    return
  end
  io.output(f)
  io.write(str)
  io.close(f)
end

local function saveNoteToLocal(id, str)
  local path = getLocalFilePath(id)
  saveToCache(path, str)
  return path
end

local function getServerURL()
  return 'http://' .. _JOPLIN_CFG.url .. ":" .. _JOPLIN_CFG.port
end

local function get(url, request)
  url = getServerURL() .. url
  if request.query == nil then
    request.query = {}
  end
  request.query.token = _JOPLIN_CFG.token
  local response = curl.get(url, request)

  if response.status == 200 then
    response.json = vim.fn.json_decode(response.body)
  end
  return response
end

local function put(url, request)
  url = getServerURL() .. url
  if request.query == nil then
    request.query = {}
  end
  request.query.token = _JOPLIN_CFG.token
  local response = curl.put(url, request)

  if response.status == 200 then
    response.json = vim.fn.json_decode(response.body)
  end
  return response
end

local function downloadNote(id)
  local response = get("/notes/" .. id, { query = { fields = 'body,title' } })
  if response.status == 200 then
    local data = {'```'}
    table.insert(data, 'title:'..response.json.title)
    table.insert(data, '```')
    table.insert(data, response.json.body)
    local path = saveNoteToLocal(id, table.concat(data, "\n"))
    return path
  end
  return nil
end

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

local function uploadFile(id)
  -- make sure that the file exists
  local path = getLocalFilePath(id)
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
  -- construct the request json body
  local jsonBody = { body = body }
  for _, key in ipairs(_JOPLIN_WHITELIST_NOTES_METADATA) do
    if metadata[key] ~= nil then
      jsonBody[key] = metadata[key]
    end
  end
  -- @todo need to update the index with the new notes' title so we don't have to fetch the index
  -- update the note
  local body = vim.fn.json_encode(jsonBody)
  local request = { body = body }
  local response = put('/notes/' .. id, request)
end

local function getAllFolders()
  local folders = {}
  local has_next = true
  local page = 1
  while has_next == true do
    local response = get('/folders', { query = { fields = 'title,id,parent_id', page = page } })
    has_next = response.json.has_more
    for k, fdr in ipairs(response.json.items) do
      folders[fdr.id] = fdr
      fdr.type = 2
    end
    page = page + 1
  end
  return folders
end

local function getNotesInFolder(id)
  local notes = {}
  local has_next = true
  local page = 1
  while has_next == true do
    local response = get('/folders/' .. id .. '/notes', { query = { fields = 'title,id,parent_id', page = page } })
    has_next = response.json.has_more
    for k, note in ipairs(response.json.items) do
      notes[note.id] = note
      note.type = 1
    end
    page = page + 1
  end
  return notes
end

local function getFullFolderName(index, id)
  if index[id] == nil then
    return ''
  end
  if index[id].fullname == nil then
    local parent_name = getFullFolderName(index, index[id].parent_id)
    local fullname = index[id].title
    if parent_name ~= '' then
      fullname = parent_name .. '/' .. fullname
    end
    index[id].fullname = fullname
  end
  return index[id].fullname
end

local function getFolderName(index, id)
  if index[id] == nil then return '' end
  return index[id].title
end

local function saveIndex(index)
  local encoded = vim.fn.json_encode(index)
  local index_path = path_join(vim.fn.stdpath("cache"), "jop", 'notes.index')
  saveToCache(index_path, encoded)
end

M.updateNotesIndex = function()
  -- Mon 11:32:41 14 Mar 2022
  -- not sure how to do this better
  -- fetch all the folders first
  local index = getAllFolders()
  -- for each of the folders, we set the full title
  for id in pairs(index) do
    -- just precompute all the folder name
    getFullFolderName(index, id)
  end
  local notesIndex = {}
  -- for each folder, also index the notes in it
  for id in pairs(index) do
    local notes = getNotesInFolder(id)
    for nid in pairs(notes) do
      notesIndex[nid] = notes[nid]
    end
  end

  for nid in pairs(notesIndex) do
    index[nid] = notesIndex[nid]
    index[nid].type = 1
    local fparent = getFullFolderName(index, notesIndex[nid].parent_id)
    local parent = getFolderName(index, notesIndex[nid].parent_id)
    local fullname = notesIndex[nid].title
    if fparent ~= nil then fullname = fparent .. "/" .. fullname end
    index[nid].fullname = fullname
    index[nid].parentname = parent
  end
  saveIndex(index)
end

M.saveFile = function()
  local id = vim.fn.fnamemodify(vim.fn.expand('%:t:r'), ":r")
  if id ~= nil then
    uploadFile(id)
  end
end

M.getNotesIndex = function()
  local index = getCache('notes.index', true)
  return index
end

M.openNote = function(id)
  local path = downloadNote(id)
  if path ~= nil then vim.cmd("edit" .. path) end
end

M.setup = function(cfg)
  cfg = cfg or {}
  if type(cfg) == "table" then
    _JOPLIN_CFG = vim.tbl_extend("keep", cfg, _JOPLIN_CFG)
  end

  if _JOPLIN_CFG.token == nil and _JOPLIN_CFG.token_path ~= nil then
    local f = io.open(_JOPLIN_CFG.token_path, "r")
    if f ~= nil then
      _JOPLIN_CFG.token = f:read("*line")
    end
  end

  local rootDir = Path:new(getRootdir())
  if not rootDir:exists() then
    rootDir:mkdir()
  end

  vim.cmd([[
    autocmd BufWritePost *.jop.md lua require('jopvim').saveFile()
    command! JopvimUpdateIndex lua require('jopvim').updateNotesIndex()
  ]])
end
return M
