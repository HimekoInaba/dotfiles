-- Code review: diffview.nvim (IntelliJ Commit / Changes window with a side-by-side diff, branch vs base),
-- lua/pr_review (pull requests in that same diff view, with the review threads on their lines) and octo.nvim
-- (the pull request list and a pull request's description and conversation). All on the `gh` CLI.
local nerd = vim.g.have_nerd_font == true

--- The remote's default branch (`origin/dev`), the base a branch is reviewed against
local function base_branch()
  local ref = vim.fn.systemlist({ "git", "symbolic-ref", "--short", "refs/remotes/origin/HEAD" })[1]
  return vim.v.shell_error == 0 and ref or "origin/main"
end

local function toggle_diffview(args)
  return function()
    if require("diffview.lib").get_current_view() then
      vim.cmd.DiffviewClose()
    else
      vim.cmd("DiffviewOpen " .. (type(args) == "function" and args() or args or ""))
    end
  end
end

--- A session reopens files only (plugins/session.lua). A diff view left open on quit would come back as
--- a stray tab page, and a PR buffer as an empty `octo://` tab that nothing can load. Created at startup,
--- so it runs before persistence.nvim's own VimLeavePre, which is registered later and saves the session.
local function keep_reviews_out_of_sessions()
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("user_review_session", { clear = true }),
    callback = function()
      if package.loaded["diffview"] then
        local lib = require("diffview.lib")
        for _, view in ipairs(vim.list_slice(lib.views)) do
          pcall(function()
            view:close()
            lib.dispose_view(view)
          end)
        end
      end
      if package.loaded["octo.reviews"] then
        for _, review in pairs(require("octo.reviews").reviews) do
          pcall(function()
            review.layout:close()
          end)
        end
      end
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(buf)
        -- PRs, and the scratch buffer of octo's "show PR diff"
        if name:match("^octo://") or (vim.bo[buf].buftype == "nofile" and vim.fs.basename(name):match("^DIFF: ")) then
          -- not nvim_buf_delete: that closes the editor window too and leaves the session without one
          pcall(Snacks.bufdelete, { buf = buf, force = true })
        end
      end
    end,
  })
end

--- IntelliJ's diff viewer opens no editor tabs. Diffview loads every file it shows as a listed buffer, so
--- when a view closes, drop the ones that were not open before and were never shown outside of it.
local opened_before = {}

local function remember_open_files(view)
  local known = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    known[buf] = vim.bo[buf].buflisted or nil
  end
  local autocmd = vim.api.nvim_create_autocmd("BufWinEnter", {
    callback = function(args)
      if vim.api.nvim_get_current_tabpage() ~= view.tabpage then
        known[args.buf] = true
      end
    end,
  })
  opened_before[view] = { known = known, autocmd = autocmd }
end

local function close_files_opened_by(view)
  local state = opened_before[view]
  if not state then
    return
  end
  opened_before[view] = nil
  pcall(vim.api.nvim_del_autocmd, state.autocmd)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local bo = vim.bo[buf]
    if bo.buflisted and bo.buftype == "" and not bo.modified and not state.known[buf] and #vim.fn.win_findbuf(buf) == 0 then
      bo.buflisted = false -- keeps it out of "Reopen closed tab"
      pcall(vim.api.nvim_buf_delete, buf, {})
    end
  end
end

