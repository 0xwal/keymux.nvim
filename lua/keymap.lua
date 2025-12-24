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
---@field pattern string
---@field condition fun(): boolean
---@field passthrough boolean|fun(): boolean
---@field mode string|string[]
---@field wrapper WrapperFn
---@field _registered boolean

---@class Callback
---@field id string
---@field desc string
---@field once boolean
---@field filetype string
---@field pattern string
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
---@field passthrough ?boolean|fun(): boolean
---@field condition fun(): boolean
---@field silent ?boolean
---@field filetype ?string
---@field pattern ?string
---@field [1] string
---@field [2] ?(fun(): nil)

---@class CallbackOptionsArg
---@field name ?string
---@field desc ?string
---@field once ?boolean
---@field enabled ?boolean
---@field filetype ?string
---@field pattern ?string
---@field buffer ?number
---@field priority ?number

---@type table<string, KeyMap>
local g_maps = {}

---@type string[]
local g_maps_ids = {}

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

local function can_run(keymap)
	if not keymap.condition then
		return true
	end

	if type(keymap.condition) ~= "function" then
		return false
	end

	return keymap.condition()
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

local function matches_pattern(pattern, filename)
	if not pattern or not filename then
		return false
	end
	
	local lua_pattern = pattern
	
	lua_pattern = lua_pattern:gsub("([%^%$%(%)%%%.%[%]%{%}%+%-%?])", "%%%1")
	
	lua_pattern = lua_pattern:gsub("%*", ".*")
	
	lua_pattern = "^" .. lua_pattern .. "$"
	
	return filename:match(lua_pattern) ~= nil
end

local function on_duplicate(keymaps, key, mode, config)
	local descs = {}
	for _, keymap in ipairs(keymaps) do
		table.insert(descs, ('"%s"'):format(keymap.desc))
	end
	local desc_list = table.concat(descs, ", ")
	local formatted_message = ("Duplicate keymap detected: %s (%s mode): %s"):format(key, mode, desc_list)

	vim.notify(formatted_message, vim.log.levels.WARN)
end

---Detect duplicate keymaps for a given key and mode
---@param mode string
---@param key string
---@return KeyMap[] Array of duplicate keymaps (including existing ones), or empty table if no duplicates
function M.detect_duplicates(mode, key)
	local keymode_identifier = make_identifier_for_keymode(key, mode)
	local existing_keymaps = g_registered_keymode[keymode_identifier]

	if not existing_keymaps or #existing_keymaps == 0 then
		return {}
	end

	-- Return existing keymaps in registration order
	local all_keymaps = {}
	for _, existing_id in ipairs(existing_keymaps) do
		local keymap = g_maps[existing_id]
		if keymap then
			table.insert(all_keymaps, {
				key = keymap.key,
				mode = keymap.mode,
				desc = keymap.desc,
			})
		end
	end

	return all_keymaps
end

