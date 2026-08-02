-- Small, practical Neovim baseline.
vim.g.mapleader = " "

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
  underline = true,
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

-- Lightweight auto-pairs without a plugin.
local bracket_pairs = {
  ["("] = ")",
  ["["] = "]",
  ["{"] = "}",
}

local quote_pairs = {
  ['"'] = true,
  ["'"] = true,
  ["`"] = true,
}

local function surrounding_characters()
  local line = vim.api.nvim_get_current_line()
  local column = vim.api.nvim_win_get_cursor(0)[2]
  return line:sub(column, column), line:sub(column + 1, column + 1)
end

for opening, closing in pairs(bracket_pairs) do
  vim.keymap.set("i", opening, opening .. closing .. "<Left>", {
    desc = "Insert matching " .. closing,
  })

  vim.keymap.set("i", closing, function()
    local _, next_character = surrounding_characters()
    return next_character == closing and "<Right>" or closing
  end, {
    expr = true,
    desc = "Step over or insert " .. closing,
  })
end

for quote in pairs(quote_pairs) do
  vim.keymap.set("i", quote, function()
    local previous_character, next_character = surrounding_characters()

    if next_character == quote then
      return "<Right>"
    end

    if previous_character == "\\" or (quote == "'" and previous_character:match("[%w_]")) then
      return quote
    end

    return quote .. quote .. "<Left>"
  end, {
    expr = true,
    desc = "Insert matching quote",
  })
end

vim.keymap.set("i", "<BS>", function()
  local previous_character, next_character = surrounding_characters()
  local is_empty_bracket = bracket_pairs[previous_character] == next_character
  local is_empty_quote = quote_pairs[previous_character] and previous_character == next_character

  return (is_empty_bracket or is_empty_quote) and "<BS><Del>" or "<BS>"
end, {
  expr = true,
  desc = "Delete an empty pair together",
})

vim.keymap.set("i", "<CR>", function()
  local previous_character, next_character = surrounding_characters()
  return previous_character == "{" and next_character == "}" and "<CR><Esc>O" or "<CR>"
end, {
  expr = true,
  desc = "Open an indented line inside braces",
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
