
map('n', '<leader>f', '<cmd>:Telescope find_files<CR>')
map('n', '<leader>g', '<cmd>:Telescope live_grep<CR>')
map('n', '<leader>b', '<cmd>:Telescope buffers<CR>')
map('n', '<leader>h', '<cmd>:Telescope help_tags<CR>')

--also map q key to close the window:
local actions = require('telescope.actions')
require('telescope').setup{
  defaults = {
    mappings = {
      n = {
        ["q"] = actions.close
      },
    },
  }
}

