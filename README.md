# miniharp.nvim

> Minimal file marks for Neovim. Zero deps, tiny API, per-cwd persistence.

## What it does

- Toggle file marks for the current project.
- Jump to the next or previous mark.
- Remember cursor positions and restore marks per cwd.
- A tiny outline glued to the bottom-right corner that stays open while you
  work; the current file shows a `*` instead of its number.

Focus the outline to interact with it: `l` jumps (and brings you back to your
code), `dd` removes, `<C-j>`/`<C-k>` reorder, `q` leaves.

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
  pin = false, -- open the pinned outline on startup (default: false)
})

vim.keymap.set('n', '<leader>m', miniharp.toggle_file, { desc = 'miniharp: toggle file mark' })
vim.keymap.set('n', '<C-n>',     miniharp.next,        { desc = 'miniharp: next file mark' })
vim.keymap.set('n', '<C-p>',     miniharp.prev,        { desc = 'miniharp: prev file mark' })
vim.keymap.set('n', '<leader>o', miniharp.toggle_pin,  { desc = 'miniharp: toggle outline' })
vim.keymap.set('n', '<leader>p', miniharp.focus_pin,   { desc = 'miniharp: focus outline' })

-- jump straight to a mark by number
for i = 1, 4 do
  vim.keymap.set('n', '<M-' .. i .. '>', function() miniharp.jump(i) end, { desc = 'miniharp: jump to mark ' .. i })
end
```

> `<C-1>`..`<C-9>` only works in terminals that speak the kitty keyboard
> protocol (kitty, WezTerm, Ghostty) or in GUIs; most terminals cannot
> distinguish Ctrl+number from a plain number. `<M-1>` (Alt) works nearly
> everywhere, `<leader>1` always does.

There is also a `:Miniharp` command: `toggle`, `focus` (default), `next`, `prev`, `jump <n>`, `pin`.

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

- `setup(opts?)` – Initialize the plugin. `opts.notify = false` silences info messages (warnings always show); `opts.pin = true` opens the pinned outline on startup.
- `toggle_file(file?)` – Toggle a mark for the current file, or for `file` when given (handy from a file explorer such as oil.nvim).
- `next()` / `prev()` – Jump to next/previous file mark (wraps).
- `jump(i)` – Jump straight to mark `i`.
- `toggle_pin()` – Toggle the outline.
- `focus_pin()` – Enter the outline to interact with it (opens it when closed); entering while inside leaves it again.

## Development

- `make test` – headless end-to-end test (uses an isolated state dir).
- `make lint` – `stylua --check`.

Both run in CI on every push.
