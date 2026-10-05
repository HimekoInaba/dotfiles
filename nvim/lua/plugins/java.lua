-- Java via nvim-jdtls and Mason's jdtls package, running on JDK 25

--- JDK used to run jdtls and Gradle, and registered as the JavaSE-25 runtime.
--- Resolution order: $JDTLS_JAVA_HOME, `/usr/libexec/java_home -v 25`, $JAVA_HOME.
local function jdk25()
  local candidates = { vim.env.JDTLS_JAVA_HOME }
  if vim.fn.executable("/usr/libexec/java_home") == 1 then
    local out = vim.system({ "/usr/libexec/java_home", "-v", "25" }, { text = true }):wait()
    if out.code == 0 then
      table.insert(candidates, vim.trim(out.stdout))
    end
  end
  table.insert(candidates, vim.env.JAVA_HOME)
  for _, home in ipairs(candidates) do
    if home and home ~= "" and vim.fn.executable(home .. "/bin/java") == 1 then
      return home
    end
  end
end

-- The Gradle/Maven build root wins over .git and over subproject build files
local root_markers = {
  { "gradlew", "mvnw", "settings.gradle", "settings.gradle.kts" },
  { ".git" },
  { "build.gradle", "build.gradle.kts", "pom.xml" },
}

local function jdtls_config(java_home, root_dir)
  local mason = vim.env.MASON or (vim.fn.stdpath("data") .. "/mason")
  local workspace = vim.fs.joinpath(
    vim.fn.stdpath("data"),
    "jdtls-workspace",
    vim.fs.basename(root_dir) .. "-" .. vim.fn.sha256(root_dir):sub(1, 8)
  )

  local cmd = {
    mason .. "/bin/jdtls",
    "--java-executable=" .. java_home .. "/bin/java",
    "--jvm-arg=-XX:+UseParallelGC",
    "--jvm-arg=-XX:GCTimeRatio=4",
    "--jvm-arg=-XX:AdaptiveSizePolicyWeight=90",
    "--jvm-arg=-Dsun.zip.disableMemoryMapping=true",
    "--jvm-arg=-Xmx2G",
    "--jvm-arg=-Xlog:disable",
    -- keeps .project/.classpath/.settings in the workspace instead of the project; a settings key does not work
    "--jvm-arg=-Djava.import.generatesMetadataFilesAtProjectRoot=false",
  }
  local lombok = mason .. "/share/jdtls/lombok.jar"
  if vim.uv.fs_stat(lombok) then
    table.insert(cmd, "--jvm-arg=-javaagent:" .. lombok)
  end
  vim.list_extend(cmd, { "-data", workspace })

  local settings = {
    java = {
      configuration = {
        updateBuildConfiguration = "interactive",
        runtimes = { { name = "JavaSE-25", path = java_home, default = true } },
      },
      import = {
        gradle = { enabled = true, wrapper = { enabled = true }, java = { home = java_home } },
        maven = { enabled = true },
      },
      -- Wrapper jars missing from jdtls's allow-list (it reports them as "could be malicious"), each
      -- checked against https://services.gradle.org/distributions/gradle-<version>-wrapper.jar.sha256
      imports = {
        gradle = {
          wrapper = {
            checksums = {
              { sha256 = "238e777fcddd7e34f9708186085def2abd6e08e658505b38718d79d74c21abd5", allowed = true }, -- 9.8.0
            },
          },
        },
      },
      eclipse = { downloadSources = true },
      maven = { downloadSources = true },
      signatureHelp = { enabled = true, description = { enabled = true } },
      symbols = { includeSourceMethodDeclarations = true }, -- Go to Symbol finds methods, not only types
      completion = {
        -- IntelliJ's default layout: all other imports, javax, java, then static imports
        importOrder = { "", "javax", "java", "#" },
        -- project-specific ones come from vim.g.java_favorite_static_members (lua/config/local.lua)
        favoriteStaticMembers = vim.list_extend({
          "org.assertj.core.api.Assertions.*",
          "org.mockito.Mockito.*",
          "org.mockito.ArgumentMatchers.*",
          "org.junit.jupiter.api.Assertions.*",
          "org.awaitility.Awaitility.*",
          "org.jooq.impl.DSL.*",
        }, vim.g.java_favorite_static_members or {}),
        filteredTypes = { "com.sun.*", "java.awt.*", "jdk.*", "sun.*", "org.graalvm.*", "io.micrometer.shaded.*" },
      },
      sources = { organizeImports = { starThreshold = 9999, staticStarThreshold = 9999 } },
    },
  }

  return {
    name = "jdtls",
    cmd = cmd,
    root_dir = root_dir,
    -- vim.lsp.start() does not merge vim.lsp.config("*"), so blink's capabilities are passed here
    capabilities = require("blink.cmp").get_lsp_capabilities(),
    settings = settings,
    -- jdtls reads settings from init_options at initialize, before the first Gradle import
    init_options = { bundles = {}, settings = settings },
  }
end

local function java_keymaps(buf)
  local jdtls = require("jdtls")
  local function map(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc, silent = true })
  end
  -- Visual mode needs <Esc> first: nvim-jdtls reads the range from the '< and '> marks
  local function visual(fn)
    return ("<Esc><Cmd>lua require('jdtls').%s({ visual = true })<CR>"):format(fn)
  end
  map("n", "gs", jdtls.super_implementation, "Go to Super Method")
  map("n", "<leader>co", jdtls.organize_imports, "Optimize Imports")
  map("n", "<leader>rv", jdtls.extract_variable_all, "Extract Variable (all occurrences)")
  map("x", "<leader>rv", visual("extract_variable_all"), "Extract Variable (all occurrences)")
  map("n", "<leader>rV", jdtls.extract_variable, "Extract Variable (this occurrence)")
  map("x", "<leader>rV", visual("extract_variable"), "Extract Variable (this occurrence)")
  map("n", "<leader>rc", jdtls.extract_constant, "Extract Constant")
  map("x", "<leader>rc", visual("extract_constant"), "Extract Constant")
  map("x", "<leader>rm", visual("extract_method"), "Extract Method")
end

return {
  {
    "mfussenegger/nvim-jdtls",
    ft = "java",
    dependencies = { "mason-org/mason.nvim", "saghen/blink.cmp" },
    config = function()
      local java_home = jdk25()

      local function start(buf)
        if not java_home then
          vim.notify("jdtls: no JDK 25 found (set JDTLS_JAVA_HOME)", vim.log.levels.ERROR)
          return
        end
        local name = vim.api.nvim_buf_get_name(buf)
        if name == "" or not vim.startswith(vim.uri_from_bufnr(buf), "file://") then
          return
        end
        local root_dir = vim.fs.root(buf, root_markers) or vim.fs.dirname(name)
        require("jdtls").start_or_attach(jdtls_config(java_home, root_dir), {}, { bufnr = buf })
      end

      -- lazy.nvim re-fires FileType for the buffer that triggered loading this plugin
      local group = vim.api.nvim_create_augroup("user_jdtls", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "java",
        callback = function(args)
          start(args.buf)
        end,
      })
      vim.api.nvim_create_autocmd("LspAttach", {
        group = group,
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client and client.name == "jdtls" then
            java_keymaps(args.buf)
          end
        end,
      })
    end,
  },
}
