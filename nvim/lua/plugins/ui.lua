-- Status line, editor tabs and the which-key popup
local nerd = vim.g.have_nerd_font == true

local function indent_info()
  return (vim.bo.expandtab and "spaces: " or "tab: ") .. vim.fn.shiftwidth()
end

local function gitsigns_diff()
  local gs = vim.b.gitsigns_status_dict
  if gs then
    return { added = gs.added, modified = gs.changed, removed = gs.removed }
  end
end

--- JDK and library classes opened by jdtls have long jdt:// URIs; show "String.java" like IntelliJ
local function jdt_name(path)
  return path:match("^jdt://[^?]*/([^/?]+)")
end

local function close_buffer(n)
  Snacks.bufdelete(n) -- asks to save instead of failing with E89
end

return {
  {
    "nvim-tree/nvim-web-devicons",
    lazy = true,
    enabled = nerd, -- also disables it as a dependency of other plugins
  },

  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = {
      options = {
        theme = "auto",
        globalstatus = true,
        icons_enabled = nerd,
        component_separators = nerd and { left = "\u{e0b1}", right = "\u{e0b3}" } or { left = "|", right = "|" },
        section_separators = nerd and { left = "\u{e0b0}", right = "\u{e0b2}" } or { left = "", right = "" },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", { "diff", source = gitsigns_diff } },
        lualine_c = {
          {
            "filename",
            path = 1,
            symbols = { modified = "[+]", readonly = "[RO]", unnamed = "[No Name]", newfile = "[New]" },
            fmt = function(name)
              return jdt_name(vim.api.nvim_buf_get_name(0)) or name
            end,
          },
        },
        lualine_x = { "diagnostics", "lsp_status", "encoding", "fileformat", indent_info, "filetype" },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
      extensions = { "neo-tree", "lazy", "mason", "quickfix" },
    },
  },

  {
    "akinsho/bufferline.nvim",
    version = "*",
    event = "VeryLazy",
    keys = {
      { "[b", "<cmd>BufferLineCyclePrev<cr>", desc = "Previous tab" },
      { "]b", "<cmd>BufferLineCycleNext<cr>", desc = "Next tab" },
      { "<leader>b[", "<cmd>BufferLineMovePrev<cr>", desc = "Move tab left" },
      { "<leader>b]", "<cmd>BufferLineMoveNext<cr>", desc = "Move tab right" },
      { "<leader>bp", "<cmd>BufferLineTogglePin<cr>", desc = "Pin tab" },
      { "<leader>bP", "<cmd>BufferLineGroupClose ungrouped<cr>", desc = "Close unpinned tabs" },
      { "<leader>bl", "<cmd>BufferLineCloseLeft<cr>", desc = "Close tabs to the left" },
      { "<leader>br", "<cmd>BufferLineCloseRight<cr>", desc = "Close tabs to the right" },
      { "<leader>bj", "<cmd>BufferLinePick<cr>", desc = "Jump to tab" },
    },
    opts = {
      options = {
        mode = "buffers",
        name_formatter = function(buf)
          return jdt_name(buf.path)
        end,
        close_command = close_buffer,
        right_mouse_command = close_buffer,
        middle_mouse_command = close_buffer,
        diagnostics = "nvim_lsp",
        diagnostics_update_in_insert = false,
        diagnostics_indicator = function(_, _, diag)
          local icons = nerd and { error = "\u{f057} ", warning = "\u{f071} " } or { error = "E", warning = "W" }
          local parts = {}
          if diag.error then
            parts[#parts + 1] = icons.error .. diag.error
          end
          if diag.warning then
            parts[#parts + 1] = icons.warning .. diag.warning
          end
          return table.concat(parts, " ")
        end,
        always_show_bufferline = true,
        sort_by = "insert_after_current",
        separator_style = "thin",
        show_buffer_icons = nerd,
        truncate_names = false,
        show_buffer_close_icons = true,
        show_close_icon = false,
        buffer_close_icon = nerd and "\u{f0156}" or "x",
        close_icon = nerd and "\u{f011b}" or "x",
        modified_icon = "●",
        left_trunc_marker = nerd and "\u{f0a8}" or "<",
        right_trunc_marker = nerd and "\u{f0a9}" or ">",
        offsets = {
          { filetype = "neo-tree", text = "Project", text_align = "left", highlight = "Directory", separator = true },
        },
      },
    },
  },

  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern",
      delay = 300,
      icons = {
        mappings = nerd,
        -- the defaults are Nerd Font glyphs and a partial table keeps them, so every key is listed
        keys = nerd and {} or {
          Up = "Up ", Down = "Down ", Left = "Left ", Right = "Right ",
          C = "C-", M = "M-", D = "D-", S = "S-",
          CR = "Enter ", Esc = "Esc ", ScrollWheelDown = "WheelDown ", ScrollWheelUp = "WheelUp ",
          NL = "Enter ", BS = "BS ", Space = "Space ", Tab = "Tab ",
          F1 = "F1", F2 = "F2", F3 = "F3", F4 = "F4", F5 = "F5", F6 = "F6",
          F7 = "F7", F8 = "F8", F9 = "F9", F10 = "F10", F11 = "F11", F12 = "F12",
        },
      },
      spec = {
        { "<leader>b", group = "buffers (tabs)" },
        { "<leader>c", group = "code" },
        { "<leader>f", group = "find / go to" },
        { "<leader>g", group = "git" },
        { "<leader>q", group = "quit" },
        { "<leader>r", group = "refactor" },
        { "<leader>s", group = "search" },
        { "<leader>t", group = "terminal" },
        { "<leader>u", group = "toggles" },
        { "<leader>w", group = "windows", proxy = "<C-w>" },
        -- Ctrl+w keys missing from which-key's preset, so that `Space w` runs them too
        { "<c-w>b", desc = "Go to the bottom-right window" },
        { "<c-w>c", desc = "Close window" },
        { "<c-w>n", desc = "New empty window" },
        { "<c-w>p", desc = "Go to the previous window" },
        { "<c-w>r", desc = "Rotate windows down" },
        { "<c-w>R", desc = "Rotate windows up" },
        { "<c-w>t", desc = "Go to the top-left window" },
        { "<c-w>W", desc = "Switch windows backwards" },
        { "<c-w>z", desc = "Close the preview window" },
        { "<leader>x", group = "problems / lists" },
        { "[", group = "previous" },
        { "]", group = "next" },
        { "g", group = "goto" },
        { "gr", group = "lsp (built-in)" },
        { "z", group = "fold" },
      },
    },
    keys = {
      { "<leader>?", function() require("which-key").show({ global = false }) end, desc = "Buffer keymaps" },
    },
  },
}
