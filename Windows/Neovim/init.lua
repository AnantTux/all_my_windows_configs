-- Small, practical Neovim baseline.
vim.g.mapleader = " "

-- Tree-sitter's compiler integration expects CC to name one executable.
-- Zig needs a subcommand, so use the wrapper instead of `CC = "zig cc"`.
local zig_cc_wrapper = vim.fs.joinpath(vim.fn.stdpath("config"), "bin", "zig-cc.cmd")
if vim.fn.executable("zig") == 1 and vim.fn.filereadable(zig_cc_wrapper) == 1 then
  vim.env.CC = zig_cc_wrapper
end

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  -- 1. Auto-pairs (Loads only when entering Insert Mode)
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = true,
  },

  -- 2. File Explorer as a buffer (Loads when pressing '-')
  {
    "stevearc/oil.nvim",
    cmd = "Oil",
    keys = {
      { "-", "<cmd>Oil<cr>", desc = "Open parent directory" },
    },
    opts = {},
  },

  -- 3. Git status signs in gutter (Loads when opening a file)
  {
    "lewis6991/gitsigns.nvim",
    event = "BufReadPost",
    opts = {
      on_attach = function(bufnr)
        local gitsigns = require("gitsigns")
        local function map(lhs, rhs, desc)
          vim.keymap.set("n", lhs, rhs, { buffer = bufnr, desc = desc })
        end
        map("<leader>gp", gitsigns.preview_hunk, "Preview Git hunk")
        map("<leader>gs", gitsigns.stage_hunk, "Stage Git hunk")
        map("<leader>gr", gitsigns.reset_hunk, "Reset Git hunk")
      end,
    },
  },

  -- 4. Fuzzy file searcher (Loads when pressing Leader + f / Leader + g)
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = "Telescope",
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find Files" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Find Text (Grep)" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Find Buffers" },
      { "<leader>fr", "<cmd>Telescope oldfiles<cr>", desc = "Recent Files" },
    },
  },

  -- 5. Status line
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    opts = {
      options = { theme = "auto", globalstatus = true },
      sections = {
        lualine_c = { { "filename", path = 1 } },
        lualine_x = {
          {
            "diagnostics",
            symbols = { error = "E:", warn = "W:", info = "I:", hint = "H:" },
          },
          "encoding",
          "fileformat",
          "filetype",
        },
      },
    },
  },

  -- 6. Auto-completion engine (blink.cmp)
  {
    "Saghen/blink.cmp",
    dependencies = "rafamadriz/friendly-snippets",
    version = "*",
    opts = {
      enabled = function()
        -- Keep completion off in real comments, without treating URLs or `--` code as comments.
        local col = vim.api.nvim_win_get_cursor(0)[2]

        -- Check Tree-sitter nodes, then fall back to syntax groups when no parser is available.
        local ok, node = pcall(vim.treesitter.get_node)
        if ok and node then
          local current = node
          while current do
            if current:type():find("comment") then
              return false
            end
            current = current:parent()
          end
        else
          local syntax_group = vim.fn.synIDattr(vim.fn.synID(vim.fn.line("."), col + 1, 1), "name")
          if syntax_group:lower():find("comment") then
            return false
          end
        end

        return vim.bo.buftype ~= "prompt"
      end,
      keymap = { preset = "default" },
      appearance = {
        use_nvim_cmp_as_default = true,
        nerd_font_variant = "mono",
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
        providers = {
          path = {
            enabled = function()
              local line = vim.api.nvim_get_current_line()
              local col = vim.api.nvim_win_get_cursor(0)[2]
              local before = line:sub(1, col)

              -- Disable path completion on comment patterns // or /*
              if before:match("//") or before:match("/%*") then
                return false
              end

              -- Disable path completion on single slashes unless inside quotes or explicit path prefixes (./, ../, ~/)
              if before:sub(-1) == "/" then
                if before:match("%s/$") or before:match(";%s*/$") or before:match(";/$") then
                  return false
                end
                local in_quote = before:match("[\"'][^\"']*$") ~= nil
                local is_path_prefix = before:match("%.%./$") or before:match("%./$") or before:match("~/+$") or before:match("%a:/$")
                if not (in_quote or is_path_prefix) then
                  return false
                end
              end

              return true
            end,
          },
        },
      },
      completion = {
        documentation = { auto_show = true, auto_show_delay_ms = 200 },
        ghost_text = { enabled = true },
      },
    },
    opts_extend = { "sources.default" },
  },

  -- 7. Treesitter for real-time syntax highlighting
  {
    "nvim-treesitter/nvim-treesitter",
    config = function()
      require("nvim-treesitter.install").prefer_git = true
      local ok, configs = pcall(require, "nvim-treesitter.configs")
      if ok then
        configs.setup({
          ensure_installed = { "java", "lua", "vim", "javascript", "python" },
          highlight = { enable = true },
        })
      end
    end,
  },})

