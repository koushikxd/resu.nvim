# resu.nvim

A Neovim plugin for reviewing and managing file changes made by AI coding cli tools.

## Overview

resu.nvim watches your project directory for file modifications and provides a streamlined interface to review, accept, or decline changes. It helps you maintain control when working with AI tools like Claude Code, Cursor CLI, or similar assistants.

## Requirements

- Neovim >= 0.8.0
- Git (for baseline tracking)
- plenary.nvim (optional, usually already installed)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "koushikxd/resu.nvim",
  config = function()
    require("resu").setup()
  end
}
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  "koushikxd/resu.nvim",
  config = function()
    require("resu").setup()
  end
}
```

## Features

- Real-time file watching with automatic change detection
- Sidebar interface for reviewing modified files
- Inline diff visualization with syntax highlighting
- Accept or decline changes per file
- Persistent state tracking across sessions
- Git integration support

## Configuration

Default configuration:

```lua
require("resu").setup({
  watch_dir = nil,
  ignored_files = {
    "%.git/",
    "node_modules/",
    "dist/",
    "build/",
    "%.DS_Store",
    "%.swp",
  },
  auto_stage = false,
  view_mode = "split",
  window = {
    position = "left",
    width = 25,
    border = "rounded",
  },
  keymaps = {
    accept = "<leader>ra",
    decline = "<leader>rd",
    next = "<C-j>",
    prev = "<C-k>",
    quit = "q",
  },
})
```

### Configuration Options

- `watch_dir`: Directory to watch for changes. Defaults to current working directory.
- `ignored_files`: Patterns of files to ignore. Uses Lua pattern matching.
- `auto_stage`: Automatically stage accepted files with `git add`.
- `window.position`: Position of the review sidebar.
- `window.width`: Width of the review sidebar in columns.
- `window.border`: Border style for the window.
- `keymaps`: Key mappings for review actions (active when review panel is open).

## Usage

### Basic Workflow

1. Open the review panel:
   
```vim
:ResuToggle
```

2. Navigate through changed files using `<C-j>` and `<C-k>` or `j` and `k`.

3. Review the inline diff for each file.

4. Accept changes with `<leader>ra` or decline with `<leader>rd`.

5. Close the panel with `q` or `:ResuToggle`.

### Commands

- `:ResuOpen` - Open the review panel
- `:ResuClose` - Close the review panel
- `:ResuToggle` - Toggle the review panel
- `:ResuNext` - Jump to next changed file
- `:ResuPrev` - Jump to previous changed file
- `:ResuAccept` - Accept changes in current file
- `:ResuDecline` - Decline changes in current file
- `:ResuAcceptAll` - Accept all pending changes
- `:ResuDeclineAll` - Decline all pending changes
- `:ResuReset` - Reset all file states

### Default Keymaps

When the review panel is open:

- `<leader>ra` - Accept current file changes
- `<leader>rd` - Decline current file changes
- `<C-j>` or `j` - Next file
- `<C-k>` or `k` - Previous file
- `<CR>` - Open current file in editor
- `q` - Close review panel
- `<leader>rt` - Toggle review panel (global)

## How It Works

1. resu.nvim monitors your project directory for file changes using filesystem events.
2. When a change is detected, it captures a baseline snapshot of the file.
3. Changes are displayed in a sidebar with inline diffs showing additions and deletions.
4. Accepting a change keeps the modifications and removes tracking.
5. Declining a change reverts the file to its baseline state.
6. State persists across Neovim sessions until explicitly cleared.

## Use Cases

- Reviewing AI-generated code changes before committing
- Managing incremental modifications from AI coding assistants
- Keeping control over file-level changes in collaborative AI workflows
- Quick approval or rejection of automated refactoring

## License

MIT
