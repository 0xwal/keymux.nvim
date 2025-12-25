local assert = require("luassert")
local match = require("luassert.match")
local spy = require("luassert.spy")

local say = require("say")
assert:set_parameter("TableFormatLevel", -1)

local function compare_nested_unordered(t1, t2)
	local function istable(t)
		return type(t) == "table"
	end

	local function deep_compare(a, b)
		if a == b then
			return true
		end
		if not istable(a) or not istable(b) then
			return false
		end

		for k, v in pairs(a) do
			if b[k] == nil then
				return false
			end
			if not deep_compare(v, b[k]) then
				return false
			end
		end
		for k, v in pairs(b) do
			if a[k] == nil then
				return false
			end
		end
		return true
	end

	if #t1 ~= #t2 then
		return false
	end

	local matched = {}
	for _, v1 in ipairs(t1) do
		local found = false
		for i2, v2 in ipairs(t2) do
			if not matched[i2] and deep_compare(v1, v2) then
				matched[i2] = true
				found = true
				break
			end
		end
		if not found then
			return false
		end
	end

	return true
end

local function same_unordered(state, args, level)
	local a, b = args[1], args[2]
	return compare_nested_unordered(a, b)
end

say:set("assertion.same_unordered.positive", "Expected arrays to be the same.")
say:set("assertion.same_unordered.negative", "Expected arrays to not be the same.")
assert:register(
	"assertion",
	"same_unordered",
	same_unordered,
	"assertion.same_unordered.positive",
	"assertion.same_unordered.negative"
)