local opt = vim.opt

-- Line numbers: absolute on the current line, relative everywhere else.
opt.number = true
opt.relativenumber = true

-- Editing comfort.
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.cursorline = true
opt.signcolumn = "yes"
opt.scrolloff = 6
opt.sidescrolloff = 6
opt.wrap = true 
opt.linebreak = true
opt.confirm = true

-- Indentation.
opt.expandtab = true
opt.tabstop = 4
opt.shiftwidth = 4
opt.softtabstop = 4
opt.smartindent = true

-- Searching.
opt.ignorecase = true
opt.smartcase = true

-- Files, splits, and colours.
opt.undofile = true
opt.splitbelow = true
opt.splitright = true
opt.termguicolors = true
opt.updatetime = 250
opt.completeopt = { "menuone", "noselect", "popup" }

-- Neutral VS Code-inspired theme.
vim.cmd.colorscheme("vscode_black")

-- IDE-style error and warning diagnostics.
vim.diagnostic.config({
  virtual_text = {
    severity = { min = vim.diagnostic.severity.ERROR },
    spacing = 2,
    prefix = "●",
    source = "if_many",
  },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "󰅚",
      [vim.diagnostic.severity.WARN] = "󰀪",
      [vim.diagnostic.severity.INFO] = "󰋽",
      [vim.diagnostic.severity.HINT] = "󰌶",
    },
  },
  underline = {
    severity = { min = vim.diagnostic.severity.ERROR },
  },
  update_in_insert = false,
  severity_sort = true,
  float = {
    border = "rounded",
    source = true,
  },
})

local function diagnostic_colours()
  vim.api.nvim_set_hl(0, "DiagnosticError", { fg = "#ff6b6b" })
  vim.api.nvim_set_hl(0, "DiagnosticWarn", { fg = "#ffd700" })
  vim.api.nvim_set_hl(0, "DiagnosticInfo", { fg = "#82aaff" })
  vim.api.nvim_set_hl(0, "DiagnosticHint", { fg = "#8bd49c" })
  vim.api.nvim_set_hl(0, "DiagnosticUnderlineError", { undercurl = true, sp = "#ff6b6b" })
  vim.api.nvim_set_hl(0, "DiagnosticUnderlineWarn", { undercurl = true, sp = "#ffd700" })
end

diagnostic_colours()

-- Built-in LSP servers: no Neovim plugin manager required.
local node = "C:/Program Files/nodejs/node.exe"
local npm_modules = vim.fs.joinpath(vim.fn.expand("$APPDATA"), "npm", "node_modules")
local nvim_tools = vim.fs.joinpath(vim.fn.expand("$LOCALAPPDATA"), "nvim-tools")

local function npm_server(...)
  return { node, vim.fs.joinpath(npm_modules, ...), "--stdio" }
end

vim.lsp.config("typescript", {
  cmd = npm_server("typescript-language-server", "lib", "cli.mjs"),
  init_options = {
    tsserver = {
      path = vim.fs.joinpath(npm_modules, "typescript", "lib", "tsserver.js"),
    },
  },
  filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
  root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
})

vim.lsp.config("pyright", {
  cmd = npm_server("pyright", "langserver.index.js"),
  filetypes = { "python" },
  root_markers = { "pyrightconfig.json", "pyproject.toml", "requirements.txt", ".git" },
})

vim.lsp.config("json", {
  cmd = npm_server("vscode-langservers-extracted", "bin", "vscode-json-language-server"),
  filetypes = { "json", "jsonc" },
  root_markers = { "package.json", ".git" },
})

vim.lsp.config("html", {
  cmd = npm_server("vscode-langservers-extracted", "bin", "vscode-html-language-server"),
  filetypes = { "html" },
  root_markers = { "package.json", ".git" },
})

vim.lsp.config("css", {
  cmd = npm_server("vscode-langservers-extracted", "bin", "vscode-css-language-server"),
  filetypes = { "css", "scss", "less" },
  root_markers = { "package.json", ".git" },
})

vim.lsp.config("clangd", {
  cmd = {
    vim.fs.joinpath(nvim_tools, "clangd", "clangd_22.1.0", "bin", "clangd.exe"),
    "--background-index",
    "--clang-tidy",
    "--completion-style=detailed",
  },
  filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
  root_dir = function(bufnr, on_dir)
    local root = vim.fs.root(bufnr, {
      ".clangd",
      "compile_commands.json",
      "compile_flags.txt",
      ".git",
    })
    on_dir(root or vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)))
  end,
})

