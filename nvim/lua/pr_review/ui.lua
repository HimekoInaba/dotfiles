-- Popups of the pull request review (pr_review/init.lua): the comment editor and the thread viewer
local M = {}

local function notify(message, level)
  vim.notify(message, level, { title = "Pull request" })
end

local function close(win)
  if vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
end

--- "3h ago" for a GitHub timestamp such as 2026-10-05T09:12:44Z
local function ago(iso)
  local year, month, day, hour, min, sec = (iso or ""):match("^(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
  if not year then
    return iso or ""
  end
  -- both sides go through os.time as if they were local time, so the difference is exact
  local seconds = os.time(os.date("!*t")) - os.time({ year = year, month = month, day = day, hour = hour, min = min, sec = sec })
  if seconds < 60 then
    return "just now"
  elseif seconds < 3600 then
    return math.floor(seconds / 60) .. "m ago"
  elseif seconds < 86400 then
    return math.floor(seconds / 3600) .. "h ago"
  elseif seconds < 30 * 86400 then
    return math.floor(seconds / 86400) .. "d ago"
  end
  return ("%s-%s-%s"):format(year, month, day)
end

--- Editor for a comment or a review summary. `Ctrl+s` (or `:w`) calls `opts.send(text, done)`. The popup
--- closes once `done()` reports no error and keeps the text otherwise. `q` in Normal mode cancels.
--- Autosave never sends: it only writes buffers of real files.
---@param opts { title: string, text?: string, allow_empty?: boolean, send: fun(text: string, done: fun(err?: string)) }
function M.edit(opts)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, ("pr-review://comment/%d"):format(buf))
  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(opts.text or "", "\n"))

  local width, height = math.min(100, vim.o.columns - 10), math.min(12, vim.o.lines - 10)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " " .. opts.title .. " ",
    footer = " Ctrl+s send   q cancel (Normal mode) ",
    footer_pos = "right",
  })
  vim.bo[buf].filetype = "markdown"
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.bo[buf].modified = false

  local function text()
    return vim.trim(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"))
  end

  local sending = false
  local function send()
    if sending then
      return
    end
    local body = text()
    if body == "" and not opts.allow_empty then
      return notify("Nothing to send", vim.log.levels.WARN)
    end
    sending = true
    vim.bo[buf].modified = false
    opts.send(body, function(err)
      sending = false
      if err then
        if vim.api.nvim_buf_is_valid(buf) then
          vim.bo[buf].modified = true
        end
        return notify(err, vim.log.levels.ERROR)
      end
      vim.cmd.stopinsert()
      close(win)
    end)
  end

  vim.api.nvim_create_autocmd("BufWriteCmd", { buffer = buf, callback = send })
  vim.keymap.set({ "n", "i" }, "<C-s>", send, { buffer = buf, desc = "Send" })
  vim.keymap.set("n", "q", function()
    if text() == vim.trim(opts.text or "") or vim.fn.confirm("Discard this text?", "&Yes\n&No", 2) == 1 then
      vim.bo[buf].modified = false
      close(win)
    end
  end, { buffer = buf, nowait = true, desc = "Cancel" })
  vim.cmd.startinsert({ bang = true })
end

--- The comments of a thread as lines: `headers[row]` is the highlight of an author line, `owner[row]` the
--- comment a line belongs to
local function thread_lines(thread)
  local lines, headers, owner = {}, {}, {}
  for index, comment in ipairs(thread.comments) do
    if index > 1 then
      table.insert(lines, "")
    end
    table.insert(lines, ("%s  %s%s"):format(comment.author, ago(comment.created_at), comment.pending and "  (pending)" or ""))
    headers[#lines] = comment.pending and "PrReviewPending" or "PrReviewAuthor"
    owner[#lines] = comment
    for _, line in ipairs(vim.split(comment.body, "\n")) do
      table.insert(lines, line)
      owner[#lines] = comment
    end
  end
  return lines, headers, owner
end

local thread_ns = vim.api.nvim_create_namespace("pr_review_thread")

--- Shows a thread under the cursor line without taking the focus, like a hover. It closes when the
--- cursor moves. Returns the window.
function M.preview(thread, title)
  local lines, headers = thread_lines(thread)
  local max_width, width = math.min(100, vim.o.columns - 10), vim.fn.strdisplaywidth(title) + 4
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  local buf, win = vim.lsp.util.open_floating_preview(lines, "markdown", {
    border = "rounded",
    title = " " .. title .. " ",
    width = math.min(width, max_width), -- wide enough for the title
    max_width = max_width,
    max_height = math.max(3, math.floor(vim.o.lines / 2)),
    focusable = false,
    close_events = { "CursorMoved", "InsertEnter", "BufLeave", "WinLeave" },
  })
  for row, group in pairs(headers) do
    pcall(vim.api.nvim_buf_set_extmark, buf, thread_ns, row - 1, 0, { line_hl_group = group })
  end
  return win
end

--- Shows a review thread next to the cursor and takes the focus. Each entry of `actions` is optional: a
--- missing one is an action GitHub does not allow the viewer on this thread.
---@param thread table
---@param actions { title: string, reply?: fun(), toggle_resolved?: fun(), edit: fun(comment: table), delete: fun(comment: table) }
function M.thread(thread, actions)
  local lines, headers, owner = thread_lines(thread)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  local width = math.min(100, vim.o.columns - 10)
  local height = 0
  for _, line in ipairs(lines) do
    height = height + math.max(1, math.ceil(vim.fn.strdisplaywidth(line) / width))
  end
  local hints = { actions.reply and "r reply" or nil }
  if actions.toggle_resolved then
    table.insert(hints, thread.resolved and "x unresolve" or "x resolve")
  end
  vim.list_extend(hints, { "e edit", "d delete", "o browser", "q close" })
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = width,
    height = math.min(height, math.max(3, vim.o.lines - 12)),
    style = "minimal",
    border = "rounded",
    title = " " .. actions.title .. " ",
    footer = " " .. table.concat(hints, "   ") .. " ",
    footer_pos = "right",
  })
  vim.bo[buf].filetype = "markdown"
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].conceallevel = 0
  for row, group in pairs(headers) do
    vim.api.nvim_buf_set_extmark(buf, thread_ns, row - 1, 0, { line_hl_group = group })
  end

  local function map(lhs, action, desc)
    vim.keymap.set("n", lhs, action, { buffer = buf, nowait = true, desc = desc })
  end
  local function under_cursor()
    return owner[vim.api.nvim_win_get_cursor(win)[1]] or thread.comments[1]
  end
  local function own(comment, allowed)
    if not allowed then
      notify("Only your own comments can be changed", vim.log.levels.WARN)
    end
    return allowed
  end
  map("q", function() close(win) end, "Close")
  map("<Esc>", function() close(win) end, "Close")
  map("o", function() vim.ui.open(under_cursor().url) end, "Open in the browser")
  map("r", function()
    if actions.reply then
      close(win)
      actions.reply()
    end
  end, "Reply")
  map("x", function()
    if actions.toggle_resolved then
      close(win)
      actions.toggle_resolved()
    end
  end, "Resolve / unresolve")
  map("e", function()
    local comment = under_cursor()
    if own(comment, comment.can_update) then
      close(win)
      actions.edit(comment)
    end
  end, "Edit comment")
  map("d", function()
    local comment = under_cursor()
    if own(comment, comment.can_delete) and vim.fn.confirm("Delete this comment?", "&Yes\n&No", 2) == 1 then
      close(win)
      actions.delete(comment)
    end
  end, "Delete comment")
  vim.api.nvim_create_autocmd("WinLeave", { buffer = buf, once = true, callback = function() close(win) end })
end

return M
