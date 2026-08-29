-- Small, practical Neovim baseline.
vim.g.mapleader = " "

-- Global tool paths (defined at top so all plugins and LSP configs can access them)
local node = "C:/Program Files/nodejs/node.exe"
local npm_modules = vim.fs.joinpath(vim.fn.expand("$APPDATA"), "npm", "node_modules")
local nvim_tools = vim.fs.joinpath(vim.fn.expand("$LOCALAPPDATA"), "nvim-tools")

-- Tree-sitter's compiler integration expects CC to name one executable.
-- Zig needs a subcommand, so use the wrapper instead of `CC = "zig cc"`.
local zig_cc_wrapper = vim.fs.joinpath(vim.fn.stdpath("config"), "bin", "zig-cc.cmd")
if vim.fn.executable("zig") == 1 and vim.fn.filereadable(zig_cc_wrapper) == 1 then
  vim.env.CC = zig_cc_wrapper
end

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
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
          local syntax_group = vim.fn.synIDattr(vim.fn.synID(vim.fn.line("."), vim.api.nvim_win_get_cursor(0)[2] + 1, 1), "name")
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
          -- JDTLS can return Windows CRLF inside snippets. Neovim already handles
          -- newlines, so remove the raw CR before Blink previews or inserts them.
          lsp = {
            transform_items = function(_, items)
              local function normalize(text)
                return type(text) == "string" and text:gsub("\r", "") or text
              end

              for _, item in ipairs(items) do
                item.insertText = normalize(item.insertText)
                item.textEditText = normalize(item.textEditText)

                if item.textEdit then
                  item.textEdit.newText = normalize(item.textEdit.newText)
                end

                for _, edit in ipairs(item.additionalTextEdits or {}) do
                  edit.newText = normalize(edit.newText)
                end
              end

              return items
            end,
          },
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

  -- 7. Treesitter for syntax highlighting + text objects (e.g. ]m next method, vif select function body)
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    dependencies = { "nvim-treesitter/nvim-treesitter-textobjects" },
    config = function()
      require("nvim-treesitter.install").prefer_git = true
      local ok, configs = pcall(require, "nvim-treesitter.configs")
      if ok then
        configs.setup({
          ensure_installed = { "java", "lua", "vim", "javascript", "python" },
          highlight = { enable = true },
          textobjects = {
            select = {
              enable = true,
              lookahead = true, -- jump forward to textobj automatically
              keymaps = {
                ["af"] = "@function.outer", -- around function
                ["if"] = "@function.inner", -- inside function
                ["ac"] = "@class.outer",    -- around class
                ["ic"] = "@class.inner",    -- inside class
                ["aa"] = "@parameter.outer",-- around argument
                ["ia"] = "@parameter.inner",-- inside argument
              },
            },
            move = {
              enable = true,
              set_jumps = true,
              goto_next_start = {
                ["]m"] = "@function.outer", -- next method start
                ["]]"] = "@class.outer",
              },
              goto_next_end = {
                ["]M"] = "@function.outer", -- next method end
                ["]["] = "@class.outer",
              },
              goto_previous_start = {
                ["[m"] = "@function.outer", -- prev method start
                ["[["] = "@class.outer",
              },
              goto_previous_end = {
                ["[M"] = "@function.outer",
                ["[]"] = "@class.outer",
              },
            },
            swap = {
              enable = true,
              swap_next     = { ["<leader>sn"] = "@parameter.inner" },
              swap_previous = { ["<leader>sp"] = "@parameter.inner" },
            },
          },
        })
      end
    end,
  },

  -- 8. Keymap popup guide (press <leader> and wait to see all your keymaps)
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      delay = 500, -- ms before popup appears
    },
  },

  -- 9. Comment lines with gcc (normal) or gc (visual)
  {
    "numToStr/Comment.nvim",
    event = "BufReadPost",
    opts = {},
  },

  -- 10. Highlight TODO, FIXME, HACK, NOTE, WARN, PERF in comments
  {
    "folke/todo-comments.nvim",
    event = "BufReadPost",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
    keys = {
      { "<leader>ft", "<cmd>TodoTelescope<cr>", desc = "Find TODOs" },
    },
  },

  -- 11. Subtle LSP progress spinner (shows when LSP is indexing)
  {
    "j-hui/fidget.nvim",
    event = "LspAttach",
    opts = {
      notification = {
        window = { winblend = 0 }, -- match transparent background
      },
    },
  },

  -- 12. nvim-jdtls: enhances jdtls with Java-only features not in generic LSP
  --     (organize imports, refactoring, code generation, test runner, DAP bridge)
  {
    "mfussenegger/nvim-jdtls",
    ft = "java", -- only loads when a .java file is opened
  },

  -- 13. DAP core — debug adapter protocol client
  {
    "mfussenegger/nvim-dap",
    ft = "java",
  },

  -- 14. DAP UI — visual debugger panels (variables, breakpoints, call stack, etc.)
  {
    "rcarriga/nvim-dap-ui",
    ft = "java",
    dependencies = {
      "mfussenegger/nvim-dap",
      "nvim-neotest/nvim-nio", -- async I/O library required by dap-ui
    },
    config = function()
      local dap, dapui = require("dap"), require("dapui")
      dapui.setup()
      -- Auto-open/close the UI when a debug session starts or ends
      dap.listeners.after.event_initialized["dapui_config"] = dapui.open
      dap.listeners.before.event_terminated["dapui_config"] = dapui.close
      dap.listeners.before.event_exited["dapui_config"] = dapui.close
    end,
  },

  -- 15. Show variable values inline next to their declarations during debug
  {
    "theHamsta/nvim-dap-virtual-text",
    ft = "java",
    dependencies = { "mfussenegger/nvim-dap", "nvim-treesitter/nvim-treesitter" },
    opts = {},
  },

  -- 16. Competitive programming helper (Codeforces, LeetCode, AtCoder via Competitive Companion)
  {
    "xeluxee/competitest.nvim",
    dependencies = "muniftanjim/nui.nvim",
    cmd = { "CompetiTest" },
    keys = {
      { "<leader>cr", "<cmd>CompetiTest run<cr>", desc = "Run competitive testcases" },
      { "<leader>cp", "<cmd>CompetiTest receive problem<cr>", desc = "Receive problem (Competitive Companion)" },
      { "<leader>cc", "<cmd>CompetiTest receive contest<cr>", desc = "Receive contest (Competitive Companion)" },
      { "<leader>ca", "<cmd>CompetiTest add_testcase<cr>", desc = "Add testcase" },
      { "<leader>ce", "<cmd>CompetiTest edit_testcase<cr>", desc = "Edit testcase" },
      { "<leader>cd", "<cmd>CompetiTest delete_testcase<cr>", desc = "Delete testcase" },
    },
    opts = {
      received_files_extension = "java",
      evaluate_template_modifiers = true,
      template_file = {
        java = vim.fs.joinpath(vim.fn.stdpath("config"), "templates", "template.java"),
      },

      -- ── Path layout: CP_ROOT / ContestID / ProblemLetter / Main.java ────────
      -- Each problem lives in its own subfolder so:
      --   • public class Main matches the filename Main.java  → no JDTLS red squiggle
      --   • JDTLS uses the problem folder as root             → no package mismatch
      --   • Codeforces sees "public class Main"               → submission accepted
      --
      -- HARDCODED: always goes to E:\CodeForces regardless of where nvim was opened.
      received_problems_path = function(task, file_extension)
        local cp_root = "E:/CodeForces"
        local url = task.url or ""
        local contest_id, prob_letter = url:match("/problemset/problem/(%d+)/([%w]+)")
        if not contest_id then
          contest_id, prob_letter = url:match("/contest/(%d+)/problem/([%w]+)")
        end

        local contest_dir
        if contest_id then
          contest_dir = contest_id
        elseif task.group and task.group ~= "" then
          contest_dir = task.group:gsub("Codeforces %- ", ""):gsub("[^%w_%-]", "_"):gsub("_+", "_"):gsub("^_", ""):gsub("_$", "")
        else
          contest_dir = "Practice"
        end

        local prob_letter_clean = prob_letter
          or (task.name and task.name:match("^([%w]+)%s*%."))
          or (task.name and task.name:match("^([%w]+)"))
          or "A"

        -- Always creates: E:\CodeForces\1903\A\Main.java
        return string.format("%s/%s/%s/Main.%s",
          cp_root, contest_dir, prob_letter_clean, file_extension)
      end,

      -- For receiving entire contests at once
      received_contests_directory = "E:/CodeForces",
      received_contests_problems_path = function(task, file_extension)
        local url = task.url or ""
        local contest_id, prob_letter = url:match("/problemset/problem/(%d+)/([%w]+)")
        if not contest_id then
          contest_id, prob_letter = url:match("/contest/(%d+)/problem/([%w]+)")
        end
        local prob = prob_letter
          or (task.name and task.name:match("^([%w]+)%s*%."))
          or (task.name and task.name:match("^([%w]+)"))
          or "A"
        -- Creates: ContestID/ProblemLetter/Main.java inside received_contests_directory
        local contest_dir = contest_id or "Contest"
        return string.format("%s/%s/Main.%s", contest_dir, prob, file_extension)
      end,

      testcases_use_single_file = true,
      testcases_single_file_format = "$(FNOEXT).testcases",
      runner_ui = { interface = "split" },
      compile_command = {
        java = { exec = "javac", args = { "$(FNAME)" } },
        c    = { exec = "gcc",   args = { "-Wall", "$(FNAME)", "-o", "$(FNOEXT).exe" } },
        cpp  = { exec = "g++",   args = { "-Wall", "$(FNAME)", "-o", "$(FNOEXT).exe" } },
      },
      run_command = {
        java   = { exec = "java",   args = { "Main" } },
        c      = { exec = "./$(FNOEXT).exe" },
        cpp    = { exec = "./$(FNOEXT).exe" },
        python = { exec = "python", args = { "$(FNAME)" } },
      },
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
opt.wrap = true
opt.linebreak = true
opt.breakindent = true    -- wrapped lines continue at the same indent level
opt.confirm = true
opt.inccommand = "split"  -- live preview of :s/find/replace in a split

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

-- Neutral VS Code-inspired theme. Falls back to habamax on a fresh install.
local ok_cs = pcall(vim.cmd.colorscheme, "vscode_black")
if not ok_cs then
  vim.cmd.colorscheme("habamax")
end

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
-- jdtls is managed by nvim-jdtls via the FileType java autocmd at the bottom of this file.
-- The java21 / jdtls_home / jdtls_launcher variables defined above are used there.

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

-- Lua LSP: gives autocompletion and type-checking inside this very file.
-- Install lua-language-server from: https://github.com/LuaLS/lua-language-server/releases
-- or: winget install LuaLS.lua-language-server
vim.lsp.config("lua_ls", {
  cmd = { "lua-language-server" },
  filetypes = { "lua" },
  root_markers = { ".luarc.json", ".luarc.jsonc", ".git" },
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      workspace = {
        -- Make lua_ls aware of Neovim's built-in globals (vim.*, etc.)
        library = vim.api.nvim_get_runtime_file("", true),
        checkThirdParty = false,
      },
      completion = { callSnippet = "Replace" },
      telemetry = { enable = false },
    },
  },
})

