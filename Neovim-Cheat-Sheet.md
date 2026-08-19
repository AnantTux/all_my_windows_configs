# My Neovim Cheat Sheet

This is the quick reference for my current Neovim setup on Windows.

## The basics

- **Leader key:** `Space`
- **Normal mode:** press `Esc` to leave Insert mode.
- **Command mode:** type `:` in Normal mode, then enter a command such as `:w` (save) or `:q` (quit).
- **All standard Vim motions and commands still work.** This sheet focuses on my custom shortcuts and the extra features I installed.

## Finding files and text

| Shortcut | What it does |
| --- | --- |
| `Space f f` | Find files in the current project. |
| `Space f g` | Search text in the current project. Requires `rg`/ripgrep, which is installed. |
| `Space f b` | Switch to an open buffer (an open file in Neovim). |
| `Space f r` | Open a recently used file. |
| `-` | Open the parent folder in Oil, Neovim's file browser. |

## Code navigation and editing

These work in a file after its language server has attached.

| Shortcut | What it does |
| --- | --- |
| `g d` | Go to the definition of the symbol under the cursor. |
| `g r` | Find references to the symbol under the cursor. |
| `K` | Show documentation for the symbol under the cursor. |
| `Space r n` | Rename the symbol under the cursor across the project. |
| `Space c a` | Show available code actions/fixes. |
| `Space f` | Format the current file with its language server. |

## Diagnostics: errors and warnings

| Shortcut | What it does |
| --- | --- |
| `] d` | Go to the next diagnostic. |
| `[ d` | Go to the previous diagnostic. |
| `Space d` | Show the full diagnostic message under the cursor. |
| `Space q` | Put all diagnostics in the location list. |
| `Space t w` | Toggle warning details inline. Errors remain visible by default. |
| `Esc` | Clear search highlighting. |

## Java: run code quickly

These shortcuts are available **only in Java files**.

| Shortcut | What it does |
| --- | --- |
| `Space r` | Save, compile, and run the Java application in a bottom terminal split. |
| `F5` | Same as `Space r`. |

### How Java running works

1. In a simple practice folder, it compiles every `*.java` file in that folder, so classes can import and use each other.
2. Keep the file containing `public static void main(String[] args)` open when running it.
3. If Neovim finds a Gradle project, it runs `gradlew.bat run` (or `./gradlew run`).
4. If it finds a Maven project, it runs `mvnw.cmd exec:java`, `./mvnw exec:java`, or `mvn exec:java`.
5. Gradle/Maven projects need their normal `run` or `exec:java` setup, including a configured main class where required.

## Git changes

Git signs appear in the left gutter for changed, added, and removed lines. These shortcuts work in Git-tracked files.

| Shortcut | What it does |
| --- | --- |
| `Space g p` | Preview the current changed block (hunk). |
| `Space g s` | Stage the current changed block. |
| `Space g r` | Reset the current changed block. |

## Completion, snippets, and pairs

- Completion uses **blink.cmp** with suggestions from language servers, file paths, snippets, and words in open buffers.
- Completion is disabled inside real comments, so it will not distract while writing comments.
- Path completion is suppressed for normal slash/comment patterns, but works in quoted paths and explicit path prefixes such as `./`, `../`, and `~/`.
- **nvim-autopairs** automatically closes brackets, parentheses, quotes, and similar pairs while typing.
- **friendly-snippets** provides reusable completion snippets.
- Blink uses its built-in default key preset. Open the completion menu and use the prompts shown there if you need to move through or confirm suggestions.

## Formatting on save

- Java files format automatically when saved.
- JavaScript, TypeScript, JSON, HTML, and CSS format automatically when their configured language server supports formatting.
- `Space f` manually formats the current buffer.

## Tree-sitter and highlighting

- Tree-sitter provides accurate syntax highlighting and comment detection.
- Parsers are configured for: **Java, Lua, Vim script, JavaScript, and Python**.
- Check parser health with `:checkhealth nvim-treesitter`.
- Check the syntax node under the cursor with `:InspectTree`.
- The Java parser is installed and working.
- A Zig compiler wrapper is configured so Tree-sitter parsers can build on this Windows setup without the Windows SDK.

## Installed plugins and what they do

| Plugin | Purpose |
| --- | --- |
| `lazy.nvim` | Downloads, updates, and loads plugins. Use `:Lazy` to view plugin status. |
| `nvim-autopairs` | Automatically inserts matching brackets and quotes. |
| `oil.nvim` | File browser that opens with `-`. |
| `gitsigns.nvim` | Git change markers and hunk actions. |
| `telescope.nvim` | File, text, buffer, and recent-file search. |
| `plenary.nvim` | Dependency used by Telescope. |
| `lualine.nvim` | Status line showing the file, diagnostics, encoding, file format, and file type. |
| `nvim-web-devicons` | File-type icons used by the status line and other plugins. |
| `blink.cmp` | Completion menu and language-server suggestions. |
| `friendly-snippets` | Snippets for completion. |
| `nvim-treesitter` | Syntax highlighting, parser-based features, and comment detection. |

## Configured language servers

| Language / files | Language server |
| --- | --- |
| Java | JDTLS |
| JavaScript and TypeScript | TypeScript Language Server |
| Python | Pyright |
| JSON / JSONC | VS Code JSON Language Server |
| HTML | VS Code HTML Language Server |
| CSS / SCSS / Less | VS Code CSS Language Server |
| JavaScript / TypeScript linting | ESLint Language Server |
| C / C++ / CUDA | clangd |

## Useful built-in commands

| Command | What it does |
| --- | --- |
| `:w` | Save the current file. |
| `:q` | Quit the current window. |
| `:wq` | Save and quit. |
| `:e filename` | Open a file. |
| `:Oil` | Open the current folder in Oil. |
| `:Lazy` | View, install, update, or troubleshoot plugins. |
| `:TSInstall java` | Install/reinstall the Java Tree-sitter parser. |
| `:checkhealth` | Run Neovim health checks. |
| `:checkhealth nvim-treesitter` | Check Tree-sitter specifically. |
| `:InspectTree` | Show the Tree-sitter node beneath the cursor. |

## Everyday workflow

1. Open a project: `Space f f`.
2. Search for text: `Space f g`.
3. Jump to code: `g d`, then return with standard Vim navigation.
4. Rename safely: `Space r n`.
5. Fix or format: `Space c a` or `Space f`.
6. Run Java: `Space r` or `F5` in a Java file.
7. Review changes: `Space g p`.

