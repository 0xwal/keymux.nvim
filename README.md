# keymux.nvim

A keymap multiplexer for Neovim - declare keymaps once, add handlers from anywhere.

## Installation

```lua
{
  "0xWal/keymux.nvim",
  priority = 1000,
  init = function()
    require("keymux").setup()
  end,
}
```

## Quick Start

```lua
local keymux = require("keymux")

-- 1. Declare a keymap
_G.find_files = keymux.k {
  "<leader>ff",
  desc = "Find files",
}

-- 2. Add handlers anywhere
find_files(function()
  require("telescope.builtin").find_files()
end)

find_files(function()
  vim.cmd("FzfLua files")
end)
```

Press `<leader>ff` to run both handlers in sequence.

## Features

- **Multiplex handlers**: One key can trigger multiple handlers
- **Conditional execution**: Filetype, buffer, and priority-based handlers
- **Context sharing**: Pass data between handlers
- **Safe registration**: Warns about conflicting keymaps

## API

### `keymux.k(opts)`

Create a keymap declaration:

```lua
local keymap = keymux.k {
  "<leader>x",
  desc = "Description",
  mode = "n",           -- optional, default "n"
  filetype = "lua",     -- optional
  once = true,          -- optional
}
```

### Adding Handlers

```lua
keymap(function(ctx)
  -- your code here
  return true  -- stop execution chain
end, {
  name = "handler-name",   -- optional
  priority = 100,          -- optional, higher runs first
  filetype = "lua",        -- optional
  buffer = 0,              -- optional
  once = true,             -- optional
})
```

### Handler Control

```lua
local handler = keymap(function() end)

handler.enable()   -- enable handler
handler.disable()  -- disable handler
handler.del()      -- remove handler
```

## Examples

### Filetype-specific handlers

```lua
_G.run_code = keymux.k { "<leader>r", desc = "Run code" }

-- Lua files
run_code(function()
  vim.cmd("source %")
end, { filetype = "lua" })

-- Python files
run_code(function()
  vim.cmd("!python %")
end, { filetype = "python" })
```

### Priority ordering

```lua
_G.ordered = keymux.k { "<leader>o", desc = "Ordered" }

ordered(function() print("3") end)                    -- priority: 0
ordered(function() print("2") end, { priority = 100 })
ordered(function() print("1") end, { priority = 200 })

-- Output: 1, 2, 3
```

### Context sharing

```lua
_G.search = keymux.k { "<leader>s", desc = "Search" }

search(function(ctx)
  ctx.query = vim.fn.input("Search: ")
end)

search(function(ctx)
  if ctx.query and ctx.query ~= "" then
    print("Searching: " .. ctx.query)
  end
end)
```

## Debugging

```vim
:Map <leader>ff    " Show all handlers for <leader>ff
```

```lua
local info = keymux.inspect("<leader>ff")
vim.print(info)
```

## License

MIT