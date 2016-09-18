--- Demonstrates adding a Lua callback as a symbol to a compilation context.
--- `luajit examples/add_symbol.lua`

local ffi = require("ffi")
local tcc = require("tcc").load()

local output = ""
function test(msg)
  output = ffi.string(msg)
end

local state = tcc.new()
assert(state:set_output_type(tcc.OUTPUT.MEMORY))

assert(state:compile_string([[
  #include <stdlib.h>
  #include <string.h>

  extern void test(char* msg);

  int main(int argc, char** argv)
  {
    if (argc == 0) { return 1; }
    char* msg = (char*)malloc(strlen(argv[0]) + 8);
    sprintf(msg, "Hello, %s!\n", argv[0]);
    test(msg);
    free(msg);
    return 0;
  }
]]))

local test_sym = ffi.cast("void (*)(char* msg)", test)
assert(state:add_symbol("test", test_sym))
assert(state:run(tcc.args("World")) == 0)
assert(output == "Hello, World!\n")
