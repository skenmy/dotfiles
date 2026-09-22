# Editors & terminal

*Reviewed against `1e30dcf` + `feat/zed-everywhere`, 2026-09-22.* Files: `dot_config/nvim/**`, `dot_config/ghostty/config`,
`.chezmoitemplates/zed-settings.json` (rendered to `~/.config/zed/settings.json` and, on Windows, `~/AppData/Roaming/Zed/settings.json`).

## Neovim

Kickstart-style lazy.nvim config. **Requires Neovim 0.11+**: `lsp.lua` uses `vim.lsp.config()` and
mason-lspconfig v2's auto-enable, and `treesitter.lua` targets nvim-treesitter's `main` branch. Distro
packages older than that fail on start ([G-02](../gaps.md#g-02)).

**Options** (`lua/options.lua`): line numbers + relative, cursorline, sign column always, `scrolloff`
8, no wrap, truecolor, dark background, 4-space soft tabs with smart indent, `ignorecase` + `smartcase`,
no `hlsearch`, splits open right/below, persistent undo, no swap or backup, `updatetime` 50, `timeoutlen`
300, mouse on, system clipboard (`unnamedplus`), confirm on quit, visible whitespace (`»`, `·`, `␣`).

**Keymaps** (`lua/keymaps.lua`, leader = Space):

| Keys | Action |
|---|---|
| `<Esc>` | clear search highlight |
| `<leader>w` / `<leader>q` | save / quit |
| `<C-h>` `<C-l>` | window left / right |
| `<C-j>` `<C-k>` | defined twice: window down/up **and** quickfix next/prev. The quickfix mapping wins ([G-13](../gaps.md#g-13)) |
| `J` / `K` (visual) | move selection down / up |
| `<C-d>` `<C-u>` `n` `N` | keep cursor centred |
| `<leader>p` (visual) | paste without yanking |
| `<leader>y` / `<leader>Y` | yank to system clipboard |
| `<S-h>` / `<S-l>` | previous / next buffer |
| `<leader>ff` `fg` `fb` `fh` `fr` `/` | Telescope files, live grep, buffers, help, resume, in-buffer |
| `<leader>e` | nvim-tree toggle |
| `<leader>gg` | LazyGit |
| `gd` `gr` `K` `<leader>rn` `<leader>ca` `<leader>fm` | LSP definition, references, hover, rename, code action, format |
| `<C-Space>` `<CR>` `<Tab>` `<S-Tab>` (insert) | completion open, confirm, next, previous |

Colourscheme tokyonight *night*; lualine themed to match. Plugins, LSP servers and parsers:
[generated Neovim page](../generated/nvim.md).

## Ghostty (macOS desktop only)

| Setting | Value |
|---|---|
| `font-family` / `font-size` / `font-thicken` | JetBrainsMono Nerd Font / 14 / true |
| `theme` | Catppuccin Mocha, opacity 1.0 |
| Window | 10 px padding balanced, `window-save-state = always`, unfocused split opacity 0.7 |
| Cursor | block, no blink |
| `copy-on-select` | `clipboard` |
| `clipboard-paste-protection` | true |
| `mouse-hide-while-typing` | true |
| `scrollback-limit` | 10,000,000 |
| `macos-option-as-alt` | true |
| `macos-titlebar-style` | tabs |
| Keybinds | `cmd+h/j/k/l` → goto split (overrides macOS Hide), `cmd+enter` → fullscreen |

Shell integration left at Ghostty's auto-detect defaults.

## Zed (every desktop profile)

Zed replaced VS Code as the GUI editor on 2026-09-22. One template, `.chezmoitemplates/zed-settings.json`,
renders to `~/.config/zed/settings.json` on macOS and Linux and to `~/AppData/Roaming/Zed/settings.json`
on Windows. Skipped on `headless` (Zed needs a GPU). Installed by the `gui.Brewfile` cask, the
`ZedIndustries.Zed` winget package, and `zed.dev/install.sh` on Linux desktops.

| Setting | Value |
|---|---|
| `base_keymap` | `VSCode` |
| `theme` | dark mode, Ayu Dark / Ayu Light |
| `icon_theme` | Colored Zed Icons Theme Dark (from the extension below) |
| `ui_font_size` / `buffer_font_size` / `buffer_font_family` | 16 / 15 / JetBrainsMono Nerd Font |
| `autosave` / `format_on_save` | `on_focus_change` / `on` |
| `cli_default_open_behavior` | `existing_window` |
| `minimap.show` | `always` |
| `session.trust_all_worktrees` | `true` |
| Panels | project, outline, collaboration and git docked right; agent docked left |
| `agent_servers` | `claude-acp` from the registry |
| `auto_install_extensions` | Zed installs these itself on launch: [generated list](../generated/zed-extensions.md) |

There is no separate extension installer script any more; add a line to `auto_install_extensions` and
push. `EDITOR`/`VISUAL` stay `nvim` for terminal use; `git config core.editor` too.
