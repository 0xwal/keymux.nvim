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
    **supermaven**: faster but suggestion quality is mostly ok  (enabled by default)  
    **codeium**: slower but suggestion quality is better (disabled by default, only on demand)  
Neovim doesn't allow multiple handlers for the same keymap, so this plugin enables that.  
For example, `<M-]>` triggers supermaven first; if the suggestion isn't good, press `<M-]>` again for codeium.
    ```lua
    _G.ai_next_suggestion = keymux.k { "<M-]>", desc = "next suggestion" }

    -- *in supermaven.lua plugin config (this how I split plugins)
    _G.ai_next_suggestion(function(ctx)
        -- hide supermaven ai suggestion
        require("supermaven.completion_preview").on_dispose_inlay()
    end, { name = "supermaven ai completion", priority = 100 })


    -- *in codeium.lua plugin config (disabling the plugin doesn't effect the setup)
    _G.ai_next_suggestion(function(ctx)
        -- now show the suggestion
        require("neocodeium").cycle_or_complete()
    end, { name = "codeium ai completion" })
    ```

- I want to use fewer keymaps and only use them in specific scenarios
    - `o` is a new line, but I want when in debugging state, I want `o` to be a step over
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

## Features

- **Multiplex handlers**: One key can trigger multiple handlers
- **Conditional execution**: Filetype, buffer, and priority-based handlers
- **Context sharing**: Pass data between handlers
- **Safe registration**: Warns about conflicting keymaps
- **Dynamic conditions**: Enable/disable keymaps based on global state
- **Passthrough**: Execute original key behavior alongside custom handlers


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

## API

### `keymux.k(opts)`

Creates a new keymap declaration.

#### Options (`KeyMapOptionsArg`)

**Wrapper Function Signature:**
```lua
---@field [2] fun(handler: table): any
-- handler has __newindex and __call metamethods
-- handler.ctx = value  -- sets context
-- handler()           -- calls the handler
```

| Field | Type | Optional | Description |
|-------|------|----------|-------------|
| `[1]` | `string` | No | The key sequence |
| `desc` | `string` | No | Description for the keymap |
| `mode` | `string\|table` | Yes | Vim mode(s) (default: `"n"`) |
| `filetype` | `string` | Yes | Filetype to restrict keymap to |
| `noremap` | `boolean` | Yes | Don't remap (default: `false`) |
| `once` | `boolean` | Yes | Remove after first execution |
| `silent` | `boolean` | Yes | Silent execution (default: `true`) |
| `[2]` | `function` | Yes | Wrapper function for all handlers (`fun(handler: table): any`) |
| `condition` | `function` | Yes | Enable keymap when function returns `true` (`fun(): boolean`) |
| `passthrough` | `boolean\|function` | Yes | Execute original key behavior (`fun(): boolean?`) |

```lua
local keymap = keymux.k {
  "<leader>x",           ---@field [1] string The key sequence
  desc = "Description", ---@field desc string Description for the keymap
  mode = "n",           ---@field mode? string|table Vim mode(s) (default: "n")
  filetype = "lua",     ---@field filetype? string Filetype to restrict keymap to
  once = true,          ---@field once? boolean Remove after first execution
  noremap = false,      ---@field noremap? boolean Don't remap (default: false)
  silent = true,         ---@field silent? boolean Silent execution (default: true)
  condition = function() ---@field condition? fun(): boolean Enable keymap when function returns true
    return vim.g.enabled
  end,
  passthrough = true,    ---@field passthrough? boolean|fun(): boolean? Execute original key behavior
}
```

### Adding Handlers

```lua
keymap(function(ctx)
  -- your code here
  return true  -- stop execution chain
end, {
  name = "handler-name",   ---@field name? string Unique name for the handler
  desc = "Handler desc",   ---@field desc? string Description for the handler
  priority = 100,          ---@field priority? number Higher numbers run first (default: 0)
  filetype = "lua",        ---@field filetype? string Restrict to specific filetype
  buffer = 0,              ---@field buffer? number Restrict to specific buffer
  once = true,             ---@field once? boolean Remove after first execution
  defer = false,            ---@field defer? boolean Don't execute immediately on creation
})
```

#### Handler Options (`CallbackOptionsArg`)

| Field | Type | Optional | Description |
|-------|------|----------|-------------|
| `name` | `string` | Yes | Unique name for the handler |
| `desc` | `string` | Yes | Description for the handler |
| `priority` | `number` | Yes | Higher numbers run first (default: `0`) |
| `filetype` | `string` | Yes | Restrict to specific filetype |
| `buffer` | `number` | Yes | Restrict to specific buffer |
| `once` | `boolean` | Yes | Remove after first execution |
| `defer` | `boolean` | Yes | Don't execute immediately on creation (default: `false`) |

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
