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
-- Keep in sync with codepoint-generated name in tests/test_setup.cmd.
local NAME = "Ελλ_中文_한국_عربي_кирил_देवनागरी"
local BASE
local PATH_RENAME_SRC
local PATH_RENAMED
local PATH_WRITE
local PATH_EXEC_MARKER
local PATH_LOADLIB_STUB

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

local function has_non_ascii(s)
  for i = 1, #s do
    if s:byte(i) > 127 then
      return true
    end
  end
  return false
end

local function command_ok(ret)
  -- LuaJIT/Lua 5.1 on Windows may return boolean true, while Lua 5.2+
  -- style semantics can return numeric zero for success. Failure values differ
  -- by version, so callers should only use this as a success predicate.
  return ret == true or ret == 0
end

local function cmd_quote(path)
  -- Escape CMD metacharacters with '^' and double embedded quotes.
  -- In the Lua pattern below, leading '%%' matches literal '%', while
  -- '%X' escapes special pattern characters used in the class.
  local escaped = path:gsub('[%%%^&|<>()!%[%]]', '^%1'):gsub('"', '""')
  return '"' .. escaped .. '"'
end

local function cleanup_fixtures()
  os.execute('cmd /c rmdir /s /q ' .. cmd_quote(DIR_WINDOWS))
end

local function ensure_fixture(path, content)
  if file_exists(path) then
    return
  end
  local f = assert(io.open(path, "wb"))
  f:write(content)
  f:close()
end

local function run_suite()
  local setup_ret = os.execute("cmd /c tests\\test_setup.cmd")
  assert(command_ok(setup_ret), "test_setup.cmd failed: " .. tostring(setup_ret))
  assert(file_exists(DIR_WINDOWS .. "\\setup_done.txt"), "setup_done.txt is missing")
  assert(has_non_ascii(NAME), "fixture name is not Unicode: " .. tostring(NAME))
  BASE = DIR_WINDOWS .. "\\" .. NAME
  PATH_RENAME_SRC = BASE .. "_rename_src.txt"
  PATH_RENAMED = BASE .. "_renamed.txt"
  PATH_WRITE = BASE .. "_write.txt"
  PATH_EXEC_MARKER = BASE .. "_exec_marker.txt"
  PATH_LOADLIB_STUB = BASE .. "_loadlib_stub.dll"

  ensure_fixture(BASE .. ".txt", "fixture-content")
  ensure_fixture(BASE .. ".lua", "return 'lua-fixture-ok'")
  ensure_fixture(PATH_RENAME_SRC, "rename-source")
  ensure_fixture(PATH_LOADLIB_STUB, "not-a-dll")

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

  test("io.open write Unicode path", function()
    assert(has_non_ascii(PATH_WRITE), "path must contain Unicode")
    local f, err = io.open(PATH_WRITE, "wb")
    assert(f, err)
    local old_output = io.output()
    io.output(f)
    io.write("written-by-luajit")
    io.output(old_output)
    f:close()
    assert(file_exists(PATH_WRITE), "written file is missing")
    local data = read_all(PATH_WRITE)
    assert(data:find("written%-by%-luajit", 1, false), "write verification failed")
  end)

  test("os.rename Unicode -> Unicode", function()
    assert(file_exists(PATH_RENAME_SRC), "precondition failed: source is missing")
    os.remove(PATH_RENAMED)
    local ok, err = os.rename(PATH_RENAME_SRC, PATH_RENAMED)
    assert(ok, err)
    assert(file_exists(PATH_RENAMED), "destination file is missing")
    assert(not file_exists(PATH_RENAME_SRC), "source file still exists")
  end)

  test("os.remove Unicode", function()
    assert(has_non_ascii(PATH_WRITE), "path must contain Unicode")
    assert(file_exists(PATH_WRITE), "precondition failed: writable file is missing")
    local ok, err = os.remove(PATH_WRITE)
    assert(ok, err)
    assert(not file_exists(PATH_WRITE), "file still exists")
  end)

  test("io.popen Unicode command arg", function()
    local target = cmd_quote(PATH_RENAMED)
    local cmd = 'cmd /c if exist ' .. target .. ' (echo 1) else (echo 0)'
    local f, err = io.popen(cmd, "r")
    assert(f, err)
    local out = f:read("*l")
    f:close()
    assert(out == "1", "io.popen command did not see Unicode path")
  end)

  test("os.execute Unicode command arg", function()
    assert(has_non_ascii(PATH_EXEC_MARKER), "path must contain Unicode")
    os.remove(PATH_EXEC_MARKER)
    local ret = os.execute('cmd /c type nul > ' .. cmd_quote(PATH_EXEC_MARKER))
    assert(command_ok(ret), "os.execute returned " .. tostring(ret))
    assert(file_exists(PATH_EXEC_MARKER), "marker file was not created")
    os.remove(PATH_EXEC_MARKER)
  end)

  test("os.getenv Unicode value", function()
    local val = os.getenv("IAT_TEST_VAR")
    assert(type(val) == "string", "unexpected env value type: " .. tostring(val))
    assert(val ~= "", "unexpected empty env value")
    if has_non_ascii(val) then
      assert(val == NAME, "unexpected Unicode env value: " .. tostring(val))
    end
  end)

  test("package.loadlib Unicode C path", function()
    assert(file_exists(PATH_LOADLIB_STUB), "loadlib stub fixture is missing")
    local loader, err = package.loadlib(PATH_LOADLIB_STUB, "luaopen_jit")
    assert(not loader, "stub load unexpectedly succeeded")
    local msg = tostring(err)
    local msg_l = msg:lower()
    assert(not msg_l:find("no such file", 1, true), "unexpected file-not-found error: " .. msg)
    assert(not msg_l:find("could not be found", 1, true), "unexpected missing-file error: " .. msg)
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