---@param opts KeyMapOptionsArg
---@param config ?table
function M.create(opts, config)
	assert(opts.desc, "opts.desc must be a string")
	assert(type(opts[1]) == "string", "opts[1] must be a string for key")
	assert(not opts[2] or type(opts[2]) == "function", "opts[2] must be a function")

	local mode = opts.mode or "n"
	local key = opts[1]

	local keymode_identifier = make_identifier_for_keymode(key, mode)

	local id = ("%s-%s-%s"):format(vim.inspect(mode), key, make_id())

	if config and config.duplicate and config.duplicate.detect then
		local on_dup = is_callable(config.duplicate.on_duplicate) and config.duplicate.on_duplicate
			or function(keymaps)
				on_duplicate(keymaps, key, mode, config)
			end
		local existing_keymaps = M.detect_duplicates(mode, key)
		if existing_keymaps and #existing_keymaps > 0 then
			local current_keymap = {
				key = key,
				desc = opts.desc,
				mode = mode,
			}
			local all_keymaps = vim.deepcopy(existing_keymaps)
			table.insert(all_keymaps, current_keymap)

			on_dup(all_keymaps)
		end
	end

	local all_same_keymaps = is_keymode_registered(keymode_identifier)
	if all_same_keymaps then
		---@type KeyMap
		local keymap = {
			id = id,
			callbacks = {},
			desc = opts.desc,
			filetype = opts.filetype,
			pattern = opts.pattern,
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
table.insert(g_maps_ids, id)

table.insert(g_registered_keymode[keymode_identifier], id)

		return keymap
	end

	---@type KeyMap
		local keymap = {
			id = id,
			callbacks = {},
			desc = opts.desc,
			filetype = opts.filetype,
			pattern = opts.pattern,
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
	table.insert(g_maps_ids, id)

	if not g_registered_keymode[keymode_identifier] then
		g_registered_keymode[keymode_identifier] = {}
	end

	table.insert(g_registered_keymode[keymode_identifier], id)

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

	local to_remove = {}

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

		if callback.pattern then
			local filename = vim.api.nvim_buf_get_name(buf)
			if filename == "" or not matches_pattern(callback.pattern, vim.fn.fnamemodify(filename, ":t")) then
				goto continue
			end
		end

		local result = forwarder(ctx, keymap.wrapper, callback)

		if callback.once then
			table.insert(to_remove, callback)
		end

		if result == true then
			break
		end

		::continue::
	end

	for _, callback in ipairs(to_remove) do
		M.remove_handler(keymap.id, callback.id)
	end

	if keymap.once then
		M.remove_keymap(keymap.id)
	end
end

---@param key string
function M.resolve_all_keymap_by_key(key)
	local out = {}

	for _, index in pairs(g_maps_ids) do
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
	---@type {keymap: KeyMap, callback: Callback[]}
	local to_remove = {}
	for _, map in pairs(g_maps) do
		for _, cb in ipairs(map.callbacks) do
			if cb.buffer == buf then
				table.insert(to_remove, {
					keymap = map,
					callback = cb,
				})
			end
		end
	end

	for _, item in ipairs(to_remove) do
		local map, callback = item.keymap, item.callback
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
		condition = keymap.condition,
		passthrough = keymap.passthrough,

		---@param cb Callback
		callbacks = vim.tbl_map(function(cb)
			---@type Callback
			return {
				buffer = cb.buffer,
				desc = cb.desc,
				enabled = cb.enabled,
				filetype = cb.filetype,
				pattern = cb.pattern,
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

	local keymode_identifier = make_identifier_for_keymode(map.key, map.mode)

	local shared_keymode = g_registered_keymode[keymode_identifier]

	for id, keymode_id in ipairs(g_registered_keymode[keymode_identifier]) do
		if keymode_id == map.id then
			table.remove(g_registered_keymode[keymode_identifier], id)
			map.callbacks = {}
			break
		end
	end

	if #shared_keymode > 0 then
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

	local the_handler = is_callable(handler) and handler or function()
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
		pattern = opts.pattern,
		once = once,
		handler = the_handler,
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
	local keymode_identifier = make_identifier_for_keymode(key, mode)

	if not g_registered_keymode[keymode_identifier] then
		return
	end

	local keymap_ids = g_registered_keymode[keymode_identifier]

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

local keymode_identifier = make_identifier_for_keymode(key, mode)

	local registered_keymaps = vim.tbl_filter(function(keymap_id)
		return g_maps[keymap_id]._registered
	end, is_keymode_registered(keymode_identifier))

	if #registered_keymaps > 0 then
		if not vim.list_contains(g_registered_keymode[keymode_identifier], keymap.id) then
			table.insert(g_registered_keymode[keymode_identifier], keymap.id)
		end

		return
	end

	keymap._registered = true

	local key = keymap.key
	local mode = keymap.mode

	local keymode_identifier = make_identifier_for_keymode(key, mode)

	if not vim.list_contains(g_registered_keymode[keymode_identifier], keymap.id) then
		table.insert(g_registered_keymode[keymode_identifier], keymap.id)
	end

	local opts = {
		desc = keymap.desc,
		noremap = keymap.noremap,
		silent = keymap.silent == nil or keymap.silent == false,
	}

	local ctx = {}

	vim.keymap.set(mode, key, function()
		local keymap_ids = g_registered_keymode[keymode_identifier]

		local ft = vim.bo.filetype

		if keymap.filetype and keymap.filetype ~= ft then
			return
		end

		if keymap.pattern then
			local filename = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
			if filename == "" or not matches_pattern(keymap.pattern, vim.fn.fnamemodify(filename, ":t")) then
				return
			end
		end

		local should_passthrough = false
		for _, keymap_id in ipairs(keymap_ids) do
			local the_keymap = M.resolve(keymap_id)
			if can_run(the_keymap) then
				M.invoke(the_keymap, ctx)
			end

if the_keymap.passthrough then
			local passthrough_result = the_keymap.passthrough
				should_passthrough = (type(passthrough_result) ~= "function") or passthrough_result()
			end
		end

		if should_passthrough then
			vim.api.nvim_feedkeys(key, "n", false)
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
