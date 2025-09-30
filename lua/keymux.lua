local keymapModule = require("keymap")

local M = {}

M.inspect = function(key)
	return keymapModule.resolve_all_keymap_by_key(key)
end

M.get = function(key)
	return M.inspect(key)[1]
end

function M.remove_keymaps(key, mode)
	-- TODO: maybe key or mode a table?
	assert(type(key) == "string", "Expect key to be a string")
	assert(type(mode) == "string", "Expect mode to be a string")

	local keymaps = keymapModule.resolve_keymaps_by_keymod(key, mode)

	for _, keymap in ipairs(keymaps) do
		keymapModule.remove_keymap(keymap.id)
	end
end

M.k = function(opts)
	if opts.enabled and type(opts.enabled) == "function" and not opts.enabled() then
		return
	end

	local keymap = keymapModule.create(opts)

	return function(handler, extra)
		if not handler then
			return {
				key = keymap.key,
			}
		end

		if handler == "CLEAR" then
			return keymapModule.remove_keymap(keymap.id)
		end

		extra = extra or {}

		local theHandler = (function()
			if type(handler) == "string" and not handler:find("^[%:]") then
				local theHandler = keymapModule.resolve_callback_by_name(keymap.id, handler)
				assert(theHandler, ("Handler (%s) not found"):format(handler))
				return theHandler
			end
			local callback = keymapModule.add_handler(keymap.id, handler, extra)
			return callback
		end)()


		if not extra.defer then
			keymapModule.register(keymap.id)
		end

		return {
			lazy_key = {
				keymap.key,
				function()
					keymapModule.invoke(keymap)
				end,
				desc = keymap.desc,
				mode = keymap.mode,
			},
			del = function()
				keymapModule.remove_handler(keymap.id, theHandler.id)
			end,
			reg = function()
				keymapModule.add_handler(keymap.id, handler, extra)
				keymapModule.register(keymap.id)
			end,
			enable = function()
				keymapModule.register(keymap.id)
				theHandler.enabled = true
			end,
			disable = function()
				theHandler.enabled = false
			end,
		}
	end
end

M.clear_keymap = function(key)
	assert(type(key) == "string", "Expect key to be a string")

	local keymaps = keymapModule.resolve_all_keymap_by_key(key)

	assert(#keymaps > 0, ("Key (%s) not registered"):format(key))

	for _, keymap in ipairs(keymaps) do
		keymapModule.remove_keymap(keymap.id)
	end
end

function M.setup()
	vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout", "BufUnload" }, {
		group = vim.api.nvim_create_augroup("nvim-keymap-delete-autocmd", { clear = true }),
		pattern = "*",
		callback = function(opts)
			local buf = opts.buf

			keymapModule.remove_callback_by_buffer(buf)
		end,
	})
end

_G.keymux = M

return M
