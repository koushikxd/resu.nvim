# resu.nvim

A Neovim plugin for reviewing and managing file changes made by AI coding CLI tools.

## Overview

resu.nvim watches your project directory for file modifications and provides a streamlined interface to review, accept, or decline changes. It integrates seamlessly with [diffview.nvim](https://github.com/sindrets/diffview.nvim) for a powerful diff experience, while also providing a built-in fallback UI.

## Requirements

- Neovim >= 0.8.0
- Git (for diff and revert operations)
- [diffview.nvim](https://github.com/sindrets/diffview.nvim) (recommended, optional)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "koushikxd/resu.nvim",
  dependencies = {
    "sindrets/diffview.nvim",
  },
  config = function()
    require("resu").setup()
  end,
}
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  "koushikxd/resu.nvim",
  requires = { "sindrets/diffview.nvim" },
  config = function()
    require("resu").setup()
  end,
}
```

## Features

- **Diffview Integration**: Uses diffview.nvim for a feature-rich diff interface (default)
- **Built-in Fallback UI**: Sidebar interface with inline diff visualization when diffview is unavailable
- **Real-time File Watching**: Automatic change detection with configurable debouncing
- **Hot Reload**: Automatically reloads buffers when files change on disk
- **Git Integration**: Stage files on accept, revert to HEAD on decline
- **Batch Operations**: Accept or decline all pending changes at once

## Configuration

Default configuration:

```lua
require("resu").setup({
  use_diffview = true,
  hot_reload = true,
  debounce_ms = 100,
  watch_dir = nil,
  ignored_files = {
    "%.git/",
    "node_modules/",
    "dist/",
    "build/",
    "%.DS_Store",
    "%.swp",
  },
  keymaps = {
    toggle = "<leader>rt",
    accept = "<leader>ra",
    decline = "<leader>rd",
    accept_all = "<leader>rA",
    decline_all = "<leader>rD",
    refresh = "<leader>rr",
    quit = "q",
  },
})
```

### Configuration Options

| Option          | Type    | Default   | Description                                   |
| --------------- | ------- | --------- | --------------------------------------------- |
| `use_diffview`  | boolean | `true`    | Use diffview.nvim when available              |
| `hot_reload`    | boolean | `true`    | Auto-reload buffers when files change on disk |
| `debounce_ms`   | number  | `100`     | Debounce delay (ms) for file watcher          |
| `watch_dir`     | string  | `nil`     | Directory to watch (defaults to cwd)          |
| `ignored_files` | table   | see above | Lua patterns for files to ignore              |
| `keymaps`       | table   | see above | Key mappings for actions                      |

## Usage

### Basic Workflow

1. Start working with your AI coding tool (Claude Code, Cursor, etc.)

2. Toggle the review panel:
```vim
:ResuToggle
```

3. Review changes in the diff view

4. Accept changes with `<leader>ra` (stages the file) or decline with `<leader>rd` (reverts to HEAD)

5. Use `<leader>rA` to accept all or `<leader>rD` to decline all pending changes

### Commands

| Command           | Description                         |
| ----------------- | ----------------------------------- |
| `:ResuOpen`       | Open the diff view                  |
| `:ResuClose`      | Close the diff view                 |
| `:ResuToggle`     | Toggle the diff view                |
| `:ResuRefresh`    | Refresh the view and reload buffers |
| `:ResuAccept`     | Accept/stage current file           |
| `:ResuDecline`    | Decline/revert current file to HEAD |
| `:ResuAcceptAll`  | Accept/stage all changes            |
| `:ResuDeclineAll` | Decline/revert all changes          |
| `:ResuReset`      | Reset plugin state                  |

### Default Keymaps

| Key          | Action                     |
| ------------ | -------------------------- |
| `<leader>rt` | Toggle diff view           |
| `<leader>ra` | Accept current file        |
| `<leader>rd` | Decline current file       |
| `<leader>rA` | Accept all changes         |
| `<leader>rD` | Decline all changes        |
| `<leader>rr` | Refresh view               |
| `q`          | Close panel (in legacy UI) |

### Legacy UI Keymaps (when diffview is unavailable)

| Key    | Action              |
| ------ | ------------------- |
| `j`    | Next file           |
| `k`    | Previous file       |
| `<CR>` | Open file in editor |
| `q`    | Close panel         |

## How It Works

### With Diffview (Default)

1. resu.nvim monitors your project directory for file changes using libuv filesystem events
2. Changes are displayed using diffview.nvim's powerful diff interface
3. **Accept** stages the file with `git add`
4. **Decline** reverts the file to HEAD using `git checkout` (or removes untracked files)
5. Hot reload keeps your buffers in sync with disk changes

### Without Diffview (Fallback)

1. A sidebar shows all modified and untracked files
2. Inline diffs are rendered using virtual text (additions in green, deletions in red)
3. Navigate files with `j`/`k` and press `<CR>` to view
4. Accept saves the current buffer state, decline reverts to the git baseline

## Use Cases

- Reviewing AI-generated code changes before committing
- Managing incremental modifications from AI coding assistants
- Quick approval or rejection of automated refactoring
- Keeping control over file-level changes in collaborative AI workflows

## License

MIT
