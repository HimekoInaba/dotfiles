-- Pull request review in the diff view (diffview.nvim), the way IntelliJ's Pull Requests window works: the
-- changed files as a tree, a side-by-side diff, and the review threads on their lines. The pull request's
-- commits are fetched by hash, so no branch is created or switched. Comments are collected in a pending
-- review until it is submitted. Keys: plugins/review.lua, README.md "Reviewing a pull request".
local github = require("pr_review.github")
local ui = require("pr_review.ui")

local M = {}

local ns = vim.api.nvim_create_namespace("pr_review")
---@type table<table, { pr: table, bufs: table<integer, { path: string, side: string }>, marks: table<integer, table>, target?: table }>
local reviews = {} -- by diffview view

for group, link in pairs({
  PrReviewOpen = "DiagnosticInfo",
  PrReviewPending = "DiagnosticWarn",
  PrReviewResolved = "Comment",
  PrReviewAuthor = "Title",
}) do
  vim.api.nvim_set_hl(0, group, { link = link, default = true })
end

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Pull request" })
end

---@return table? review, table? view
local function current()
  local view = package.loaded["diffview.lib"] and require("diffview.lib").get_current_view()
  return view and reviews[view], view
end

local function not_a_pull_request()
  notify("This diff is not a pull request. Open one with Space g P.", vim.log.levels.WARN)
end

local function git(args)
  local out = vim.system(vim.list_extend({ "git" }, args), { text = true }):wait()
  return out.code == 0, vim.trim(out.stdout or "")
end

--- Makes the base and head commits available locally. Fetching by hash leaves branches and refs alone.
local function fetch_commits(pr, done)
  local function has(oid)
    return (git({ "cat-file", "-e", oid .. "^{commit}" }))
  end
  if has(pr.base_oid) and has(pr.head_oid) then
    return done()
  end
  local wanted, remote = ("/%s/%s"):format(pr.owner, pr.name):lower(), nil
  local _, remotes = git({ "remote", "-v" })
  for line in remotes:gmatch("[^\n]+") do
    local name, url = line:match("^(%S+)%s+(%S+)")
    -- git@host:owner/name.git and https://host/owner/name both end in /owner/name
    if url and vim.endswith(url:lower():gsub("%.git$", ""):gsub(":", "/"), wanted) then
      remote = name
      break
    end
  end
  if not remote then
    return done(("%s/%s is not a remote of this repository"):format(pr.owner, pr.name))
  end
  vim.system({ "git", "fetch", "--no-tags", "--quiet", remote, pr.head_oid, pr.base_oid }, { text = true }, function(out)
    vim.schedule(function()
      done(out.code ~= 0 and ("git fetch failed: " .. vim.trim(out.stderr or "")) or nil)
    end)
  end)
end

local function pending_comments(pr)
  local count = 0
  for _, thread in ipairs(pr.threads) do
    for _, comment in ipairs(thread.comments) do
      count = count + ((comment.pending and comment.mine) and 1 or 0)
    end
  end
  return count
end

local function has_pending(thread)
  return vim.iter(thread.comments):any(function(comment)
    return comment.pending
  end)
end

local function highlight(thread)
  return thread.resolved and "PrReviewResolved" or has_pending(thread) and "PrReviewPending" or "PrReviewOpen"
end

--- The first line of a comment that says something, without Markdown images, HTML tags and emphasis marks
local function first_line(body)
  for line in body:gmatch("[^\n]+") do
    local text = line:gsub("!%b[]%b()", ""):gsub("<[^>]+>", ""):gsub("^[%s#>*~_-]+", ""):gsub("[%s*~_]+$", ""):gsub("%s+", " ")
    if text ~= "" then
      return text
    end
  end
  return ""
end

