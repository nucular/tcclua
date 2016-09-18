--- Ported from libtcc_test.c.
--- `luajit examples/libtcc_test.lua`

local ffi = require("ffi")
local tcc = require("tcc").load()

--- this function is called by the generated code
local function add(a, b)
  return a + b
end

local my_program = [[
int fib(int n)
{
  if (n <= 2)
    return 1;
  else
    return fib(n-1) + fib(n-2);
}

int foo(int n)
{
  printf("Hello World!\n");
  printf("fib(%d) = %d\n", n, fib(n));
  printf("add(%d, %d) = %d\n", n, 2 * n, add(n, 2 * n));
  return 0;
}
]]

local function main()
  local s = tcc.new()
  if not s then
    io.stderr:write("Could not create tcc state\n")
    return 1
  end

  -- MUST BE CALLED before any compilation
  s:set_output_type(tcc.OUTPUT.MEMORY)

  if not s:compile_string(my_program) then
    return 1
  end

  -- as a test, we add a symbol that the compiled program can use.
  s:add_symbol("add", ffi.cast("double (*)(double, double)", add))

  -- relocate the code
  if not s:relocate(tcc.RELOCATE.AUTO) then
    return 1
  end

  -- get entry symbol
  local func = s:get_symbol("foo")
  if not func then
    return 1
  end

  -- run the code
  ffi.cast("int (*)(int)", func)(32)

  return 0
end

os.exit(main())
