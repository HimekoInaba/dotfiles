-- Editor keymaps. Plugin keys live in lua/plugins/*.lua (`keys` and LspAttach), see README.md.
-- Neovim defaults kept: grr gri grn gra grt grx gO K [d ]d [D ]D <C-w>d gc gcc ]q [q an in ]n [n.
local map = vim.keymap.set
local files = require("config.autocmds")

-- IntelliJ Cmd+S. Insert-mode signature help moves from <C-s> to blink.cmp's <C-k>.
map({ "n", "i", "x", "s" }, "<C-s>", files.save, { desc = "Save file (and all modified)" })
map("n", "<leader>bu", files.reopen_closed, { desc = "Reopen closed tab" })
map("n", "<leader>bb", "<Cmd>e #<CR>", { desc = "Switch to previous file" })
map("n", "<leader>fn", "<Cmd>enew<CR>", { desc = "New file" })
map("n", "<leader>qq", "<Cmd>qa<CR>", { desc = "Quit all" })

map("n", "<Esc>", "<Cmd>nohlsearch<CR><Esc>", { desc = "Clear search highlight" })

-- Windows: <C-h/j/k/l> (replaces the <C-l> redraw default), <leader>w proxies <C-w>
map("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })
map("n", "<leader>|", "<C-w>v", { desc = "Split right" })
map("n", "<leader>-", "<C-w>s", { desc = "Split below" })

-- Move line(s): Shift+Up/Down, plus IntelliJ's Option+Shift+Up/Down when Option sends Esc+
for _, keys in ipairs({ { "<S-Down>", "<S-Up>" }, { "<M-S-Down>", "<M-S-Up>" } }) do
  local down, up = keys[1], keys[2]
  map("n", down, "<Cmd>execute 'silent! move .+' . v:count1<CR>", { desc = "Move line down" })
  map("n", up, "<Cmd>execute 'silent! move .-' . (v:count1 + 1)<CR>", { desc = "Move line up" })
  map("i", down, "<Esc><Cmd>silent! move .+1<CR>gi", { desc = "Move line down" })
  map("i", up, "<Esc><Cmd>silent! move .-2<CR>gi", { desc = "Move line up" })
  map("x", down, ":<C-u>execute \"silent! '<,'>move '>+\" . v:count1<CR>gv", { desc = "Move selection down", silent = true })
  map("x", up, ":<C-u>execute \"silent! '<,'>move '<-\" . (v:count1 + 1)<CR>gv", { desc = "Move selection up", silent = true })
end

-- IntelliJ Cmd+D
map("n", "<leader>cd", function()
  local col = vim.fn.col(".")
  vim.cmd("copy .")
  vim.fn.cursor(0, col)
end, { desc = "Duplicate line" })
map("x", "<leader>cd", ":copy '><CR>", { desc = "Duplicate selection", silent = true })

-- IntelliJ Cmd+/. Legacy terminals send <C-_> for Ctrl+/, kitty-protocol terminals <C-/>.
for _, lhs in ipairs({ "<C-/>", "<C-_>" }) do
  map("n", lhs, "gcc", { remap = true, desc = "Comment line" })
  map("x", lhs, "gc", { remap = true, desc = "Comment selection" })
  map("i", lhs, "<Cmd>normal gcc<CR>", { desc = "Comment line" })
end

-- IntelliJ Option+Up / Option+Down on top of the 0.12 treesitter `an` / `in` defaults
map("n", "<C-Space>", "van", { remap = true, desc = "Expand selection" })
map("x", "<C-Space>", "an", { remap = true, desc = "Expand selection" })
map("x", "<BS>", "in", { remap = true, desc = "Shrink selection" })
map("n", "<M-Up>", "van", { remap = true, desc = "Expand selection" })
map("x", "<M-Up>", "an", { remap = true, desc = "Expand selection" })
map("x", "<M-Down>", "in", { remap = true, desc = "Shrink selection" })

map("x", "<", "<gv", { desc = "Unindent" })
map("x", ">", ">gv", { desc = "Indent" })
map("x", "<Tab>", ">gv", { desc = "Indent" })
map("x", "<S-Tab>", "<gv", { desc = "Unindent" })

-- With clipboard=unnamedplus, x and paste over a selection keep the clipboard
map({ "n", "x" }, "x", '"_x', { desc = "Delete char (keep clipboard)" })
map("x", "p", "P", { desc = "Paste (keep clipboard)" })

for _, ch in ipairs({ ",", ".", ";" }) do
  map("i", ch, ch .. "<C-g>u", { desc = "Insert " .. ch .. " with undo break" })
end

-- IntelliJ F2 / Shift+F2 (errors only); ]d [d stay "any severity"
local function jump(count, severity)
  return function()
    vim.diagnostic.jump({ count = count, severity = vim.diagnostic.severity[severity] })
  end
end
map("n", "]e", jump(1, "ERROR"), { desc = "Next error" })
map("n", "[e", jump(-1, "ERROR"), { desc = "Previous error" })
map("n", "]w", jump(1, "WARN"), { desc = "Next warning" })
map("n", "[w", jump(-1, "WARN"), { desc = "Previous warning" })
map("n", "<leader>xd", vim.diagnostic.open_float, { desc = "Error description (line diagnostics)" })
map("n", "<leader>xq", function()
  local open = vim.fn.getqflist({ winid = 0 }).winid ~= 0
  vim.cmd(open and "cclose" or "botright copen")
end, { desc = "Toggle quickfix list" })
map("n", "<leader>xl", function()
  if vim.fn.getloclist(0, { winid = 0 }).winid ~= 0 then
    vim.cmd.lclose()
  elseif not pcall(vim.cmd.lopen) then
    vim.notify("No location list", vim.log.levels.INFO)
  end
end, { desc = "Toggle location list" })

local function copy_path(modifier)
  return function()
    local path = vim.fn.expand("%" .. modifier)
    vim.fn.setreg("+", path)
    vim.notify("Copied " .. path)
  end
end
map("n", "<leader>fy", copy_path(":."), { desc = "Copy relative path" })
map("n", "<leader>fY", copy_path(":p"), { desc = "Copy absolute path" })

map("n", "<leader>ua", function()
  vim.g.autosave = not vim.g.autosave
  vim.notify("Autosave " .. (vim.g.autosave and "on" or "off"))
end, { desc = "Toggle autosave" })
map("n", "<leader>uu", function()
  vim.cmd.packadd("nvim.undotree")
  require("undotree").open()
end, { desc = "Undo tree (Local History)" })
map("n", "<leader>uw", "<Cmd>setlocal wrap!<CR>", { desc = "Toggle soft wrap" })
map("n", "<leader>ud", function()
  vim.diagnostic.enable(not vim.diagnostic.is_enabled())
end, { desc = "Toggle diagnostics" })
map("n", "<leader>uh", function()
  vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = 0 }), { bufnr = 0 })
end, { desc = "Toggle inlay hints" })

-- iTerm's "Natural Text Editing" preset: Cmd+Left/Right send <C-a>/<C-e>, Option+Left/Right
-- <M-b>/<M-f>, Option+Backspace <M-BS>, Cmd+Backspace <C-u> (Vim's own delete to line start),
-- fn+Delete <C-d>, Option+fn+Delete <M-d>. Increment/decrement move to +/-.
if vim.g.macos_text_keys then
  map({ "n", "x", "o" }, "<C-a>", "^", { desc = "Line start (Cmd+Left)" })
  map({ "n", "x", "o" }, "<C-e>", "$", { desc = "Line end (Cmd+Right)" })
  map("n", "+", "<C-a>", { desc = "Increment number" })
  map("n", "-", "<C-x>", { desc = "Decrement number" })
  map("x", "+", "g<C-a>", { desc = "Increment numbers" })
  map("x", "-", "g<C-x>", { desc = "Decrement numbers" })
  map("i", "<C-a>", "<C-o>^", { desc = "Line start (Cmd+Left)" })
  map("i", "<C-e>", "<End>", { desc = "Line end (Cmd+Right)" })
  map("i", "<C-d>", "<Del>", { desc = "Delete forward (fn+Delete)" })
  map("i", "<M-d>", function()
    return vim.fn.col(".") > #vim.fn.getline(".") and "<Del>" or "<C-o>de"
  end, { expr = true, desc = "Delete word forward (Option+fn+Delete)" })
  map({ "i", "c" }, "<M-b>", "<S-Left>", { desc = "Word left (Option+Left)" })
  map({ "i", "c" }, "<M-f>", "<S-Right>", { desc = "Word right (Option+Right)" })
  -- in prompt buffers (search popups, rename) Insert-mode <C-w> starts a window command, <C-S-w> deletes a word
  map("i", "<M-BS>", function()
    return vim.bo.buftype == "prompt" and "<C-S-w>" or "<C-w>"
  end, { expr = true, desc = "Delete word (Option+Backspace)" })
  map("c", "<M-BS>", "<C-w>", { desc = "Delete word (Option+Backspace)" })
  map("c", "<C-a>", "<Home>", { desc = "Line start (Cmd+Left)" })
end
