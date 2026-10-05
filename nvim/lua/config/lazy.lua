local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", "https://github.com/folke/lazy.nvim.git", lazypath })
  if vim.v.shell_error ~= 0 then
    error("lazy.nvim clone failed:\n" .. out)
  end
end
vim.opt.rtp:prepend(lazypath)

-- lazy's default UI icons are Nerd Font glyphs
local ascii_icons = {
  cmd = "cmd ",
  config = "config ",
  event = "event ",
  favorite = "* ",
  ft = "ft ",
  init = "init ",
  import = "import ",
  keys = "keys ",
  lazy = "lazy ",
  plugin = "plugin ",
  runtime = "runtime ",
  require = "require ",
  source = "source ",
  start = "start ",
}

require("lazy").setup({
  spec = { { import = "plugins" } },
  install = { colorscheme = { "islands-dark", "habamax" } },
  checker = { enabled = false },
  change_detection = { notify = false },
  rocks = { enabled = false },
  ui = { icons = not vim.g.have_nerd_font and ascii_icons or nil },
})
