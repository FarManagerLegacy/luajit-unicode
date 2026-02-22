local PASS, FAIL = 0, 0
-- This test intentionally targets Windows path APIs and wrappers only.

local function test(name, fn)
  io.write("[TEST] " .. name)
  io.flush()
  local ok, err = pcall(fn)
  if ok then
    io.write("\r[PASS] " .. name .. "\n")
    PASS = PASS + 1
  else
    io.write("\r[FAIL] " .. name .. ": " .. tostring(err) .. "\n")
    FAIL = FAIL + 1
  end
end

local DIR_WINDOWS = "tests\\_unicode_fixture"
local NAME = "Ελλ_中文_한국_عربي_кирил_देवनागरी"
local BASE = DIR_WINDOWS .. "\\" .. NAME

local function file_exists(path)
  local f = io.open(path, "rb")
  if f then
    f:close()
    return true
  end
  return false
end

local function read_all(path)
  local f, err = io.open(path, "rb")
  assert(f, err)
  local data = f:read("*a")
  f:close()
  return data
end

local function command_ok(ret)
  -- LuaJIT/Lua 5.1 on Windows may return boolean true, while Lua 5.2+
  -- style semantics can return numeric zero for success.
  return ret == true or ret == 0
end

local function cmd_quote(path)
  -- Escape CMD metacharacters with '^' and double embedded quotes.
  local escaped = path:gsub('[%%%^&|<>()!]', '^%1'):gsub('"', '""')
  return '"' .. escaped .. '"'
end

local function cleanup_fixtures()
  os.execute('cmd /c rmdir /s /q ' .. cmd_quote(DIR_WINDOWS))
end

local function run_suite()
  local setup_ret = os.execute("cmd /c tests\\test_setup.cmd")
  assert(command_ok(setup_ret), "test_setup.cmd failed: " .. tostring(setup_ret))
  assert(file_exists(DIR_WINDOWS .. "\\setup_done.txt"), "setup_done.txt is missing")

  test("io.open read trusted Unicode fixture", function()
    local data = read_all(BASE .. ".txt")
    assert(data:find("fixture%-content", 1, false), "unexpected fixture data")
  end)

  test("loadfile Unicode path", function()
    local chunk, err = loadfile(BASE .. ".lua")
    assert(chunk, err)
    assert(chunk() == "lua-fixture-ok")
  end)

  test("dofile Unicode path", function()
    assert(dofile(BASE .. ".lua") == "lua-fixture-ok")
  end)

  test("require Lua module from Unicode path", function()
    local old_path = package.path
    package.path = DIR_WINDOWS .. "\\?.lua;" .. old_path
    package.loaded[NAME] = nil
    local ok, mod = pcall(require, NAME)
    package.path = old_path
    package.loaded[NAME] = nil
    assert(ok, tostring(mod))
    assert(mod == "lua-fixture-ok")
  end)

  test("io.open write Unicode", function()
    local path = BASE .. "_write.txt"
    local f, err = io.open(path, "wb")
    assert(f, err)
    assert(f:write("written-by-luajit"))
    f:close()
    assert(file_exists(path), "written file is missing")
    local data = read_all(path)
    assert(data:find("written%-by%-luajit", 1, false), "write verification failed")
  end)

  test("os.rename Unicode -> Unicode", function()
    local src = DIR_WINDOWS .. "\\rename_src_" .. NAME .. ".txt"
    local dst = BASE .. "_renamed.txt"
    assert(file_exists(src), "precondition failed: source is missing")
    os.remove(dst)
    local ok, err = os.rename(src, dst)
    assert(ok, err)
    assert(file_exists(dst), "destination file is missing")
    assert(not file_exists(src), "source file still exists")
  end)

  test("os.remove Unicode", function()
    local path = BASE .. "_write.txt"
    assert(file_exists(path), "precondition failed: writable file is missing")
    local ok, err = os.remove(path)
    assert(ok, err)
    assert(not file_exists(path), "file still exists")
  end)

  test("io.popen Unicode command arg", function()
    local target = cmd_quote(BASE .. "_renamed.txt")
    local cmd = 'cmd /c if exist ' .. target .. ' (echo 1) else (echo 0)'
    local f, err = io.popen(cmd, "r")
    assert(f, err)
    local out = f:read("*l")
    f:close()
    assert(out == "1", "io.popen command did not see Unicode path")
  end)

  test("os.execute Unicode command arg", function()
    local marker = BASE .. "_exec_marker.txt"
    os.remove(marker)
    local ret = os.execute('cmd /c type nul > ' .. cmd_quote(marker))
    assert(command_ok(ret), "os.execute returned " .. tostring(ret))
    assert(file_exists(marker), "marker file was not created")
    os.remove(marker)
  end)

  test("os.getenv Unicode value", function()
    local val = os.getenv("IAT_TEST_VAR")
    assert(val == NAME, "unexpected env value: " .. tostring(val))
  end)

  test("package.loadlib Unicode C path", function()
    local dll = DIR_WINDOWS .. "\\lib_" .. NAME .. "\\jitmod.dll"
    local loader, err = package.loadlib(dll, "luaopen_jit")
    assert(loader, err)
    local ok, mod = pcall(loader)
    assert(ok, tostring(mod))
    assert(type(mod) == "table", "luaopen_jit did not return module table")
  end)
end

local ok, err = xpcall(run_suite, debug.traceback)
cleanup_fixtures()
if not ok then
  io.write("\n[FATAL] " .. tostring(err) .. "\n")
  os.exit(1)
end

io.write(string.format("\n%d passed, %d failed\n", PASS, FAIL))
if FAIL > 0 then
  os.exit(1)
end