local java21 = vim.fs.joinpath(nvim_tools, "java21", "jdk-21.0.12+8", "bin", "java.exe")
local jdtls_home = vim.fs.joinpath(nvim_tools, "jdtls")
local jdtls_launcher = vim.fs.joinpath(
  jdtls_home,
  "plugins",
  "org.eclipse.equinox.launcher_1.7.200.v20260619-2039.jar"
)

vim.lsp.config("jdtls", {
  cmd = function(dispatchers, config)
    local root = config.root_dir or vim.fn.getcwd()
    local workspace = vim.fs.joinpath(
      vim.fn.stdpath("data"),
      "jdtls-workspaces",
      vim.fn.sha256(root):sub(1, 16)
    )
    vim.fn.mkdir(workspace, "p")

    return vim.lsp.rpc.start({
      java21,
      "-Declipse.application=org.eclipse.jdt.ls.core.id1",
      "-Dosgi.bundles.defaultStartLevel=4",
      "-Declipse.product=org.eclipse.jdt.ls.core.product",
      "-Dlog.protocol=true",
      "-Dlog.level=ALL",
      "-Xmx1g",
      "--add-modules=ALL-SYSTEM",
      "--add-opens",
      "java.base/java.util=ALL-UNNAMED",
      "--add-opens",
      "java.base/java.lang=ALL-UNNAMED",
      "-jar",
      jdtls_launcher,
      "-configuration",
      vim.fs.joinpath(jdtls_home, "config_win"),
      "-data",
      workspace,
    }, dispatchers)
  end,
  filetypes = { "java" },
  root_dir = function(bufnr, on_dir)
    local root = vim.fs.root(bufnr, {
      "mvnw",
      "gradlew",
      "pom.xml",
      "build.gradle",
      "build.gradle.kts",
      "settings.gradle",
      "settings.gradle.kts",
      ".git",
    })
    on_dir(root or vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)))
  end,
  settings = {
    java = {
      signatureHelp = { enabled = true },
    },
  },
})

vim.lsp.config("eslint", {
  cmd = npm_server("vscode-langservers-extracted", "bin", "vscode-eslint-language-server"),
  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
  },
  root_markers = {
    "eslint.config.js",
    "eslint.config.mjs",
    "eslint.config.cjs",
    "eslint.config.ts",
    ".eslintrc",
    ".eslintrc.js",
    ".eslintrc.json",
    "package.json",
    ".git",
  },
  settings = {
    nodePath = npm_modules,
    validate = "on",
    useESLintClass = false,
    run = "onType",
    format = false,
    quiet = false,
    onIgnoredFiles = "off",
    rulesCustomizations = {},
    codeActionOnSave = { enable = false, mode = "all" },
    codeAction = {
      disableRuleComment = { enable = true, location = "separateLine" },
      showDocumentation = { enable = true },
    },
    problems = { shortenToSingleLine = false },
    experimental = {},
    workingDirectory = { mode = "auto" },
  },
})

-- Integrate blink.cmp with built-in LSP server capabilities.
local ok, blink = pcall(require, "blink.cmp")
if ok then
  vim.lsp.config("*", {
    capabilities = blink.get_lsp_capabilities(),
  })
end

vim.lsp.enable({
  "typescript",
  "pyright",
  "json",
  "html",
  "css",
  "eslint",
  "clangd",
  "jdtls",
})

-- LSP navigation is available only in buffers with an attached language server.
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local function map(lhs, rhs, desc)
      vim.keymap.set("n", lhs, rhs, { buffer = args.buf, desc = desc })
    end

    map("gd", vim.lsp.buf.definition, "Go to definition")
    map("gr", vim.lsp.buf.references, "Find references")
    map("K", vim.lsp.buf.hover, "Show documentation")
    map("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
    map("<leader>ca", vim.lsp.buf.code_action, "Code actions")
  end,
})

vim.keymap.set("n", "]d", function()
  vim.diagnostic.jump({ count = 1, float = true })
end, { desc = "Next diagnostic" })

vim.keymap.set("n", "[d", function()
  vim.diagnostic.jump({ count = -1, float = true })
end, { desc = "Previous diagnostic" })

vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, {
  desc = "Show diagnostic details",
})

vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, {
  desc = "List diagnostics",
})

-- Clear search highlighting with Escape.
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", {
  desc = "Clear search highlighting",
})

-- Briefly highlight text after it is copied.
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank({ timeout = 150 })
  end,
})

