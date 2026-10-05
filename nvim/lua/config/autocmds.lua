-- Editor behaviour. Returns the save/reopen helpers used by config/keymaps.lua.
local M = {}

local function augroup(name)
  return vim.api.nvim_create_augroup("user_" .. name, { clear = true })
end

local function disk_mtime(path)
  local stat = vim.uv.fs_stat(path)
  return stat and (stat.mtime.sec .. ":" .. stat.mtime.nsec) or nil
end

local function remember_mtime(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  if name ~= "" and vim.bo[buf].buftype == "" then
    vim.b[buf].disk_mtime = disk_mtime(name)
  end
end

local function relative_name(buf)
  return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":~:.")
end

--- A buffer is autosaved only when it is a real, writable, modified file buffer.
function M.can_autosave(buf)
  if not (vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf)) then
    return false
  end
  local bo = vim.bo[buf]
  return bo.modified
    and bo.modifiable
    and not bo.readonly
    and bo.buftype == ""
    and vim.api.nvim_buf_get_name(buf) ~= ""
    and vim.b[buf].autosave ~= false
end

--- True when another tool changed or deleted the file after Neovim last read or wrote it.
local function changed_on_disk(buf)
  local known = vim.b[buf].disk_mtime
  return known ~= nil and disk_mtime(vim.api.nvim_buf_get_name(buf)) ~= known
end

local function write(buf)
  local ok, err = pcall(vim.api.nvim_buf_call, buf, function()
    vim.cmd("silent lockmarks update")
  end)
  if not ok then
    vim.notify(("Save failed: %s\n%s"):format(relative_name(buf), err), vim.log.levels.ERROR)
  end
end

--- Silent autosave. Never overwrites a file that changed on disk and never raises.
--- `force` ignores the vim.g.autosave toggle (explicit <C-s>).
function M.autosave(buf, force)
  if not (force or vim.g.autosave) or not M.can_autosave(buf) then
    return
  end
  if changed_on_disk(buf) then
    local mtime = disk_mtime(vim.api.nvim_buf_get_name(buf)) or "deleted"
    if vim.b[buf].autosave_warned ~= mtime then
      vim.b[buf].autosave_warned = mtime
      vim.notify(
        ("Not autosaved, %s changed on disk. Use :w! to overwrite or :e! to reload."):format(relative_name(buf)),
        vim.log.levels.WARN
      )
    end
    return
  end
  write(buf)
end

function M.autosave_all(force)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    M.autosave(buf, force)
  end
end

--- <C-s>: save the current buffer (asking for a name if it has none), then all other modified ones.
function M.save()
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].buftype == "" and vim.api.nvim_buf_get_name(buf) == "" then
    vim.ui.input({ prompt = "Save as: ", default = vim.fn.getcwd() .. "/", completion = "file" }, function(path)
      if path and path ~= "" then
        pcall(vim.cmd.write, vim.fn.fnameescape(path))
      end
    end)
  elseif vim.bo[buf].modified then
    pcall(vim.cmd.update)
  end
  M.autosave_all(true)
end

M.closed = {}

--- Reopen the most recently closed file buffer (IntelliJ "Reopen Closed Tab").
function M.reopen_closed()
  while #M.closed > 0 do
    local path = table.remove(M.closed)
    local buf = vim.fn.bufnr(path)
    if vim.fn.filereadable(path) == 1 and (buf == -1 or not vim.bo[buf].buflisted) then
      vim.cmd.edit(vim.fn.fnameescape(path))
      return
    end
  end
  vim.notify("No closed files to reopen", vim.log.levels.INFO)
end

-- nested: the write must fire BufWritePre/Post (mkdir, mtime, LSP didSave, gitsigns)
vim.api.nvim_create_autocmd("FocusLost", {
  group = augroup("autosave_all"),
  nested = true,
  callback = function()
    M.autosave_all()
  end,
})

vim.api.nvim_create_autocmd("BufLeave", {
  group = augroup("autosave_buf"),
  nested = true,
  callback = function(args)
    M.autosave(args.buf)
  end,
})

-- BufReadPost also fires when checktime reloads a buffer. FileChangedShellPost is left out on
-- purpose: it also fires when the user keeps their version after a W12 conflict.
vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
  group = augroup("disk_mtime"),
  callback = function(args)
    remember_mtime(args.buf)
    vim.b[args.buf].autosave_warned = nil
  end,
})

vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "TermClose", "TermLeave" }, {
  group = augroup("checktime"),
  callback = function()
    if vim.o.buftype ~= "nofile" and vim.fn.getcmdwintype() == "" then
      pcall(vim.cmd.checktime)
    end
  end,
})

