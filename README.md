# mrubuftab.nvim

A simple, lightweight, and MRU (Most Recently Used) based buffer tabline plugin for Neovim.

![Demo](https://via.placeholder.com/800x100?text=MRU+BufTab+Demo+Placeholder)

## Features

- **MRU Ordering**: Automatically sorts tabs based on your usage history. The active buffer is always highlighted, and recent buffers are easily accessible.
- **Dynamic Sizing**: Tab width automatically adjusts to show relevant information (filename, icons, status) without wasting space.
- **LSP Integration**: Displays LSP diagnostic counts (Errors, Warnings) with icons directly on the tab. The tab expands to show this information only when needed.
- **Smart Scrolling**:
    - Always shows `` and `` indicators.
    - When tabs overflow the screen, the right indicator sticks to the right edge for a consistent UI.
- **Visuals**:
    - Uses `nvim-web-devicons` for file icons.
    - Superscript buffer numbers (e.g., `¹`, `²`) for a cleaner look.
    - Minimalist design (no unnecessary separators or active buffer bars).
- **Lightweight**: Written in pure Lua.

## Requirements

- Neovim >= 0.7.0
- [nvim-tree/nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons) (Recommended for icons)

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "coil398/mrubuftab.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    require("mrubuftab").setup()
  end,
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "coil398/mrubuftab.nvim",
  requires = { "nvim-tree/nvim-web-devicons" },
  config = function()
    require("mrubuftab").setup()
  end
}
```

## Configuration

`mrubuftab.nvim` works out of the box with minimal configuration. Pass an empty table to setup to use defaults.

```lua
require("mrubuftab").setup({
  -- Currently no options are exposed, but the setup call is required to initialize highlights and autocmds.
})
```

## Keymaps

The plugin exposes user commands `:MruNext` and `:MruPrev` to cycle through the MRU list.

```lua
-- Cycle through buffers in MRU order
vim.keymap.set("n", "<Tab>", "<cmd>MruNext<CR>", { silent = true })
vim.keymap.set("n", "<S-Tab>", "<cmd>MruPrev<CR>", { silent = true })
```

## Highlights

The plugin uses the following highlight groups, which link to standard TabLine groups by default. You can override them in your colorscheme.

- `TabLine`: Background for unselected tabs.
- `TabLineSel`: Background for the selected tab.
- `TabLineFill`: Background for the empty space in the tabline.
- `TabLineSelItalic`: Used for the selected filename (italicized).

## License

MIT