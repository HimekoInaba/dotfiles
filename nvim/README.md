# Neovim for IntelliJ users

Leader is `Space`, local leader is `\`. Press `Space` and wait: which-key lists every group.
`Space ?` lists the keys of the current buffer, `Space s k` searches all keymaps.

Option/Alt and Cmd do not reach Neovim in iTerm2 (Option sends normal characters, Cmd belongs to iTerm),
so IntelliJ's Cmd/Option shortcuts became `Space` mnemonics or Ctrl keys.

The previous setup is saved in `~/.config/nvim-backup-2026-10-02/` (see its `README.txt`) and `~/.config/nvim.bak/`.

## IntelliJ action to Neovim key

### Search and navigation

| IntelliJ action | IntelliJ mac key | Neovim key |
|---|---|---|
| Search Everywhere | Double Shift | `Space Space` |
| Go to File | Cmd+Shift+O | `Space f f` |
| Go to Class | Cmd+O | `Space f c` |
| Go to Symbol | Cmd+Option+O | `Space f s` |
| Find Action | Cmd+Shift+A | `Space f a` (this config's actions by name, `Enter` runs one; Ex commands: `Space s C`) |
| Recent Files | Cmd+E | `Space f r` |
| Switcher (open tabs) | Ctrl+Tab | `Space ,` or `Space f b` (the previous file is preselected, `Enter` switches to it) |
| Recent Locations | Cmd+Shift+E | `Space f j` |
| Go to Test | Cmd+Shift+T | `Space f t` (finds `*Test` and `*Spec`) |
| Find in Files | Cmd+Shift+F | `Space /` or `Space f g` |
| Find word or selection in files | Cmd+Shift+F on a selection | `Space f w` |
| Replace in Files | Cmd+Shift+R | `Space s r` (`\r` replaces all, `g?` help) |
| Find / Replace in file | Cmd+F / Cmd+R | `/text`, `:%s/old/new/gc` (live preview), fuzzy lines `Space s b` |
| Repeat last search popup | none | `Space s R` |
| File Structure | Cmd+F12 | `Space s s` (built-in list: `gO`) |
| Project tool window | Cmd+1 | `Space e` (hides it when the tree has focus) |
| Select In... (Project View) | Option+F1, then 1 | `Space E` |
| Go to Line | Cmd+L | `42G` or `:42` |
| Back / Forward | Cmd+[ / Cmd+] | `Ctrl+o` / `Ctrl+i` |
| Toggle / show bookmarks | F3 / Cmd+F3 | `mA` (capital = global mark), jump `'A`, list `Space s m` |
| Copy Path | Cmd+Shift+C | `Space f y` (absolute: `Space f Y`) |
| Help | none | `Space s h` (Neovim and plugin help pages) |

### Code

| IntelliJ action | IntelliJ mac key | Neovim key |
|---|---|---|
| Go to Declaration | Cmd+B | `gd` (also `Ctrl+]`; the LSP "declaration" request: `gD`) |
| Go to Implementation | Cmd+Option+B | `gI` (quickfix flavour: `gri`; see Known limitations) |
| Go to Type Declaration | Cmd+Shift+B | `gy` (quickfix flavour: `grt`) |
| Go to Super Method (Java) | Cmd+U | `gs` |
| Find Usages | Option+F7 | `Space f u` (quickfix flavour: `grr`) |
| Highlight Usages in File | Cmd+Shift+F7 | automatic, jump with `]]` / `[[` |
| Call Hierarchy | Ctrl+Option+H | `Space c h` (callees: `Space c C`) |
| Type Hierarchy | Ctrl+H | `Space c t` (supertypes: `Space c T`) |
| Quick Documentation | F1 | `K` |
| Parameter Info | Cmd+P | opens automatically, `Ctrl+k` in Insert mode |
| Basic Completion | Ctrl+Space | `Ctrl+Space` in Insert mode |
| Choose Lookup Item | Enter (Tab replaces) | `Enter` or `Tab` (both insert, the rest of the word stays) |
| Show Context Actions | Option+Enter | `Space c a` (also `gra`) |
| Generate (constructor, getters, toString) | Cmd+N | `Space c g` |
| Reformat Code | Cmd+Option+L | `Space c f` (selection in Visual mode) |
| Optimize Imports | Ctrl+Option+O | `Space c o` |
| Rename | Shift+F6 | `Space r n` (also `grn`) |
| Rename File | Shift+F6 in Project | `Space r f`, or `r` in the tree |
| Refactor This | Ctrl+T | `Space r r` |
| Extract Variable | Cmd+Option+V | `Space r v` (all occurrences), `Space r V` (this one) |
| Extract Constant | Cmd+Option+C | `Space r c` |
| Extract Method | Cmd+Option+M | select lines, `Space r m` |
| Inline | Cmd+Option+N | `Space r i` |
| Next / previous highlighted error | F2 / Shift+F2 | `]e` / `[e` (any problem `]d` / `[d`, warnings `]w` / `[w`) |
| Show error description | Cmd+F1 | `Space x d` (also `Ctrl+w d`) |
| Problems tool window | Cmd+6 | `Space x x` (current file: `Space x X`) |
| Quickfix / location list (results of `grr`, `gri`, `Ctrl+q`) | none | toggle `Space x q` / `Space x l`, search the quickfix list `Space s q` |
| Load Gradle Changes | Cmd+Shift+I | `:JdtUpdateConfig` |
| Build Project | Cmd+F9 | `:JdtCompile full` |
| Restart language server / info | none | `Space c L` / `Space c l` |

