-- Syntax highlighting, folds and sticky scroll (nvim-treesitter main branch)
local parsers = {
  "bash", "comment", "diff", "dockerfile", "git_config", "git_rebase", "gitattributes", "gitcommit",
  "gitignore", "groovy", "html", "java", "javadoc", "json", "kotlin", "lua", "luadoc", "markdown",
  "markdown_inline", "printf", "properties", "query", "regex", "sql", "toml", "vim", "vimdoc", "xml", "yaml",
}

-- Treesitter indent only where it beats the built-in indent (Java keeps Vim's own indent)
local ts_indent = { xml = true, html = true }

return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false, -- does not support lazy-loading
    build = function()
      require("nvim-treesitter").update():wait(300000)
    end,
    config = function()
      local task = require("nvim-treesitter").install(parsers)
      if #vim.api.nvim_list_uis() == 0 then
        task:wait(300000) -- headless bootstrap: install parsers synchronously
      end

      local group = vim.api.nvim_create_augroup("user_treesitter", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        desc = "Start treesitter highlighting and folds for filetypes with an installed parser",
        callback = function(ev)
          local lang = vim.treesitter.language.get_lang(ev.match)
          if not lang or not vim.treesitter.language.add(lang) then
            return
          end
          if not pcall(vim.treesitter.start, ev.buf, lang) then
            return
          end
          vim.wo[0][0].foldmethod = "expr"
          if ts_indent[lang] then
            vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
      -- FileType runs in a helper window for buffers loaded in the background (pickers, LSP jumps)
      vim.api.nvim_create_autocmd("BufWinEnter", {
        group = group,
        desc = "Treesitter folds in every window that shows a buffer with a running parser",
        callback = function(ev)
          if vim.b[ev.buf].ts_highlight then
            vim.wo[0][0].foldmethod = "expr"
          end
        end,
      })
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter-context",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      max_lines = 5,
      multiline_threshold = 1,
      min_window_height = 20,
      trim_scope = "outer",
      mode = "cursor",
    },
    keys = {
      { "[x", function() require("treesitter-context").go_to_context(vim.v.count1) end, desc = "Go to sticky line (enclosing scope)" },
      { "<leader>us", "<cmd>TSContext toggle<cr>", desc = "Toggle sticky lines" },
    },
  },
}
