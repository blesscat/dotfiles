-- vim.opt.list = true
-- vim.opt.listchars:append("space:⋅")
-- vim.opt.listchars:append("eol:↴")

require('indent_blankline').setup {
  -- char = "┊",
  char = "|",
  space_char_blankline = " ",
  show_current_context = true,
  --  show_current_context_start = true,
  buftype_exclude = {'terminal', 'nofile', 'NvimTree'},
  filetype_exclude = {'help', 'packer', 'startify', 'NvimTree', 'alpha'},
}