-- Blend Neovim's background with Alacritty's background.
local function transparent_background()
  for _, group in ipairs({
    "Normal",
    "NormalNC",
    "SignColumn",
    "EndOfBuffer",
  }) do
    vim.api.nvim_set_hl(0, group, { bg = "none" })
  end
end

transparent_background()

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    transparent_background()
    diagnostic_colours()
  end,
})

-- Format Java code manually using Space + f
vim.keymap.set("n", "<leader>f", function()
  vim.lsp.buf.format({ async = true })
end, { desc = "Format current buffer with LSP" })

-- Auto-format Java on save
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.java",
  callback = function(args)
    vim.lsp.buf.format({ bufnr = args.buf, timeout_ms = 2000 })
  end,
})

-- Format languages whose configured LSP server supports formatting when saving.
local format_on_save_filetypes = {
  css = true,
  html = true,
  javascript = true,
  javascriptreact = true,
  json = true,
  jsonc = true,
  typescript = true,
  typescriptreact = true,
}

vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function(args)
    if format_on_save_filetypes[vim.bo[args.buf].filetype] then
      vim.lsp.buf.format({ bufnr = args.buf, timeout_ms = 2000 })
    end
  end,
})

-- Toggle warning virtual text and underlines on demand with Space + t + w
local show_warnings = false

vim.keymap.set("n", "<leader>tw", function()
  show_warnings = not show_warnings

  vim.diagnostic.config({
    virtual_text = show_warnings and {
      spacing = 2,
      prefix = "●",
      source = "if_many",
    } or {
      severity = { min = vim.diagnostic.severity.ERROR },
      spacing = 2,
      prefix = "●",
      source = "if_many",
    },
    underline = show_warnings and true or {
      severity = { min = vim.diagnostic.severity.ERROR },
    },
  })

  print("Warnings " .. (show_warnings and "Enabled" or "Disabled"))
end, { desc = "Toggle warning details inline" })

local function open_terminal_split(command, cwd)
  vim.cmd("belowright 14split")
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, buf)
  vim.fn.termopen(command, { cwd = cwd })
  vim.cmd("startinsert")
end

local function find_java_project_root()
  local marker = vim.fs.find({ "gradlew.bat", "gradlew", "mvnw.cmd", "mvnw", "pom.xml" }, {
    path = vim.fn.expand("%:p:h"),
    upward = true,
    limit = 1,
  })[1]
  return marker and vim.fs.dirname(marker), marker and vim.fs.basename(marker)
end

-- Run a Gradle/Maven application when available, otherwise compile all Java files in this folder.
local function run_java_file()
  vim.cmd("w") -- Auto-save buffer before running
  local project_root, marker = find_java_project_root()
  if project_root then
    if marker == "gradlew.bat" then
      open_terminal_split("gradlew.bat run", project_root)
    elseif marker == "gradlew" then
      open_terminal_split("./gradlew run", project_root)
    elseif marker == "mvnw.cmd" then
      open_terminal_split("mvnw.cmd exec:java", project_root)
    elseif marker == "mvnw" then
      open_terminal_split("./mvnw exec:java", project_root)
    else
      open_terminal_split("mvn exec:java", project_root)
    end
    return
  end

  local filedir = vim.fn.expand("%:p:h")
  local filename = vim.fn.expand("%:t:r")

  -- Check if file has a package declaration (e.g. package video2;)
  local pkg = nil
  for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, 10, false)) do
    local match = line:match("^%s*package%s+([%w_%.]+)%s*;")
    if match then
      pkg = match
      break
    end
  end

  -- Use JDK 21 from nvim-tools if present, otherwise system java/javac
  local javac21 = vim.fs.joinpath(nvim_tools, "java21", "jdk-21.0.12+8", "bin", "javac.exe")
  local java21 = vim.fs.joinpath(nvim_tools, "java21", "jdk-21.0.12+8", "bin", "java.exe")

  local javac_cmd = vim.fn.executable(javac21) == 1 and string.format('"%s"', javac21) or "javac"
  local java_cmd = vim.fn.executable(java21) == 1 and string.format('"%s"', java21) or "java"

  local cmd
  if pkg then
    cmd = string.format('%s *.java && %s -cp .. %s.%s', javac_cmd, java_cmd, pkg, filename)
  else
    cmd = string.format('%s *.java && %s "%s"', javac_cmd, java_cmd, filename)
  end

  open_terminal_split(cmd, filedir)
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "java",
  callback = function(args)
    vim.keymap.set("n", "<leader>r", run_java_file, {
      buffer = args.buf,
      desc = "Run Java application",
    })
    vim.keymap.set("n", "<F5>", run_java_file, {
      buffer = args.buf,
      desc = "Run Java application",
    })
  end,
})
