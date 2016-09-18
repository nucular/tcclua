--- Demonstrates running the main function of a compilation context.
--- `luajit examples/run_main.lua`

local tcc = require("tcc").load()

local state = tcc.new()
assert(state:set_output_type(tcc.OUTPUT.MEMORY))

assert(state:compile_string([[
  #include <stdio.h>
  int main(int argc, char** argv)
  {
    if (argc == 0) { return 1; }
    printf("Hello, %s!\n", argv[0]);
    return 0;
  }
]]))

assert(state:run(tcc.args("World")) == 0)
