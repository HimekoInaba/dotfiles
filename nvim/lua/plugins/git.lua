-- Gutter change markers, blame and rollback (IntelliJ VCS gutter). Git pickers are in plugins/snacks.lua.
return {
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPost", "BufNewFile", "BufWritePre" },
    opts = {
      signs = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "▁" },
        topdelete = { text = "▔" },
        changedelete = { text = "▎" },
        untracked = { text = "┆" },
      },
      signs_staged = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "▁" },
        topdelete = { text = "▔" },
        changedelete = { text = "▎" },
      },
      current_line_blame_opts = { virt_text_pos = "eol", delay = 500 },
      current_line_blame_formatter = "<author>, <author_time:%Y-%m-%d> - <summary>",
      on_attach = function(buf)
        local gs = require("gitsigns")
        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc })
        end
        local function selected_lines()
          return { vim.fn.line("."), vim.fn.line("v") }
        end

        map("n", "]h", function()
          if vim.wo.diff then
            vim.cmd.normal({ "]c", bang = true })
          else
            gs.nav_hunk("next")
          end
        end, "Next change")
        map("n", "[h", function()
          if vim.wo.diff then
            vim.cmd.normal({ "[c", bang = true })
          else
            gs.nav_hunk("prev")
          end
        end, "Previous change")
        map("n", "]H", function() gs.nav_hunk("last") end, "Last change")
        map("n", "[H", function() gs.nav_hunk("first") end, "First change")

        map("n", "<leader>ga", gs.blame, "Annotate with Git Blame")
        map("n", "<leader>gb", function() gs.blame_line({ full = true }) end, "Blame line")
        map("n", "<leader>gd", gs.diffthis, "Diff file vs index")
        map("n", "<leader>gD", function() gs.diffthis("HEAD") end, "Diff file vs last commit")
        map("n", "<leader>gp", gs.preview_hunk, "Show change (preview hunk)")
        map("n", "<leader>gh", gs.stage_hunk, "Stage / unstage change (hunk)")
        map("x", "<leader>gh", function() gs.stage_hunk(selected_lines()) end, "Stage / unstage lines")
        map("n", "<leader>gr", gs.reset_hunk, "Rollback change (hunk)")
        map("x", "<leader>gr", function() gs.reset_hunk(selected_lines()) end, "Rollback lines")
        map("n", "<leader>gR", gs.reset_buffer, "Rollback file")
        map("n", "<leader>ub", gs.toggle_current_line_blame, "Toggle inline blame")
        map({ "o", "x" }, "ih", gs.select_hunk, "Inside change (hunk)")
      end,
    },
  },
}
