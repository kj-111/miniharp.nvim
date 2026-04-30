# miniharp.nvim

> Minimal file marks for Neovim. Zero deps, tiny API, per-cwd persistence.

## What it does

- Toggle file marks for the current project.
- Jump to the next or previous mark.
- Remember cursor positions and restore marks per cwd.
- Show a tiny focused list in the center.

The list uses `l` to jump, `dd` to remove, and `q` to close.

## Installation

```lua
vim.pack.add({
  { src = 'https://github.com/kj-111/miniharp.nvim' },
})
```

## Usage

```lua
local miniharp = require('miniharp')

miniharp.setup()

vim.keymap.set('n', '<leader>m', miniharp.toggle_file, { desc = 'miniharp: toggle file mark' })
vim.keymap.set('n', '<C-n>',     miniharp.next,        { desc = 'miniharp: next file mark' })
vim.keymap.set('n', '<C-p>',     miniharp.prev,        { desc = 'miniharp: prev file mark' })
vim.keymap.set('n', '<leader>l', miniharp.show_list,   { desc = 'miniharp: toggle marks list' })
```

## API

- `setup()` – Initialize the plugin.
- `toggle_file()` – Toggle a mark for the current file.
- `next()` / `prev()` – Jump to next/previous file mark (wraps).
- `show_list()` – Toggle the floating list.
