local curl = require('plenary.curl')
local json = require('plenary.json')
local c = require('jopvim.conf')
local notes = require('jopvim.notes')

local _JOPLIN_WHITELIST_NOTES_METADATA = {
  "title", "is_todo"
}

-- Wrap various api of joplin. Implement on a need basis

local function get_serverURL()
  return 'http://' .. c.config.url .. ":" .. c.config.port
end

local function post(url, request)
  url = get_serverURL() .. url
  if request.query == nil then
    request.query = {}
  end
  request.query.token = c.config.token
  local response = curl.post(url, request)

  if response.status == 200 and response.body ~= "" then
		response.json = vim.fn.json_decode(response.body)
  end
  return response
end

local function put(url, request)
  url = get_serverURL() .. url
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
  url = get_serverURL() .. url
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

local function delete(url, request)
  url = get_serverURL() .. url
  if request.query == nil then
    request.query = {}
  end
  request.query.token = c.config.token
  local response = curl.delete(url, request)

  if response.status == 200 and response.body ~= "" then
    response.json = vim.fn.json_decode(response.body)
  end
  return response
end

local M = {}

M.update_note = function(id, note)
  local body = vim.fn.json_encode(note)
  local request = { raw_body = body }
  local response = put('/notes/' .. id, request)
  return response.json
end

M.get_all_folders = function()
  local folders = {}
  local has_next = true
  local page = 1
  while has_next == true do
    local response = get('/folders', { query = { fields = 'title,id,parent_id', page = page } })
    has_next = response.json.has_more
    for k, fdr in ipairs(response.json.items) do
      fdr.children = {}
      folders[fdr.id] = fdr
      fdr.type = 2
    end
    page = page + 1
  end
  -- reverse index the children
  -- because joplin don't handle this ??
  for id, fdr in pairs(folders) do
    if fdr.parent_id ~= nil then
      local parent = folders[fdr.parent_id]
      if parent ~= nil then table.insert(parent.children, fdr.id) end
    end
  end
  return folders
end

M.get_folder = function(id, fields)
  local response = get("/folders/" .. id, { query = { fields = fields } })
  if response.status ~= 200 then return nil end
  return response.json
end

M.get_folder_full_path = function(id)
  if id == nil then return '' end

  local folder = M.get_folder(id, 'title,parent_id')
  if folder == nil then return '' end
  if folder.title == nil then return '' end
  if folder.parent_id == nil then return folder.title end

  return M.get_folder_full_path(folder.parent_id)..'/'..folder.title
end

M.get_note = function(id, fields)
  local response = get("/notes/" .. id, { query = { fields = fields } })
  if response.status ~= 200 then return nil end
  return response.json
end

M.get_notes_in_folders = function(id)
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

M.create_note = function(parent_id, title, body)
  title = title or ''
  body = body or ''
  local data = { title = title, parent_id = parent_id, body = body }
  local jsonData = vim.fn.json_encode(data)
  local response = post("/notes", { body = jsonData })
  if response.status == 200 then
    return response.json.id
  end
  return nil
end

local tags_by_name = nil
M.get_tag = function(tag_str, create)
	if tags_by_name == nil then
		local response = get("/tags", {})
		tags_by_name = {}
		if response.status == 200 then
			for _, item in pairs(response.json["items"]) do
				tags_by_name[item["title"]] = item
			end
		end
	end
	local t = tags_by_name[tag_str]
	if t == nil and create == true then
		local r = post("/tags", { body = vim.fn.json_encode({ title = tag_str }) })
		tags_by_name[tag_str] = r.json
		t = r.json
	end
	return t
end

M.get_tags_for_notes = function(id)
  local response = get("/notes/"..id.."/tags", {})
  if response.status ~= 200 then return nil end
  local data = response.json
	local tags = {}
  for i, item in pairs(data["items"]) do
    table.insert(tags, item["title"])
  end
  return tags
end

M.add_tag_to_note = function(tag_id, note_id)
  local response = post("/tags/"..tag_id.."/notes", { body = vim.fn.json_encode({id = note_id})})
end

M.remove_tag_from_note = function(tag_id, note_id)
	local response = delete("/tags/"..tag_id.."/notes/"..note_id, {})
end

M.sync_note_tags = function(note_id, tag_strs)
	local tag_names = {}
	for str in string.gmatch(tag_strs, "([^"..",".."]+)") do
		table.insert(tag_names, str)
	end
	local tags_by_id = {}
	for i, tag_str in pairs(tag_names) do
		tags_by_id[tag_str] = true

		local tag = M.get_tag(tag_str, true)
		M.add_tag_to_note(tag["id"], note_id)
	end

	local existing_tags = M.get_tags_for_notes(note_id)
	-- delete the tags that got deleted
	for i, tag_str in pairs(existing_tags) do
		if tags_by_id[tag_str] == nil then
			local tag = M.get_tag(tag_str, true)
			local r = M.remove_tag_from_note(tag["id"], note_id)
		end
	end
end

return M
