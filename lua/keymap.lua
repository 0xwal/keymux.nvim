---@alias WrapperFn function(ctx: table|fun())
---@alias HandlerFn fun(ctx: table): boolean

---@class KeyMap
---@field id string
---@field key string
---@field desc string
---@field noremap boolean
---@field once boolean
---@field silent boolean
---@field callbacks Callback[]
---@field filetype string
---@field mode string|string[]
---@field wrapper WrapperFn
---@field _registered boolean

---@class Callback
---@field id string
---@field desc string
---@field once boolean
---@field filetype string
---@field handler HandlerFn
---@field enabled boolean
---@field buffer number
---@field index number
---@field priority number

---@class KeyMapOptionsArg
---@field desc ?string
---@field mode ?string|table
---@field noremap ?boolean
---@field once ?boolean
---@field silent ?boolean
---@field filetype ?string
---@field [1] string
---@field [2] ?(fun(): nil)

---@class CallbackOptionsArg
---@field name ?string
---@field desc ?string
---@field once ?boolean
---@field enabled ?boolean
---@field filetype ?string
---@field buffer ?number
---@field priority ?number

---@type table<string, KeyMap>
local g_maps = {}

---@type string[]
local g_mapsIds = {}

---@type table<string, string[]>
local g_registered_keymode = {}

local M = {}

local idx = 0

local function make_id()
	idx = idx + 1
	return tostring(idx)
end

local function make_identifier_for_keymode(key, mode)
	mode = vim.inspect(mode)
	key = vim.inspect(key)

	local identifier = ("%s-%s"):format(mode, key)

	return identifier
end

---@param keymode_identifier string
local function is_keymode_registered(keymode_identifier)
	return g_registered_keymode[keymode_identifier]
end

local function is_callable(var)
	if type(var) == "function" then
		return true
	end

	if type(var) ~= "table" then
		return false
	end

	return getmetatable(var) ~= nil and getmetatable(var).__call ~= nil
end

---@param opts KeyMapOptionsArg
function M.create(opts)
	assert(opts.desc, "opts.desc must be a string")
	assert(type(opts[1]) == "string", "opts[1] must be a string for key")
	assert(not opts[2] or type(opts[2]) == "function", "opts[2] must be a function")

	local mode = opts.mode or "n"
	local key = opts[1]

	local keymodeIdentifier = make_identifier_for_keymode(key, mode)

	local id = ("%s-%s-%s"):format(vim.inspect(mode), key, make_id())

	if is_keymode_registered(keymodeIdentifier) then
		---@type KeyMap
		local keymap = {
			id = id,
			callbacks = {},
			desc = opts.desc,
			filetype = opts.filetype,
			mode = mode,
			noremap = opts.noremap or false,
			once = opts.once == true,
			wrapper = opts[2],
			key = key,
			enabled = true,
			passthrough = opts.passthrough,
			_registered = true,
			condition = opts.condition,
		}

		g_maps[id] = keymap
		table.insert(g_mapsIds, id)

		table.insert(g_registered_keymode[keymodeIdentifier], id)

		return keymap
	end

	---@type KeyMap
	local keymap = {
		id = id,
		callbacks = {},
		desc = opts.desc,
		filetype = opts.filetype,
		mode = mode,
		noremap = opts.noremap or false,
		once = opts.once == true,
		wrapper = opts[2],
		key = key,
		enabled = true,
		passthrough = opts.passthrough,
		_registered = false,
		condition = opts.condition,
	}

	g_maps[id] = keymap
	table.insert(g_mapsIds, id)

	if not g_registered_keymode[keymodeIdentifier] then
		g_registered_keymode[keymodeIdentifier] = {}
	end

	table.insert(g_registered_keymode[keymodeIdentifier], id)

	return keymap
end

