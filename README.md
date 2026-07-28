# miniharp.nvim

> Minimal file marks for Neovim. Zero deps, tiny API, per-cwd persistence.

## What it does

- Toggle file marks for the current project.
- Jump to the next or previous mark.
- Remember cursor positions and restore marks per cwd.
- Show a tiny focused list in the center.
- Pin a read-only outline in the top-right corner that stays open while you work.

The list uses `l` to jump, `dd` to remove, `<C-j>`/`<C-k>` to reorder, and `q` to close.

## Installation

```lua
vim.pack.add({
  { src = 'https://github.com/kj-111/miniharp.nvim' },
})
```

## Usage

```lua
local miniharp = require('miniharp')

miniharp.setup({
  notify = true, -- show info messages on add/remove/jump/restore (default: true)
})

vim.keymap.set('n', '<leader>m', miniharp.toggle_file, { desc = 'miniharp: toggle file mark' })
vim.keymap.set('n', '<C-n>',     miniharp.next,        { desc = 'miniharp: next file mark' })
vim.keymap.set('n', '<C-p>',     miniharp.prev,        { desc = 'miniharp: prev file mark' })
vim.keymap.set('n', '<leader>l', miniharp.show_list,   { desc = 'miniharp: toggle marks list' })

-- jump straight to a mark by number
for i = 1, 4 do
  vim.keymap.set('n', '<M-' .. i .. '>', function() miniharp.jump(i) end, { desc = 'miniharp: jump to mark ' .. i })
end
```

> `<C-1>`..`<C-9>` only works in terminals that speak the kitty keyboard
> protocol (kitty, WezTerm, Ghostty) or in GUIs; most terminals cannot
> distinguish Ctrl+number from a plain number. `<M-1>` (Alt) works nearly
> everywhere, `<leader>1` always does.

There is also a `:Miniharp` command: `toggle`, `list` (default), `next`, `prev`, `jump <n>`, `pin`.

## API

- `setup(opts?)` – Initialize the plugin. `opts.notify = false` silences info messages (warnings always show).
- `toggle_file()` – Toggle a mark for the current file.
- `next()` / `prev()` – Jump to next/previous file mark (wraps).
- `jump(i)` – Jump straight to mark `i`.
- `show_list()` – Toggle the floating list.
- `toggle_pin()` – Toggle the pinned outline (top-right, non-focusable, live-updating).

## Development

- `make test` – headless end-to-end test (uses an isolated state dir).
- `make lint` – `stylua --check`.

Both run in CI on every push.
