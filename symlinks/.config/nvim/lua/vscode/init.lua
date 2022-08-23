vim.cmd [[packadd packer.nvim]]

require('packer').startup(function()
  -- Packer can manage itself
  use 'wbthomason/packer.nvim'

  -- nvim-surround
  use({
    'kylechui/nvim-surround',
    tag = "*", -- Use for stability; omit to use `main` branch for the latest features
    config = function()
        require('nvim-surround').setup({
            -- Configuration here, or leave empty to use defaults
        })
    end
  })

  -- comment
  use {
      'numToStr/Comment.nvim',
      config = function()
          require('Comment').setup()
      end
  }
end)

