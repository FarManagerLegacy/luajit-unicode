local filename_prefix = "тест_юникод_файл"
local original = filename_prefix .. ".txt"
local renamed = filename_prefix .. ".renamed.txt"

local function cleanup()
  os.remove(original)
  os.remove(renamed)
end

cleanup()

local f, err = io.open(original, "wb")
assert(f, "io.open(write) failed: " .. tostring(err))
assert(f:write("patched utf8 wrappers"))
f:close()

local rf, read_err = io.open(original, "rb")
assert(rf, "io.open(read) failed: " .. tostring(read_err))
local data = rf:read("*a")
rf:close()
assert(data == "patched utf8 wrappers", "Unexpected file contents")

local ok, rename_err = os.rename(original, renamed)
assert(ok, "os.rename failed: " .. tostring(rename_err))

local removed, remove_err = os.remove(renamed)
assert(removed, "os.remove failed: " .. tostring(remove_err))

print("UTF-8 wrapper smoke test passed")
