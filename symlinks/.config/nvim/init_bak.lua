require('common')
require('packages')
require('indentGuides')
require('treeSitterSetup')
require('coqSetup')
require('telescopeSetup')
require('tabLineTreeSetup')
require('lsp')

vim.cmd [[autocmd CursorHold,CursorHoldI * lua vim.lsp.diagnostic.show_line_diagnostics({focusable=false})]]

