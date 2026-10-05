-- netrw would run before neo-tree's hijack and give the first window a window-local cwd (the launch
-- dir), so `nvim ~/Work/project` started elsewhere would search the wrong folder.
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
-- neo-tree's netrw hijack runs `autocmd! FileExplorer *`, which needs the netrw group to exist
vim.api.nvim_create_augroup("FileExplorer", { clear = true })
-- Other tools edit the same checkout concurrently: keep git child processes (pickers, gitsigns,
-- terminals) from taking optional index locks.
vim.env.GIT_OPTIONAL_LOCKS = "0"

local opt = vim.opt

opt.number = true
opt.relativenumber = false
opt.cursorline = true
opt.signcolumn = "yes"
opt.termguicolors = true
opt.showmode = false
opt.laststatus = 3
opt.showtabline = 2
opt.winborder = "rounded"
opt.wrap = false
opt.linebreak = true
opt.breakindent = true
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.smoothscroll = true
opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
opt.pumheight = 12

-- Treesitter folds (zc/zo, zM/zR), all open by default; a closed fold shows its first line highlighted.
-- plugins/treesitter.lua switches a window to foldmethod=expr once a parser runs, so big files and
-- files without a parser never evaluate the fold expression.
opt.foldmethod = "manual"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldtext = ""
opt.foldlevel = 99
opt.foldlevelstart = 99
opt.fillchars = { eob = " ", fold = " " }

opt.splitright = true
opt.splitbelow = true

opt.mouse = "a"
opt.confirm = true
vim.schedule(function()
  opt.clipboard = vim.env.SSH_CONNECTION and "" or "unnamedplus"
end)

opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.softtabstop = 4
opt.shiftround = true

opt.ignorecase = true
opt.smartcase = true
opt.inccommand = "split"
opt.grepprg = "rg --vimgrep --smart-case --hidden --glob=!.git/"

opt.autoread = true
opt.undofile = true
opt.undolevels = 10000

opt.updatetime = 250
opt.timeoutlen = 300

opt.virtualedit = "block"
opt.jumpoptions:append("view")
opt.shortmess:append({ W = true, I = true, c = true })
opt.wildmode = "longest:full,full"
