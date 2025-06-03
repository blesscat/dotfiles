return {
  -- surround 快速操作配對字符 例如ds' 刪除前後的'
  {
    "kylechui/nvim-surround",
    version = "^3.0.0", -- Use for stability; omit to use `main` branch for the latest features
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup({
        -- Configuration here, or leave empty to use defaults
      })
    end,
  },
  {
    "f-person/git-blame.nvim",
    version = "*",
  },
  -- {
  --   "hrsh7th/nvim-cmp",
  --   dependencies = { "L3MON4D3/LuaSnip" },
  --   opts = function(_, opts)
  --     local cmp = require("cmp")
  --     opts.snippet = {
  --       expand = function(args)
  --         require("luasnip").lsp_expand(args.body)
  --       end,
  --     }
  --     opts.sources = cmp.config.sources({
  --       { name = "nvim_lsp" },
  --       { name = "luasnip" },
  --       { name = "buffer" },
  --       { name = "path" },
  --       { name = "codeium" },
  --     })
  --   end,
  -- },
}
