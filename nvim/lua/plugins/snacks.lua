-- Pickers (Search Everywhere, Go to File, Find in Files, LSP lists), terminal, notifications
local nerd = vim.g.have_nerd_font == true

-- ASCII replacements for every Nerd Font glyph in the snacks defaults used here.
-- Box drawing and geometric shapes are regular Unicode and stay.
local ascii_picker_icons = {
  files = { enabled = false, dir = "+ ", dir_open = "- ", file = "  " },
  keymaps = { nowait = "! " },
  undo = { saved = "S " },
  ui = { live = "live " },
  git = {
    enabled = false, -- status letters (M, A, D, R, ?, !) instead of glyphs
    commit = "",
    staged = "+",
    added = "A",
    deleted = "D",
    ignored = "!",
    modified = "M",
    renamed = "R",
    unmerged = "U",
    untracked = "?",
  },
  diagnostics = { Error = "E ", Warn = "W ", Hint = "H ", Info = "I " },
  lsp = { unavailable = "-", enabled = "+ ", disabled = "x ", attached = "* " },
  -- IntelliJ-like one-letter kind markers (c = class, m = method, f = field, ...)
  kinds = {
    Array = "a ", Boolean = "b ", Class = "c ", Color = "# ", Control = "> ", Collapsed = "> ",
    Constant = "k ", Constructor = "c ", Copilot = "* ", Enum = "e ", EnumMember = "e ",
    Event = "! ", Field = "f ", File = "F ", Folder = "D ", Function = "f ", Interface = "I ",
    Key = "k ", Keyword = "w ", Method = "m ", Module = "M ", Namespace = "N ", Null = "0 ",
    Number = "n ", Object = "o ", Operator = "+ ", Package = "P ", Property = "p ",
    Reference = "r ", Snippet = "s ", String = "s ", Struct = "S ", Text = "t ",
    TypeParameter = "T ", Unit = "u ", Unknown = "? ", Value = "v ", Variable = "v ",
  },
}

-- .gitignore already hides build/, .gradle, .idea and out/ in git repos; these also apply when
-- gitignored files are toggled on (<C-o>) or outside a repo.
local exclude = { ".gradle", ".idea", ".kotlin", "node_modules", "*.class", ".DS_Store", ".claude/worktrees" }

-- Alt does not reach Neovim in iTerm2, so every <a-*> toggle gets a Ctrl alias in the prompt and an
-- uppercase alias in Normal mode of the list.
local toggle_keys = {
  ["<c-t>"] = { "toggle_preview", mode = { "i", "n" }, desc = "Toggle preview" },
  ["<c-o>"] = { "toggle_ignored", mode = { "i", "n" }, desc = "Toggle gitignored files" },
  ["<c-y>"] = { "toggle_hidden", mode = { "i", "n" }, desc = "Toggle hidden files" },
  ["<c-l>"] = { "toggle_regex", mode = { "i", "n" }, desc = "Toggle regex" },
  ["<c-z>"] = { "toggle_maximize", mode = { "i", "n" }, desc = "Toggle maximize" },
  ["P"] = "toggle_preview",
  ["I"] = "toggle_ignored",
  ["H"] = "toggle_hidden",
  ["R"] = "toggle_regex",
  ["M"] = "toggle_maximize",
}

-- One Esc closes a popup, like in IntelliJ. With the macOS text keys on, the prompt leaves the keys
-- iTerm sends for Cmd/Option+arrows, Cmd+Backspace and (Option+)fn+Delete to config/keymaps.lua and
-- Vim's Insert mode instead of select all, follow, scroll and inspect.
local input_keys = vim.tbl_extend("force", toggle_keys, {
  ["<Esc>"] = { "close", mode = { "n", "i" } },
}, vim.g.macos_text_keys and {
  ["<c-a>"] = false,
  ["<c-u>"] = false,
  ["<c-d>"] = false,
  ["<a-f>"] = false,
  ["<a-d>"] = false,
} or {})

local function no_preview()
  return { preset = "intellij", hidden = { "preview" } }
end

local class_kinds = { "Class", "Interface", "Enum", "Struct" }

-- IntelliJ Find Action: actions are this config's keymaps, found by name and run with Enter
local function find_action()
  Snacks.picker.keymaps({
    title = "Find Action",
    modes = { "n" },
    layout = no_preview(),
    transform = function(item)
      return (item.item.desc or "") ~= ""
    end,
  })