-- CursorHold fires once per idle period, so also poll while idle in Normal mode:
-- files edited by other tools show up live even when Neovim is not focused.
if (vim.g.autoread_poll_ms or 0) > 0 then
  M.poll_timer = M.poll_timer or vim.uv.new_timer()
  M.poll_timer:start(
    vim.g.autoread_poll_ms,
    vim.g.autoread_poll_ms,
    vim.schedule_wrap(function()
      if vim.api.nvim_get_mode().mode == "n" and vim.fn.getcmdwintype() == "" then
        pcall(vim.cmd.checktime)
      end
    end)
  )
end

-- A deleted file fires this on every checktime; Neovim reports the deletion once itself (E211)
vim.api.nvim_create_autocmd("FileChangedShellPost", {
  group = augroup("reload_notify"),
  callback = function(args)
    if not vim.bo[args.buf].modified and vim.uv.fs_stat(vim.api.nvim_buf_get_name(args.buf)) then
      vim.notify("Reloaded " .. vim.fn.fnamemodify(args.file, ":~:.") .. " (changed on disk)", vim.log.levels.INFO)
    end
  end,
})

-- No empty "[No Name]" tab next to the first file: `nvim <dir>` (the tree's netrw hijack) and plain
-- `nvim` start with an empty buffer that opening a file from the tree does not reuse.
vim.api.nvim_create_autocmd("BufReadPost", {
  group = augroup("drop_empty_buffers"),
  callback = function()
    vim.schedule(function()
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if
          vim.bo[buf].buflisted
          and vim.bo[buf].buftype == ""
          and not vim.bo[buf].modified
          and vim.api.nvim_buf_get_name(buf) == ""
          and vim.api.nvim_buf_line_count(buf) == 1
          and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
          and #vim.fn.win_findbuf(buf) == 0
        then
          pcall(vim.api.nvim_buf_delete, buf, {})
        end
      end
    end)
  end,
})

vim.api.nvim_create_autocmd("BufDelete", {
  group = augroup("closed_files"),
  callback = function(args)
    local name = vim.api.nvim_buf_get_name(args.buf)
    if name == "" or vim.bo[args.buf].buftype ~= "" or not vim.bo[args.buf].buflisted then
      return
    end
    M.closed = vim.tbl_filter(function(it)
      return it ~= name
    end, M.closed)
    table.insert(M.closed, name)
    if #M.closed > 50 then
      table.remove(M.closed, 1)
    end
  end,
})

vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup("highlight_yank"),
  callback = function()
    vim.hl.on_yank({ timeout = 200 })
  end,
})

vim.api.nvim_create_autocmd("BufReadPost", {
  group = augroup("last_location"),
  callback = function(args)
    local buf = args.buf
    if vim.bo[buf].filetype == "gitcommit" or vim.b[buf].last_location_restored then
      return
    end
    vim.b[buf].last_location_restored = true
    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(buf) and vim.api.nvim_get_current_buf() == buf then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

vim.api.nvim_create_autocmd("VimResized", {
  group = augroup("resize_splits"),
  callback = function()
    local tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. tab)
  end,
})

--- Helper views (help, quickfix, blame, diff bases): no editor tab, `q` closes them
local function close_with_q(args)
  vim.bo[args.buf].buflisted = false
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(args.buf) then
      return
    end
    vim.keymap.set("n", "q", function()
      if not pcall(vim.cmd.close) then
        pcall(vim.api.nvim_buf_delete, args.buf, { force = true })
      end
    end, { buffer = args.buf, silent = true, nowait = true, desc = "Close window" })
  end)
end

vim.api.nvim_create_autocmd("FileType", {
  group = augroup("close_with_q"),
  pattern = { "checkhealth", "gitsigns-blame", "help", "lspinfo", "man", "nvim-undotree", "qf", "startuptime" },
  callback = close_with_q,
})

-- Gitsigns diff bases (Space g d / g D) keep the file's own filetype
vim.api.nvim_create_autocmd("BufWinEnter", {
  group = augroup("close_diff_base_with_q"),
  pattern = "gitsigns://*",
  callback = close_with_q,
})

vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroup("auto_create_dir"),
  callback = function(args)
    if args.match:match("^%w%w+:[\\/][\\/]") then
      return
    end
    local file = vim.uv.fs_realpath(args.match) or args.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = augroup("wrap_text"),
  pattern = { "gitcommit", "markdown", "text" },
  callback = function()
    vim.opt_local.wrap = true
  end,
})

return M
