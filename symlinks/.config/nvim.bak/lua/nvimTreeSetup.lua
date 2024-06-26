require'nvim-tree'.setup {
  disable_netrw       = true,
  hijack_netrw        = true,
  -- auto_close          = false,
  open_on_tab         = false,
  hijack_cursor       = false,
  update_cwd          = false,
  -- update_to_buf_dir   = {
  --   enable = true,
  --   auto_open = true,
  -- },
  diagnostics = {
    enable = false,
    icons = {
      hint = "",
      info = "",
      warning = "",
      error = "",
    }
  },
  update_focused_file = {
    enable      = false,
    -- enable      = true,
    update_cwd  = false,
    -- update_cwd  = true,
    ignore_list = {}
  },
  system_open = {
    cmd  = nil,
    args = {}
  },
  filters = {
    dotfiles = false,
    custom = {}
  },
  view = {
    width = 40,
    -- height = 30,
    hide_root_folder = false,
    side = 'left',
    -- auto_resize = false,
    mappings = {
      custom_only = false,
      list = {}
    }
  }
}

map('n', '<leader>n', '<cmd>:NvimTreeToggle<cr>')
map('n', '<leader>tf', '<cmd>:NvimTreeFindFile<cr>')


