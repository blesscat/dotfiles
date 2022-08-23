-- vim.cmd [[packadd packer.nvim]]

require('packer').startup(function()
  -- Packer can manage itself
  use 'wbthomason/packer.nvim'

  -- autopairs
  use {
	"windwp/nvim-autopairs",
    config = function() require("nvim-autopairs").setup {} end
  }

  -- tree-sitter
  use {'nvim-treesitter/nvim-treesitter', run = ':TSUpdate' }

  use {
    'kyazdani42/nvim-tree.lua',
    requires = 'kyazdani42/nvim-web-devicons',
    config = function() require'nvim-tree'.setup {} end
  }

  -- lsp
  use 'neovim/nvim-lspconfig'

  -- lsp installer
  use { "williamboman/mason.nvim" }

  -- autocomplete
  use {'ms-jpq/coq_nvim', branch = 'coq'}
  -- use {'ms-jpq/coq.artifacts', branch = 'artifacts'}
 
 
  -- surround 快速操作配對字符 例如ds' 刪除前後的'
  use({
    "kylechui/nvim-surround",
    tag = "*", -- Use for stability; omit to use `main` branch for the latest features
    config = function()
        require("nvim-surround").setup({
            -- Configuration here, or leave empty to use defaults
        })
    end
  })

  -- fuzzy finder
  use {
    'nvim-telescope/telescope.nvim',
    requires = { {'nvim-lua/plenary.nvim'} }
  }
 
  -- indent guides
  use "lukas-reineke/indent-blankline.nvim"

  -- themes
  use {'drewtempelmeyer/palenight.vim'}
  use {'rakr/vim-one'}
end)

