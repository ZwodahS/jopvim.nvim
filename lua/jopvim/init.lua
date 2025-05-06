local Path = require('plenary.path')
local api = require('jopvim.api')
local index = require('jopvim.index')
local notes = require('jopvim.notes')
local util = require('jopvim.util')

local M = {}

local function split_note_data(fileData)
  local metadata = {}
  local body = {}
  local lNo = 1
  if (fileData[1]:find('```', 1, true) == 1) then -- if start with ``` then we treat it as metadata
    lNo = 2
    while (fileData[lNo]:find('```', 1, true) ~= 1) do
			if fileData[lNo]:sub(1, 2) == '--'  then
			else
				local line = fileData[lNo]
				local index = line:find(':', 1, true)
				if index ~= nil then
					metadata[line:sub(1, index-1)] = line:sub(index + 1, #line)
				end
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

M.on_bufWritePost = function()
  local id = vim.fn.fnamemodify(vim.fn.expand('%:t:r'), ":r")
	if id == nil then return end

	local path = notes.get_tmp_note_path(id)
	local f= io.open(path, "r")
	if f == nil then return end

	-- read the file
	local fileData = {}
	for line in f:lines() do
		fileData[#fileData + 1] = line
	end

	-- get the metadata
	local metadata, body = split_note_data(fileData)

	if metadata["type"] == "note" then
		local note = { body = body }
		for _, key in ipairs(_JOPLIN_WHITELIST_NOTES_METADATA) do
			if metadata[key] ~= nil then
				note[key] = metadata[key]
			end
		end
		api.update_note(id, note)
		index.update_note(id, note)
	elseif metadata["type"] == "folder" then
		-- folder don't get updated for now
	end

end

local download_note = function(id)
  if id == '' then return nil end
  local note = api.get_note(id, 'body,title,is_todo,source_url,parent_id')

  if note == nil then return nil end

  local full_path = api.get_folder_full_path(note.parent_id)

  local data = {'```'}
	table.insert(data, 'type:note')
  table.insert(data, 'title:'..note.title)
  table.insert(data, 'is_todo:'..note.is_todo)
  table.insert(data, '')
  table.insert(data, '-- id: '..id)
  table.insert(data, '-- link: [](:/'..id..')')
	if note.parent_id ~= nil then
		table.insert(data, '-- directory: '..'['..full_path..'](:/'..note.parent_id..')')
	end
  table.insert(data, '```')
  table.insert(data, note.body)

  local path = notes.save_note_to_local(id, table.concat(data, "\n"))
  return path
end

local download_folder = function(id)
	if id == '' then return nil end
	local folder = api.get_folder(id, 'title,parent_id')
	if folder == nil then return nil end

  local full_path = api.get_folder_full_path(folder.parent_id)

  local data = {'```'}
	table.insert(data, 'type:folder')
  table.insert(data, 'title:'..folder.title)
  table.insert(data, '')
  table.insert(data, '-- id: '..id)
  table.insert(data, '-- link: [](:/'..id..')')
	if folder.parent_id ~= nil then
		table.insert(data, '-- directory: '..'['..full_path..']('..folder.parent_id..')')
	end
	table.insert(data, '-- This is a folder. Any changes made here are temporary.')
  table.insert(data, '```')

	-- Tue 15:53:59 06 May 2025
	-- Not sure yet how best to get and display folder. Might have to do it from cache as joplin
	-- does not provide the api to get folders in folder.
  table.insert(data, '')
  table.insert(data, '# Notes in Folder')
	local folder_notes = api.get_notes_in_folders(id)
	for key, note in pairs(folder_notes) do
		table.insert(data, '- ['..note.title..'](:/'..key..')')
	end

	local path = notes.save_note_to_local(id, table.concat(data, "\n"))
	return path
end

M.open_note = function(id)
  local path = download_note(id)
  if path ~= nil then
		vim.cmd("edit" .. path)
		return true
	end
	return false
end

M.open_folder = function(id)
  local path = download_folder(id)
  if path ~= nil then
		vim.cmd("edit" .. path)
		return true
	end
	return false
end

M.create_note = function(fid, title, body, open_note)
  title = title or ''
  body = body or ''
  local nid = api.create_note(fid, title, body)
  if nid == nil then return end
  index.update_note(nid, {
    parent_id = fid,
    title = title,
  })
  if open_note == true then M.open_note(nid) end
end

M.get_markdown_id_under_cursor = function()
	-- note that this function is only called in open_file_under_cursor and does not handle the case that
	-- the cursor is inside ](:/)
	--
	-- If the current word is not, then we can check if the current char is wrapped around [](:/)
	-- If so, then we know it is markdown link, then we should just get the id and open
	--
	-- assumption markdown are always in the format (based on joplin file linking format)
	-- [Text](:/id)
	-- Observation 1: ](:/ is the pattern we are looking for
	-- Observation 2: while cursor is on ](:/.........) block, we can assume that cword already took care of it
	-- Observation 3: Based on 2, we can assume that we are in the [] block or in [
	--
	-- Which means to say, we need to find the first ](:/w+) block and open it
	-- However, there is potential problem if we do this
	-- We might be outside of the [], so the solution is to look left first and find the first '[',
	-- but if we encounter a ']' before '[', then we are not in a [] then we return
	--
	-- This should works for most cases I think
	-- Mostly work because we don't have to handle the case inside () as that is taken care of by <cword>
	-- If we need to, then the ] before [ guard need to be expanded to check for us being in (:/) block

	local line_content = vim.api.nvim_get_current_line()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local column = cursor[2] + 1 -- shift the offset

	local line_content_reverse = string.reverse(line_content)
	local r_column = #line_content - column + 1

	-- check backwards if we are in ] before [
	local close_index = string.find(line_content_reverse, ']', r_column, true)
	local open_index = string.find(line_content_reverse, '[', r_column, true)

	-- if we can't find a open bracket then we return since we are not in the [] block
	if open_index == nil then return nil end
	-- if close is closer than open, then we just return since we are not in a block
	if close_index ~= nil and close_index < open_index then return nil end

	-- find the closest ] to the right side, and also the pattern we want to match
	local close_index = string.find(line_content, ']', column, true)
	local group_index = string.find(line_content, '](:/', column, true)

	-- these 2 if guard checks for [] that is not [](:/)
	if close_index == nil or group_index == nil then return nil end
	if close_index ~= group_index then return nil end

	-- we can just regex it and get the content inside
	local group = string.match(line_content, '%]%(:/%w+%)', column)
	if group == nil then return nil end

	return string.sub(group, 5, #group-1)
end

M.open_file_under_cursor = function()
	local id = vim.fn.expand("<cword>")
	if M.open_note(id) then return end
	if M.open_folder(id) then return end
	id = M.get_markdown_id_under_cursor()
	if id ~= nil and M.open_note(id) then return end
	if id ~= nil and M.open_folder(id) then return end
	print("joplin note/folder not found.")
end

M.setup = function(cfg)
  conf.setup(cfg)
  -- create the tmp directory if does not exists
  local rootDir = Path:new(util.get_root_dir())
  if not rootDir:exists() then
    rootDir:mkdir()
  end
  -- set up autocmd
  vim.cmd([[
    autocmd BufWritePost *.jop.md lua require('jopvim').on_bufWritePost()
    command! JopvimUpdateIndex lua require('jopvim.index').update()
  ]])
end

return M