---@param keymap KeyMap
function M.invoke(keymap, ctx)
	---@param ctx table
	---@param wrapper WrapperFn|nil
	---@param callback Callback
	local function forwarder(ctx, wrapper, callback)
		if not wrapper then
			return callback.handler(ctx)
		end

		local forward = setmetatable({}, {
			__newindex = function(_, k, v)
				ctx[k] = v
			end,
			__call = function()
				return callback.handler(ctx)
			end,
		})

		return wrapper(forward)
	end

	local buf = vim.api.nvim_get_current_buf()
	--TODO: Ensure __index?

	local toRemove = {}

	table.sort(keymap.callbacks, function(a, b)
		return a.priority > b.priority
	end)

	for _, callback in ipairs(keymap.callbacks) do
		if not callback.enabled then
			goto continue
		end

		if callback.buffer and callback.buffer ~= buf then
			goto continue
		end

		if callback.filetype and callback.filetype ~= vim.bo[buf].filetype then
			goto continue
		end

		local result = forwarder(ctx, keymap.wrapper, callback)

		if callback.once then
			table.insert(toRemove, callback)
		end

		if result == true then
			break
		end

		::continue::
	end

	for _, callback in ipairs(toRemove) do
		M.remove_handler(keymap.id, callback.id)
	end

	if keymap.once then
		M.remove_keymap(keymap.id)
	end
end

---@param key string
function M.resolve_all_keymap_by_key(key)
	local out = {}

	for _, index in pairs(g_mapsIds) do
		local keymap = g_maps[index]
		if keymap.key == key then
			local packed = M.pack(keymap)
			table.insert(out, packed)
		end
	end

	return out
end

---@param buf number
function M.remove_callback_by_buffer(buf)
	---@type {keymap: KeyMap, callbacks: Callback[]}
	local to_remove = {}
	for _, map in pairs(g_maps) do
		for _, cb in ipairs(map.callbacks) do
			if cb.buffer == buf then
				table.insert(to_remove, {
					keymap = map,
					callbacks = cb,
				})
			end
		end
	end

	for _, item in ipairs(to_remove) do
		local map, callback = item.keymap, item.callbacks
		M.remove_handler(map.id, callback.id)
	end
end

---@param keymap KeyMap
function M.pack(keymap)
	return {
		id = keymap.id,
		key = keymap.key,
		desc = keymap.desc,
		mode = keymap.mode,

		---@param cb Callback
		callbacks = vim.tbl_map(function(cb)
			---@type Callback
			return {
				buffer = cb.buffer,
				desc = cb.desc,
				enabled = cb.enabled,
				filetype = cb.filetype,
				name = cb.name,
				once = cb.once,
				handler = cb.handler,
			}
		end, keymap.callbacks),
	}
end

---@param keymap_id string
function M.remove_keymap(keymap_id)
	local map = g_maps[keymap_id]
	if not map then
		return
	end

	local keymodeIdentifier = make_identifier_for_keymode(map.key, map.mode)

	local sharedKeymode = g_registered_keymode[keymodeIdentifier]

	for id, keymodeId in ipairs(g_registered_keymode[keymodeIdentifier]) do
		if keymodeId == map.id then
			table.remove(g_registered_keymode[keymodeIdentifier], id)
			map.callbacks = {}
			break
		end
	end

	if #sharedKeymode > 0 then
		return
	end

	map._registered = false
	pcall(vim.keymap.del, map.mode, map.key, {})
end

---@param keymap_id string
---@param handler HandlerFn
---@param opts CallbackOptionsArg
---@return Callback
function M.add_handler(keymap_id, handler, opts)
	local keymap = M.resolve(keymap_id)

	if not keymap then
		error("keymap not found")
	end

	local index = #keymap.callbacks + 1

	local theHandler = is_callable(handler) and handler or function()
		vim.cmd(handler)
	end

	local filetype = keymap.filetype or opts.filetype
	local once = (keymap.once ~= nil) and keymap.once or opts.once

	---@type Callback
	local callback = {
		id = make_id(),
		index = index,
		name = opts.name,
		desc = opts.desc,
		filetype = filetype,
		once = once,
		handler = theHandler,
		buffer = opts.buffer,
		enabled = (opts.enabled == nil) or (opts.enabled == true),
		priority = opts.priority or 0,
	}

	table.insert(keymap.callbacks, callback)

	return callback