vim.lsp.enable({
  "typescript",
  "pyright",
  "json",
  "html",
  "css",
  "eslint",
  "clangd",
  -- jdtls is intentionally omitted — nvim-jdtls handles it via FileType java
  "lua_ls",
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

-- Make Neovim's background transparent so any terminal's background shows through.
-- This is applied once at startup and re-applied after every :colorscheme change,
-- because colorscheme files and plugins can re-add backgrounds at any time.
local function transparent_background()
  local groups = {
    "Normal", "NormalNC",        -- main editor panes
    "NormalFloat", "FloatBorder",-- hover docs, diagnostics, blink.cmp float
    "SignColumn",                -- gutter (git signs, diagnostics icons)
    "EndOfBuffer",               -- the ~ lines below file content
    "StatusLine", "StatusLineNC",-- status bar (lualine draws over this, but just in case)
    "TabLine", "TabLineFill",    -- buffer/tab bar
  }
  for _, group in ipairs(groups) do
    vim.api.nvim_set_hl(0, group, { bg = "none" })
  end
end

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    transparent_background()
    diagnostic_colours()
  end,
})

-- Per-filetype formatter preference.
-- Maps filetype → LSP server name to use exclusively for formatting.
-- Any filetype NOT listed here uses whatever server is attached (first one wins).
local format_server = {
  java = "jdtls",
}

