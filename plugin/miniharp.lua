if vim.g.loaded_miniharp then return end
vim.g.loaded_miniharp = 1

local subcommands = {
  toggle = function() require('miniharp').toggle_file() end,
  list = function() require('miniharp').show_list() end,
  next = function() require('miniharp').next() end,
  prev = function() require('miniharp').prev() end,
  jump = function(n) require('miniharp').jump(tonumber(n) or -1) end,
}

vim.api.nvim_create_user_command('Miniharp', function(opts)
  local name = opts.fargs[1] or 'list'
  local subcommand = subcommands[name]
  if not subcommand then
    require('miniharp.log').warn('unknown subcommand: %s', name)
    return
  end

  subcommand(opts.fargs[2])
end, {
  nargs = '*',
  complete = function(arglead)
    local names = vim.tbl_keys(subcommands)
    table.sort(names)
    return vim.tbl_filter(function(name) return vim.startswith(name, arglead) end, names)
  end,
  desc = 'miniharp: toggle|list|next|prev|jump <n>',
})