--- "alice: why not from config?  (+2, resolved)"
local function summary(thread)
  local first = thread.comments[1]
  local text = first_line(first.body)
  if vim.fn.strdisplaywidth(text) > 70 then
    text = vim.fn.strcharpart(text, 0, 69) .. "…"
  end
  local tags = {}
  if #thread.comments > 1 then
    table.insert(tags, "+" .. (#thread.comments - 1))
  end
  if thread.resolved then
    table.insert(tags, "resolved")
  end
  if has_pending(thread) then
    table.insert(tags, "pending")
  end
  return ("%s: %s%s"):format(first.author, text, #tags > 0 and ("  (" .. table.concat(tags, ", ") .. ")") or "")
end

local function winbar(pr, side)
  local function escaped(text)
    return (text:gsub("%%", "%%%%"))
  end
  if side == "LEFT" then
    return " " .. escaped(pr.base_ref) .. " (base)"
  end
  local title = vim.fn.strdisplaywidth(pr.title) > 60 and vim.fn.strcharpart(pr.title, 0, 59) .. "…" or pr.title
  local state = pr.state ~= "OPEN" and pr.state:lower() or pr.draft and "draft" or nil
  local pending = pending_comments(pr)
  local review = pending > 0 and ("   %d pending, \\vs submits"):format(pending) or ""
  return (" #%d %s   %s%s%s"):format(pr.number, escaped(title), pr.author, state and (", " .. state) or "", review)
end

---@return table? thread
local function thread_under_cursor(review)
  local buf, row = vim.api.nvim_get_current_buf(), vim.api.nvim_win_get_cursor(0)[1] - 1
  local marks = review.marks[buf] or {}
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, ns, { row, 0 }, { row, -1 }, {})) do
    if marks[mark[1]] then
      return marks[mark[1]].thread
    end
  end
end

local function thread_title(thread)
  return ("%s:%d%s"):format(vim.fs.basename(thread.path), thread.line or 0, thread.resolved and "  resolved" or "")
end

--- IntelliJ shows a comment under its line. Here it pops up while the cursor rests on the line.
local function preview_on_hold(buf)
  vim.api.nvim_create_autocmd("CursorHold", {
    group = vim.api.nvim_create_augroup("pr_review_preview_" .. buf, { clear = true }),
    buffer = buf,
    callback = function()
      local review = reviews[require("diffview.lib").get_current_view()]
      local thread = review and vim.api.nvim_win_get_config(0).relative == "" and thread_under_cursor(review)
      local shown = vim.b[buf].pr_review_preview
      if thread and not (shown and vim.api.nvim_win_is_valid(shown)) then
        vim.b[buf].pr_review_preview = ui.preview(thread, thread_title(thread) .. "   Enter opens")
      end
    end,
  })
end

--- Marks the threads of one side of one file: a sign and the first comment at the end of the line
local function render(review, buf, path, side)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  if not review.bufs[buf] then
    preview_on_hold(buf)
  end
  review.bufs[buf] = { path = path, side = side }
  local marks, last = {}, vim.api.nvim_buf_line_count(buf)
  review.marks[buf] = marks
  for _, thread in ipairs(review.pr.threads) do
    if not thread.outdated and thread.path == path and thread.side == side and thread.line <= last then
      local group = highlight(thread)
      local id = vim.api.nvim_buf_set_extmark(buf, ns, thread.line - 1, 0, {
        sign_text = "●",
        sign_hl_group = group,
        number_hl_group = group,
        virt_text = { { "  ● " .. summary(thread), group } },
        virt_text_pos = "eol",
        priority = 200,
      })
      marks[id] = { thread = thread, main = true }
      for line = thread.start_line, thread.line - 1 do
        local range = vim.api.nvim_buf_set_extmark(buf, ns, line - 1, 0, { sign_text = "│", sign_hl_group = group, priority = 200 })
        marks[range] = { thread = thread }
      end
    end
  end
end

local function sides(view)
  local windows = {}
  for _, window in ipairs(view.cur_layout and view.cur_layout.windows or {}) do
    local symbol = window.file and window.file.symbol
    if (symbol == "a" or symbol == "b") and vim.api.nvim_win_is_valid(window.id) then
      windows[symbol == "a" and "LEFT" or "RIGHT"] = window
    end
  end
  return windows
end

local function redraw(review, view)
  for buf, where in pairs(review.bufs) do
    if vim.api.nvim_buf_is_valid(buf) then
      render(review, buf, where.path, where.side)
    else
      review.bufs[buf], review.marks[buf] = nil, nil
    end
  end
  for side, window in pairs(sides(view)) do
    vim.wo[window.id].winbar = winbar(review.pr, side)
  end
end

local function refresh(review, view)
  local pr = review.pr
  github.pull_request(pr.owner, pr.name, pr.number, function(err, loaded)
    if reviews[view] ~= review then
      return
    elseif err then
      return notify(err, vim.log.levels.ERROR)
    end
    if loaded.head_oid ~= pr.head_oid then
      notify(("#%d has new commits. Close it (q) and open it again to see them."):format(pr.number), vim.log.levels.WARN)
    end
    review.pr = loaded
    redraw(review, view)
  end)
end

--- Callback for a write: reports to the editor popup, if there is one, and reloads the threads
local function written(review, view, done)
  return function(err)
    if done then
      done(err)
    elseif err then
      notify(err, vim.log.levels.ERROR)
    end
    if not err then
      refresh(review, view)
    end
  end
end

--- GitHub takes line comments only inside the hunks of the diff (the changed lines and 3 lines around them)
local function commentable(pr, where, from, to)
  local ok, diff = git({ "diff", "--no-color", "--no-ext-diff", "-U3", pr.base_oid .. "..." .. pr.head_oid, "--", where.path })
  if not ok then
    return true
  end
  for old_start, old_count, new_start, new_count in diff:gmatch("\n@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@") do
    local start = tonumber(where.side == "LEFT" and old_start or new_start)
    local count = tonumber(where.side == "LEFT" and old_count or new_count) or 1
    if from >= start and to < start + count then
      return true
    end
  end
  return false
end

local function show_thread(review, view, thread)
  local can_toggle = thread.resolved and thread.can_unresolve or not thread.resolved and thread.can_resolve
  ui.thread(thread, {
    title = thread_title(thread),
    reply = thread.can_reply and function()
      ui.edit({
        title = "Reply to " .. thread.comments[1].author,
        send = function(text, done)
          github.reply(thread, text, written(review, view, done))
        end,
      })
    end or nil,
    toggle_resolved = can_toggle and function()
      github.set_resolved(thread, not thread.resolved, written(review, view))
    end or nil,
    edit = function(comment)
      ui.edit({
        title = "Edit comment",
        text = comment.body,
        send = function(text, done)
          github.update_comment(comment, text, written(review, view, done))
        end,
      })
    end,
    delete = function(comment)
      github.delete_comment(comment, written(review, view))
    end,
  })
end

--- Opens a pull request in the diff view. `target`: `{ repo = "owner/name", number = 1 }`, a number in this
--- repository, or nothing for the PR tab under the cursor or else the pull request of the current branch.
function M.open(target)
  local function load(owner, name, number)
    for view, review in pairs(reviews) do
      local pr = review.pr
      local same = pr.number == number and (pr.owner .. "/" .. pr.name):lower() == (owner .. "/" .. name):lower()
      if same and vim.api.nvim_tabpage_is_valid(view.tabpage) then
        vim.api.nvim_set_current_tabpage(view.tabpage)
        return refresh(review, view)
      end
    end
    notify(("Loading #%d ..."):format(number))
    github.pull_request(owner, name, number, function(err, pr)
      if err then
        return notify(err, vim.log.levels.ERROR)
      end
      fetch_commits(pr, function(fetch_err)
        if fetch_err then
          return notify(fetch_err, vim.log.levels.ERROR)
        end
        -- with the pull request's head checked out the right side is the real file, with the language server
        local _, head = git({ "rev-parse", "HEAD" })
        vim.cmd(("DiffviewOpen %s...%s%s"):format(pr.base_oid, pr.head_oid, head == pr.head_oid and " --imply-local" or ""))
        local view = require("diffview.lib").get_current_view()
        if view then
          reviews[view] = { pr = pr, bufs = {}, marks = {} }
        end
      end)
    end)
  end

  if type(target) == "table" then
    local owner, name = target.repo:match("^([^/]+)/(.+)$")
    return load(owner, name, target.number)
  end
  local owner, name, number = vim.api.nvim_buf_get_name(0):match("^octo://([^/]+)/([^/]+)/pull/(%d+)$")
  if owner and not target then
    return load(owner, name, tonumber(number))
  end
  github.locate(target, function(err, found_owner, found_name, found_number)
    if err then
      return notify(err, vim.log.levels.WARN)
    end
    load(found_owner, found_name, found_number)
  end)
end

--- diffview hook: a file version was put into one of the two diff windows
function M.on_diff_buf(buf, win, ctx)
  local review, view = current()
  local side = ctx.symbol == "a" and "LEFT" or ctx.symbol == "b" and "RIGHT" or nil
  if not (review and side and view.cur_entry) then
    return
  end
  render(review, buf, view.cur_entry.path, side)
  vim.wo[win].winbar = winbar(review.pr, side)
  local target = review.target
  if target and target.path == view.cur_entry.path and target.side == side then
    review.target = nil
    -- the hook runs inside nvim_win_call, which would undo a window switch made here
    vim.schedule(function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_set_current_win(win)
        pcall(vim.api.nvim_win_set_cursor, win, { target.line, 0 })
        vim.cmd("normal! zvzz")
      end
    end)
  end
end

--- diffview hook
function M.on_view_closed(view)
  local review = reviews[view]
  if review then
    for buf in pairs(review.bufs) do
      pcall(vim.api.nvim_del_augroup_by_name, "pr_review_preview_" .. buf)
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
      end
    end
    reviews[view] = nil
  end
end

--- Comment on the cursor line, or on the selected lines
function M.comment()
  local review, view = current()
  if not review then
    return not_a_pull_request()
  end
  local where = review.bufs[vim.api.nvim_get_current_buf()]
  if not where then
    return notify("Put the cursor in the old or the new version of a file first", vim.log.levels.WARN)
  end
  local from, to = vim.fn.line("v"), vim.fn.line(".")
  if from > to then
    from, to = to, from
  end
  if vim.fn.mode():match("^[vV\22]") then
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
  end
  if not commentable(review.pr, where, from, to) then
    return notify("GitHub only takes comments on changed lines and the 3 lines around them", vim.log.levels.WARN)
  end
  ui.edit({
    title = ("Comment on %s:%s"):format(vim.fs.basename(where.path), from == to and to or (from .. "-" .. to)),
    send = function(text, done)
      local range = { path = where.path, side = where.side, start_line = from, line = to }
      github.add_thread(review.pr, range, text, written(review, view, done))
    end,
  })
end

--- Opens the thread on the cursor line. Returns false when there is none.
function M.open_thread()
  local review, view = current()
  local thread = review and thread_under_cursor(review)
  if thread then
    show_thread(review, view, thread)
  end
  return thread ~= nil
end

function M.toggle_resolved()
  local review, view = current()
  if not review then
    return not_a_pull_request()
  end
  local thread = thread_under_cursor(review)
  if not thread then
    return notify("No comment on this line", vim.log.levels.WARN)
  elseif not (thread.resolved and thread.can_unresolve or not thread.resolved and thread.can_resolve) then
    return notify("GitHub does not let you change this thread", vim.log.levels.WARN)
  end
  github.set_resolved(thread, not thread.resolved, written(review, view))
end

--- Jumps to the next (1) or previous (-1) thread of the file
function M.jump(direction)
  local review = current()
  if not review then
    return not_a_pull_request()
  end
  local buf, row = vim.api.nvim_get_current_buf(), vim.api.nvim_win_get_cursor(0)[1] - 1
  local marks, target = review.marks[buf] or {}, nil
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})) do
    if marks[mark[1]] and marks[mark[1]].main then
      if direction > 0 and mark[2] > row then
        target = math.min(target or mark[2], mark[2])
      elseif direction < 0 and mark[2] < row then
        target = math.max(target or mark[2], mark[2])
      end
    end
  end
  if not target then
    return notify("No more comments in this file. \\cl lists all of them.")
  end
  vim.api.nvim_win_set_cursor(0, { target + 1, 0 })
  vim.cmd("normal! zv")
