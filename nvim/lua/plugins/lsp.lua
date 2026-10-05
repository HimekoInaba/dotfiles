-- Language servers (Java is in plugins/java.lua), diagnostics and the LSP keymaps shared by all servers
local nerd = vim.g.have_nerd_font == true

local function setup_diagnostics()
  local s = vim.diagnostic.severity
  vim.diagnostic.config({
    severity_sort = true,
    underline = true,
    update_in_insert = false,
    virtual_text = { spacing = 2, source = "if_many" },
    signs = {
      text = nerd and { [s.ERROR] = "\u{f057} ", [s.WARN] = "\u{f071} ", [s.INFO] = "\u{f05a} ", [s.HINT] = "\u{f0335} " }
        or { [s.ERROR] = "E", [s.WARN] = "W", [s.INFO] = "I", [s.HINT] = "H" },
    },
    float = { source = "if_many" },
    jump = {
      on_jump = function(diagnostic, bufnr)
        if diagnostic then
          vim.diagnostic.open_float({ bufnr = bufnr, scope = "cursor", focus = false })
        end
      end,
    },
  })
end

-- Not gated on client capabilities: jdtls registers most of them only after attaching.
local function lsp_keymaps(args)
  local client = vim.lsp.get_client_by_id(args.data.client_id)
  if not client then
    return
  end
  local function map(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { buffer = args.buf, desc = desc, silent = true })
  end
  local function pick(source)
    return function()
      Snacks.picker[source]()
    end
  end
  local function code_action(kind, apply)
    return function()
      vim.lsp.buf.code_action({ context = { only = { kind } }, apply = apply })
    end
  end

  map("n", "gd", pick("lsp_definitions"), "Go to Declaration")
  map("n", "gD", pick("lsp_declarations"), "Go to declaration (LSP declaration)")
  map("n", "gI", pick("lsp_implementations"), "Go to Implementation")
  map("n", "gy", pick("lsp_type_definitions"), "Go to Type Declaration")

  map({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, "Show Context Actions")
  map({ "n", "x" }, "<leader>cf", function()
    vim.lsp.buf.format({ async = true })
  end, "Reformat Code")
  map("n", "<leader>cg", code_action("source"), "Generate (source actions)")
  map("n", "<leader>ch", pick("lsp_incoming_calls"), "Call Hierarchy (callers)")
  map("n", "<leader>cC", pick("lsp_outgoing_calls"), "Call Hierarchy (callees)")
  map("n", "<leader>ct", function()
    vim.lsp.buf.typehierarchy("subtypes")
  end, "Type Hierarchy (subtypes)")
  map("n", "<leader>cT", function()
    vim.lsp.buf.typehierarchy("supertypes")
  end, "Type Hierarchy (supertypes)")
  map("n", "<leader>cl", "<Cmd>checkhealth vim.lsp<CR>", "LSP info")
  map("n", "<leader>cL", "<Cmd>lsp restart<CR>", "Restart LSP")
  map("n", "<leader>rn", vim.lsp.buf.rename, "Rename")
  map({ "n", "x" }, "<leader>rr", code_action("refactor"), "Refactor This")
  map({ "n", "x" }, "<leader>ri", code_action("refactor.inline"), "Inline")
  if client.name ~= "jdtls" then -- nvim-jdtls has its own organize imports
    map("n", "<leader>co", code_action("source.organizeImports", true), "Optimize Imports")
  end
end

return {
  {
    "mason-org/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonUninstall", "MasonUninstallAll", "MasonUpdate", "MasonLog" },
    opts = {
      ui = {
        icons = { package_installed = "✓", package_pending = "➜", package_uninstalled = "✗" },
      },
    },
  },
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
        { path = "snacks.nvim", words = { "Snacks" } },
        { path = "lazy.nvim", words = { "LazyVim", "lazy" } },
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "mason-org/mason.nvim",
      "mason-org/mason-lspconfig.nvim",
      "saghen/blink.cmp", -- its plugin file sets vim.lsp.config("*") capabilities before servers start
    },
    config = function()
      setup_diagnostics()

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("user_lsp_attach", { clear = true }),
        callback = lsp_keymaps,
      })

      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            completion = { callSnippet = "Replace" },
            workspace = { checkThirdParty = false },
            telemetry = { enable = false },
            hint = { enable = true, setType = false, paramType = true, arrayIndex = "Disable" },
          },
        },
      })

      -- ensure_installed runs in interactive sessions only; jdtls is started by nvim-jdtls
      require("mason-lspconfig").setup({
        ensure_installed = { "lua_ls", "yamlls", "jsonls", "bashls", "jdtls" },
        automatic_enable = { exclude = { "jdtls" } },
      })

      -- bashls lints with shellcheck, which it finds on the PATH that Mason extends with its bin dir
      local registry = require("mason-registry")
      registry.refresh(vim.schedule_wrap(function()
        if #vim.api.nvim_list_uis() > 0 and registry.has_package("shellcheck") and not registry.is_installed("shellcheck") then
          registry.get_package("shellcheck"):install()
        end
      end))
    end,
  },
}
