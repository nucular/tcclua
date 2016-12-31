--- Provides semi-high-level bindings for `libtcc`, the library interface of the
--- [Tiny C Compiler](http://bellard.org/tcc/).
--- [Source on GitHub](https://github.com/nucular/tcclua)
-- @license LGPL
local tcc = {}
local ffi = require("ffi")

tcc._NAME = "tcc"
tcc._VERSION = "scm"

--- Compatible version of TCC (currently `0.9.26`)
tcc.TCC_VERSION = "0.9.26"

--- Output types used by @{State:set_output_type}
tcc.OUTPUT = {
  MEMORY = 0, -- output will be run in memory (default)
  EXE = 1, -- executable file
  DLL = 2, -- dynamic library
  OBJ = 3, -- object file
  PREPROCESS = 4 -- only preprocess (used internally)
}

--- Relocation constants used by @{State:relocate}
tcc.RELOCATE = {
  SIZE = ffi.cast("void*", 0), -- return required memory size for relocation
  AUTO = ffi.cast("void*", 1) -- allocate and manage memory internally
}

--- Path to the TCC home, containing the `lib` and `include` directories.
--- Usually set automatically by @{tcc.load}.
tcc.home_path = nil

--- C library namespace of the dynamically loaded `libtcc`. Set by @{tcc.load}.
tcc.clib = nil

--- Load the `libtcc` dynamic library.
---
--- If the environment variable `CONFIG_TCCDIR` is set, @{home_path} will be set
--- to its value. It can be overriden by passing the `home_path` parameter.
---
--- If @{home_path} is set, it will be searched for the library before the
--- default paths.
-- @tparam[opt="[lib]tcc"] string lib name of the libtcc library, defaults to
-- `libtcc` on Windows and `tcc` on other platforms due to naming issues
-- @tparam[opt=$CONFIG_TCCDIR] string home_path path to the TCC home
-- @treturn table the `tcc` module itself (to allow for chaining)
-- @usage
--local tcc = require("tcc").load("tcc", "/lib/tcc")
function tcc.load(lib, home_path)
  if home_path then
    tcc.home_path = tccdir
  else
    tcc.home_path = os.getenv("CONFIG_TCCDIR") or tcc.home_path
  end
  lib = lib or (ffi.os == "Windows" and "libtcc" or "tcc")

  ffi.cdef([[
    struct TCCState;
    typedef struct TCCState TCCState;
    TCCState *tcc_new(void);
    void tcc_delete(TCCState *s);
    void tcc_set_lib_path(TCCState *s, const char *path);
    void tcc_set_error_func(TCCState *s, void *error_opaque,
      void (*error_func)(void *opaque, const char *msg));
    int tcc_set_options(TCCState *s, const char *str);
    int tcc_add_include_path(TCCState *s, const char *pathname);
    int tcc_add_sysinclude_path(TCCState *s, const char *pathname);
    void tcc_define_symbol(TCCState *s, const char *sym, const char *value);
    void tcc_undefine_symbol(TCCState *s, const char *sym);
    int tcc_add_file(TCCState *s, const char *filename);
    int tcc_compile_string(TCCState *s, const char *buf);
    int tcc_set_output_type(TCCState *s, int output_type);
    int tcc_add_library_path(TCCState *s, const char *pathname);
    int tcc_add_library(TCCState *s, const char *libraryname);
    int tcc_add_symbol(TCCState *s, const char *name, const void *val);
    int tcc_output_file(TCCState *s, const char *filename);
    int tcc_run(TCCState *s, int argc, char **argv);
    int tcc_relocate(TCCState *s1, void *ptr);
    void *tcc_get_symbol(TCCState *s, const char *name);
  ]])
  ffi.metatype("TCCState", tcc.State)

  local clib
  if tcc.home_path then
    clib = pcall(ffi.load(("%s/%s"):format(tcc.home_path, lib)))
  end
  if not clib then
    clib = ffi.load(lib)
  end
  tcc.clib = clib
  return tcc
end

--- Create a new TCC compilation context (@{State}).
---
--- If `add_paths` is not `false` and @{home_path} is set, call
--- @{State:set_home_path} on it, @{State:add_sysinclude_path} on
--- `home_path/include` and @{State:add_library_path} on `home_path/lib`.
-- @tparam[opt=true] bool add_paths whether to set the home path on the new
-- @{State}
-- @treturn State the new compilation context
function tcc.new(add_paths)
  local state = tcc.clib.tcc_new()
  ffi.gc(state, tcc.State.__gc)
  if addpaths ~= false and tcc.tccdir then
    state:set_home_path(tcc.tccdir)
    state:add_sysinclude_path(tcc.tccdir .. "/include")
    state:add_library_path(tcc.tccdir .. "/lib")
  end
  return state
end

--- Convert all passed strings to `argc` and `argv` arguments that can be passed
--- to @{State:run}.
-- @tparam string ... any number of string arguments
-- @treturn cdata(int) number of passed arguments
-- @treturn cdata(char**) passed arguments as an array of C strings
-- @usage
--state:run(tcc.args("foo", "bar"))
function tcc.args(...)
  local argc = select("#", ...)
  local argv

  argv = ffi.new("char*[?]", argc)
  for i = 1, argc do
    local arg = select(i, ...)
    argv[i - 1] = ffi.cast("char*", arg)
  end

  return argc, argv
end

--- A TCC compilation context.
-- @type State
local State = {}
tcc.State = State
State.__index = State

--- Free the compilation context and associated resources. Usually called
--- automatically when the @{State} is garbage-collected.
function State:delete()
  tcc.clib.tcc_delete(self)
end

--- Set the home path of TCC used by this context. Usually called automatically
--- by @{new}.
---
--- Originally named `set_lib_path` but renamed for consistency and clarity.
-- @tparam string path
function State:set_home_path(path)
  tcc.clib.tcc_set_lib_path(self, path)
end

--- Set the error/warning display callback.
---
--- The passed output strings will be formatted like
--- `<file or "tcc">:[<line>:] <severity> <message>`.
-- @tparam function(string) error_func function to be called
function State:set_error_func(error_func)
  tcc.clib.tcc_set_error_func(self, nil, function(_, msg)
    error_func(ffi.string(msg))
  end)
end

--- Set one or multiple command line arguments for the compiler.
-- @tparam string args the arguments
-- @treturn bool success
function State:set_options(args)
  return tcc.clib.tcc_set_options(self, args) == 0
end

--- Preprocessor
-- @section

--- Add an include path.
-- @tparam string path include path to be added
-- @treturn bool success
function State:add_include_path(path)
  return tcc.clib.tcc_add_include_path(self, path) == 0
end

--- Add a system include path. Usually called automatically by @{new}.
-- @tparam string path system include path to be added
-- @treturn bool success
function State:add_sysinclude_path(path)
  return tcc.clib.tcc_add_sysinclude_path(self, path) == 0
end

--- Define a preprocessor symbol with an optional value.
-- @tparam string name name of the symbol
-- @tparam[opt] string value optional value of the symbol 
function State:define_symbol(name, value)
  tcc.clib.tcc_define_symbol(self, sym, value)
end

--- Undefine a preprocessor symbol.
-- @tparam string name name of the symbol
function State:undefine_symbol(name)
  tcc.clib.tcc_undefine_symbol(self, sym)
end

--- Compiling
-- @section

--- Add a file.
--- This includes:
---
--- - C files to be compiled
--- - DLLs, object files and libraries to be linked against
--- - ld scripts
-- @tparam string file_path path to the file to be added
-- @treturn bool success
function State:add_file(file_path)
  return tcc.clib.tcc_add_file(self, file_path) == 0
end

--- Compile a string containing a C source.
-- @tparam string source source code to be compiled
-- @treturn bool success
function State:compile_string(source)
  return tcc.clib.tcc_compile_string(self, source) == 0
end

--- Linking commands
-- @section

--- Set the output type.
---
--- **Must be called** before any compilation.
-- @tparam OUTPUT output_type
-- @treturn bool success
function State:set_output_type(output_type)
  return tcc.clib.tcc_set_output_type(self, output_type) == 0
end

--- Add a library path. Equivalent to the `-Lpath` option.
-- @tparam string path library path to be added
-- @treturn bool success
function State:add_library_path(path)
  return tcc.clib.tcc_add_library_path(self, path) == 0
end

--- Add a library to be linked against. Equivalent to the `-lname` option.
-- @tparam string name name of the library to be linked against
-- @treturn bool success
function State:add_library(name)
  return tcc.clib.tcc_add_library(self, name) == 0
end

--- Add a pointer symbol to the compiled program.
-- @tparam string name name of the symbol
-- @tparam cdata(void*) value pointer of the symbol
-- @treturn bool success
-- @see ./examples/add_symbol.lua.html
function State:add_symbol(name, value)
  return tcc.clib.tcc_add_symbol(self, name, value) == 0
end

--- Output a compiled executable, library or object file to a path. **Do not**
--- call @{State:relocate} before.
-- @tparam string file_path output file path
-- @treturn bool success
function State:output_file(file_path)
  return tcc.clib.tcc_output_file(self, file_path) == 0
end

--- Link and run the `main()` function and return its return code. **Do not**
--- call @{State:relocate} before.
-- @tparam[opt] cdata(int) argc number of passed arguments
-- @tparam[opt] cdata(char**) argv arguments as an array of C-strings
-- @treturn cdata(int) return code
-- @usage
--local argv = ffi.new("char*[2]")
--argv[0] = "foo"
--argv[1] = "bar"
--state:run(2, argv)
-- @see ./examples/run.lua.html
function State:run(argc, argv)
  return tcc.clib.tcc_run(self, argc, argv)
end

--- Do all relocations needed for using @{State:get_symbol}.
--- This can be done either within internally managed memory (by passing
--- @{RELOCATE|RELOCATE.AUTO}) or within an user-managed memory chunk that is at
--- least of the size that is returned by passing @{RELOCATE|RELOCATE.SIZE}.
-- @tparam cdata(void*) ptr pointer to a memory chunk or one of the members of
-- @{RELOCATE}
-- @treturn[0] bool success
-- @treturn[1] number required memory size if @{RELOCATE|RELOCATE.SIZE} was
-- passed
-- @usage
--local size = state:relocate(tcc.RELOCATE.SIZE)
--local mem = ffi.new("char[?]", size)
--state:relocate(mem)
function State:relocate(ptr)
  if ptr == tcc.RELOCATE.SIZE then
    return tcc.clib.tcc_relocate(self, ptr)
  else
    return tcc.clib.tcc_relocate(self, ptr) == 0
  end
end

--- Return the pointer to a symbol or `NULL` if it was not found.
-- @tparam string name name of the symbol
-- @treturn cdata(void*) pointer to the symbol
-- @see ./examples/get_symbol.lua.html
function State:get_symbol(name)
  return tcc.clib.tcc_get_symbol(self, name)
end

function State:__gc()
  self:delete()
end

return tcc
