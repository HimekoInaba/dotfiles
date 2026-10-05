-- IntelliJ "Insert pair bracket/quote": typing ( [ { " ' ` adds the closing one, typing the closing one
-- steps over it, Backspace between a pair deletes both, Enter between braces opens an indented line

-- Like IntelliJ, no pair in front of a word, a quote, a dot or an opening bracket
local next_char = "[^%w%%%'%[%\"%.%`%$]"

local function open(pair)
  return { action = "open", pair = pair, neigh_pattern = "^[^\\]" .. next_char }
end

local function quote(pair, before)
  return { action = "closeopen", pair = pair, neigh_pattern = before .. next_char, register = { cr = false } }
end

return {
  "nvim-mini/mini.pairs",
  version = "*",
  event = "InsertEnter",
  init = function()
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("user_pairs", { clear = true }),
      pattern = "grug-far", -- search and replace fields take literal text
      callback = function(args)
        vim.b[args.buf].minipairs_disable = true
      end,
    })
  end,
  opts = {
    modes = { insert = true, command = false, terminal = false },
    mappings = {
      ["("] = open("()"),
      ["["] = open("[]"),
      ["{"] = open("{}"),
      ['"'] = quote('""', "^[^\\]"),
      ["'"] = quote("''", "^[^%a\\]"),
      ["`"] = quote("``", "^[^\\]"),
    },
  },
}