local function diffview_opts()
  local actions = require("diffview.actions")
  local shared = {
    { "n", "q", "<Cmd>DiffviewClose<CR>", { desc = "Close the diff view" } },
    { "n", "<leader>gt", actions.toggle_files, { desc = "Toggle the changed files panel" } },
    -- diffview's <leader>b (toggle the file panel) would shadow the whole `Space b` tab group
    { "n", "<leader>b", false },
  }
  -- diffview rolls a file back on one key press; like the rollback in `Space g s`, this one asks
  local function restore_after_confirm()
    local ok, file = pcall(function()
      return require("diffview.lib").get_current_view():infer_cur_file()
    end)
    local entry = ok and file and file.path or "the selected entry"
    if vim.fn.confirm("Roll back " .. entry .. "?", "&Yes\n&No", 2) == 1 then
      actions.restore_entry()
    end
  end
  local panel = vim.list_slice(shared)
  table.insert(panel, { "n", "X", restore_after_confirm, { desc = "Roll back to the version on the left (asks first)" } })
  -- Pull request keys (lua/pr_review). They are set in every diff view and say so when it is not one.
  local function pr(action, ...)
    local args = { ... }
    return function()
      require("pr_review")[action](unpack(args))
    end
  end
  local review = {
    { "n", "<localleader>vs", pr("submit"), { desc = "PR: submit review (approve / comment / request changes)" } },
    { "n", "<localleader>vd", pr("discard"), { desc = "PR: discard my pending review" } },
    { "n", "<localleader>vr", pr("refresh"), { desc = "PR: reload comments" } },
    { "n", "<localleader>cl", pr("list"), { desc = "PR: list all comments" } },
    { "n", "<localleader>pp", pr("description"), { desc = "PR: description and conversation" } },
    { "n", "<localleader>pb", pr("browse"), { desc = "PR: open in the browser" } },
  }
  vim.list_extend(panel, review)
  -- Keys that diffview sets on a diffed file are deleted, not restored, when the view closes. Its default
  -- merge keys <leader>ca / co / ct / cT would take the LSP's Context Actions, Optimize Imports and
  -- Type Hierarchy of that file with them, so the merge keys live under <localleader>x, next to ]x and dx.
  local view = vim.list_slice(shared)
  for key, side in pairs({ o = "ours", t = "theirs", b = "base", a = "all" }) do
    vim.list_extend(view, {
      { "n", "<leader>c" .. key, false },
      { "n", "<leader>c" .. key:upper(), false },
      { "n", "<localleader>x" .. key, actions.conflict_choose(side), { desc = "Conflict: choose " .. side } },
      {
        "n",
        "<localleader>x" .. key:upper(),
        actions.conflict_choose_all(side),
        { desc = "Conflict: choose " .. side .. " in the whole file" },
      },
    })
  end
  vim.list_extend(view, review)
  vim.list_extend(view, {
    { { "n", "x" }, "<localleader>ca", pr("comment"), { desc = "PR: comment on the line or selection" } },
    { "n", "<localleader>rt", pr("toggle_resolved"), { desc = "PR: resolve / unresolve the comment thread" } },
    { "n", "]t", pr("jump", 1), { desc = "PR: next comment" } },
    { "n", "[t", pr("jump", -1), { desc = "PR: previous comment" } },
    {
      "n",
      "<CR>",
      function()
        if not (package.loaded["pr_review"] and require("pr_review").open_thread()) then
          vim.cmd("normal! " .. vim.v.count1 .. "+")
        end
      end,
      { desc = "PR: open the comment thread on this line" },
    },
  })
  return {
    enhanced_diff_hl = true,
    use_icons = nerd,
    file_panel = { win_config = { width = 45 } }, -- Java paths are long
    signs = not nerd and { fold_closed = "> ", fold_open = "v " } or nil, -- no icon: the name follows directly
    hooks = {
      view_opened = remember_open_files,
      view_closed = function(closed)
        close_files_opened_by(closed)
        if package.loaded["pr_review"] then
          require("pr_review").on_view_closed(closed)
        end
      end,
      diff_buf_win_enter = function(buf, win, ctx)
        if package.loaded["pr_review"] then
          require("pr_review").on_diff_buf(buf, win, ctx)
        end
      end,
    },
    keymaps = { view = view, file_panel = panel, file_history_panel = panel },
  }
end

--- Octo's PR list merges and checks out a branch on one key press, on the keys that toggle a filter in
--- every other search popup (`Ctrl+r`, `Ctrl+o`). Both ask first here.
local function ask_first(question, run)
  return function(_, item)
    if item and vim.fn.confirm(question:format(item.number), "&Yes\n&No", 2) == 1 then
      run(item.number)
    end
  end
end

local ascii_octo = {
  use_timeline_icons = false,
  file_panel = { icons = false },
  reaction_viewer_hint_icon = "* ",
  user_icon = "@",
  ghost_icon = "@",
  copilot_icon = "@",
  dependabot_icon = "@",
  outdated_icon = "(outdated) ",
  resolved_icon = "(resolved) ",
  timeline_marker = ">",
  right_bubble_delimiter = "",
  left_bubble_delimiter = "",
}

