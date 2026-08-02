vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end

vim.g.colors_name = "vscode_black"

local colors = {
  bg = "#0f1113",
  bg_alt = "#17191c",
  bg_cursor = "#202328",
  bg_visual = "#34383e",
  fg = "#d4d4d4",
  bright = "#f0f0f0",
  muted = "#6f737a",
  comment = "#697078",
  red = "#ff6b6b",
  orange = "#ff9e64",
  yellow = "#ffd700",
  green = "#8bd49c",
  cyan = "#89ddff",
  blue = "#82aaff",
  violet = "#c792ea",
  pink = "#e879d2",
}

local groups = {
  Normal = { fg = colors.fg, bg = colors.bg },
  NormalNC = { fg = colors.fg, bg = colors.bg },
  NormalFloat = { fg = colors.fg, bg = colors.bg_alt },
  FloatBorder = { fg = colors.muted, bg = colors.bg_alt },
  ColorColumn = { bg = colors.bg_alt },
  Cursor = { fg = colors.bg, bg = colors.bright },
  CursorLine = { bg = colors.bg_cursor },
  CursorColumn = { bg = colors.bg_cursor },
  LineNr = { fg = colors.muted },
  CursorLineNr = { fg = colors.bright, bold = true },
  SignColumn = { fg = colors.muted, bg = colors.bg },
  EndOfBuffer = { fg = colors.bg },
  Visual = { bg = colors.bg_visual },
  Search = { fg = colors.bg, bg = colors.yellow },
  IncSearch = { fg = colors.bg, bg = colors.orange },
  MatchParen = { fg = colors.yellow, bold = true },
  Pmenu = { fg = colors.fg, bg = colors.bg_alt },
  PmenuSel = { fg = colors.bright, bg = colors.bg_visual, bold = true },
  StatusLine = { fg = colors.fg, bg = colors.bg_cursor },
  StatusLineNC = { fg = colors.muted, bg = colors.bg_alt },
  WinSeparator = { fg = colors.bg_visual },
  VertSplit = { fg = colors.bg_visual },
  Folded = { fg = colors.muted, bg = colors.bg_alt },
  Title = { fg = colors.blue, bold = true },
  Directory = { fg = colors.blue },

  Comment = { fg = colors.comment, italic = true },
  Constant = { fg = colors.orange },
  String = { fg = colors.blue },
  Character = { fg = colors.blue },
  Number = { fg = colors.orange },
  Boolean = { fg = colors.orange, bold = true },
  Float = { fg = colors.orange },
  Identifier = { fg = colors.fg },
  Function = { fg = colors.violet },
  Statement = { fg = colors.pink },
  Conditional = { fg = colors.pink },
  Repeat = { fg = colors.pink },
  Label = { fg = colors.blue },
  Operator = { fg = colors.red },
  Keyword = { fg = colors.pink },
  Exception = { fg = colors.red },
  PreProc = { fg = colors.pink },
  Include = { fg = colors.pink },
  Define = { fg = colors.pink },
  Macro = { fg = colors.yellow },
  Type = { fg = colors.yellow },
  StorageClass = { fg = colors.red },
  Structure = { fg = colors.yellow },
  Typedef = { fg = colors.yellow },
  Special = { fg = colors.cyan },
  SpecialChar = { fg = colors.cyan },
  Tag = { fg = colors.red },
  Delimiter = { fg = colors.fg },
  Underlined = { fg = colors.blue, underline = true },
  Error = { fg = colors.red, bold = true },
  Todo = { fg = colors.bg, bg = colors.yellow, bold = true },

  DiagnosticError = { fg = colors.red },
  DiagnosticWarn = { fg = colors.yellow },
  DiagnosticInfo = { fg = colors.blue },
  DiagnosticHint = { fg = colors.cyan },
  DiffAdd = { fg = colors.green, bg = "#15251a" },
  DiffChange = { fg = colors.blue, bg = "#18212d" },
  DiffDelete = { fg = colors.red, bg = "#2a1719" },
  DiffText = { fg = colors.bright, bg = "#24344a" },
  GitSignsAdd = { fg = colors.green },
  GitSignsChange = { fg = colors.blue },
  GitSignsDelete = { fg = colors.red },

  ["@comment"] = { link = "Comment" },
  ["@string"] = { link = "String" },
  ["@number"] = { link = "Number" },
  ["@boolean"] = { link = "Boolean" },
  ["@variable"] = { fg = colors.fg },
  ["@variable.builtin"] = { fg = colors.cyan, italic = true },
  ["@property"] = { fg = colors.orange },
  ["@function"] = { fg = colors.violet },
  ["@function.call"] = { fg = colors.violet },
  ["@constructor"] = { fg = colors.yellow },
  ["@keyword"] = { fg = colors.pink },
  ["@keyword.function"] = { fg = colors.red },
  ["@keyword.return"] = { fg = colors.pink },
  ["@operator"] = { fg = colors.red },
  ["@type"] = { fg = colors.yellow },
  ["@tag"] = { fg = colors.red },
  ["@tag.attribute"] = { fg = colors.orange },
  ["@punctuation.bracket"] = { fg = colors.yellow },
  ["@punctuation.delimiter"] = { fg = colors.fg },
}

for group, spec in pairs(groups) do
  vim.api.nvim_set_hl(0, group, spec)
end

vim.g.terminal_color_0 = colors.bg_alt
vim.g.terminal_color_1 = colors.red
vim.g.terminal_color_2 = colors.green
vim.g.terminal_color_3 = colors.yellow
vim.g.terminal_color_4 = colors.blue
vim.g.terminal_color_5 = colors.violet
vim.g.terminal_color_6 = colors.cyan
vim.g.terminal_color_7 = colors.fg
vim.g.terminal_color_8 = colors.muted
vim.g.terminal_color_9 = "#ff8585"
vim.g.terminal_color_10 = "#a7e3b5"
vim.g.terminal_color_11 = "#ffe45c"
vim.g.terminal_color_12 = "#a5c2ff"
vim.g.terminal_color_13 = "#dfa8ff"
vim.g.terminal_color_14 = "#b2ebff"
vim.g.terminal_color_15 = colors.bright
