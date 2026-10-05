-- Completion: Enter and Tab accept (IntelliJ "Choose Lookup Item"; neither replaces the rest of the word),
-- Ctrl+Space opens
local nerd = vim.g.have_nerd_font == true

return {
  {
    "saghen/blink.cmp",
    version = "1.*", -- release tags ship the prebuilt Rust matcher
    event = { "InsertEnter", "CmdlineEnter" },
    dependencies = { "rafamadriz/friendly-snippets" },
    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      -- grug-far's search and replace fields are no place for code completion
      enabled = function()
        return vim.bo.filetype ~= "grug-far"
      end,
      keymap = {
        preset = "enter",
        ["<Tab>"] = {
          function(cmp)
            if cmp.snippet_active() then
              return cmp.accept()
            end
            return cmp.select_and_accept()
          end,
          "snippet_forward",
          "fallback",
        },
        ["<S-Tab>"] = { "snippet_backward", "fallback" },
        ["<C-y>"] = { "select_and_accept", "fallback" },
      },
      appearance = { nerd_font_variant = "mono" },
      completion = {
        list = { selection = { preselect = true, auto_insert = false } },
        accept = { auto_brackets = { enabled = true } },
        documentation = { auto_show = true, auto_show_delay_ms = 300 },
        menu = {
          draw = {
            -- without a Nerd Font the kind is shown as text on the right ("Method", "Field")
            columns = nerd and { { "kind_icon" }, { "label", "label_description", gap = 1 } }
              or { { "label", "label_description", gap = 1 }, { "kind" } },
          },
        },
      },
      signature = { enabled = true }, -- Parameter Info; <C-k> toggles it in Insert mode
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
        per_filetype = {
          lua = { inherit_defaults = true, "lazydev" },
        },
        providers = {
          lazydev = { name = "LazyDev", module = "lazydev.integrations.blink", score_offset = 100 },
          snippets = {
            -- only members and jdtls postfix templates after `receiver.`, like IntelliJ
            should_show_items = function(ctx)
              return ctx.trigger.initial_kind ~= "trigger_character"
            end,
            opts = {
              -- friendly-snippets' Java set duplicates jdtls's own templates (sout, psvm, fori, ...)
              filter_snippets = function(filetype, file)
                return not (filetype == "java" and file:match("friendly%-snippets/snippets/java/java%.json$"))
              end,
            },
          },
        },
      },
      fuzzy = { implementation = "prefer_rust_with_warning" },
    },
    opts_extend = { "sources.default" },
  },
}