### Editing

| IntelliJ action | IntelliJ mac key | Neovim key |
|---|---|---|
| Save All | Cmd+S | `Ctrl+s` (and autosave) |
| Insert pair bracket / quote | automatic | automatic for `(` `[` `{` `"` `'` `` ` ``: the closing one is stepped over, `Backspace` deletes the pair |
| Comment with Line Comment | Cmd+/ | `Ctrl+/` (also `gcc`, `gc` on a selection) |
| Duplicate Line or Selection | Cmd+D | `Space c d` |
| Delete Line | Cmd+Backspace | `dd` |
| Move Line Up / Down | Option+Shift+Up / Down | `Shift+Up` / `Shift+Down` (lines, selections, counts) |
| Indent / Unindent selection | Tab / Shift+Tab | `Tab` / `Shift+Tab` in Visual mode (also `>` / `<`) |
| Extend / Shrink Selection | Option+Up / Option+Down | `Ctrl+Space` / `Backspace` (Visual mode also `an` / `in`) |
| Expand / Collapse | Cmd+= / Cmd+- | `zo` / `zc` (all: `zR` / `zM`) |
| Undo / Redo | Cmd+Z / Cmd+Shift+Z | `u` / `Ctrl+r` |
| Local History | VCS menu | `Space u u` (undo tree, kept across restarts; search it: `Space s u`) |
| New file | Cmd+N in Project | `Space f n` (name asked on `Ctrl+s`), or `a` in the tree |

### Git

| IntelliJ action | IntelliJ mac key | Neovim key |
|---|---|---|
| Commit tool window (changed files) | Cmd+0 / Cmd+K | `Space g s`: `Tab` stages or unstages the file, `Ctrl+r` rolls it back (asks); tree view: `Space g e`; commit with `git commit` in `Space t t` |
| Git log | Cmd+9 | `Space g l` |
| Show History for file | VCS menu | `Space g f` |
| Branches | Ctrl+V (VCS popup) | `Space g B` |
| Annotate with Git Blame | gutter menu | `Space g a` (`q` closes) |
| Blame for current line | none | `Space g b` (inline on/off: `Space u b`) |
| Next / previous change | Ctrl+Option+Shift+Down / Up | `]h` / `[h` (last / first: `]H` / `[H`) |
| Show change (gutter click) | none | `Space g p` |
| Select change | none | text object `ih`, for example `vih` or `dih` |
| Compare with index / Latest Repository Version | Cmd+D | `Space g d` / `Space g D` (`q` in the left pane closes the diff) |
| Rollback lines | Cmd+Option+Z | `Space g r` (selection in Visual mode, whole file: `Space g R`) |
| Stage change | none | `Space g h` (selection in Visual mode) |
| Open on GitHub | none | `Space g o` |
| Commit window with side-by-side diff | Cmd+0, then Cmd+D | `Space g v` (again or `q` closes): `Tab` / `Shift+Tab` next / previous file, `-` stages, `X` rolls back (asks), `Space g t` hides the file list |
| Compare branch with base (`origin/dev`) | Git log, Compare with branch | `Space g m` |
| Resolve Conflicts (three panes) | merge dialog | `Space g v` during a merge: `]x` / `[x` next / previous conflict, `\xo` ours, `\xt` theirs, `\xb` base, `\xa` all |
| Show History with diffs | VCS menu | `Space g H` (file), `Space g L` (branch) |
| Pull Requests tool window | Cmd+Shift+A, Pull Requests | `Space g P`, `Enter` opens the pull request: files tree, side-by-side diff, comments on their lines (search: `Space g S`, notifications: `Space g N`) |
| Review the pull request of the current branch | Pull Requests, current branch | `Space g V` (also from a PR tab) |
| Add a review comment | `+` in the diff gutter | `\ca` on the line or selection, `Ctrl+s` sends |
| Submit Review | Submit button | `\vs`: Approve / Comment / Request changes |

### Tabs, windows, tool windows

| IntelliJ action | IntelliJ mac key | Neovim key |
|---|---|---|
| Close tab / Close others | Cmd+W / none | `Space b d` / `Space b o` |
| Reopen closed tab | none | `Space b u` |
| Next / previous tab | Cmd+Shift+] / Cmd+Shift+[ | `]b` / `[b` |
| Pin tab / close unpinned | none | `Space b p` / `Space b P` |
| Close tabs to the left / right | none | `Space b l` / `Space b r` (these also close pinned tabs) |
| Move tab left / right | none | `Space b [` / `Space b ]` |
| Jump to a tab by letter | none | `Space b j` |
| Previous file | Ctrl+Tab | `Space b b` |
| Split right / down | Window menu | `Space \|` / `Space -` (any `Ctrl+w` key also works as `Space w`, for example `Space w c` closes a split) |
| Move between splits | Option+Tab / Option+Shift+Tab | `Ctrl+h` / `Ctrl+j` / `Ctrl+k` / `Ctrl+l` |
| Hide All Tool Windows (maximize editor) | Cmd+Shift+F12 | `Space w m` |
| Terminal | Option+F12 | `Space t t`; inside the terminal `Ctrl+/` hides it (or `Esc Esc` then `q`) |
| Notifications | none | `Space s n` (dismiss: `Space u n`) |
| Sticky Lines on/off | settings | `Space u s` (jump to the enclosing line: `[x`) |
| Quit | Cmd+Q | `Space q q` (asks about unsaved files) |

Toggles under `Space u`: `a` autosave, `w` soft wrap, `d` diagnostics, `h` inlay hints, `s` sticky lines,
`b` inline blame, `u` undo tree, `n` dismiss notifications.

### Reviewing changes and pull requests

Diff view (`Space g v` local changes, `Space g m` the branch against `origin/dev`): the changed files are listed on the left,
`Enter` or `Tab` / `Shift+Tab` shows one, `-` stages or unstages it, `X` rolls it back (asks), `Space e` focuses the list,
`Space g t` hides it, `gf` opens the file in the editor, `g?` lists every key, `q` closes. The right side is the real file
and can be edited there. Files it showed do not stay open as tabs. In the three-pane merge view the capital keys
`\xO` `\xT` `\xB` `\xA` take one side for the whole file.

Pull requests open in that same diff view. `Space g P` lists them and `Enter` opens one: the changed files as a tree, the
base on the left and the pull request on the right. Nothing is checked out. If the pull request's branch already is, the
right side is the real file, with the language server. `Space g V` opens the pull request of the current branch, or of
the PR tab you are in.

- Review comments sit on their lines: a `●` in the margin and the start of the comment after the code. Rest the cursor on
  the line to read the thread; `Enter` opens it: `r` reply, `x` resolve, `e` edit, `d` delete, `o` browser. `]t` / `[t`
  jump between comments, `\cl` lists all of them, `\rt` resolves or reopens the one on the line.
- `\ca` comments on the line, or on the selected lines: type, `Ctrl+s` sends, `q` in Normal mode cancels. GitHub only
  takes comments on changed lines and the 3 lines around them.
- Your comments stay pending, visible only to you, until `\vs` submits the review: Approve, Comment or Request changes,
  with an optional summary. The header of the right pane counts them. `\vd` throws the pending review away.
- `\pp` opens the description and conversation as an editor tab (from the list: `Ctrl+v` / `Ctrl+s`), `\pb` the browser,
  `\vr` reloads the comments.
- Comments on code that has changed since they were written are not in the diff. They are in the conversation.
- In the list, `Ctrl+o` checks the branch out and `Ctrl+r` squash-merges; both ask first.

The PR tab (description and conversation) is octo.nvim: `\ca` adds a comment to the conversation, which is posted when you
save it (`Ctrl+s`), `\pa` approves, `Enter` lists all actions. Autosave never posts anything.

Diff views and PR tabs are not reopened with the project.

### Inside a search popup

- `Enter` opens, `Ctrl+v` / `Ctrl+s` open in a split, `Tab` selects several (in `Space g s` it stages instead),
  `Ctrl+q` sends results to the quickfix list. One `Esc` closes the popup.
- Toggles: `Ctrl+t` preview, `Ctrl+o` gitignored files (IntelliJ "include non-project items"), `Ctrl+y` hidden files,
  `Ctrl+l` regex (Find in Files is literal by default, like IntelliJ), `Ctrl+z` maximize.
- The query edits like a macOS text field: Cmd/Option+Left/Right, Cmd+Backspace clears it, Option+Backspace, fn+Delete.
- File mask in Find in Files: type `pattern -- -g *.java` (anything after `--` goes to ripgrep).

### Inside the Project tree

`a` new file (opens it; end with `/` for a folder), `A` new folder, `r` rename, `m` move, `c` copy, `d` delete (asks),
`T` move to the macOS trash, `x` / `gy` cut / copy then `p` paste, `y` / `Y` copy relative / absolute path,
`H` show or hide gitignored files (shown dimmed by default), `/` filter, `P` preview, `l` / `h` open / close,
`.` make the folder the root, `Backspace` go up, `R` refresh, `?` all keys.
Single-child folders are compacted like IntelliJ's "Compact Middle Packages" (`src/main/java/com/example`), one `Enter` opens them.
Folders that a build creates while Neovim runs (jdtls `bin/`, Gradle `build/`) are dimmed after `R` or once Neovim regains focus.

Neovim defaults kept: `grr` `gri` `grn` `gra` `grt` `grx` `gO` `K` `gc` `gcc` `[d` `]d` `[D` `]D` `Ctrl+w d`
`[q` `]q` and the Visual `an` `in` `]n` `[n` node selection.
Changed: `Ctrl+s` saves in every mode (Insert-mode signature help moved to `Ctrl+k`), `Ctrl+l` moves to the right split
(`Esc` clears the search highlight), `x` and paste over a selection keep the clipboard, `]]` / `[[` jump between usages,
in LSP buffers `gD` is the LSP declaration and `gI` Go to Implementation (Vim: insert at column 1), in Java buffers `gs`
is Go to Super Method (Vim: sleep), and in the terminal `Ctrl+/` hides it (the shell's `Ctrl+_` undo is gone there).
With the macOS text keys on, Normal-mode `Ctrl+a` / `Ctrl+e` jump to the line start / end (Vim: increment, scroll a line;
`+` / `-` increment and decrement numbers now), and Insert-mode `Ctrl+d` deletes forward (Vim: unindent, use Visual `Shift+Tab`).

## Behaviour

- Projects reopen like in IntelliJ: `nvim` in a folder of a git repository or Gradle/Maven project, or `nvim <dir>`,
  restores the files that were open when Neovim last quit in that folder and shows the Project tree.
  `nvim <file>` opens just that file and leaves the saved tabs alone. Sessions live in `~/.local/state/nvim/sessions/`.
- Closing the last tab (`Space b d`, `:bd`) keeps the tree and an empty editor; `:q` in the last editor quits.
- Autosave: modified files are written when you leave a buffer or switch to another app. `Space u a` toggles it,
  `:let b:autosave = v:false` turns it off for one buffer. A file that another tool changed on disk is never
  overwritten: you get a warning and decide with `:w!` (keep yours) or `:e!` (take theirs). `u` undoes an edit
  even after autosave wrote it, and `Space u u` shows the history.
- Files changed by other tools reload on focus, on buffer switch and every second while idle (`vim.g.autoread_poll_ms`).
- The system clipboard is the default register: `y`, `d` and `c` copy to it like Cmd+C / Cmd+X.
- `:q` with unsaved changes asks instead of failing. Undo history survives restarts.
- Cmd+Left/Right, Option+Left/Right, Cmd+Backspace, Option+Backspace, fn+Delete and Option+fn+Delete behave like in
  other macOS apps in Insert mode and in search popups (iTerm's "Natural Text Editing" key preset sends them).
  In Normal mode Cmd+Left/Right jump to the line start/end.
- Files over 1.5 MB open in a light mode (plain Vim syntax colours, no language server, folds or indent guides).
- Java: jdtls starts on the first Java file, with the Gradle root (the folder with `gradlew`) as the project and JDK 25
  (`/usr/libexec/java_home -v 25`; override with `JDTLS_JAVA_HOME`). The first import takes about a minute; progress is
  in the status line. Imports keep IntelliJ's order. Its workspace lives in `~/.local/share/nvim/jdtls-workspace/`.
- Switches at the top of `init.lua`: `have_nerd_font`, `autosave`, `autoread_poll_ms`, `macos_text_keys`.

## Known limitations

- Go to Implementation (`gI`, `gri`) on a method of a generic interface lists only some implementations:
  jdtls 1.61 misses the classes whose type argument is a nested type (11 of 125 in one project).
  On the interface name `gI` lists all of them, and `Space c t` shows all subtypes.
- Classes generated by the Gradle build (jOOQ `org.jooq.generated`, other `build/generated` sources) show as
  unresolved until a Gradle build has generated them; then run `:JdtUpdateConfig`.
- jdtls writes Eclipse compiler output to `bin/` in each subproject and Gradle writes `.gradle/` and `build/`.
  Keep all three in the project's `.gitignore`.
- The first import starts Gradle daemons (and a Kotlin daemon for `buildSrc`) that keep running after Neovim quits,
  as they do for IntelliJ. `./gradlew --stop` stops them.
- `Space c f` uses the Eclipse formatter, which differs from the IntelliJ code style: format a selection, not whole files.
- Two Neovim instances on the same project share one jdtls workspace; open the project in one of them.
- `:checkhealth snacks` reports errors for `fd`, `lazygit` and image tools. Those modules are not used: file search runs on `rg`.

## Icons (Nerd Font)

Icons are on (`vim.g.have_nerd_font = true` in `init.lua`) and need a Nerd Font in the terminal:

1. `brew install --cask font-jetbrains-mono-nerd-font` (installed)
2. iTerm2 ▸ Settings ▸ Profiles ▸ Text ▸ Font: "JetBrainsMono Nerd Font Mono" (or set it only as the Non-ASCII font)

Boxes or question marks instead of icons mean the terminal font has no icon glyphs. Then set `vim.g.have_nerd_font = false`
and restart Neovim for a plain ASCII and common Unicode rendering.

## Optional: let Option reach Neovim

iTerm2 ▸ Settings ▸ Profiles ▸ Keys ▸ General ▸ "Left Option key": `Esc+`. Keep the right Option key as `Normal`
to still type special characters. Then IntelliJ's Option+Shift+Up/Down (move line) and Option+Up/Down
(extend selection) work as mapped, and the search popups' own Alt toggles work too.

## Inside tmux

Add these to `~/.tmux.conf`, then run `tmux source-file ~/.tmux.conf`:

```
set -g focus-events on                          # autosave on focus loss, reload on focus
set -sg escape-time 10                          # Esc without the 500 ms delay
set -as terminal-features ',xterm-256color:RGB' # 24-bit colours instead of the nearest 256
```

## Layout and maintenance

```
init.lua                  switches, leader, load order
lua/config/options.lua    editor options
lua/config/lazy.lua       plugin manager bootstrap
lua/config/autocmds.lua   autosave, reload, small behaviours
lua/config/keymaps.lua    editor keymaps (plugin keys live with each plugin)
lua/config/local.lua      optional, gitignored: machine-specific settings such as vim.g.java_favorite_static_members
lua/plugins/*.lua         one file per area: snacks, neo-tree, lsp, java, completion, treesitter, ui, git, colorscheme,
                          grug-far, editor (bracket pairs), session (reopen projects)
queries/java/context.scm  sticky lines for records, interfaces, enums, constructors, lambdas, try blocks
```

- Plugins: `:Lazy` (`:Lazy sync` updates them, `lazy-lock.json` records the versions; commit it if you version this folder).
- Language servers: `:Mason`. Missing ones, and shellcheck for the shell script warnings, install the next time Neovim opens a file.
- Treesitter parsers: `:TSUpdate`.
- The colour scheme `islands-dark` is pinned to a reviewed commit in `lua/plugins/colorscheme.lua`; bump it on purpose.
  To switch to tokyonight, replace `vim.cmd.colorscheme("islands-dark")` with `vim.cmd.colorscheme("tokyonight")`.