-- Helper: format using a specific server if one is configured, else use all.
local function smart_format(bufnr, opts)
  opts = opts or {}
  opts.bufnr = bufnr or 0
  local ft = vim.bo[opts.bufnr].filetype
  local preferred = format_server[ft]
  if preferred then
    opts.filter = function(client) return client.name == preferred end
  end
  vim.lsp.buf.format(opts)
end

-- Format current buffer with <leader>f
vim.keymap.set("n", "<leader>f", function()
  smart_format(0, { async = true })
end, { desc = "Format current buffer with LSP" })

-- Format on save: all languages whose LSP server supports it.
local format_on_save_filetypes = {
  css = true,
  html = true,
  java = true,
  javascript = true,
  javascriptreact = true,
  json = true,
  jsonc = true,
  typescript = true,
  typescriptreact = true,
}

vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function(args)
    -- Prevent raw carriage returns from malformed Windows LSP snippets being saved.
    if vim.bo[args.buf].filetype == "java" then
      local lines = vim.api.nvim_buf_get_lines(args.buf, 0, -1, false)
      local changed = false
      for index, line in ipairs(lines) do
        local normalized, count = line:gsub("\r", "")
        if count > 0 then
          lines[index] = normalized
          changed = true
        end
      end
      if changed then
        vim.api.nvim_buf_set_lines(args.buf, 0, -1, false, lines)
      end
    end

    if format_on_save_filetypes[vim.bo[args.buf].filetype] then
      smart_format(args.buf, { timeout_ms = 2000 })
    end
  end,
})