end

---@param keymap_id string
---@param handler_id string
function M.remove_handler(keymap_id, handler_id)
	local keymap = M.resolve(keymap_id)

	if not keymap then
		error("keymap not found when removing handler")
	end

	local to_delete = nil
	for i, cb in ipairs(keymap.callbacks) do
		if cb.id == handler_id then
			to_delete = i
			break
		end
	end

	if not to_delete then
		error("handler not found")
	end

	table.remove(keymap.callbacks, to_delete)

	if #keymap.callbacks == 0 then
		-- vim.keymap.del(keymap.mode, keymap.key, { })
		-- keymap._registered = false
		M.remove_keymap(keymap.id)
	end
end

function M.resolve_keymaps_by_keymod(key, mode)
	local keymodeIdentifier = make_identifier_for_keymode(key, mode)

	if not g_registered_keymode[keymodeIdentifier] then
		return
	end

	local keymap_ids = g_registered_keymode[keymodeIdentifier]

	local out = {}

	for _, id in ipairs(keymap_ids) do
		local keymap = M.resolve(id)
		table.insert(out, keymap)
	end

	return out
end

function M.register(keymap_id)
	local keymap = M.resolve(keymap_id)

	if not keymap then
		error("keymap not found")
	end

	local key = keymap.key
	local mode = keymap.mode

	local keymodeIdentifier = make_identifier_for_keymode(key, mode)

	if keymap._registered then
		if not vim.list_contains(g_registered_keymode[keymodeIdentifier], keymap.id) then
			table.insert(g_registered_keymode[keymodeIdentifier], keymap.id)
		end
		return
	end

	keymap._registered = true

	local key = keymap.key
	local mode = keymap.mode

	local keymodeIdentifier = make_identifier_for_keymode(key, mode)

	if not vim.list_contains(g_registered_keymode[keymodeIdentifier], keymap.id) then
		table.insert(g_registered_keymode[keymodeIdentifier], keymap.id)
	end

	local opts = {
		desc = keymap.desc,
		noremap = keymap.noremap,
		silent = keymap.silent == nil or keymap.silent == false,
	}

	local ctx = {}

	vim.keymap.set(mode, key, function()
		local keymapIds = g_registered_keymode[keymodeIdentifier]

		local ft = vim.bo.filetype

		if keymap.filetype and keymap.filetype ~= ft then
			return
		end

		local function canRun(keymap)
			if not keymap.condition then
				return true
			end

			if type(keymap.condition) ~= "function" then
				return false
			end

			return keymap.condition()
		end

		local should_passthrough = false
		for _, keymapId in ipairs(keymapIds) do
			local theKeymap = M.resolve(keymapId)
			if canRun(theKeymap) then
				M.invoke(theKeymap, ctx)
			end

			if theKeymap.passthrough then
				local passthrough_result = theKeymap.passthrough
				if type(passthrough_result) == "function" then
					if passthrough_result() then
						should_passthrough = true
					end
				else
					should_passthrough = true
				end
			end
		end

		if should_passthrough then
			vim.api.nvim_feedkeys(key, "nx", false)
		end
	end, opts)
end

---@return KeyMap|nil
function M.resolve(keymap_id)
	return g_maps[keymap_id]
end

---@return Callback|nil
function M.resolve_callback_by_name(keymap_id, name)
	local keymap = M.resolve(keymap_id)
	assert(keymap, "keymap not found")
	for _, cb in ipairs(keymap.callbacks) do
		if cb.name == name then
			return cb
		end
	end
end

return M
