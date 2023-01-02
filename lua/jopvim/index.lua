local cache = require('jopvim.cache')
local api = require('jopvim.api')
local util = require('jopvim.util')

local M = {}

local function get_folder_fullname(index, id)
  if index[id] == nil then
    return ''
  end
  if index[id].fullname == nil then
    local parent_name = get_folder_fullname(index, index[id].parent_id)
    local fullname = index[id].title
    if parent_name ~= '' then
      fullname = parent_name .. ' > ' .. fullname
    end
    index[id].fullname = fullname
  end
  return index[id].fullname
end

local function get_foldername(index, id)
  if index[id] == nil then return '' end
  return index[id].title
end

local function save_index(index)
  local encoded = vim.fn.json_encode(index)
  local index_path = util.joinPath(vim.fn.stdpath("cache"), "jop", 'notes.index')
  cache.save_to_cache(index_path, encoded)
end

M.get = function()
  local index = cache.get_cache('notes.index', true)
  return index
end

M.update = function()
  -- Mon 11:32:41 14 Mar 2022
  -- not sure how to do this better
  -- fetch all the folders first
  local index = api.get_all_folders()
  -- for each of the folders, we set the full title
  for id in pairs(index) do
    -- just precompute all the folder name
    get_folder_fullname(index, id)
  end
  local notesIndex = {}
  -- for each folder, also index the notes in it
  for id in pairs(index) do
    local notes = api.get_notes_in_folders(id)
    for nid in pairs(notes) do
      notesIndex[nid] = notes[nid]
    end
  end

  for nid in pairs(notesIndex) do
    index[nid] = notesIndex[nid]
    index[nid].type = 1
    local fparent = get_folder_fullname(index, notesIndex[nid].parent_id)
    local parent = get_foldername(index, notesIndex[nid].parent_id)
    local fullname = notesIndex[nid].title
    if fparent ~= nil then fullname = fparent .. " > " .. fullname end
    index[nid].fullname = fullname
    index[nid].parentname = parent
  end
  save_index(index)
end

M.update_note = function(nid, note)
  local index = M.get()
  -- check if the note exists
  if note == nil then -- note got deleted ?
    if index[nid] == nil then return end
    index[nid] = nil
  else
    -- we need to add more metadata to the notes
    -- if there is no parent_id in note, we will assume it is the same
    local prev = index[nid] or nil
    if note.parent_id == nil and prev ~= nil then
      note.parent_id = prev.parent_id
    end
    local fparent = get_folder_fullname(index, note.parent_id)
    local parent = get_foldername(index, note.parent_id)
    local fullname = note.title

    if fparent ~= nil then fullname = fparent .. " > " .. fullname end

    -- @todo: perhaps should move this to a common function
    index[nid] = {
      id = nid, fullname = fullname, parentname = parent, type = 1,
      parent_id = note.parent_id, title = note.title
    }
  end
  save_index(index)
end

-- Format is A > B > C
M.get_object_id_by_fullname = function(fullname)
  local index = M.get()
  for id, item in pairs(index) do
    if item.fullname == fullname then
      return id
    end
  end
    return nil
end

return M
