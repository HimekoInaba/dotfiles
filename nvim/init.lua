-- Switches read by the modules below
vim.g.have_nerd_font = true -- false = ASCII only, for a terminal font without icon glyphs (see README.md)
vim.g.autosave = true -- write modified files on FocusLost/BufLeave, toggle with <leader>ua
vim.g.autoread_poll_ms = 1000 -- reload files changed by other tools while idle, 0 disables
vim.g.macos_text_keys = true -- Cmd/Option+arrows and fn+Delete from iTerm's "Natural Text Editing" preset

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

pcall(require, "config.local") -- optional machine-specific settings, not in git

require("config.options")
require("config.lazy")
require("config.autocmds")
require("config.keymaps")
