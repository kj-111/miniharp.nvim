# miniharp.nvim

> Minimal Harpoon-like plugin for Neovim. Zero deps, tiny API, per-cwd persistence.

Inspired by (and giving full credit to) **Harpoon** by [ThePrimeagen](https://github.com/ThePrimeagen/). If you want a richer feature set (lists, terminals, advanced UI), check out [Harpoon2](https://github.com/ThePrimeagen/harpoon/tree/harpoon2).

This is a personal fork focused on a smaller core workflow.

## What it does

- Toggle file marks for the current project.
- Jump to the next or previous mark.
- Remember cursor positions and restore marks per cwd.
- Show a tiny focused list in the top-right corner.

The list uses `l` to jump and `dd` to remove. Calling `show_list()` again closes it.

## Installation

### vim.pack

```lua
vim.pack.add({
  {
    src = 'https://github.com/kj-111/miniharp.nvim',
  }
})

require('miniharp').setup()
```

### lazy.nvim

```lua
{
  'kj-111/miniharp.nvim',
  opts = {},
}
```

## Usage

```lua
local miniharp = require('miniharp')

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
