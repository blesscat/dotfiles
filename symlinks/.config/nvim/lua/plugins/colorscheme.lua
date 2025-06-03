return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    proirity = 1000,
    opts = function()
      -- 判斷是否在 TUI 環境執行
      -- vim.fn.has("gui_running") 在 GUI 環境下返回 1，在 TUI 環境下返回 0
      local is_tui = (vim.fn.has("gui_running") == 0)

      local options = {
        -- 你可以選擇喜歡的 tokyonight 風格: "night", "storm", "day", "moon"
        style = "night",

        -- ★ 主要設定：只有在 TUI 時才啟用透明背景
        transparent = is_tui,

        -- 是否將主題顏色應用到 Neovim 內建終端機
        terminal_colors = true,

        styles = {
          -- 通用樣式設定
          comments = { italic = true },
          keywords = { italic = true },
          functions = {},
          variables = {},

          -- ★ 側邊欄和浮動視窗的背景設定
          --   TUI 環境下設為 "transparent"
          --   GUI 環境下設為 "dark" (tokyonight 的預設面板顏色) 或其他你喜歡的非透明顏色
          sidebars = is_tui and "transparent" or "dark",
          floats = is_tui and "transparent" or "dark",
        },

        -- 你也可以在這裡添加或覆寫其他的 tokyonight 設定選項
        -- 例如：
        -- on_colors = function(colors)
        --   -- colors.bg_visual = "#00ff00" -- 修改 visual selection 的背景色
        -- end,
        -- on_highlights = function(highlights, colors)
        --   -- highlights.MyCustomGroup = { fg = colors.orange, bold = true }
        -- end,
      }
      return options
    end,
    config = function(_, opts)
      -- 使用上面 opts function 回傳的設定來載入 tokyonight
      require("tokyonight").setup(opts)
      -- 載入色彩主題
      vim.cmd.colorscheme("tokyonight")
    end,
    -- opts = {
    --   -- transparent = true,
    --   style = "night",
    --   -- styles = {
    --   --   sidebars = "transparent",
    --   --   floats = "transparent",
    --   -- },
    -- },
  },
}
