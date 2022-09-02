require'nvim-treesitter.configs'.setup {
  highlight = {
    enable = true,
    custom_captures = {
      -- Highlight the @foo.bar capture group with the "Identifier" highlight group.
      ["foo.bar"] = "Identifier",
    },
    -- rainbow = {
    --   enable = true,
    --   disable = { "svelte" },-- list of languages you want to disable the plugin for
    --   extended_mode = true, -- Also highlight non-bracket delimiters like html tags, boolean or table: lang -> boolean
    --   max_file_lines = nil, -- Do not enable for files with more than n lines, int
    --   -- colors = {}, -- table of hex strings
    --   -- termcolors = {} -- table of colour name strings
    -- },
    ensure_installed = {
      "tsx",
      "json",
      "yaml",
      "html",
      "scss",
      "css",
      "svelte",
    },
    -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
    -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
    -- Using this option may slow down your editor, and you may see some duplicate highlights.
    -- Instead of true it can also be a list of languages
    -- additional_vim_regex_highlighting = true,
  },
}

local parser_config = require "nvim-treesitter.parsers".get_parser_configs()
parser_config.tsx.filetype_to_parsername = { "javascript", "typescript.tsx" }

cmd 'autocmd BufRead,BufEnter *.astro set filetype=astro'
