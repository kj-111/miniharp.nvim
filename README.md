# miniharp.nvim

> Minimal file marks for Neovim. Zero deps, tiny API, per-cwd persistence.

## What it does

- Toggle file marks for the current project.
- Jump to the next or previous mark.
- Remember cursor positions and restore marks per cwd.
- A centred menu listing the marks, one path per line.

The menu is a normal modifiable buffer, so you edit the list with the vim you
already know: `dd` removes, `ddp` or `:m` reorders, typing a path adds. `<CR>`
or `l` opens the file under the cursor; `q` or `<Esc>` closes. The text is
applied when the menu closes, or on `:w` if you want to keep it open.

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
vim.keymap.set('n', '<C-e>',     miniharp.toggle_menu, { desc = 'miniharp: toggle menu' })
vim.keymap.set('n', '<C-n>',     miniharp.next,        { desc = 'miniharp: next file mark' })
vim.keymap.set('n', '<C-p>',     miniharp.prev,        { desc = 'miniharp: prev file mark' })

-- jump straight to a mark by number
for i = 1, 4 do
  vim.keymap.set('n', '<M-' .. i .. '>', function() miniharp.jump(i) end, { desc = 'miniharp: jump to mark ' .. i })
end
```

> `<C-1>`..`<C-9>` only works in terminals that speak the kitty keyboard
> protocol (kitty, WezTerm, Ghostty) or in GUIs; most terminals cannot
> distinguish Ctrl+number from a plain number. `<M-1>` (Alt) works nearly
> everywhere, `<leader>1` always does.

There is also a `:Miniharp` command: `menu` (default), `toggle`, `next`, `prev`, `jump <n>`.

From [oil.nvim](https://github.com/stevearc/oil.nvim) you can mark the file under the cursor, via oil's own `keymaps`:

```lua
['<leader>m'] = {
  callback = function()
    local oil = require('oil')
    local entry, dir = oil.get_cursor_entry(), oil.get_current_dir()
    if entry and entry.type == 'file' and dir then require('miniharp').toggle_file(dir .. entry.name) end
  end,
  desc = 'miniharp: toggle mark for file under cursor',
},
```

## API

- `setup(opts?)` – Initialize the plugin. `opts.notify = false` silences info messages (warnings always show).
- `toggle_file(file?)` – Toggle a mark for the current file, or for `file` when given (handy from a file explorer such as oil.nvim). Buffers that are not files – a directory listing, a terminal, help – are refused.
- `next()` / `prev()` – Jump to next/previous file mark (wraps).
- `jump(i)` – Jump straight to mark `i`.
- `toggle_menu()` – Toggle the mark list, a centred float you edit like any other buffer.

## Development

- `make test` – headless end-to-end test (uses an isolated state dir).
- `make lint` – `stylua --check`.

Run both locally before pushing. The CI workflow exists but its jobs are
currently blocked before they start any step, so a red badge there says
nothing about the code.
