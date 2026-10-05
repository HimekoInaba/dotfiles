-- IntelliJ "Replace in Files" (Cmd+Shift+R) with a live preview
local nerd = vim.g.have_nerd_font == true

return {
  "MagicDuck/grug-far.nvim",
  cmd = { "GrugFar", "GrugFarWithin" },
  opts = {
    -- the same files as Find in Files: dotfiles included, gitignored files and .git left out
    engines = { ripgrep = { extraArgs = "--hidden --glob=!.git/" } },
    icons = { enabled = nerd },
    spinnerStates = not nerd and { "|", "/", "-", "\\" } or nil,
  },
  keys = {
    {
      "<leader>sr",
      function()
        require("grug-far").open({ transient = true })
      end,
      mode = { "n", "x" },
      desc = "Replace in Files",
    },
  },
}
