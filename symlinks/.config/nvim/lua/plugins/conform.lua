return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      typescript = { "prettier" },
      typescriptreact = { "prettier" },
      javascript = { "prettier" },
      javascriptreact = { "prettier" },
    },
    formatters = {
      prettier = {
        -- 使用專案本地的 prettier
        require_cwd = true,
      },
    },
  },
}
