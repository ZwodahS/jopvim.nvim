local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local index = require('jopvim.index')
local jopvim = require('jopvim')

local M = {}
M.joplin_notes_picker = function(opts)
  local data = {}
  local index = index.get()
  for k in pairs(index) do
    local v = index[k]
    if v["type"] == 1 then
      table.insert(data, {v.title .. ' | ' .. v.parentname, v.id})
    end
  end
  return pickers.new(opts, {
    prompt_title = "Joplin Notes",
    finder = finders.new_table({
      results = data,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry[1],
          ordinal = entry[1],
        }
      end
    }),
    sorter = conf.generic_sorter(opts),
  })
end

M.joplin_insert_link = function(opts)
  opts = opts or {}
	local buf = vim.api.nvim_get_current_buf()
	opts.attach_mappings = function(prompt_bufnr, map)
		actions.select_default:replace(function()
			actions.close(prompt_bufnr)
			local selection = action_state.get_selected_entry()
			local id = selection.value[2]
			local link = jopvim.get_link(id)
			if link ~= nil then
				local row = vim.api.nvim_win_get_cursor(0)[1]
				local col = vim.api.nvim_win_get_cursor(0)[2]
				local line = vim.api.nvim_get_current_line()
				vim.api.nvim_buf_set_text(buf, row-1, col, row-1, col, {link})
			end
		end)
		return true
	end
	local picker = M.joplin_notes_picker(opts)
	picker:find()
end

M.joplin_notes = function(opts)
  opts = opts or {}
	opts.attach_mappings = function(prompt_bufnr, map)
		actions.select_default:replace(function()
			actions.close(prompt_bufnr)
			local selection = action_state.get_selected_entry()
			jopvim.open_note(selection.value[2])
		end)
		return true
	end
	local picker = M.joplin_notes_picker(opts)
	picker:find()
end

M.joplin_folders = function(opts)
  opts = opts or {}
  local index = index.get()
  local data = {}
  for k in pairs(index) do
    local v = index[k]
    if v["type"] == 2 then
      table.insert(data, {v.fullname, v.id})
    end
  end
  pickers.new(opts, {
    prompt_title = "Joplin Notes",
    finder = finders.new_table({
      results = data,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry[1],
          ordinal = entry[1],
        }
      end
    }),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        jopvim.create_note(selection.value[2], "", "", true)
      end)
      return true
    end
  }):find()
end

return M