-- Toggle warning virtual text and underlines on demand with Space + t + w
local show_warnings = false

vim.keymap.set("n", "<leader>tw", function()
  show_warnings = not show_warnings

  vim.diagnostic.config({
    virtual_text = show_warnings and {
      severity = { min = vim.diagnostic.severity.WARN }, -- WARN + ERROR only
      spacing = 2,
      prefix = "●",
      source = "if_many",
    } or {
      severity = { min = vim.diagnostic.severity.ERROR },
      spacing = 2,
      prefix = "●",
      source = "if_many",
    },
    underline = show_warnings and {
      severity = { min = vim.diagnostic.severity.WARN },
    } or {
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
    local buf = args.buf
    local jdtls = require("jdtls")

    -- ── Workspace (per-project, so different projects don't share state) ───
    -- For Gradle/Maven/Git projects, use the project root.
    -- For standalone CP files (no build system markers), use the FILE'S OWN FOLDER
    -- so JDTLS treats it as a default-package root — no "package mismatch" errors!
    local root = vim.fs.root(buf, {
      "mvnw", "gradlew", "pom.xml",
      "build.gradle", "build.gradle.kts",
      "settings.gradle", "settings.gradle.kts",
    }) or vim.fn.expand("%:p:h")   -- ← file's own dir, NOT getcwd()

    local workspace = vim.fs.joinpath(
      vim.fn.stdpath("data"),
      "jdtls-workspaces",
      vim.fn.sha256(root):sub(1, 16)
    )
    vim.fn.mkdir(workspace, "p")

    -- ── Optional extension bundles ─────────────────────────────────────────
    -- java-debug: enables DAP debugging via nvim-dap
    --   Download: https://github.com/microsoft/java-debug/releases
    --   Extract to: %LOCALAPPDATA%\nvim-tools\java-debug\
    local bundles = {}
    local debug_jar = vim.fn.glob(
      vim.fs.joinpath(nvim_tools, "java-debug", "server",
        "com.microsoft.java.debug.plugin-*.jar"), true)
    if debug_jar ~= "" then
      vim.list_extend(bundles, { debug_jar })
    end

    -- java-test: enables running JUnit tests from Neovim
    --   Download: https://github.com/microsoft/vscode-java-test/releases
    --   Extract to: %LOCALAPPDATA%\nvim-tools\java-test\
    local test_jars = vim.split(
      vim.fn.glob(vim.fs.joinpath(nvim_tools, "java-test", "extension", "server", "*.jar"), true),
      "\n", { trimempty = true })
    vim.list_extend(bundles, test_jars)

    -- ── Lombok support ─────────────────────────────────────────────────────
    -- Lombok annotations (@Getter, @Builder, etc.) need the agent at startup.
    --   Download lombok.jar from: https://projectlombok.org/download
    --   Place at: %LOCALAPPDATA%\nvim-tools\lombok\lombok.jar
    local lombok_jar = vim.fs.joinpath(nvim_tools, "lombok", "lombok.jar")
    local lombok_arg = vim.uv.fs_stat(lombok_jar)
        and ("-javaagent:" .. lombok_jar)
        or nil

    -- ── Build the jdtls cmd ────────────────────────────────────────────────
    -- Note: JDTLS itself requires Java 17+ (we use Java 21) to launch the server.
    local cmd = {
      java21,
      "-Declipse.application=org.eclipse.jdt.ls.core.id1",
      "-Dosgi.bundles.defaultStartLevel=4",
      "-Declipse.product=org.eclipse.jdt.ls.core.product",
      "-Dlog.protocol=true",
      "-Dlog.level=ALL",
      "-Xmx1g",
      "--add-modules=ALL-SYSTEM",
      "--add-opens", "java.base/java.util=ALL-UNNAMED",
      "--add-opens", "java.base/java.lang=ALL-UNNAMED",
      "-jar", jdtls_launcher,
      "-configuration", vim.fs.joinpath(jdtls_home, "config_win"),
      "-data", workspace,
    }
    if lombok_arg then
      table.insert(cmd, 2, lombok_arg) -- insert after java21
    end

    -- ── Start (or re-attach to) jdtls ─────────────────────────────────────
    jdtls.start_or_attach({
      cmd = cmd,
      root_dir = root,
      settings = {
        java = {
          signatureHelp = { enabled = true },
          contentProvider = { preferred = "fernflower" }, -- decompiler
          completion = {
            favoriteStaticMembers = {
              "org.junit.Assert.*",
              "org.junit.Assume.*",
              "org.junit.jupiter.api.Assertions.*",
              "org.junit.jupiter.api.Assumptions.*",
              "org.junit.jupiter.api.DynamicContainer.*",
              "org.junit.jupiter.api.DynamicTest.*",
            },
            importOrder = { "java", "javax", "com", "org" },
          },
          sources = {
            organizeImports = {
              starThreshold = 9999,
              staticStarThreshold = 9999,
            },
          },
          codeGeneration = {
            toString = { template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}" },
            useBlocks = true,
          },
          format = { enabled = true },
        },
      },
      init_options = {
        bundles = bundles,
      },
      capabilities = (function()
        local ok_b, b = pcall(require, "blink.cmp")
        return ok_b and b.get_lsp_capabilities() or vim.lsp.protocol.make_client_capabilities()
      end)(),
      on_attach = function(client, bufnr)
        -- Enable DAP if java-debug bundle was loaded
        if #bundles > 0 then
          jdtls.setup_dap({ hotcodereplace = "auto" })
        end

        local function map(lhs, rhs, desc)
          vim.keymap.set("n", lhs, rhs, { buffer = bufnr, desc = desc })
        end
        local function vmap(lhs, rhs, desc)
          vim.keymap.set("v", lhs, rhs, { buffer = bufnr, desc = desc })
        end

        -- ── Java-only LSP keymaps ──────────────────────────────────────────
        map("<leader>oi", jdtls.organize_imports,          "Organize imports")
        map("<leader>tc", jdtls.test_class,                "Run test class")
        map("<leader>tm", jdtls.test_nearest_method,       "Run nearest test method")

        -- Refactoring
        map("<leader>rv", jdtls.extract_variable,          "Extract variable")
        map("<leader>rm", jdtls.extract_method,            "Extract method")
        map("<leader>rc", jdtls.extract_constant,          "Extract constant")
        vmap("<leader>rv", function() jdtls.extract_variable(true) end, "Extract variable (selection)")
        vmap("<leader>rm", function() jdtls.extract_method(true) end,   "Extract method (selection)")

        -- Code generation (via code actions — opens a picker)
        map("<leader>jg", function()
          vim.lsp.buf.code_action({
            context = { only = { "source" }, diagnostics = {} },
          })
        end, "Generate code (toString/hashCode/getters…)")

        -- ── DAP debugging keymaps ──────────────────────────────────────────
        local dap_ok, dap = pcall(require, "dap")
        if dap_ok then
          map("<F9>",  dap.toggle_breakpoint,  "Toggle breakpoint")
          map("<F10>", dap.step_over,          "Step over")
          map("<F11>", dap.step_into,          "Step into")
          map("<F12>", dap.step_out,           "Step out")
          map("<F8>",  dap.continue,           "Continue / Start debugger")
          map("<leader>db", dap.toggle_breakpoint, "Toggle breakpoint")
          map("<leader>dc", dap.continue,          "Continue debug")
          map("<leader>dx", dap.terminate,         "Terminate debug session")
          map("<leader>dr", function() dap.repl.open() end, "Open debug REPL")
          map("<leader>du", function()
            local dapui_ok, dapui = pcall(require, "dapui")
            if dapui_ok then dapui.toggle() end
          end, "Toggle debug UI")
        end

        -- ── Gradle task picker ────────────────────────────────────────────
        map("<leader>jt", function()
          local project_root, marker = find_java_project_root()
          if not project_root then
            vim.notify("No Gradle/Maven project found", vim.log.levels.WARN)
            return
          end

          local is_gradle = marker and marker:find("gradle")
          local tasks_cmd
          if is_gradle then
            tasks_cmd = marker == "gradlew.bat"
                and "gradlew.bat tasks --all"
                or  "./gradlew tasks --all"
          else
            tasks_cmd = "mvn help:describe -Dcmd=process-test-resources 2>/dev/null; mvn help:all-profiles"
          end

          -- Capture task list and let Telescope pick from them
          local output = vim.fn.systemlist(tasks_cmd, nil, 1)
          local tasks = {}
          for _, line in ipairs(output) do
            local task = line:match("^([%w:%-]+)%s%-")
            if task then table.insert(tasks, task) end
          end

          if #tasks == 0 then
            vim.notify("No tasks found (run `:!gradlew tasks` manually)", vim.log.levels.WARN)
            return
          end

          vim.ui.select(tasks, { prompt = "Gradle task:" }, function(choice)
            if choice then
              local run_cmd = (marker == "gradlew.bat" and "gradlew.bat " or "./gradlew ") .. choice
              open_terminal_split(run_cmd, project_root)
            end
          end)
        end, "Pick and run Gradle/Maven task")
      end,
    })

    -- ── Run / F5 (kept from original config) ──────────────────────────────
    vim.keymap.set("n", "<leader>r", run_java_file, { buffer = buf, desc = "Run Java application" })
    vim.keymap.set("n", "<F5>",      run_java_file, { buffer = buf, desc = "Run Java application" })
  end,
})