end

--- IntelliJ Switcher: the previous file (#) is the first row, so Enter switches back to it. The default
--- order by last use has one-second resolution and puts a file left within the same second first.
local function buffers_previous_first(opts, ctx)
  local items = require("snacks.picker.source.buffers").buffers(opts, ctx)
  local function rank(item)
    return item.flags:find("#", 1, true) and math.huge or item.info.lastused
  end
  table.sort(items, function(a, b)
    return rank(a) > rank(b)
  end)
  return items
end

local function go_to_test()
  local name = vim.fn.expand("%:t:r"):gsub("Test$", ""):gsub("Spec$", "")
  Snacks.picker.files({ pattern = name })
end

return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    bigfile = {
      enabled = true,
      -- the default setup, plus indent guides and scope tracking, which cost seconds on big files
      setup = function(ctx)
        vim.b[ctx.buf].snacks_indent = false
        vim.b[ctx.buf].snacks_scope = false
        vim.cmd("silent! NoMatchParen")
        Snacks.util.wo(0, { foldmethod = "manual", statuscolumn = "", conceallevel = 0 })
        vim.b.completion = false
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(ctx.buf) then
            vim.bo[ctx.buf].syntax = ctx.ft
          end
        end)
      end,
    },
    indent = { enabled = true, animate = { enabled = false } },
    input = {
      enabled = true,
      icon = nerd and " " or "",
      icon_pos = nerd and "left" or false,
      win = { keys = { i_esc = { "<esc>", { "cmp_close", "cancel" }, mode = "i", expr = true } } },
    },
    notifier = {
      enabled = true,
      timeout = 3000,
      icons = not nerd and { error = "E ", warn = "W ", info = "I ", debug = "D ", trace = "T " } or nil,
    },
    terminal = { enabled = true, win = { position = "bottom", height = 0.3 } },
    words = { enabled = true },
    picker = {
      enabled = true,
      prompt = nerd and " " or "> ",
      ui_select = true,
      layout = { preset = "intellij", cycle = true },
      layouts = {
        -- IntelliJ-style popup: centered, input on top, results, preview below (like Find in Files)
        intellij = {
          layout = {
            backdrop = false,
            width = 0.7,
            min_width = 100,
            height = 0.85,
            min_height = 25,
            box = "vertical",
            border = true,
            title = "{title} {live} {flags}",
            title_pos = "center",
            { win = "input", height = 1, border = "bottom" },
            { win = "list", border = "none" },
            { win = "preview", title = "{preview}", height = 0.5, border = "top" },
          },
        },
      },
      formatters = {
        file = { filename_first = true, truncate = "left" },
      },
      previewers = {
        diff = { style = nerd and "fancy" or "syntax" }, -- the fancy diff header hard-codes a Nerd Font glyph
      },
      toggles = {
        regex = { icon = ".*", value = true }, -- IntelliJ-style ".*" flag while regex is on
      },
      icons = not nerd and ascii_picker_icons or nil,
      win = {
        input = { keys = input_keys },
        list = { keys = toggle_keys },
      },
      sources = {
        smart = { layout = no_preview(), filter = { cwd = true } },
        files = {
          hidden = true,
          ignored = false,
          exclude = exclude,
          matcher = { frecency = true, cwd_bonus = true },
          layout = no_preview(),
        },
        recent = { filter = { cwd = true }, layout = no_preview() },
        buffers = { current = false, finder = buffers_previous_first, layout = no_preview() },
        grep = { hidden = true, ignored = false, regex = false, exclude = exclude },
        grep_word = { hidden = true, ignored = false, exclude = exclude },
        lsp_symbols = { layout = no_preview() },
        lsp_references = { include_declaration = false },
        git_branches = {
          format = not nerd and function(item, picker)
            local ret = require("snacks.picker.format").git_branch(item, picker)
            if item.current then
              ret[1][1] = "* " -- replaces a hard-coded Nerd Font glyph
            end
            return ret
          end or nil,
        },
      },
    },
    styles = {
      input = { relative = "cursor", row = -3, col = 0 }, -- rename prompts open next to the symbol
    },
    dashboard = { enabled = false },
    explorer = { enabled = false },
    image = { enabled = false },
    quickfile = { enabled = false },
    scope = { enabled = false },
    scroll = { enabled = false },
    statuscolumn = { enabled = false },
  },
  keys = {
    -- Search / Go to
    { "<leader><space>", function() Snacks.picker.smart() end, desc = "Search Everywhere" },
    { "<leader>ff", function() Snacks.picker.files() end, desc = "Go to File" },
    { "<leader>fc", function() Snacks.picker.lsp_workspace_symbols({ filter = { default = class_kinds } }) end, desc = "Go to Class" },
    { "<leader>fs", function() Snacks.picker.lsp_workspace_symbols() end, desc = "Go to Symbol" },
    { "<leader>fa", find_action, desc = "Find Action" },
    { "<leader>fr", function() Snacks.picker.recent() end, desc = "Recent Files" },
    { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Switcher (open files)" },
    { "<leader>,", function() Snacks.picker.buffers() end, desc = "Switcher (open files)" },
    { "<leader>fj", function() Snacks.picker.jumps() end, desc = "Recent Locations (jumps)" },
    { "<leader>ft", go_to_test, desc = "Go to Test" },
    { "<leader>fu", function() Snacks.picker.lsp_references() end, desc = "Find Usages" },
    { "<leader>fg", function() Snacks.picker.grep() end, desc = "Find in Files" },
    { "<leader>/", function() Snacks.picker.grep() end, desc = "Find in Files" },
    { "<leader>fw", function() Snacks.picker.grep_word() end, desc = "Find word / selection in Files", mode = { "n", "x" } },
    { "<leader>ss", function() Snacks.picker.lsp_symbols() end, desc = "File Structure" },
    { "<leader>sb", function() Snacks.picker.lines() end, desc = "Find in current file" },
    { "<leader>sC", function() Snacks.picker.commands() end, desc = "Commands" },
    { "<leader>sR", function() Snacks.picker.resume() end, desc = "Resume last search" },
    { "<leader>sh", function() Snacks.picker.help() end, desc = "Help pages" },
    { "<leader>sk", function() Snacks.picker.keymaps() end, desc = "Keymaps" },
    { "<leader>sm", function() Snacks.picker.marks() end, desc = "Bookmarks (marks)" },
    { "<leader>sn", function() Snacks.picker.notifications() end, desc = "Notification history" },
    { "<leader>sq", function() Snacks.picker.qflist() end, desc = "Quickfix list" },
    { "<leader>su", function() Snacks.picker.undo() end, desc = "Undo history" },
    -- Problems tool window
    { "<leader>xx", function() Snacks.picker.diagnostics() end, desc = "Problems (project)" },
    { "<leader>xX", function() Snacks.picker.diagnostics_buffer() end, desc = "Problems (current file)" },
    -- Git
    { "<leader>gs", function() Snacks.picker.git_status() end, desc = "Changed files (git status)" },
    { "<leader>gl", function() Snacks.picker.git_log() end, desc = "Git log" },
    { "<leader>gf", function() Snacks.picker.git_log_file() end, desc = "File history" },
    { "<leader>gB", function() Snacks.picker.git_branches() end, desc = "Branches" },
    { "<leader>go", function() Snacks.gitbrowse() end, desc = "Open on GitHub", mode = { "n", "x" } },
    -- Files, tabs and windows
    { "<leader>rf", function() Snacks.rename.rename_file() end, desc = "Rename file" },
    { "<leader>bd", function() Snacks.bufdelete() end, desc = "Close tab" },
    { "<leader>bo", function() Snacks.bufdelete.other() end, desc = "Close other tabs" },
    { "<leader>wm", function() Snacks.toggle.zoom():toggle() end, desc = "Maximize editor" },
    { "<leader>un", function() Snacks.notifier.hide() end, desc = "Dismiss notifications" },
    -- Terminal tool window: opens and focuses, or hides when focused. Ctrl+/ hides it from inside.
    { "<leader>tt", function() Snacks.terminal.focus() end, desc = "Terminal" },
    { "<c-/>", function() Snacks.terminal.focus() end, mode = "t", desc = "Hide terminal" },
    { "<c-_>", function() Snacks.terminal.focus() end, mode = "t", desc = "Hide terminal" },
    -- Highlight usages in file (snacks.words)
    { "]]", function() Snacks.words.jump(vim.v.count1) end, desc = "Next usage in file" },
    { "[[", function() Snacks.words.jump(-vim.v.count1) end, desc = "Previous usage in file" },
  },
}
