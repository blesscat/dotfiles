return {
  -- surround 快速操作配對字符 例如ds' 刪除前後的'
  -- {
  --   "kylechui/nvim-surround",
  --   version = "^3.0.0", -- Use for stability; omit to use `main` branch for the latest features
  --   event = "VeryLazy",
  --   config = function()
  --     require("nvim-surround").setup({
  --       -- Configuration here, or leave empty to use defaults
  --     })
  --   end,
  -- },
  {
    "f-person/git-blame.nvim",
    version = "*",
  },
  {
    "sphamba/smear-cursor.nvim",
    enabled = vim.fn.has("gui_running") == 0,
    opts = {},
  },
  {
    "echasnovski/mini.surround",
    opts = {
      mappings = {
        add = "ys", -- Add surrounding in Normal and Visual modes
        delete = "ds", -- Delete surrounding
        replace = "cs", -- Replace surrounding
        find = "gzf", --  (可自行決定是否修改)
        find_left = "gzF", -- (可自行決定是否修改)
        highlight = "gzh", -- (可自行決定是否修改)
        update_n_lines = "gzn", -- (可自行決定是否修改)
      },
    },
  },
}
