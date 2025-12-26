local keymap_module = require("keymap")

local M = {}

---@class KeymuxConfig
---@field duplicate ?DuplicateConfig
---@field [string] any

---@class DuplicateConfig
---@field detect ?boolean Enable duplicate detection (default: false)
---@field on_duplicate ?fun(keymaps: KeyMap[]): Callback function called when duplicate detected

---@type KeymuxConfig
local config = {
	duplicate = {
		detect = false,
	},
}

M.inspect = function(key)
	return keymap_module.resolve_all_keymap_by_key(key)
end

M.get = function(key)
	return M.inspect(key)[1]
end

function M.remove_keymaps(key, mode)
	-- TODO: maybe key or mode a table?
	assert(type(key) == "string", "Expect key to be a string")
	assert(type(mode) == "string", "Expect mode to be a string")

	local keymaps = keymap_module.resolve_keymaps_by_keymod(key, mode)

	for _, keymap in ipairs(keymaps) do
		keymap_module.remove_keymap(keymap.id)
	end
end

M.get_config = function()
	return config
end

M.detect_duplicates = function(mode, key)
	return keymap_module.detect_duplicates(mode, key)
end

M.k = function(opts)
	if opts.enabled and type(opts.enabled) == "function" and not opts.enabled() then
		return
	end

	local keymap = keymap_module.create(opts, config)

	keymap_module.register(keymap.id)

	return function(handler, extra)
		if not handler then
			return {
				key = keymap.key,
			}
		end

		if handler == "CLEAR" then
			return keymap_module.remove_keymap(keymap.id)
		end

		extra = extra or {}

		local the_handler = (function()
			if type(handler) == "string" and not handler:find("^[%:]") then
				local the_handler = keymap_module.resolve_callback_by_name(keymap.id, handler)
				assert(the_handler, ("Handler (%s) not found"):format(handler))
				return the_handler
			end
			local callback = keymap_module.add_handler(keymap.id, handler, extra)
			return callback
		end)()

		if not extra.defer then
			keymap_module.register(keymap.id)
		end

		return {
			lazy_key = {
				keymap.key,
				function()
					keymap_module.invoke(keymap)
				end,
				desc = keymap.desc,
				mode = keymap.mode,
			},
			del = function()
				keymap_module.remove_handler(keymap.id, the_handler.id)
			end,
			reg = function()
				keymap_module.add_handler(keymap.id, handler, extra)
				keymap_module.register(keymap.id)
			end,
			enable = function()
				keymap_module.register(keymap.id)
				the_handler.enabled = true
			end,
			disable = function()
				the_handler.enabled = false
			end,
		}
	end
end

M.clear_keymap = function(key)
	assert(type(key) == "string", "Expect key to be a string")

	local keymaps = keymap_module.resolve_all_keymap_by_key(key)

	assert(#keymaps > 0, ("Key (%s) not registered"):format(key))

	for _, keymap in ipairs(keymaps) do
		keymap_module.remove_keymap(keymap.id)
	end
end

function M.setup(opts)
	opts = opts or {}

	-- Merge user config with defaults
	if opts.duplicate then
		config.duplicate = vim.tbl_deep_extend("force", config.duplicate, opts.duplicate)
	end

	-- Store other config options
	for key, value in pairs(opts) do
		if key ~= "duplicate" then
			config[key] = value
		end
	end

	vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout", "BufUnload" }, {
		group = vim.api.nvim_create_augroup("nvim-keymap-delete-autocmd", { clear = true }),
		pattern = "*",
		callback = function(opts)
			local buf = opts.buf

			keymap_module.remove_callback_by_buffer(buf)
		end,
	})
end

_G.keymux = M

return M
