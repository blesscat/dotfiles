return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      tailwindcss = {
        filetypes = { "html", "javascript", "typescript", "javascriptreact", "typescriptreact", "vue", "svelte" },
        init_options = {
          userLanguages = {
            eelixir = "html",
            eruby = "html",
            heex = "html",
          },
        },
      },
    },
  },

  -- 補全時顯示 Tailwind 顏色方塊
  {
    "roobert/tailwindcss-colorizer-cmp.nvim",
    dependencies = { "nvim-cmp" },
    opts = {
      color_square_width = 2,
    },
    config = function(_, opts)
      require("tailwindcss-colorizer-cmp").setup(opts)
    end,
  },

  -- Tailwind CSS snippets 套件（用 LuaSnip）
  --{
  --  "rafamadriz/friendly-snippets",
  --  config = function()
  --    require("luasnip.loaders.from_vscode").lazy_load()
  --  end,
  --},

  -- 確保 cmp 有接上 LuaSnip
  {
    "hrsh7th/nvim-cmp",
    dependencies = { "L3MON4D3/LuaSnip" },
    opts = function(_, opts)
      local cmp = require("cmp")
      opts.snippet = {
        expand = function(args)
          require("luasnip").lsp_expand(args.body)
        end,
      }

      -- 加上 snippet source
      opts.sources = cmp.config.sources(vim.list_extend(opts.sources, {
        { name = "luasnip" },
      }))
    end,
  },
}