end

--- Lists every thread of the pull request and jumps to the chosen one
function M.list()
  local review, view = current()
  if not review then
    return not_a_pull_request()
  end
  local threads = vim.tbl_filter(function(thread)
    return not thread.outdated
  end, review.pr.threads)
  local outdated = #review.pr.threads - #threads
  if #threads == 0 then
    return notify(outdated > 0 and (outdated .. " comments, all on code that has changed since. \\pp shows them.") or "No comments yet")
  end
  table.sort(threads, function(a, b)
    return a.path == b.path and a.line < b.line or a.path < b.path
  end)
  vim.ui.select(threads, {
    prompt = ("Comments on #%d%s"):format(review.pr.number, outdated > 0 and (" (%d more on outdated code)"):format(outdated) or ""),
    format_item = function(thread)
      return ("%s:%d  %s"):format(vim.fs.basename(thread.path), thread.line, summary(thread))
    end,
  }, function(thread)
    if not thread or reviews[view] ~= review then
      return
    end
    local window = view.cur_entry and view.cur_entry.path == thread.path and sides(view)[thread.side]
    if window then
      vim.api.nvim_set_current_win(window.id)
      pcall(vim.api.nvim_win_set_cursor, window.id, { thread.line, 0 })
      return vim.cmd("normal! zvzz")
    end
    for _, entry in view.files:iter() do
      if entry.path == thread.path then
        review.target = { path = thread.path, side = thread.side, line = thread.line }
        return view:set_file(entry, false, true)
      end
    end
  end)
