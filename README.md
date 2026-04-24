# miniharp.nvim

> Minimal Harpoon-like plugin for Neovim. Zero deps, tiny API, per-cwd persistence.

Inspired by (and giving full credit to) **Harpoon** by [ThePrimeagen](https://github.com/ThePrimeagen/). If you want a richer feature set (lists, terminals, advanced UI), check out [Harpoon2](https://github.com/ThePrimeagen/harpoon/tree/harpoon2).

## Features

- **File marks**.
- **Auto-remembers last cursor position** in each marked file when you switch buffers.
- **Jump next/prev** from anywhere.
- **Per-cwd persistence**.
- **Tiny floating list UI**:
  - Shows compact file names plus parent paths.
  - Marks and highlights the **current** file in the loop.
  - Opens in the top-right corner by default.
  - Opens focused.
  - Closes with `q`, `<Esc>`, `<C-c>`, or by calling `show_list()` again.
  - When focused, supports `l` to jump and `dd` to remove.
- **Quiet default flow**:
  - No info notification when a cwd has no saved session yet.
  - Mark, jump, and remove actions do not echo status messages.
  - Missing files are removed automatically when encountered during navigation.

## Installation

### vim.pack

```lua
vim.pack.add({
  {
    src = 'https://github.com/vieitesss/miniharp.nvim',
  }
})

require('miniharp').setup()
```

### lazy.nvim

```lua
{
  'vieitesss/miniharp.nvim',
  opts = {},
}
```

## Usage (recommended keymaps)

`miniharp` doesn’t force maps. Here are some defaults you might like:

```lua
local miniharp = require('miniharp')

vim.keymap.set('n', '<leader>m', miniharp.toggle_file, { desc = 'miniharp: toggle file mark' })
vim.keymap.set('n', '<C-n>',     miniharp.next,        { desc = 'miniharp: next file mark' })
vim.keymap.set('n', '<C-p>',     miniharp.prev,        { desc = 'miniharp: prev file mark' })
vim.keymap.set('n', '<leader>l', miniharp.show_list,   { desc = 'miniharp: toggle marks list' })
```

Typical flow:

1. In a file you care about, hit `<leader>m` to toggle a **file mark**.
2. Work as usual. When you leave that file, its last cursor spot is auto-saved.
3. From anywhere, use `<C-n>` / `<C-p>` to jump around marked files.
4. On a new Neovim session in the **same cwd**, marks auto-load.
   Toggle the list on demand with `<leader>l`.

## API

All functions are exposed from `require('miniharp')`:

- `setup()` – Initialize the plugin.
- `toggle_file()` – Toggle a file mark for the **current** file.
- `next()` / `prev()` – Jump to next/previous file mark (wraps).
- `show_list()` – Toggle the floating list UI. You can close it with `q`, `<Esc>`, or `<C-c>`. In all cases, calling `show_list()` again closes it.

## Design notes

- **Minimalism first.** Small surface area and simple behavior; no dependencies.
- **Per-cwd persistence.** Keeps marks project-scoped.
- **UI stays out of the way.** The popup stays lightweight and optimized for a tiny loop of files.
