--- Demonstrates getting and calling a symbol from a compilation context.
--- `luajit examples/call_symbol.lua`

local ffi = require("ffi")
local tcc = require("tcc").load()

local state = tcc.new()
assert(state:set_output_type(tcc.OUTPUT.MEMORY))

assert(state:compile_string([[
  double test(double a, double b)
  {
    return a + b;
  }
]]))

assert(state:relocate(tcc.RELOCATE.AUTO))
local test_sym = assert(state:get_symbol("test"))
local test = ffi.cast("double (*)(double, double)", test_sym)
assert(test(1, 2) == 3)
