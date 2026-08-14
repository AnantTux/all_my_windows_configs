-- Small, practical Neovim baseline.
vim.g.mapleader = " "
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
    opts = {},
  },

  -- 4. Fuzzy file searcher (Loads when pressing Leader + f / Leader + g)
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = "Telescope",
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find Files" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Find Text (Grep)" },
    },
  },
})

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
opt.wrap = false
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

-- Automatic LSP suggestions, including real import paths and filenames.
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = true })
    end
  end,
})

vim.keymap.set("i", "<C-Space>", function()
  vim.lsp.completion.get()
end, { desc = "Show code and path suggestions" })

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