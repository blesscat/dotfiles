require('common')

-- vim.cmd [[packadd packer.nvim]]

require('packer').startup(function()
  -- Packer can manage itself
  use 'wbthomason/packer.nvim'

  -- autopairs
  use { "windwp/nvim-autopairs", config = function()
    require("nvim-autopairs").setup {}
  end}

  -- tree-sitter
  use { 'nvim-treesitter/nvim-treesitter', run = ':TSUpdate',
    -- requires = 'p00f/nvim-ts-rainbow',
    config = function() 
      require('treeSitterSetup')
    end
  }

  use 'f-person/git-blame.nvim'

  -- nvim-tree
  use { 'kyazdani42/nvim-tree.lua', requires = 'kyazdani42/nvim-web-devicons', config = function()
    require('nvimTreeSetup')
  end}

  -- lsp
  use { 'neovim/nvim-lspconfig', require = 'mrshmllow/document-color.nvim', config = function()
    require('lsp')
  end}

  -- lsp installer
  use { "williamboman/mason.nvim", config = function()
    require("mason").setup()
  end}

  -- autocomplete
  use { 'ms-jpq/coq_nvim', branch = 'coq', config = function()
    require('coqSetup')
  end}
  -- use {'ms-jpq/coq.artifacts', branch = 'artifacts'}
 
  -- comment
  use { 'numToStr/Comment.nvim', config = function()
    require('Comment').setup()
  end}

  -- statusbar
  use { 'nvim-lualine/lualine.nvim', requires = { 'kyazdani42/nvim-web-devicons', opt = true }, config = function()
      require('lualineSetup')
  end}

  -- tabline
  use { 'akinsho/bufferline.nvim', tag = "v2.*", requires = 'kyazdani42/nvim-web-devicons', config = function()
    require('bufferlineSetup')
  end}
 
  -- surround 快速操作配對字符 例如ds' 刪除前後的'
  use { "kylechui/nvim-surround",
    tag = "*", -- Use for stability; omit to use `main` branch for the latest features
    config = function()
        require("nvim-surround").setup()
  end}

  -- fuzzy finder
  use { 'nvim-telescope/telescope.nvim', requires = { {'nvim-lua/plenary.nvim'} }, config = function()
    require('telescopeSetup')
  end}
 
  -- indent guides
  use { "lukas-reineke/indent-blankline.nvim", config = function()
    require('indentGuides')
  end}

  -- Image Viewer as ASCII Art for Neovim, written in Lua
  use { 'samodostal/image.nvim', requires = { 'nvim-lua/plenary.nvim' }, config = function()
    require('imageSetup')
  end}

  -- terminal
  use {"akinsho/toggleterm.nvim", tag = 'v2.*', config = function()
      require('toggletermSetup')
  end}

  -- themes
  use {'drewtempelmeyer/palenight.vim'}
  use {'rakr/vim-one'}

  -- tailwindcss color
  use { 'mrshmllow/document-color.nvim', config = function()
    require("document-color").setup {
      -- Default options
      mode = "background", -- "background" | "foreground" | "single"
    }
  end}

  -- Invert text in vim. ex: ture <-> false
  use { 'nguyenvukhang/nvim-toggler', config = function()
    require('nvim-toggler').setup({
      inverses = {
        ['vim'] = 'emacs'
      }
    })
  end}

  -- markdown筆記
  use { 'phaazon/mind.nvim', branch = 'v2.1', config = function()
    require('mindSetup')
  end}

  -- markdown preview
  use {
      "iamcco/markdown-preview.nvim",
      run = function() vim.fn["mkdp#util#install"]() end,
  }


  -- githib copilot
  use 'github/copilot.vim'

end)