-- Octo's state icons are not options. Without a Nerd Font a known state gets a letter and any other
-- icon-font glyph a `*`; the highlight colour still tells the rest apart.
local ascii_octo_states = {
  open = "o ", draft = "d ", merged = "m ", closed = "x ", queued = "q ", unread = "* ", read = "  ",
  VIEWED = "[x] ", UNVIEWED = "[ ] ", DISMISSED = "[!] ",
}
local icon_font_glyph = [=[[\uE000-\uF8FF\U000F0000-\U000FFFFF]]=]

local function use_ascii_icons(tbl, name, seen)
  seen = seen or {}
  if seen[tbl] then
    return
  end
  seen[tbl] = true
  for key, value in pairs(tbl) do
    if type(value) == "table" then
      use_ascii_icons(value, key, seen)
    elseif type(value) == "string" and vim.fn.match(value, icon_font_glyph) >= 0 then
      tbl[key] = ascii_octo_states[key] or ascii_octo_states[name] or vim.fn.substitute(value, icon_font_glyph, "*", "g")
    end
  end
end

return {
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory", "DiffviewToggleFiles" },
    keys = {
      { "<leader>gv", toggle_diffview(), desc = "Review local changes (diff view)" },
      { "<leader>gm", toggle_diffview(function() return base_branch() .. "...HEAD --imply-local" end), desc = "Review branch vs base branch" },
      { "<leader>gH", "<Cmd>DiffviewFileHistory %<CR>", desc = "File history with diffs" },
      { "<leader>gL", "<Cmd>DiffviewFileHistory<CR>", desc = "Branch history with diffs" },
    },
    init = keep_reviews_out_of_sessions,
    opts = diffview_opts,
  },

  {
    "pwntester/octo.nvim",
    cmd = "Octo",
    dependencies = { "nvim-lua/plenary.nvim", "folke/snacks.nvim" },
    keys = {
      { "<leader>gP", "<Cmd>Octo pr list<CR>", desc = "Pull requests" },
      { "<leader>gV", function() require("pr_review").open() end, desc = "Review the pull request (PR tab or current branch)" },
      { "<leader>gS", "<Cmd>Octo pr search<CR>", desc = "Search pull requests" },
      { "<leader>gN", "<Cmd>Octo notification list<CR>", desc = "GitHub notifications" },
    },
    opts = vim.tbl_deep_extend("force", nerd and {} or ascii_octo, {
      picker = "snacks",
      default_merge_method = "squash",
      picker_config = {
        snacks = {
          actions = {
            -- octo rejects an action without lhs, desc and mode, and then does not set itself up at all
            pull_requests = {
              {
                -- IntelliJ opens a pull request with its changed files; Ctrl+v / Ctrl+s open the description
                name = "confirm",
                lhs = "<CR>",
                mode = { "n", "i" },
                desc = "review pull request",
                fn = function(picker, item, action)
                  if not item then
                    return
                  elseif action and action.cmd then -- the split keys run `confirm` with a window command
                    return Snacks.picker.actions.jump(picker, item, action)
                  end
                  picker:close()
                  require("pr_review").open({ repo = item.repository.nameWithOwner, number = item.number })
                end,
              },
              {
                name = "merge_pr",
                lhs = "<C-r>",
                mode = { "n", "i" },
                desc = "merge pull request (asks first)",
                fn = ask_first("Merge PR #%d?", function(number)
                  require("octo.utils").merge_pr(number)
                end),
              },
              {
                name = "check_out_pr",
                lhs = "<C-o>",
                mode = { "n", "i" },
                desc = "check out pull request (asks first)",
                fn = ask_first("Check out the branch of PR #%d?", function(number)
                  require("octo.utils").checkout_pr(number)
                end),
              },
            },
          },
        },
      },
      mappings = {
        -- the default <leader>qa sits next to `Space q q` (quit)
        pull_request = { approve_pr = { lhs = "<localleader>pa", desc = "approve PR" } },
      },
    }),
    config = function(_, opts)
      require("octo").setup(opts)
      if not nerd then
        use_ascii_icons(require("octo.utils"))
      end
    end,
  },
}
