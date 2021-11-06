-------------- lualine --------------------------
local status, lualine = pcall(require, "lualine")
if (not status) then return end
lualine.setup {
  options = {
    icons_enabled = true,
    theme = 'horizon',
    section_separators = {'', ''},
    component_separators = {'', ''},
    disabled_filetypes = {}
  },
  sections = {
    lualine_a = {'mode'},
    lualine_b = {'branch'},
    lualine_c = {'filename'},
    lualine_x = {
      { 'diagnostics', sources = {"nvim_lsp"}, symbols = {error = ' ', warn = ' ', info = ' ', hint = ' '} },
      'encoding',
      'filetype'
    },
    lualine_y = {'progress'},
    lualine_z = {'location'}
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {'filename'},
    lualine_x = {'location'},
    lualine_y = {},
    lualine_z = {}
  },
  extensions = {'fugitive'}
}

-------------- nvim-tree ------------------------------
require'nvim-tree'.setup {
  disable_netrw       = true,
  hijack_netrw        = true,
  open_on_setup       = false,
  ignore_ft_on_setup  = {},
  auto_close          = false,
  open_on_tab         = false,
  hijack_cursor       = false,
  update_cwd          = false,
  update_to_buf_dir   = {
    enable = true,
    auto_open = true,
  },
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
    update_cwd  = false,
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
    width = 30,
    height = 30,
    hide_root_folder = false,
    side = 'left',
    auto_resize = false,
    mappings = {
      custom_only = false,
      list = {}
    }
  }
}

map('n', '<leader>n', '<cmd>:NvimTreeToggle<cr>')
map('n', 'nr', '<cmd>:NvimTreeRefresh<cr>')
map('n', 'nf', '<cmd>:NvimTreeFindFile<cr>')


------------- bufferline ----------------
require("bufferline").setup {
  options = {
    show_close_icon = false,
    show_buffer_close_icons = false,
    diagnostics = 'nvim_lsp',

    name_formatter = function(buf)  -- buf contains a "name", "path" and "bufnr"
        return vim.fn.fnamemodify(buf.name, ':p:.')
    end,

    max_name_length = 30,
    tab_size = 30,
    separator_style = 'thin',

    offsets = {
      {
        filetype = "NvimTree",
        text = function()
          return vim.fn.fnamemodify(vim.fn.getcwd(), ':p:~')
        end,
        highlight = "Directory",
        text_align = "left"
      }
    },
  }
}

map('n', '<C-j>', '<Cmd>BufferLineCyclePrev<CR>')
map('n', '<C-k>', '<Cmd>BufferLineCycleNext<CR>')
map('n', 'be', '<Cmd>BufferLineSortByExtension<CR>')
map('n', 'bd', '<Cmd>BufferLineSortByDirectory<CR>')

map('n', '<leader>1', '<Cmd>BufferLineGoToBuffer 1<CR>')
map('n', '<leader>2', '<Cmd>BufferLineGoToBuffer 2<CR>')
map('n', '<leader>3', '<Cmd>BufferLineGoToBuffer 3<CR>')
map('n', '<leader>4', '<Cmd>BufferLineGoToBuffer 4<CR>')
map('n', '<leader>5', '<Cmd>BufferLineGoToBuffer 5<CR>')
map('n', '<leader>6', '<Cmd>BufferLineGoToBuffer 6<CR>')
map('n', '<leader>7', '<Cmd>BufferLineGoToBuffer 7<CR>')
map('n', '<leader>8', '<Cmd>BufferLineGoToBuffer 8<CR>')
map('n', '<leader>9', '<Cmd>BufferLineGoToBuffer 9<CR>')
