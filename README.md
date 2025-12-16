# keymux.nvim

A keymap multiplexer for Neovim - declare keymaps once, add handlers from anywhere.

## Motivation
- Decouple keymap declaration and handler assignment:
    I don't want to have the keymap `<lhs>` everywhere, and want easier/simpler API
    ```lua
        -- declare keymap
        _G.keybind_do_x = keymux.k {
            "<leader>x", -- in once place
            desc = "a description for the keymap",
            -- ... other options
        }

        -- assign handlers later anywhere
        _G.keybind_do_x(function() print("do x") end)
    ```
- Register n handlers for a keymap:
I use two ai completion plugins (codeium, supermaven), why two?  
    **supermaven**: faster but suggestion quality is mostly ok  
    **codeium**: slower but suggestion quality is better  
Neovim doesn't allow multiple handlers for the same keymap, so this plugin enables that.  
For example, <M-]> triggers supermaven first; if the suggestion isn't good, press <M-]> again for codeium.

- I want to use fewer keymaps and only use them in specific scenarios
    - `o` is a new line, but I want when in debugging state, I want o to be a step over
        ```lua
        _G.debug_o = keymux.k { 
            "o",
            desc = "step over",
            passthrough = function()
                -- only passthrough when not in debug mode
                return not vim.g._in_debug;
            end,
            condition = function()
                -- only enable when in debug mode
                return vim.g._in_debug;
            end
        }
        
        -- register the handler
        debug_o(function()
            vim.cmd("StepOver")
        end, { name = "debug_o" })

        -- later when exiting debug mode
        debug_o("CLEAR") -- will clear all keymap and restore `o`

        ```
    - ``

## Features

- Enhance keymaps with context sharing, filetype/buffer conditions, priority ordering, wrappers, oneshot execution, and middleware-like behavior.
- Avoid keymap conflicts by separating declaration from handler assignment.
- Better api and all declaration can be in one place
- Assign multiple handlers to one keymap with fallback logic.

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
- **Dynamic conditions**: Enable/disable keymaps based on global state
- **Passthrough**: Execute original key behavior alongside custom handlers

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

### Dynamic conditions

```lua
_G.debug_toggle = keymux.k { 
  "<leader>d", 
  desc = "Debug toggle",
  condition = function()
    return vim.g.debug_enabled
  end,
}

debug_toggle(function()
  print("Debug action executed")
end)
```

### Passthrough keymaps

```lua
_G.smart_l = keymux.k { 
  "l", 
  desc = "Smart movement",
  passthrough = true,  -- Also execute normal 'l' behavior
}

smart_l(function()
  -- Custom logic before normal movement
  vim.notify("Moving right")
end)
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

### Plugin fallback with priority

```lua
_G.find_files = keymux.k { "<leader>ff", desc = "Find files" }

-- Try Snacks picker first (highest priority)
find_files(function()
  local success = pcall(function()
    require("snacks").picker.files()
  end)
  return success  -- Stop chain if Snacks works
end, { priority = 200 })

-- Fallback to Telescope
find_files(function()
  local success = pcall(function()
    require("telescope.builtin").find_files()
  end)
  return success  -- Stop chain if Telescope works
end, { priority = 100 })

-- Final fallback if neither plugin exists
find_files(function()
  vim.notify("No file picker plugin available", vim.log.levels.ERROR)
end, { priority = 0 })
```

## Debugging

```vim
:Map <leader>ff    " Show all handlers for <leader>ff
```

```lua
local info = keymux.inspect("<leader>ff")
vim.print(info)
```
