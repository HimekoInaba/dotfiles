-- IntelliJ reopens a project with its editor tabs and the Project tree. A project start is `nvim` in a
-- folder of a project or `nvim <dir>`: it restores the files that were open when Neovim last quit in
-- that folder (persistence.nvim saves them on quit) and shows the tree. `nvim <file>` leaves sessions alone.
local project_markers = { ".git", "gradlew", "settings.gradle", "settings.gradle.kts", "pom.xml" }

local function restore()
  require("persistence").load()
  vim.cmd("Neotree show filesystem left")
end

return {
  "folke/persistence.nvim",
  lazy = true, -- loaded, and so saving on quit, only after a project start
  opts = { branch = false },
  init = function()
    vim.opt.sessionoptions = { "buffers", "curdir", "folds", "tabpages", "winsize" }
    local group = vim.api.nvim_create_augroup("user_session", { clear = true })
    vim.api.nvim_create_autocmd("StdinReadPre", {
      group = group,
      callback = function()
        vim.g.started_with_stdin = true
      end,
    })
    vim.api.nvim_create_autocmd("VimEnter", {
      group = group,
      callback = function()
        if #vim.api.nvim_list_uis() == 0 or vim.g.started_with_stdin then
          return
        end
        local argc, buf = vim.fn.argc(), vim.api.nvim_get_current_buf()
        if argc == 0 and vim.fs.root(vim.fn.getcwd(), project_markers) then
          vim.schedule(restore)
        elseif argc == 1 and vim.fn.isdirectory(vim.fn.argv(0)) == 1 then
          vim.fn.chdir(vim.fn.argv(0))
          -- neo-tree's netrw hijack replaces the directory buffer a moment later; restoring before
          -- that would let it replace a restored file instead
          vim.api.nvim_create_autocmd("BufWipeout", {
            group = group,
            buffer = buf,
            once = true,
            callback = function()
              vim.schedule(restore)
            end,
          })
        end
      end,
    })
    vim.api.nvim_create_autocmd("User", {
      group = group,
      pattern = "PersistenceLoadPre",
      desc = "Close the tree of `nvim <dir>` and drop its state, which would otherwise be redrawn stale",
      callback = function()
        require("neo-tree.sources.manager").dispose("filesystem")
      end,
    })
    vim.api.nvim_create_autocmd("User", {
      group = group,
      pattern = "PersistenceSavePre",
      desc = "Keep only file windows: the tree, terminals, help and lists reopen on demand",
      callback = function()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          if vim.bo[vim.api.nvim_win_get_buf(win)].buftype ~= "" then
            pcall(vim.api.nvim_win_close, win, true)
          end
        end
        -- `nvim <dir>` puts the folder in the argument list, which a session would reopen as a tab
        vim.cmd("silent! %argdelete")
      end,
    })
  end,
}
