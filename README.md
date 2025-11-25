# resu.nvim

**resu.nvim** is a Neovim plugin designed to streamline the workflow of reviewing code changes made by AI CLI tools (like Claude Code, Gemini CLI, etc.). It watches your project for changes and provides an interface to review, accept, or decline them, similar to `git add -p` but for file-level AI modifications.

## Features

- **Real-time File Watching**: Automatically detects changes in your project directory.
- **Review Interface**: Sidebar UI showing modified files with status indicators.
- **Diff Integration**: Seamlessly integrates with [Diffview.nvim](https://github.com/sindrets/diffview.nvim) (recommended) or falls back to native vim diffs.
- **Workflow Actions**: Accept (`<leader>ra`) or Decline (`<leader>cd`) changes quickly.
- **Git Integration**: Option to auto-stage (`git add`) accepted files.

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

**Option 1: Install from GitHub (once pushed)**

```lua
{
  "koushikxd/resu.nvim",
  dependencies = {
    "sindrets/diffview.nvim", -- Optional but recommended
    "nvim-lua/plenary.nvim",  -- Required (usually present)
  },
  config = function()
    require("resu").setup({
      -- Configuration options here
    })
  end
}
```

**Option 2: Local Development (Symlink)**

If you want to test the plugin locally without pushing to GitHub first:

```lua
{
  "resu",
  dir = "/path/to/resu.nvim", -- Update this path
  dependencies = {
    "sindrets/diffview.nvim",
  },
  config = function()
    require("resu").setup({
      watch_dir = vim.fn.getcwd(), -- Start watching cwd immediately
    })
  end
}
```

## Configuration

Default configuration:

```lua
require("resu").setup({
  -- Directory to watch (nil = cwd)
  watch_dir = nil,
  
  -- Patterns to ignore
  ignored_files = {
    "%.git/",
    "node_modules/",
    "dist/",
    "build/",
    "%.DS_Store",
    "%.swp",
  },
  
  -- Auto-stage accepted files with git add
  auto_stage = false,
  
  -- Keymaps for the review window
  keymaps = {
    accept = "<leader>ra",
    decline = "<leader>cd",
    next = "<leader>rn",
    prev = "<leader>rp",
    accept_file = "<leader>raf",
    decline_file = "<leader>rdf",
    refresh = "<leader>rr",
    quit = "<leader>rq",
  },
})
```

## Usage

1. Run your AI tool (e.g., `claude-code "refactor this file"`).
2. Changes are detected automatically.
3. Open the review panel: `:AIReviewOpen` (or bind a key).
4. Navigate the list. The diff view will open automatically for the selected file.
5. Use keymaps to Accept or Decline changes.

## Commands

- `:AIReviewOpen` - Open the review panel
- `:AIReviewToggle` - Toggle the review panel
- `:AIReviewReset` - Clear the list of changed files

## License

MIT