end

--- Approve, comment or request changes. Sends the pending comments along.
function M.submit()
  local review, view = current()
  if not review then
    return not_a_pull_request()
  end
  local pr = review.pr
  local pending = pending_comments(pr)
  local events = { Approve = "APPROVE", Comment = "COMMENT", ["Request changes"] = "REQUEST_CHANGES" }
  vim.ui.select({ "Approve", "Comment", "Request changes" }, {
    prompt = ("Submit review of #%d (%d pending comment%s)"):format(pr.number, pending, pending == 1 and "" or "s"),
  }, function(choice)
    if not choice then
      return
    end
    ui.edit({
      title = ("%s #%d: summary, may stay empty"):format(choice, pr.number),
      allow_empty = true,
      send = function(text, done)
        github.submit(review.pr, events[choice], text, function(err)
          if not err then
            notify(("Review of #%d submitted: %s"):format(pr.number, choice:lower()))
          end
          written(review, view, done)(err)
        end)
      end,
    })
  end)
end

--- Deletes the pending review and its unsubmitted comments
function M.discard()
  local review, view = current()
  if not review then
    return not_a_pull_request()
  end
  local pr = review.pr
  if not pr.pending_review_id then
    return notify("No pending review")
  end
  local question = ("Delete your pending review of #%d with %d unsubmitted comment(s)?"):format(pr.number, pending_comments(pr))
  if vim.fn.confirm(question, "&Yes\n&No", 2) == 1 then
    github.discard(pr, written(review, view))
  end
end

function M.refresh()
  local review, view = current()
  if not review then
    return not_a_pull_request()
  end
  refresh(review, view)
end

--- The description and conversation of the pull request, as an editor tab next to the project's files
function M.description()
  local review = current()
  if not review then
    return not_a_pull_request()
  end
  local tab = require("diffview.lib").get_prev_non_view_tabpage()
  if tab then
    vim.api.nvim_set_current_tabpage(tab)
  else
    vim.cmd.tabnew()
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(win).relative == "" and vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= "neo-tree" then
      vim.api.nvim_set_current_win(win)
      break
    end
  end
  vim.cmd(("Octo pr edit %d %s/%s"):format(review.pr.number, review.pr.owner, review.pr.name))
end

function M.browse()
  local review = current()
  if not review then
    return not_a_pull_request()
  end
  vim.ui.open(review.pr.url)
end

return M
