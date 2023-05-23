return {
  -- tailwindcss color
  {
    "mrshmllow/document-color.nvim",
    version = "*", -- Use for stability; omit to use `main` branch for the latest features
    config = function()
      require("document-color").setup({
        -- Default options
        mode = "background", -- "background" | "foreground" | "single"
      })
    end,
  },

  -- surround 快速操作配對字符 例如ds' 刪除前後的'
  {
    "kylechui/nvim-surround",
    version = "*",
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
  {
    "norcalli/nvim-colorizer.lua",
    version = "*",
  },
}
