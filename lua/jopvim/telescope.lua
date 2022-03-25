local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local index = require('jopvim.index')
local jopvim = require('jopvim')

local M = {}
-- our picker function: colors
M.joplin_notes = function(opts)
  opts = opts or {}
  local index = index.get()
  local data = {}
  for k in pairs(index) do
    local v = index[k]
    if v["type"] == 1 then
      table.insert(data, {v.title .. ' | ' .. v.parentname, v.id})
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
        jopvim.openNote(selection.value[2])
      end)
      return true
    end
  }):find()
end

return M
