local curl = require('plenary.curl')
local json = require('plenary.json')
local c = require('jopvim.conf')
local notes = require('jopvim.notes')

local _JOPLIN_WHITELIST_NOTES_METADATA = {
  "title", "is_todo"
}

-- Wrap various api of joplin. Implement on a need basis

local function getServerURL()
  return 'http://' .. c.config.url .. ":" .. c.config.port
end

local function post(url, request)
  url = getServerURL() .. url
  if request.query == nil then
    request.query = {}
  end
  request.query.token = c.config.token
  local response = curl.post(url, request)

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
  request.query.token = c.config.token
  local response = curl.put(url, request)

  if response.status == 200 then
    response.json = vim.fn.json_decode(response.body)
  end
  return response
end

local function get(url, request)
  url = getServerURL() .. url
  if request.query == nil then
    request.query = {}
  end
  request.query.token = c.config.token
  local response = curl.get(url, request)

  if response.status == 200 then
    response.json = vim.fn.json_decode(response.body)
  end
  return response
end

local M = {}

M.updateNote = function(id, note)
  local body = vim.fn.json_encode(note)
  local request = { body = body }
  local response = put('/notes/' .. id, request)
  return response.json
end

M.getAllFolders = function()
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

M.getNote = function(id, fields)
  local response = get("/notes/" .. id, { query = { fields = fields } })
  if response.status ~= 200 then return nil end
  return response.json
end

M.getNotesInFolder = function(id)
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

M.createNote = function(parent_id)
  local data = { title = "", parent_id = parent_id, body = "" }
  local jsonData = vim.fn.json_encode(data)
  local response = post("/notes", { body = jsonData })
  if response.code == 200 then
    return response.json.id
  end
  return nil
end

return M

