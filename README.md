# Jopvim

Integrate neovim with [joplin](https://joplinapp.org/).

## Dependencies

- [Telescope](https://github.com/nvim-telescope/telescope.nvim)

## Setup

```
require('jopvim').setup(cfg)
```

This plugin uses the RestAPI provided by Joplin, so a token is required.
There are 2 ways to provide the token.

```
require('jopvim').setup({
  token = '...'
})
```

or

```
require('jopvim').setup({
  token_path = vim.fn.expand('~/.vim/.joplin_token')
})
```

The token file is a text file containing the token string in the first line. Any other lines are ignored.
Since it is not recommended to commit your token, it is better to use a token file.

## How this works

The plugin works by creating a index of all the notes. Updating the notes index is relatively slow so you only need to do it when you have new notes.

You can update the note index by running `:JopvimUpdateIndex`

### Searching Notes
`lua require("jopvim.telescope").joplin_notes()`

You can bind the this to whatever mapping you desire. No default mapping is provided.

The default action will open the notes. It will download the note and store it in `.cache/nvim/jop/*`.
Anytime the file is saved, a put request will be sent to Joplin to update the note.

### Searching Folders
`lua require("jopvim.telescope").joplin_folders()`

You can bind the this to whatever mapping you desire. No default mapping is provided.

The default action will create a note in the folder, and a new note will be open in nvim.

## Disclaimer
This plugin lacks features, and might be buggy. Although I am personally using, there might be bug and I am not responsible for any data loss.

## Future Plans
????
