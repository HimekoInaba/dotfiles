-- IntelliJ "Islands Dark" colours. Fallback: replace "islands-dark" with "tokyonight" in the config below.
return {
  {
    "vcraescu/islands-dark.nvim",
    -- young single-maintainer plugin: pinned to the reviewed commit, bump on purpose
    commit = "782988f600ba7e79f7d8c55a5e875cc6c2aa2cac",
    lazy = false,
    priority = 1000,
    -- Java colours from IntelliJ's own Islands Dark export, for treesitter and jdtls semantic tokens
    opts = {
      overrides = function(c)
        return {
          ["@attribute"] = { fg = c.metadata },
          ["@attribute.builtin"] = { fg = c.metadata },
          ["@function.call"] = { fg = c.foreground },
          ["@function.method.call"] = { fg = c.foreground },
          ["@type"] = { fg = c.foreground },
          ["@type.definition"] = { fg = c.foreground },
          ["@type.builtin"] = { fg = c.keyword },
          ["@comment.documentation"] = { fg = c.comment_doc, italic = true },

          ["@lsp.mod.readonly"] = {}, -- jdtls marks every `final var` readonly
          ["@lsp.type.decorator"] = { fg = c.metadata },
          ["@lsp.type.typeParameter"] = { fg = "#16BAAC" },
          ["@lsp.type.property"] = { fg = c.property },
          ["@lsp.type.enumMember"] = { fg = c.constant, italic = true },
          ["@lsp.typemod.property.static"] = { fg = c.constant, italic = true },
          ["@lsp.type.method"] = { fg = c.foreground },
          ["@lsp.typemod.method.declaration"] = { fg = c.method },
          ["@lsp.typemod.method.static"] = { fg = "#57AAF7", italic = true },

          -- indent guides as faint as IntelliJ's; the scheme has no snacks colours (NonText = comment grey)
          SnacksIndent = { fg = c.border },
          SnacksIndentScope = { fg = c.line_number },

          TreesitterContext = { bg = c.background_gutter },
          TreesitterContextLineNumber = { fg = c.line_number, bg = c.background_gutter },
          TreesitterContextBottom = { underline = true, sp = c.border },
          TreesitterContextLineNumberBottom = { underline = true, sp = c.border },
        }
      end,
    },
    config = function(_, opts)
      require("islands-dark").setup(opts)
      vim.cmd.colorscheme("islands-dark")
    end,
  },
  {
    "folke/tokyonight.nvim",
    lazy = true,
    opts = { style = "night" },
  },
}
