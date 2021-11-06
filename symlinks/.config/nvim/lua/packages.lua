vim.cmd [[packadd packer.nvim]]

require('packer').startup(function()

  -- Packer can manage itself
  use 'wbthomason/packer.nvim'

  -- tree-sitter
  use {'nvim-treesitter/nvim-treesitter', run = ':TSUpdate' }

  -- lsp
  use 'neovim/nvim-lspconfig'
  use 'glepnir/lspsaga.nvim'

  -- autocomplete
  use {'ms-jpq/coq_nvim', branch = 'coq'}
  use {'ms-jpq/coq.artifacts', branch = 'artifacts'}


  -- surround 快速操作配對字符 例如ds' 刪除前後的'
  use 'tpope/vim-surround'
  -- indent guides
  -- use 'glepnir/indent-guides.nvim'
  use "lukas-reineke/indent-blankline.nvim"

  -- fuzzy finder
  use {
    'nvim-telescope/telescope.nvim',
    requires = { {'nvim-lua/plenary.nvim'} }
  }
  use 'nvim-lua/popup.nvim'

  -- statusbar
  use 'nvim-lualine/lualine.nvim'

  use {
    'kyazdani42/nvim-tree.lua',
    requires = 'kyazdani42/nvim-web-devicons',
    config = function() require'nvim-tree'.setup {} end
  }

  use {'akinsho/bufferline.nvim', requires = 'kyazdani42/nvim-web-devicons'}

  -- icons
  use 'kyazdani42/nvim-web-devicons'

  -- themes
  use {'drewtempelmeyer/palenight.vim'}
  use {'rakr/vim-one'}

 --css color
  use 'ap/vim-css-color'


end)

