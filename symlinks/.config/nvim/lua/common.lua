cmd = vim.cmd  -- to execute Vim commands e.g. cmd('pwd')
fn = vim.fn    -- to call Vim functions e.g. fn.bufnr()
g = vim.g      -- a table to access global variables
opt = vim.opt  -- to set options

g.mapleader = ' '

function map(mode, lhs, rhs, opts)
  local options = {noremap = true, silent = true}
  if opts then options = vim.tbl_extend('force', options, opts) end
  vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

---------------- OPTIONS -------------------------------------
-- colorscheme
cmd 'colorscheme palenight'
-- cmd 'colorscheme one'

opt.background = 'dark'

if vim.opt.termguicolors == true then
  -- True color support
  opt.termguicolors = true
end

cmd([[
if exists('g:neovide')
  colorscheme one
  set guifont=FiraCode\ Nerd\ font:h12
  let neovide_remember_window_size = v:true
  let g:neovide_cursor_vfx_mode = "pixiedust"
endif
]])

-- opt.completeopt = {'menuone', 'noinsert', 'noselect'}  -- Completion options (for deoplete)
opt.expandtab = true                -- Use spaces instead of tabs
opt.hidden = true                   -- Enable background buffers
opt.ignorecase = true               -- Ignore case
opt.joinspaces = false              -- No double spaces with join
opt.list = true                     -- Show some invisible characters
opt.number = true                   -- Show line numbers
-- opt.relativenumber = true           -- Relative line numbers
opt.scrolloff = 4                   -- Lines of context
opt.shiftround = true               -- Round indent
opt.shiftwidth = 2                  -- Size of an indent
opt.sidescrolloff = 8               -- Columns of context
opt.smartcase = true                -- Do not ignore case with capitals
opt.smartindent = true              -- Insert indents automatically
opt.splitbelow = true               -- Put new windows below current
opt.splitright = true               -- Put new windows right of current
opt.tabstop = 2                     -- Number of spaces tabs count for
opt.wildmode = {'list', 'longest'}  -- Command-line completion mode
opt.wrap = false                    -- Disable line wrap

-- g['deoplete#enable_at_startup'] = 1  -- enable deoplete at startup

-------------------- MAPPINGS ------------------------------
map('', '<leader>y', '"+y')       -- Copy to clipboard in normal, visual, select and operator modes
map('i', '<C-u>', '<C-g>u<C-u>')  -- Make <C-u> undo-friendly
map('i', '<C-w>', '<C-g>u<C-w>')  -- Make <C-w> undo-friendly

-- Copy to clipboard
map('v', '<leader>y', '"+y')
map('v', '<leader>Y', '"+yg_')
map('n', '<leader>y', '"+y')
map('n', '<leader>yy', '"+yy')

-- Paste from clipboard
map('n', '<leader>p', '"+p')
map('n', '<leader>P', '"+P')
map('v', '<leader>p', '"+p')
map('v', '<leader>P', '"+P')

-- <Tab> to navigate the completion menu
map('i', '<S-Tab>', 'pumvisible() ? "\\<C-p>" : "\\<Tab>"', {expr = true})
map('i', '<Tab>', 'pumvisible() ? "\\<C-n>" : "\\<Tab>"', {expr = true})

map('n', '<C-l>', '<cmd>noh<CR>')    -- Clear highlights

-- for auto pairs
map('i', '(', '()<left>')
map('i', '{', '{}<left>')
map('i', '[', '[]<left>')
map('i', '<', '<><left>')
map('i', '`', '``<left>')
map('i', '"', '""<left>')
map('i', "'", "''<left>")

-- map('n', '<C-j>', '<cmd>:bprev<cr>')
-- map('n', '<C-k>', '<cmd>:bprev<cr>')
-- map('n', '<leader>1', '1gt')
-- map('n', '<leader>2', '2gt')
-- map('n', '<leader>3', '3gt')
-- map('n', '<leader>4', '4gt')
-- map('n', '<leader>5', '5gt')
-- map('n', '<leader>6', '6gt')
-- map('n', '<leader>7', '7gt')
-- map('n', '<leader>8', '8gt')
-- map('n', '<leader>9', '9gt')
-- map('n', '<leader>0', '<cmd>tablast<cr>')

map('i', 'jk', '<esc>')

