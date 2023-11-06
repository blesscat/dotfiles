-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--

local function map(mode, lhs, rhs, opts)
  local options = { noremap = true, silent = true }
  if opts then
    options = vim.tbl_extend("force", options, opts)
  end
  vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

map("n", "B", "<cmd>bd<CR>")
map("n", "<leader>mp", "<cmd>MindOpenProject<CR>")
map("n", "<leader>mm", "<cmd>MindOpenMain<CR>")
map("n", "<leader>mr", "<cmd>MindReloadState<CR>")
map("n", "<leader>o", "<cmd>!open %:p:h<CR>")

map("v", "<leader>y", '"hy')
map("n", "<leader>y", '"hy')

map("n", "<leader>p", '"hp')
map("v", "<leader>p", '"hp')

map("n", "<leader>C", "<cmd>let @+=expand('%:p')<CR>")
