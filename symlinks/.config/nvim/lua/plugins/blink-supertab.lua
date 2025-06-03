return {
  {
    "saghen/blink.cmp",
    opts = {
      keymap = {
        preset = "super-tab",
        ["<Tab>"] = { "select_next", "fallback" },
        ["<S-Tab>"] = { "select_prev", "fallback" },
      },
    },
  },
}
