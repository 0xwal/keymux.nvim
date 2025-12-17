local keymux = require("keymux")

local function expand_leader(str)
	if not str then
		return str
	end
	local leader = vim.g.mapleader or "\\"
	return (str:gsub("<[lL]eader>", leader))
end

local function display_keymaps(mode, key)
	local maps = vim.api.nvim_get_keymap(mode)
	if #maps == 0 then
		print("No mappings found for mode: " .. mode)
		return
	end

	local expanded_key = key and expand_leader(key) or nil

	print("Keymaps for mode '" .. mode .. "':")
	local found = false
	for _, map in ipairs(maps) do
		local expanded_lhs = expand_leader(map.lhs)
		if not expanded_key or expanded_lhs == expanded_key then
			found = true
			local info = string.format(
				"LHS: %s | RHS: %s | Noremap: %s | Expr: %s | Desc: %s",
				expanded_lhs or "(none)",
				map.rhs or "(function)",
				tostring(map.noremap or false),
				tostring(map.expr or false),
				map.desc or "(no description)"
			)
			print(info)
		end
	end
	if expanded_key and not found then
		print("No mappings found for key: " .. (key or expanded_key) .. " in mode: " .. mode)
	end
end

---@param key string
local function get_actual_info(key, mode)
	---@type KeyMap[]
	local keymaps = keymux.inspect(key)

	local out = {}

	for _, keymap in ipairs(keymaps) do
		if mode and keymap.mode ~= mode then
			goto continue
		end

		table.insert(out, {
			key = keymap.key,
			mode = keymap.mode,
			desc = keymap.desc,
			filetype = keymap.filetype or "*",
			once = keymap.once and "YES" or "NO",
			hasWrapper = keymap.wrapper ~= nil,
			condition = keymap.condition,
			passthrough = keymap.passthrough,
			callbacks = vim.tbl_map(function(callback)
				return {
					id = callback.id,
					name = callback.name,
					desc = callback.desc,
					once = callback.once and "YES" or "NO",
					filetype = callback.filetype or "*",
					enabled = callback.enabled,
					buffer = callback.buffer,
					priority = callback.priority,
				}
			end, keymap.callbacks),
		})

		::continue::
	end

	return out
end

local function to_string(keymaps)
	local out = {}

	for _, keymap in ipairs(keymaps) do
		local callbacks = {}

		for _, callback in ipairs(keymap.callbacks) do
				table.insert(
					callbacks,
					string.format(
						[[
	Name: %s
	Once: %s
	Desc: %s
	Priority: %s
	Filetype: %s
	Enabled: %s
	Buffer: %s
				]],
					callback.name or "",
					tostring(callback.once),
					callback.desc or "",
					tostring(callback.priority or 0),
					callback.filetype or "",
					tostring(callback.enabled),
					tostring(callback.buffer or "")
				)
			)
		end

		table.insert(
			out,
			string.format(
				[[
 Key: %s
 Mode: %s
 Desc: %s
 Filetype: %s
 Once: %s
 Condition: %s
 Passthrough: %s
 Callbacks:
%s
		]],
				keymap.key,
				keymap.mode,
				keymap.desc,
				keymap.filetype,
				keymap.once,
				keymap.condition and "YES" or "NO",
				keymap.passthrough and "YES" or "NO",
				table.concat(callbacks, "\n")
			)
		)
	end

	return table.concat(out, "\n")
end

local function handle_command(key, mode)
	local keymaps = get_actual_info(key, mode)
	local asString = to_string(keymaps)
	vim.print(asString)
end

vim.api.nvim_create_user_command("Map", function(opts)
	local key = opts.args ~= "" and opts.args or nil
	handle_command(key)
	end, { desc = "Display general keymap info", nargs = "?" })

vim.api.nvim_create_user_command("Nmap", function(opts)
	local key = opts.args ~= "" and opts.args or nil
	handle_command(key, "n")
end, { desc = "Display normal mode keymap info", nargs = "?" })

vim.api.nvim_create_user_command("Imap", function(opts)
	local key = opts.args ~= "" and opts.args or nil
	handle_command(key, "i")
end, { desc = "Display insert mode keymap info", nargs = "?" })

vim.api.nvim_create_user_command("Vmap", function(opts)
	local key = opts.args ~= "" and opts.args or nil
	handle_command(key, "v")
end, { desc = "Display visual mode keymap info", nargs = "?" })
