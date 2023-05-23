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
    -- separator_style = 'thin',

    numbers = function(opts)
      return string.format('%s|%s.)', opts.id, opts.raise(opts.ordinal))
    end,

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

map('n', '{', '<Cmd>BufferLineMovePrev<CR>')
map('n', '}', '<Cmd>BufferLineMoveNext<CR>')

map('n', '<leader>be', '<Cmd>BufferLineSortByExtension<CR>')
map('n', '<leader>bd', '<Cmd>BufferLineSortByDirectory<CR>')

map('n', '<leader>1', '<Cmd>BufferLineGoToBuffer 1<CR>')
map('n', '<leader>2', '<Cmd>BufferLineGoToBuffer 2<CR>')
map('n', '<leader>3', '<Cmd>BufferLineGoToBuffer 3<CR>')
map('n', '<leader>4', '<Cmd>BufferLineGoToBuffer 4<CR>')
map('n', '<leader>5', '<Cmd>BufferLineGoToBuffer 5<CR>')
map('n', '<leader>6', '<Cmd>BufferLineGoToBuffer 6<CR>')
map('n', '<leader>7', '<Cmd>BufferLineGoToBuffer 7<CR>')
map('n', '<leader>8', '<Cmd>BufferLineGoToBuffer 8<CR>')
map('n', '<leader>9', '<Cmd>BufferLineGoToBuffer 9<CR>')