describe("keymap", function()
	local M
	local init_buf

	-- #region pre test

	setup(function()
		init_buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_current_buf(init_buf)

		package.path = ("%s;lua/?.lua"):format(package.path)
	end)

	before_each(function()
		spy.on(vim.keymap, "set")
		spy.on(vim.keymap, "del")

		package.loaded["keymux"] = nil
		package.loaded["keymap"] = nil
		M = require("keymux")
		M.setup()
	end)
	-- #endregion

	-- #region test case

	it("#1-1 can register keymap", function()
		local k = M.k({
			"ff",
			desc = "a keymap",
		})

		local cb = spy()

		k(cb)

		do -- check if registered
			assert.spy(vim.keymap.set).was_called(1)
			assert
				.spy(vim.keymap.set)
				.was_called_with("n", "ff", match.is_function(), match.same({ desc = "a keymap", noremap = false, silent = true }))
		end

		do -- check if it called
			vim.api.nvim_feedkeys("ff", "x", false)
			vim.api.nvim_feedkeys("ff", "x", false)

			assert.spy(cb).was_called(2)
		end
	end)

	-- NOTE: this non-sense now, maybe later. two keymap with same mode can uses different filetype
	-- it("#1-2 can register multiple keymaps with same key but different filetype", function()
	-- 	local k1 = M.k({
	-- 		"ff",
	-- 		desc = "a keymap",
	-- 		filetype = "rust",
	-- 	})
	--
	-- 	local k2 = M.k({
	-- 		"ff",
	-- 		desc = "a keymap",
	-- 		filetype = "lua",
	-- 	})
	--
	-- 	local cb_rust = spy()
	-- 	local cb_lua = spy()
	--
	-- 	k1(cb_rust)
	-- 	k2(cb_lua)
	--
	-- 	do -- check if registered
	-- 		assert.spy(vim.keymap.set).was_called(1)
	-- 		assert.spy(vim.keymap.set).was_called_with(
	-- 			"n",
	-- 			"ff",
	-- 			match.is_function(),
	-- 			match.same({ desc = "a keymap", noremap = false, silent = true })
	-- 		)
	-- 	end
	--
	-- 	do -- check if it called
	-- 		local rust_buf = vim.api.nvim_create_buf(false, false)
	-- 		vim.api.nvim_buf_call(rust_buf, function()
	-- 			vim.api.nvim_feedkeys("ff", "x", false)
	-- 		end)
	--
	-- 		local lua_buf = vim.api.nvim_create_buf(false, false)
	-- 		vim.api.nvim_buf_call(lua_buf, function()
	-- 			vim.api.nvim_feedkeys("ff", "x", false)
	-- 		end)
	--
	--
	-- 		assert.spy(cb_rust).was_called(1)
	-- 		assert.spy(cb_lua).was_called(1)
	-- 	end
	-- end)

	it("#1-3 when registering two different keymaps key and mode", function()
		local k1 = M.k({
			"ff",
			desc = "a keymap 1",
		})

		local k2 = M.k({
			"ff",
			desc = "a keymap 2",
		})

		local cb1 = spy()
		local cb2 = spy()

		k1(cb1)
		k2(cb2)

		do -- check if registered
			assert.spy(vim.keymap.set).was_called(1)
			assert
				.spy(vim.keymap.set)
				.was_called_with("n", "ff", match.is_function(), match.same({ desc = "a keymap 1", noremap = false, silent = true }))
		end

		do -- check if it called
			vim.api.nvim_feedkeys("ff", "x", false)
			vim.api.nvim_feedkeys("ff", "x", false)

			assert.spy(cb1).was_called(2)
			assert.spy(cb2).was_called(2)
		end
	end)

	-- #endregion

	-- #region test case
	it("#2 expect desc to be added", function()
		assert.was_error(function()
			M.k({
				"ff",
			})
		end, "opts.desc must be a string")
	end)
	-- #endregion

	-- #region test case
	-- it("#3 can pass `#noremap` `#silent` when declaring", function()
	-- 	local k = M.k({
	-- 		"ff",
	-- 		desc = "a keymap",
	-- 		silent = false,
	-- 		noremap = true,
	-- 	})
	--
	-- 	local cb = spy()
	--
	-- 	k(cb)
	--
	-- 	do -- check if registered
	-- 		assert.spy(vim.keymap.set).was_called(1)
	-- 		assert.spy(vim.keymap.set).was_called_with(
	-- 			"n",
	-- 			"ff",
	-- 			match.is_function(),
	-- 			match.same({ desc = "a keymap", noremap = true, silent = false })
	-- 		)
	-- 	end
	--
	-- 	do -- check if it called
	-- 		vim.api.nvim_feedkeys("ff", "x", false)
	-- 		vim.api.nvim_feedkeys("ff", "x", false)
	--
	-- 		assert.spy(cb).was_called(2)
	-- 	end
	-- end)

	-- #endregion

	-- #region test case
	-- NOTE: this doesn't make sense, as keymap.set happens once
	-- it("#4 can pass `#noremap` `#silent` when defining", function()
	-- 	local k = M.k({
	-- 		"ff",
	-- 		desc = "a keymap",
	-- 	})
	--
	-- 	local cb = spy()
	--
	-- 	k(cb, { noremap = true })
	--
	-- 	do -- check if registered
	-- 		assert.spy(vim.keymap.set).was_called(1)
	-- 		assert.spy(vim.keymap.set).was_called_with(
	-- 			"n",
	-- 			"ff",
	-- 			match.is_function(),
	-- 			match.same({ desc = "a keymap", noremap = true, silent = true })
	-- 		)
	-- 	end
	--
	-- 	do -- check if it called
	-- 		vim.api.nvim_feedkeys("ff", "x", false)
	-- 		vim.api.nvim_feedkeys("ff", "x", false)
	--
	-- 		assert.spy(cb).was_called(2)
	-- 	end
	-- end)
	-- #endregion

	-- #region test case
	it("#5 can add multiple handlers to a keymap", function()
		local k = M.k({
			"ff",
			desc = "a keymap",
		})

		local cb1 = spy()
		local cb2 = spy()

		k(cb1)
		k(cb2)

		do -- check if registered
			assert.spy(vim.keymap.set).was_called(1)
			assert
				.spy(vim.keymap.set)
				.was_called_with("n", "ff", match.is_function(), match.same({ desc = "a keymap", noremap = false, silent = true }))
		end

		do -- check if it called
			vim.api.nvim_feedkeys("ff", "x", false)
			vim.api.nvim_feedkeys("ff", "x", false)

			assert.spy(cb1).was_called(2)
			assert.spy(cb2).was_called(2)
		end
	end)
	-- #endregion

	-- #region test case
	it("#6 can pass ctx", function()
		local k = M.k({
			"ff",
			desc = "a keymap",
		})

		local cb1 = stub().invokes(function(ctx)
			ctx.a = 1
		end)

		local cb2 = stub().invokes(function(ctx)
			ctx.b = 2
		end)

		k(cb1)
		k(cb2)

		do -- check if registered
			assert.spy(vim.keymap.set).was_called(1)
			assert
				.spy(vim.keymap.set)
				.was_called_with("n", "ff", match.is_function(), match.same({ desc = "a keymap", noremap = false, silent = true }))
		end

		do -- check if it called
			vim.api.nvim_feedkeys("ff", "x", false)

			assert.spy(cb1).was_called_with(match.same({}))
			assert.spy(cb2).was_called_with(match.same({ a = 1 }))

			vim.api.nvim_feedkeys("ff", "x", false)
			assert.spy(cb2).was_called_with(match.same({ a = 1, b = 2 }))
		end
	end)

	it("#7 can pass #ctx with wrapper", function()
		local k = M.k({
			"ff",
			desc = "a keymap",
			function(handler)
				handler.a = 100
				handler()
			end,
		})

		local cb1 = stub()
		local cb2 = stub()

		k(cb1)
		k(cb2)

		do -- check if it called
			vim.api.nvim_feedkeys("ff", "x", false)

			assert.spy(cb1).was_called_with(match.same({ a = 100 }))
			assert.spy(cb2).was_called_with(match.same({ a = 100 }))

			vim.api.nvim_feedkeys("ff", "x", false)
			assert.spy(cb2).was_called_with(match.same({ a = 100 }))
		end
	end)

	-- #endregion

	-- #region test case
	it("#8-1 can register to specific #buffer", function()
		local k = M.k({
			"ff",
			desc = "a keymap",
		})

		local cb1 = stub()
		local cb2 = stub()

		local target_buffer = vim.api.nvim_create_buf(false, false)

		k(cb1, { name = "cb1", buffer = target_buffer })
		k(cb2, { name = "cb2" })
		--
		do -- check if registered
			assert.spy(vim.keymap.set).was_called(1)
			assert.spy(vim.keymap.set).was_called_with(
				"n",
				"ff",
				match.is_function(),
				match.same({
					desc = "a keymap",
					noremap = false,
					silent = true,
				})
			)
		end

		do -- check if it called
			vim.api.nvim_buf_call(target_buffer, function()
				vim.api.nvim_feedkeys("ff", "x", true)
			end)

			vim.api.nvim_buf_call(init_buf, function()
				vim.api.nvim_feedkeys("ff", "x", true)
			end)

			assert.spy(cb1).was_called(1)

			assert.spy(cb2).was_called(2)
		end
	end)

	it("#8-2 clean the keymap handler when #buffer closed", function()
		local k = M.k({
			"ff",
			desc = "a keymap",
		})

		local cb1 = stub()
		local cb2 = stub()

		local target_buffer = vim.api.nvim_create_buf(false, false)

		k(cb1, { buffer = target_buffer })
		k(cb2)

		do
			vim.api.nvim_buf_delete(target_buffer, { unload = true })

			vim.api.nvim_buf_call(init_buf, function()
				vim.api.nvim_feedkeys("ff", "x", true)
			end)

			local keymap = M.inspect("ff")

			assert.equals(1, #keymap)
			assert.equals(1, #keymap[1].callbacks)

			assert.spy(cb2).was_called(1)
		end
	end)

	-- #endregion

	-- #region test case
	it("#9 can register to specific #filetype when declaring", function()
		local k = M.k({
			"ff",
			desc = "a keymap",
			filetype = "rust",
		})

		local cb = stub()

		local target_buffer = vim.api.nvim_create_buf(false, false)

		vim.api.nvim_set_option_value("filetype", "rust", {
			buf = target_buffer,
		})

		k(cb)
		--
		do -- check if registered
			assert.spy(vim.keymap.set).was_called(1)
			assert.spy(vim.keymap.set).was_called_with(
				"n",
				"ff",
				match.is_function(),
				match.same({
					desc = "a keymap",
					noremap = false,
					silent = true,
				})
			)
		end

		do -- check if it called
			vim.api.nvim_buf_call(target_buffer, function()
				vim.api.nvim_feedkeys("ff", "x", true)
				vim.api.nvim_feedkeys("ff", "x", true)
			end)

			vim.api.nvim_buf_call(init_buf, function()
				vim.api.nvim_feedkeys("ff", "x", true)
			end)

			assert.spy(cb).was_called(2)
		end
	end)
	-- #endregion

	-- #region test case
	it("#10 can register to specific #filetype when defining", function()
		local k = M.k({
			"ff",
			desc = "a keymap",
		})

		local cb1 = stub()
		local cb2 = stub()

		local target_buffer = vim.api.nvim_create_buf(false, false)

		vim.api.nvim_set_option_value("filetype", "rust", {
			buf = target_buffer,
		})

		k(cb1, { filetype = "rust" })
		k(cb2)

		do -- check if registered
			assert.spy(vim.keymap.set).was_called(1)
			assert.spy(vim.keymap.set).was_called_with(
				"n",
				"ff",
				match.is_function(),
				match.same({
					desc = "a keymap",
					noremap = false,
					silent = true,
				})
			)
		end

		do -- check if it called
			vim.api.nvim_buf_call(target_buffer, function()
				vim.api.nvim_feedkeys("ff", "x", true)
			end)

			vim.api.nvim_buf_call(init_buf, function()
				vim.api.nvim_feedkeys("ff", "x", true)
			end)

			assert.spy(cb1).was_called(1)

			assert.spy(cb2).was_called(2)
		end
	end)
	-- #endregion

	-- #region test case
	describe("filetype arrays", function()
		it("can register to specific #filetype array when declaring", function()
			local k = M.k({
				"ff",
				desc = "a keymap",
				filetype = { "rust", "python" },
			})

			local cb = stub()

			local rust_buffer = vim.api.nvim_create_buf(false, false)
			local python_buffer = vim.api.nvim_create_buf(false, false)
			local js_buffer = vim.api.nvim_create_buf(false, false)

			vim.api.nvim_set_option_value("filetype", "rust", { buf = rust_buffer })
			vim.api.nvim_set_option_value("filetype", "python", { buf = python_buffer })
			vim.api.nvim_set_option_value("filetype", "javascript", { buf = js_buffer })

			k(cb)

			do -- check if called for rust buffer
				vim.api.nvim_buf_call(rust_buffer, function()
					vim.api.nvim_feedkeys("ff", "x", true)
				end)
				assert.spy(cb).was_called(1)
			end

			cb:clear()

			do -- check if called for python buffer
				vim.api.nvim_buf_call(python_buffer, function()
					vim.api.nvim_feedkeys("ff", "x", true)
				end)
				assert.spy(cb).was_called(1)
			end

			cb:clear()

			do -- check if not called for javascript buffer
				vim.api.nvim_buf_call(js_buffer, function()
					vim.api.nvim_feedkeys("ff", "x", true)
				end)
				assert.spy(cb).was_called(0)
			end

			vim.api.nvim_buf_delete(rust_buffer, { force = true })
			vim.api.nvim_buf_delete(python_buffer, { force = true })
			vim.api.nvim_buf_delete(js_buffer, { force = true })
		end)

		it("can register to specific #filetype array when defining", function()
			local k = M.k({
				"ff",
				desc = "a keymap",
			})

			local cb1 = stub()
			local cb2 = stub()

			local rust_buffer = vim.api.nvim_create_buf(false, false)
			local python_buffer = vim.api.nvim_create_buf(false, false)
			local js_buffer = vim.api.nvim_create_buf(false, false)

			vim.api.nvim_set_option_value("filetype", "rust", { buf = rust_buffer })
			vim.api.nvim_set_option_value("filetype", "python", { buf = python_buffer })
			vim.api.nvim_set_option_value("filetype", "javascript", { buf = js_buffer })

			k(cb1, { filetype = { "rust", "python" } })
			k(cb2)

			do -- rust buffer should trigger both callbacks
				vim.api.nvim_buf_call(rust_buffer, function()
					vim.api.nvim_feedkeys("ff", "x", true)
				end)
				assert.spy(cb1).was_called(1)
				assert.spy(cb2).was_called(1)
			end

			cb1:clear()
			cb2:clear()

			do -- python buffer should trigger both callbacks
				vim.api.nvim_buf_call(python_buffer, function()
					vim.api.nvim_feedkeys("ff", "x", true)
				end)
				assert.spy(cb1).was_called(1)
				assert.spy(cb2).was_called(1)
			end

			cb1:clear()
			cb2:clear()

			do -- javascript buffer should only trigger cb2
				vim.api.nvim_buf_call(js_buffer, function()
					vim.api.nvim_feedkeys("ff", "x", true)
				end)
				assert.spy(cb1).was_called(0)
				assert.spy(cb2).was_called(1)
			end

			vim.api.nvim_buf_delete(rust_buffer, { force = true })
			vim.api.nvim_buf_delete(python_buffer, { force = true })
			vim.api.nvim_buf_delete(js_buffer, { force = true })
		end)

		it("can mix string and array filetype declarations", function()
			local k1 = M.k({
				"ff",
				desc = "keymap with string filetype",
				filetype = "rust",
			})

			local k2 = M.k({
				"ff",
				desc = "keymap with array filetype",
				filetype = { "python", "javascript" },
			})

			local cb1 = stub()
			local cb2 = stub()

			local rust_buffer = vim.api.nvim_create_buf(false, false)
			local python_buffer = vim.api.nvim_create_buf(false, false)

			vim.api.nvim_set_option_value("filetype", "rust", { buf = rust_buffer })
			vim.api.nvim_set_option_value("filetype", "python", { buf = python_buffer })

			k1(cb1)
			k2(cb2)

			do -- rust buffer should only trigger cb1
				vim.api.nvim_buf_call(rust_buffer, function()
					vim.api.nvim_feedkeys("ff", "x", true)
				end)
				assert.spy(cb1).was_called(1)
				assert.spy(cb2).was_called(0)
			end

			cb1:clear()
			cb2:clear()

			do -- python buffer should only trigger cb2
				vim.api.nvim_buf_call(python_buffer, function()
					vim.api.nvim_feedkeys("ff", "x", true)
				end)
				assert.spy(cb1).was_called(0)
				assert.spy(cb2).was_called(1)
			end

			vim.api.nvim_buf_delete(rust_buffer, { force = true })
			vim.api.nvim_buf_delete(python_buffer, { force = true })
		end)
	end)

	-- #endregion

	-- #region test case
	-- it("#11-1 error when declaring multiple keymap with same key", function()
	-- 	M.k({
	-- 		"y7",
	-- 		desc = "a keymap",
	-- 	})
	--
	-- 	assert.was_error(function()
	-- 		M.k({
	-- 			"y7",
	-- 			desc = "a keymap",
	-- 		})
	-- 	end, "Keymap (y7) already registered?")
	-- end)

	-- it("#11-2 it can register if filetype differ", function()
	-- 	M.k({
	-- 		"y7",
	-- 		desc = "a keymap",
	-- 	})
	--
	-- 	M.k({
	-- 		"y7",
	-- 		desc = "a keymap",
	-- 		filetype = "rust",
	-- 	})
	-- end)

	-- it("#11-3 it can register if filetype differ", function()
	-- 	M.k({
	-- 		"y7",
	-- 		desc = "a keymap",
	-- 	})
	--
	-- 	M.k({
	-- 		"y7",
	-- 		desc = "a keymap",
	-- 		duplicate = true,
	-- 	})
	-- end)

	-- #endregion

	-- #region test case
	-- it("#12-1 should able to #remove the callback from the keymap", function()
	-- 	local k = M.k({
	-- 		"ff",
	-- 		desc = "a keymap",
	-- 	})
	--
	-- 	local c1 = spy()
	-- 	local c2 = spy()
	--
	-- 	local k1 = k(c1)
	-- 	local k2 = k(c2)
	--
	-- 	vim.api.nvim_feedkeys("ff", "x", false)
	--
	-- 	k1.del()
	--
	-- 	vim.api.nvim_feedkeys("ff", "x", false)
	--
	-- 	assert.spy(c1).was_called(1)
	-- 	assert.spy(c2).was_called(2)
	--
	-- 	k2.del()
	--
	-- 	assert.spy(vim.keymap.del).was_called(1)
	-- 	assert.spy(vim.keymap.del).was_called_with("n", "ff", { })
	--
	-- 	assert.is_not_nil(M.inspect("ff"))
	-- end)

	it("#12-2 should able to enable/disable callback without removing it", function()
		local k = M.k({
			"ff",
			desc = "a keymap",
		})

		local c1 = spy()
		local c2 = spy()

		local k1 = k(c1)
		k(c2, { name = "c2" })

		k1.disable()
		k("c2").disable()

		vim.api.nvim_feedkeys("ff", "x", false)

		k1.enable()
		k("c2").enable()

		vim.api.nvim_feedkeys("ff", "x", false)

		assert.spy(c1).was_called(1)
		assert.spy(c2).was_called(1)
	end)

	it("#12-3 should able to enable/disable callback when they created as deferred", function()
		local k = M.k({
			"ff",
			desc = "a keymap",
		})

		do -- when resolving
			local c = spy()

			k(c, { name = "c1", defer = true })

			k("c1").disable()

			vim.api.nvim_feedkeys("ff", "x", false)

			k("c1").enable()

			vim.api.nvim_feedkeys("ff", "x", false)

			assert.spy(c).was_called(1)
		end

		do -- when resolving
			local c = spy()

			local k = k(c, { name = "c1", defer = true })

			k.disable()

			vim.api.nvim_feedkeys("ff", "x", false)

			k.enable()

			vim.api.nvim_feedkeys("ff", "x", false)

			assert.spy(c).was_called(1)
		end
	end)

	-- #endregion

	-- #region test case
	it("#13 returns the lazy package manager format", function()
		local k = M.k({
			"ff",
			desc = "a keymap",
			mode = "v",
		})

		local cb = spy()

		local k1 = k(cb)

		assert.equals(k1.lazy_key[1], "ff")
		assert.truthy(type(k1.lazy_key[2]) == "function")
		assert.equals(k1.lazy_key.mode, "v")
	end)
	-- #endregion

	-- #region test case
	it("#14 can register #once callback when #declarting", function()
		local k_once = M.k({
			"ff",
			desc = "a keymap",
			once = true,
		})

		local k = M.k({
			"fk",
			desc = "a keymap",
		})

		local cb1 = spy()
		local cb2 = spy()

		k_once(cb1)
		k(cb2)

		vim.api.nvim_feedkeys("ff", "x", false)
		vim.api.nvim_feedkeys("ff", "x", false)

		vim.api.nvim_feedkeys("fk", "x", false)
		vim.api.nvim_feedkeys("fk", "x", false)

		assert.spy(cb1).was_called(1)
		assert.spy(cb2).was_called(2)
	end)

	it("#15 can register #once callback when #defining", function()
		local k = M.k({
			"ff",
			desc = "a keymap",
		})

		local cb1 = stub()

		local cb2 = stub()

		k(cb1, { once = true, name = "once-handler" })
		k(cb2)

		vim.api.nvim_feedkeys("ff", "x", false)
		vim.api.nvim_feedkeys("ff", "x", false)

		assert.spy(cb1).was_called(1)
		assert.spy(cb2).was_called(2)
	end)

	-- #endregion

	-- #region test case
	it("#16 can add callback as #command string", function()
		local k = M.k({
			"ff",
			desc = "a keymap",
		})

		_G.spy_callback = spy()

		k(":silent! lua spy_callback()")

		vim.api.nvim_feedkeys("ff", "x", false)

		assert.spy(_G.spy_callback).was_called(1)
	end)
	-- #endregion

	-- #region test case
	it("#17 can retrieve info of a keymap", function()
		local vk = M.k({
			"ff",
			desc = "a keymap v",
			mode = "v",
		})

		local nk = M.k({
			"ff",
			desc = "a keymap n",
			mode = "n",
		})

		local cb1 = spy()
		local cb2 = spy()
		vk(cb1, { buffer = 1, name = "cb1" })
		vk(cb2, { filetype = "rust", name = "cb2" })

		nk(cb1, { name = "nk1", once = true })
		nk(cb2, { name = "nk2", desc = "the cb2" })

		assert.is_table(M.inspect("not-valid"))
		assert.equals(0, #M.inspect("not-valid"))

		local t = M.inspect("ff")

		local slimmed = vim.tbl_map(function(item)
			item.id = nil
			return item
		end, t)

		assert.are.same({
			{
				key = "ff",
				mode = "v",
				desc = "a keymap v",
				callbacks = {
					{
						name = "cb1",
						handler = cb1,
						buffer = 1,
						enabled = true,
					},
					{
						name = "cb2",
						handler = cb2,
						filetype = "rust",
						enabled = true,
					},
				},
			},
			{
				key = "ff",
				mode = "n",
				desc = "a keymap n",
				callbacks = {
					{
						handler = cb1,
						once = true,
						enabled = true,
						name = "nk1",
					},
					{
						handler = cb2,
						desc = "the cb2",
						enabled = true,
						name = "nk2",
					},
				},
			},
		}, slimmed)
	end)
	-- #endregion

	-- #region test case
	it("#17-1 can register to specific #pattern when declaring", function()
		local k = M.k({
			"ff",
			desc = "a keymap",
			pattern = ".env",
		})

		local cb = stub()

		local target_buffer = vim.api.nvim_create_buf(false, false)
		vim.api.nvim_buf_set_name(target_buffer, "/path/to/.env")

		k(cb)

		do -- check if registered
			assert.spy(vim.keymap.set).was_called(1)
			assert.spy(vim.keymap.set).was_called_with(
				"n",
				"ff",
				match.is_function(),
				match.same({
					desc = "a keymap",
					noremap = false,
					silent = true,
				})
			)
		end

		do -- check if it called
			vim.api.nvim_buf_call(target_buffer, function()
				vim.api.nvim_feedkeys("ff", "x", true)
				vim.api.nvim_feedkeys("ff", "x", true)
			end)

			vim.api.nvim_buf_call(init_buf, function()
				vim.api.nvim_feedkeys("ff", "x", true)
			end)

			assert.spy(cb).was_called(2)
		end
		vim.api.nvim_buf_delete(target_buffer, { force = true })
	end)

	it("#17-2 can register to specific #pattern when defining", function()
		local k = M.k({
			"ff",
			desc = "a keymap",
		})

		local cb1 = stub()
		local cb2 = stub()

		local target_buffer = vim.api.nvim_create_buf(false, false)
		vim.api.nvim_buf_set_name(target_buffer, "/path/to/.env.test")

		k(cb1, { pattern = ".env*" })
		k(cb2)

		do -- check if registered
			assert.spy(vim.keymap.set).was_called(1)
			assert.spy(vim.keymap.set).was_called_with(
				"n",
				"ff",
				match.is_function(),
				match.same({
					desc = "a keymap",
					noremap = false,
					silent = true,
				})
			)
		end

		do -- check if it called
			vim.api.nvim_buf_call(target_buffer, function()
				vim.api.nvim_feedkeys("ff", "x", true)
			end)

			vim.api.nvim_buf_call(init_buf, function()
				vim.api.nvim_feedkeys("ff", "x", true)
			end)

			assert.spy(cb1).was_called(1)
			assert.spy(cb2).was_called(2)
		end
		vim.api.nvim_buf_delete(target_buffer, { force = true })
	end)

	it("#17-3 can register to specific #pattern with wildcards", function()
		local k = M.k({
			"ff",
			desc = "a keymap",
		})

		local cb1 = stub()
		local cb2 = stub()

		local target_buffer1 = vim.api.nvim_create_buf(false, false)
		vim.api.nvim_buf_set_name(target_buffer1, "/path/to/.env.local")

		local target_buffer2 = vim.api.nvim_create_buf(false, false)
		vim.api.nvim_buf_set_name(target_buffer2, "/path/to/.env.prod")

		k(cb1, { pattern = ".env*" })
		k(cb2)

		do -- check if it called for .env.local
			vim.api.nvim_buf_call(target_buffer1, function()
				vim.api.nvim_feedkeys("ff", "x", true)
			end)

			assert.spy(cb1).was_called(1)
			assert.spy(cb2).was_called(1)
		end

		cb1:clear()
		cb2:clear()

		do -- check if it called for .env
			vim.api.nvim_buf_call(target_buffer2, function()
				vim.api.nvim_feedkeys("ff", "x", true)
			end)

			assert.spy(cb1).was_called(1)
			assert.spy(cb2).was_called(1)
		end
		vim.api.nvim_buf_delete(target_buffer1, { force = true })
		vim.api.nvim_buf_delete(target_buffer2, { force = true })
	end)

	it("#17-4 pattern should not match when filename doesn't match", function()
		local k = M.k({
			"ff",
			desc = "a keymap",
		})

		local cb1 = stub()
		local cb2 = stub()

		local target_buffer = vim.api.nvim_create_buf(false, false)
		vim.api.nvim_buf_set_name(target_buffer, "/path/to/config.txt")

		k(cb1, { pattern = ".env*" })
		k(cb2)

		do -- check if it called
			vim.api.nvim_buf_call(target_buffer, function()
				vim.api.nvim_feedkeys("ff", "x", true)
			end)

			assert.spy(cb1).was_called(0)
			assert.spy(cb2).was_called(1)
		end
		vim.api.nvim_buf_delete(target_buffer, { force = true })
	end)

	it("#17-5 pattern should match in anywhere of the filename when declaring handlers", function()
		local k = M.k({
			"ff",
			desc = "a keymap",
			pattern = "*env*",
		})

		local cb1 = stub()
		local cb2 = stub()

		local target_buffer = vim.api.nvim_create_buf(false, false)
		vim.api.nvim_buf_set_name(target_buffer, "/path/env/config.txt")

		k(cb1)
		k(cb2)

		do -- check if it called
			vim.api.nvim_buf_call(target_buffer, function()
				vim.api.nvim_feedkeys("ff", "x", true)
			end)

			assert.spy(cb1).was_called(1)
			assert.spy(cb2).was_called(1)
		end
		vim.api.nvim_buf_delete(target_buffer, { force = true })
	end)


	it("#17-6 pattern should match in anywhere of the filename when defining handlers", function()
		local k = M.k({
			"ff",
			desc = "a keymap",
		})

		local cb1 = stub()
		local cb2 = stub()

		local target_buffer = vim.api.nvim_create_buf(false, false)
		vim.api.nvim_buf_set_name(target_buffer, "/path/env/config.txt")

		k(cb1, { pattern = "*env*" })
		k(cb2, { pattern = "*path*" })

		do -- check if it called
			vim.api.nvim_buf_call(target_buffer, function()
				vim.api.nvim_feedkeys("ff", "x", true)
			end)

			assert.spy(cb1).was_called(1)
			assert.spy(cb2).was_called(1)
		end
		vim.api.nvim_buf_delete(target_buffer, { force = true })
	end)

	it("#17-8 should allow passthrough when using pattern and not matched", function()
		local k = M.k({
			"l",
			desc = "a keymap",
			pattern = "*env*",
			passthrough = true,
		})

		local cb = stub()

		local target_buffer = vim.api.nvim_create_buf(false, false)
		vim.api.nvim_buf_set_name(target_buffer, "/path/xyz/config.txt")

		k(cb)

		vim.api.nvim_buf_set_lines(target_buffer, 0, -1, false, { "Hello, world!" })

		local win = vim.api.nvim_open_win(target_buffer, true, {
			relative = "editor",
			width = 80,
			height = 20,
			col = 10,
			row = 10,
			style = "minimal",
		})


		do -- check if it called
			vim.api.nvim_buf_call(target_buffer, function()
				vim.api.nvim_feedkeys("l", "x", true)
			end)

			assert.spy(cb).was_called(0)
		end

		local cursor = vim.api.nvim_win_get_cursor(win)
		assert.are.same({ 1, 1 }, cursor)
		vim.api.nvim_win_close(win, { force = true })


		vim.api.nvim_buf_delete(target_buffer, { force = true })
	end)


	-- #endregion

	-- #region test case
	it("#18 can #conditionally register keymap", function()
		M.k({
			"ff",
			desc = "a keymap",
			enabled = function()
				return false
			end,
		})

		M.k({
			"cc",
			desc = "a keymap",
			enabled = function()
				return true
			end,
		})

		assert.is_table(M.inspect("ff"))
		assert.equals(0, #M.inspect("ff"))
		assert.is_not_nil(M.inspect("cc"))
	end)

	it("#18-1 can conditionally execute based on global variable", function()
		local k = M.k({
			"ff",
			desc = "a keymap",
			condition = function()
				return vim.g.xyz
			end,
		})

		local cb = spy()
		k(cb)

		vim.g.xyz = true
		vim.api.nvim_feedkeys("ff", "x", false)
		assert.spy(cb).was_called(1)
		cb:clear()

		vim.g.xyz = false
		vim.api.nvim_feedkeys("ff", "x", false)
		assert.spy(cb).was_called(0)

		vim.g.xyz = true
		vim.api.nvim_feedkeys("ff", "x", false)
		assert.spy(cb).was_called(1)
	end)
	-- #endregion

	-- #region test case
	it("#19 has the ability to clear the keymap along with the handlers", function()
		local k = M.k({
			"ff",
			desc = "a keymap",
		})

		local cb1 = spy()
		local cb2 = spy()

		assert.was_error(function()
			M.clear_keymap()
		end, "Expect key to be a string")

		assert.was_error(function()
			M.clear_keymap("not-exist")
		end, "Key (not-exist) not registered")

		k(cb1)
		k(cb2)

		M.clear_keymap("ff")

		vim.api.nvim_feedkeys("ff", "x", false)

		assert.spy(cb1).was_not_called()
		assert.spy(cb2).was_not_called()

		assert.is_table(M.inspect("ff"))

		assert.equals(0, #M.inspect("ff")[1].callbacks)
	end)

	-- #endregion

	-- #region test case
	it("#20 can assign priority to a callback", function()
		local k = M.k({
			"ff",
			desc = "a keymap",
		})

		local orders = {}

		local cb = stub().invokes(function()
			table.insert(orders, 3)
		end)

		local cb_1 = stub().invokes(function()
			table.insert(orders, 2)
		end)

		local cb_2 = stub().invokes(function()
			table.insert(orders, 1)
		end)

		k(cb_1, { priority = 100 }) -- 2
		k(cb) -- 3
		k(cb_2, { priority = 200 }) -- 1

		vim.api.nvim_feedkeys("ff", "x", false)

		assert.are.same({ 1, 2, 3 }, orders)
	end)

	it("#21 resolving", function()
		local k1 = M.k({
			"ff",
			desc = "a keymap",
		})

		local cb1 = spy()
		local cb2 = spy()

		k1(cb1, { name = "cb1" })
		k1(cb2, { name = "cb2" })

		do
			local resolvedCb1 = k1("cb1")
			local resolvedCb2 = k1("cb2")

			resolvedCb1.disable()
			resolvedCb2.disable()
		end

		do
			local resolvedCb1 = k1("cb1")

			vim.api.nvim_feedkeys("ff", "x", false)

			resolvedCb1.enable()

			vim.api.nvim_feedkeys("ff", "x", false)

			resolvedCb1.del()

			vim.api.nvim_feedkeys("ff", "x", false)

			assert.spy(cb1).was_called(1)

			assert.is_not_nil(M.get("ff"))
		end

		do
			local resolvedCb2 = k1("cb2")

			resolvedCb2.enable()

			vim.api.nvim_feedkeys("ff", "x", false)

			resolvedCb2.del()

			vim.api.nvim_feedkeys("ff", "x", false)

			assert.spy(cb2).was_called(1)

			assert.is_not_nil(M.get("ff"))
		end
	end)

	-- #endregion

	-- #region test case
	it("#22-1 should able to break the chain", function()
		local k = M.k({
			"ff",
			desc = "a keymap",
		})

		local cb1 = stub().returns(true)
		local cb2 = stub()

		k(cb1)
		k(cb2)

		vim.api.nvim_feedkeys("ff", "x", false)

		assert.spy(cb1).was_called(1)
		assert.spy(cb2).was_not_called()
	end)

	it("#22-2 should able to break the chain when the keymap has a wrapper", function()
		local k = M.k({
			"ff",
			desc = "a keymap",
			function(handler)
				return handler()
			end,
		})

		local cb1 = stub().returns(true)
		local cb2 = stub()

		k(cb1)
		k(cb2)

		vim.api.nvim_feedkeys("ff", "x", false)

		assert.spy(cb1).was_called(1)
		assert.spy(cb2).was_not_called()
	end)

	-- #endregion

	-- #region test case
	it("#23-1 expect to combine both keymaps when the key and mode are the same", function()
		local k1 = M.k({
			"ff",
			desc = "a keymap 1",
			mode = "n",
		})

		local k2 = M.k({
			"ff",
			desc = "a keymap 2",
			mode = "n",
			filetype = "markdown",
		})

		local k3 = M.k({
			"ff",
			desc = "a keymap 3",
			mode = "n",
			once = true,
		})

		local cb1 = spy()
		local cb2 = spy()
		local cb3 = spy()

		k1(cb1, { name = "cb1", filetype = "rust" })
		k2(cb2, { name = "cb2" })

		do
			local buf = vim.api.nvim_create_buf(false, false)
			vim.api.nvim_set_option_value("filetype", "unknown", { buf = buf })

			k3(cb3, { name = "cb3", buffer = buf })

			vim.api.nvim_buf_call(buf, function()
				vim.api.nvim_feedkeys("ff", "x", false)
			end)
			vim.wait(1)
		end

		do
			local buf = vim.api.nvim_create_buf(false, false)
			vim.api.nvim_set_option_value("filetype", "rust", { buf = buf })

			vim.api.nvim_buf_call(buf, function()
				vim.api.nvim_feedkeys("ff", "x", false)
			end)

			assert.spy(cb1).was_called(1)
		end

		do
			local buf = vim.api.nvim_create_buf(false, false)
			vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })

			vim.api.nvim_buf_call(buf, function()
				vim.api.nvim_feedkeys("ff", "x", false)
			end)

			assert.spy(cb2).was_called(1)
		end

		-- NOTE: to ensure no one invokes this beside the k3
		assert.spy(cb3).was_called(1)
	end)

	it("#23-2 expect to combine both keymaps when the key and mode are the same", function()
		local k1 = M.k({
			"ff",
			desc = "a keymap 1",
			mode = "n",
		})

		local k2 = M.k({
			"ff",
			desc = "a keymap 2",
			mode = "n",
			filetype = "markdown",
		})

		local k3 = M.k({
			"ff",
			desc = "a keymap 3",
			mode = "n",
			once = true,
		})

		local cb1 = spy()
		local cb2 = spy()
		local cb3 = spy()

		local k1instance = k1(cb1, { name = "cb1", filetype = "rust" })
		local k2instance = k2(cb2, { name = "cb2" })

		k1instance.del()
		k1instance.reg()

		do
			local buf = vim.api.nvim_create_buf(false, false)
			vim.api.nvim_set_option_value("filetype", "unknown", { buf = buf })

			k3(cb3, { name = "cb3", buffer = buf })

			vim.api.nvim_buf_call(buf, function()
				vim.api.nvim_feedkeys("ff", "x", false)
			end)
		end

		k2instance.del()
		k2instance.reg()

		do
			local buf = vim.api.nvim_create_buf(false, false)
			vim.api.nvim_set_option_value("filetype", "rust", { buf = buf })

			vim.api.nvim_buf_call(buf, function()
				vim.api.nvim_feedkeys("ff", "x", false)
			end)

			assert.spy(cb1).was_called(1)
		end

		do
			local buf = vim.api.nvim_create_buf(false, false)
			vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })

			vim.api.nvim_buf_call(buf, function()
				vim.api.nvim_feedkeys("ff", "x", false)
			end)

			assert.spy(cb2).was_called(1)
		end

		-- NOTE: to ensure no one invokes this beside the k3
		assert.spy(cb3).was_called(1)
	end)

	-- #endregion

	-- #region test case
	it("able to create the deleted keymap", function()
		-- expecting not to remove the keymap completely when handlers is 0, but unregister the kaymap

		local k = M.k({
			"ff",
			desc = "a keymap",
		})

		local cb = spy()
		k(cb, { name = "cb" })

		k("cb").del()

		assert.spy(vim.keymap.del).was_called(1)

		k(cb, { name = "cb-second-time" })

		vim.api.nvim_feedkeys("ff", "x", false)
		assert.spy(cb).was_called(1)
	end)

	-- #endregion

	-- #region test case
	it("can remove the keymap completely", function()
		local km1 = M.k({
			"ff",
			desc = "a keymap 1",
			mode = "n",
		})

		local km2 = M.k({
			"ff",
			desc = "a keymap 2",
			mode = "n",
		})

		local km3 = M.k({
			"ffx",
			desc = "a keymap",
			mode = "n",
		})

		local cb1 = spy()
		local cb2 = spy()
		local cb3 = spy()

		km1(cb1, { name = "cb1" })
		km2(cb2, { name = "cb2" })
		km3(cb3, { name = "cb3" })

		M.remove_keymaps("ff", "n")

		vim.api.nvim_feedkeys("ffx", "x", false)
		assert.spy(cb1).was_not_called()
		assert.spy(cb2).was_not_called()
		assert.spy(cb3).was_called(1)
	end)

	it("can remove the keymap completely with simpler api", function()
		local km1 = M.k({
			"ff",
			desc = "a keymap 1",
			mode = "n",
		})

		local km2 = M.k({
			"ff",
			desc = "a keymap 2",
			mode = "n",
		})

		local km3 = M.k({
			"ffx",
			desc = "a keymap",
			mode = "n",
		})

		local cb1 = spy()
		local cb2 = spy()
		local cb3 = spy()

		km1(cb1, { name = "cb1" })
		km2(cb2, { name = "cb2" })
		km3(cb3, { name = "cb3" })

		km1("CLEAR")

		vim.api.nvim_feedkeys("ffx", "x", false)
		assert.spy(cb1).was_not_called()
		assert.spy(cb2).was_not_called()
		assert.spy(cb3).was_called(1)
	end)
	-- #endregion

	it("can invoke the #original keymap when invoked 1", function()
		local k = M.k({
			"l",
			desc = "a keymap",
			passthrough = true,
		})

		vim.api.nvim_buf_set_lines(init_buf, 0, -1, false, { "Hello, world!" })

		local win = vim.api.nvim_open_win(init_buf, true, {
			relative = "editor",
			width = 80,
			height = 20,
			col = 10,
			row = 10,
			style = "minimal",
		})

		local cb = spy()
		k(cb)

		vim.api.nvim_feedkeys("l", "x", false)
		assert.spy(cb).was_called(1)

		local cursor = vim.api.nvim_win_get_cursor(win)
		assert.are.same({ 1, 1 }, cursor)
		vim.api.nvim_win_close(win, { force = true })
	end)

	it("can register the same key when the first keymap is not adding handler", function()
		M.k({
			"o",
			desc = "a keymap",
			condition = function()
				return false
			end,
			passthrough = false,
		})

		local k2 = M.k({
			"o",
			desc = "a keymap",
			passthrough = true,
			condition = function()
				return true
			end
		})

		local cb1 = spy()
		local cb2 = spy()

		k2(cb2)

		do
			vim.api.nvim_buf_set_lines(init_buf, 0, -1, false, { "Hello, world!" })

			local win = vim.api.nvim_open_win(init_buf, true, {
				relative = "editor",
				width = 80,
				height = 20,
				col = 10,
				row = 10,
				style = "minimal",
			})

			vim.api.nvim_feedkeys("o", "x", false)

			assert.spy(cb1).was_called(0)
			assert.spy(cb2).was_called(1)

			local cursor = vim.api.nvim_win_get_cursor(win)
			assert.are.same({ 2, 0 }, cursor)
			vim.api.nvim_win_close(win, { force = true })

		end
	end)

	it("can invoke the #original keymap when invoked 2", function()
		local k = M.k({
			"l",
			desc = "a keymap",
			passthrough = true,
		})

		vim.api.nvim_buf_set_lines(init_buf, 0, -1, false, { "Hello, world!" })

		local win = vim.api.nvim_open_win(init_buf, true, {
			relative = "editor",
			width = 80,
			height = 20,
			col = 10,
			row = 10,
			style = "minimal",
		})

		local cb1 = spy()
		local cb2 = spy()
		k(cb1)
		k(cb2)

		vim.api.nvim_feedkeys("l", "x", false)
		assert.spy(cb1).was_called(1)
		assert.spy(cb2).was_called(1)

		local cursor = vim.api.nvim_win_get_cursor(win)
		assert.are.same({ 1, 1 }, cursor)
		vim.api.nvim_win_close(win, { force = true })
	end)

	it("can invoke the #original keymap when invoked using the passthrough as function returning true 3", function()
		local k = M.k({
			"l",
			desc = "a keymap",
			passthrough = function()
				return vim.g.canPassthrough
			end,
		})

		vim.api.nvim_buf_set_lines(init_buf, 0, -1, false, { "Hello, world!" })

		local win = vim.api.nvim_open_win(init_buf, true, {
			relative = "editor",
			width = 80,
			height = 20,
			col = 10,
			row = 10,
			style = "minimal",
		})

		local cb1 = spy()
		local cb2 = spy()
		k(cb1)
		k(cb2)

		vim.api.nvim_feedkeys("l", "x", false)
		assert.spy(cb1).was_called(1)
		assert.spy(cb2).was_called(1)
		cb1:clear()
		cb2:clear()

		vim.g.canPassthrough = true
		vim.api.nvim_feedkeys("l", "x", false)
		assert.spy(cb1).was_called(1)
		assert.spy(cb2).was_called(1)

		local cursor = vim.api.nvim_win_get_cursor(win)
		assert.are.same({ 1, 1 }, cursor)
		vim.api.nvim_win_close(win, { force = true })
	end)

	describe("duplicate", function()
		it("expect not to warn when disabled", function()
			local on_dup = stub()

			M.setup({
				duplicate = {
					detect = false,
					on_duplicate = on_dup,
				},
			})

			local k1 = M.k({
				"dd",
				desc = "first keymap",
			})

			local k2 = M.k({
				"dd",
				desc = "second keymap",
			})

			assert.spy(on_dup).was_called(0)
		end)

		it("warn when enabled", function()
			local on_dup = stub()

			M.setup({
				duplicate = {
					detect = true,
					on_duplicate = on_dup,
				},
			})

			local k1 = M.k({
				"dd",
				desc = "first keymap",
			})

			local k2 = M.k({
				"dd",
				desc = "second keymap",
			})

			assert.stub(on_dup).was_called(1)
			assert.stub(on_dup).was_called_with({
				{
					key = "dd",
					mode = "n",
					desc = "first keymap",
				},
				{
					key = "dd",
					mode = "n",
					desc = "second keymap",
				},
			})
		end)
	end)
end)
