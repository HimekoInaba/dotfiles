-- IntelliJ "Project" tool window on the left
local nerd = vim.g.have_nerd_font == true

local function copy_path(modifier)
  return function(state)
    local node = state.tree:get_node()
    if not node or node.type == "message" then
      return
    end
    local path = vim.fn.fnamemodify(node:get_id(), modifier)
    vim.fn.setreg("+", path)
    vim.fn.setreg('"', path)
    vim.notify("Copied " .. path, vim.log.levels.INFO, { title = "Project" })
  end
end

-- IntelliJ opens a newly created file in the editor
local function add_and_open(state)
  require("neo-tree.sources.common.commands").add(state, function(path)
    require("neo-tree.sources.filesystem").show_new_children(state, path)
    if vim.fn.isdirectory(path) == 0 then
      require("neo-tree.utils").open_file(state, path)
    end
  end)
end

--- Non-floating windows of a tab page
local function split_windows(tab)
  return vim.tbl_filter(function(win)
    return vim.api.nvim_win_get_config(win).relative == ""
  end, vim.api.nvim_tabpage_list_wins(tab))
end

--- The file the closed editor showed while it is still open, else the most recently used open file
local function file_to_reopen(closed_buf)
  if vim.api.nvim_buf_is_valid(closed_buf) and vim.bo[closed_buf].buflisted then
    return closed_buf
  end
  local listed = vim.fn.getbufinfo({ buflisted = 1 })
  table.sort(listed, function(a, b)
    return a.lastused > b.lastused
  end)
  return listed[1] and listed[1].bufnr
end

--- IntelliJ stays open when the last editor tab closes. neo-tree's close_if_last_window quits as soon
--- as the tree is the only window left, also after `:bd` or `Ctrl+w c`. Instead, reopen an editor next
--- to the tree, and when a quit command (`:q`, `:wq`, `ZZ`) closed the last editor window, quit from
--- that editor. Quitting from the editor, not the tree, lets the session record the file, and a
--- cancelled save prompt shows the modified buffer in the editor: in the tree, neo-tree would move it
--- out and delete the tree buffer, which asks a second time and drops the buffer on No.
local function keep_editor_next_to_tree()
  local group = vim.api.nvim_create_augroup("user_neotree_last_window", { clear = true })
  local quitting = false
  vim.api.nvim_create_autocmd("QuitPre", {
    group = group,
    callback = function()
      quitting = true
      vim.schedule(function()
        quitting = false
      end)
    end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(args)
      local closing = tonumber(args.match)
      local tab = vim.api.nvim_win_get_tabpage(closing)
      local others = vim.tbl_filter(function(win)
        return win ~= closing
      end, split_windows(tab))
      local tree = others[1]
      if #others ~= 1 or vim.bo[vim.api.nvim_win_get_buf(tree)].filetype ~= "neo-tree" then
        return
      end
      local width, quit, closed_buf = vim.api.nvim_win_get_width(tree), quitting, args.buf
      vim.schedule(function()
        if not vim.api.nvim_win_is_valid(tree) or #split_windows(tab) ~= 1 then
          return
        end
        vim.api.nvim_set_current_win(tree)
        local file = file_to_reopen(closed_buf)
        vim.cmd(file and ("rightbelow vertical sbuffer " .. file) or "rightbelow vertical new")
        vim.api.nvim_win_set_width(tree, width)
        if quit then
          pcall(vim.cmd, #vim.api.nvim_list_tabpages() > 1 and "tabclose" or "confirm qall")
        end
      end)
    end,
  })
end

--- neo-tree dims gitignored files from a cached `git status`, so folders that jdtls or Gradle create
--- while Neovim runs (bin/, build/) look like project folders until the tree is refreshed
local function refresh_after_builds()
  vim.api.nvim_create_autocmd({ "FocusGained", "TermLeave" }, {
    group = vim.api.nvim_create_augroup("user_neotree_refresh", { clear = true }),
    callback = function()
      if package.loaded["neo-tree"] then
        require("neo-tree.sources.manager").refresh("filesystem")
      end
    end,
  })
end

local ascii = {
  indent = { expander_collapsed = ">", expander_expanded = "v" },
  icon = {
    folder_closed = ">",
    folder_open = "v",
    folder_empty = ">",
    folder_empty_open = "v",
    default = " ",
    selected = "*",
    -- never ask nvim-web-devicons for glyphs, even if another plugin installed it
    provider = function() end,
  },
  git_status = {
    symbols = {
      added = "A",
      deleted = "D",
      modified = "M",
      renamed = "R",
      untracked = "?",
      ignored = "",
      unstaged = "",
      staged = "",
      conflict = "!",
    },
  },
  diagnostics = { symbols = { error = "E", warn = "W", info = "I", hint = "H" } },
}

return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  lazy = false, -- neo-tree lazy-loads itself; needed for the netrw hijack on `nvim .`
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-tree/nvim-web-devicons", -- only enabled with a Nerd Font, see plugins/ui.lua
  },
  init = function()
    keep_editor_next_to_tree()
    refresh_after_builds()
  end,
  keys = {
    -- IntelliJ Cmd+1: open and focus, or hide when the tree already has focus
    {
      "<leader>e",
      function()
        if vim.bo.filetype == "neo-tree" then
          vim.cmd("Neotree close")
        else
          vim.cmd("Neotree focus filesystem left")
        end
      end,
      desc = "Project tree",
    },
    -- IntelliJ Option+F1: Select In Project View
    { "<leader>E", "<cmd>Neotree reveal filesystem left<cr>", desc = "Select in Project tree" },
    { "<leader>ge", "<cmd>Neotree float git_status<cr>", desc = "Git changes tree" },
  },
  opts = {
    sources = { "filesystem", "buffers", "git_status" },
    close_if_last_window = false, -- see keep_editor_next_to_tree
    popup_border_style = "rounded",
    use_popups_for_input = false, -- rename/add prompts go through vim.ui.input (snacks.input)
    sort_case_insensitive = true,
    open_files_do_not_replace_types = { "terminal", "snacks_terminal", "qf" },
    default_component_configs = {
      indent = nerd and {} or ascii.indent,
      icon = nerd and {} or ascii.icon,
      git_status = nerd and {} or ascii.git_status,
      diagnostics = nerd and {} or ascii.diagnostics,
      modified = { symbol = "[+]" },
      file_size = { enabled = false },
      type = { enabled = false },
      last_modified = { enabled = false },
    },
    window = {
      position = "left",
      width = 40,
      mappings = {
        ["<space>"] = "none", -- keep <leader> working inside the tree
        ["<C-s>"] = "none", -- global <C-s> save instead of quick_jump
        ["l"] = "open",
        ["<right>"] = "open",
        ["h"] = "close_node",
        ["<left>"] = "close_node",
        ["P"] = { "toggle_preview", config = { use_float = true, use_snacks_image = false, use_image_nvim = false } },
        ["a"] = { add_and_open, config = { show_path = "relative" }, desc = "add (opens files)" },
        ["A"] = { "add_directory", config = { show_path = "relative" } },
        ["d"] = "delete",
        ["r"] = "rename",
        ["m"] = { "move", config = { show_path = "relative" } },
        ["c"] = { "copy", config = { show_path = "relative" } },
        ["x"] = "cut_to_clipboard",
        ["gy"] = "copy_to_clipboard",
        ["p"] = "paste_from_clipboard",
        ["y"] = { copy_path(":."), desc = "copy relative path" },
        ["Y"] = { copy_path(":p"), desc = "copy absolute path" },
      },
    },
    filesystem = {
      bind_to_cwd = true,
      follow_current_file = { enabled = true, leave_dirs_open = true },
      use_libuv_file_watcher = true,
      hijack_netrw_behavior = "open_default",
      group_empty_dirs = true, -- IntelliJ "Compact Middle Packages": src/main/java/com/example as one node
      scan_mode = "deep", -- compacts a folder before it is expanded, so one Enter opens the whole chain
      filtered_items = {
        visible = true, -- filtered items are shown dimmed; H hides them
        hide_dotfiles = false,
        hide_gitignored = true,
        never_show = { ".git", ".DS_Store" },
      },
      window = {
        mappings = {
          ["H"] = "toggle_hidden",
          ["/"] = "fuzzy_finder",
          ["<bs>"] = "navigate_up",
          ["."] = "set_root",
        },
      },
    },
    buffers = { follow_current_file = { enabled = true } },
  },
}
