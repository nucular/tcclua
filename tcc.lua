--- Provides semi-high-level bindings for `libtcc`, the library interface of the
--- [Tiny C Compiler](http://bellard.org/tcc/).
--- [Source on GitHub](https://github.com/nucular/tcclua)
-- @license LGPL
local tcc = {}
local ffi = require("ffi")

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

--- Path to the TCC root, containing the `lib` and `include` directories.
--- Set by @{tcc.load}.
tcc.tccdir = nil

--- Load libtcc.
---
--- If the environment variable `CONFIG_TCCDIR` is set, @{tccdir} will be set
--- to its value. It can be overriden by passing the `tccdir` parameter.
---
--- If @{tccdir} is set, it will be searched for the library before the default
--- search paths are searched.
-- @tparam[opt="libtcc"] string lib name of the libtcc library
-- @tparam[opt=$CONFIG_TCCDIR] string tccdir path to the TCC root
-- @treturn table the `tcc` module itself
-- @usage
--local tcc = require("tcc").load("libtcc", "/lib/tcc")
function tcc.load(lib, tccdir)
  if tccdir then
    tcc.tccdir = tccdir
  else
    tcc.tccdir = os.getenv("CONFIG_TCCDIR") or tcc.tccdir
  end
  lib = lib or "libtcc"

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
  if tcc.tccdir then
    clib = pcall(ffi.load(("%s/%s"):format(tcc.tccdir, lib)))
  end
  if not clib then
    clib = ffi.load(lib)
  end
  tcc.clib = clib
  return tcc
end

--- Create a new TCC compilation context (@{State}).
---
--- If `addpaths` is not `false` and @{tccdir} is set, call
--- @{State:set_lib_path}, @{State:add_sysinclude_path} and
--- @{State:add_library_path}.
-- @tparam[opt=true] bool addpaths
-- @treturn State
function tcc.new(addpaths)
  local state = tcc.clib.tcc_new()
  ffi.gc(state, tcc.State.__gc)
  if addpaths ~= false and tcc.tccdir then
    state:set_lib_path(tcc.tccdir)
    state:add_sysinclude_path(tcc.tccdir .. "/include")
    state:add_library_path(tcc.tccdir .. "/lib")
  end
  return state
end

--- Convert all passed arguments to `argc` and `argv` that can be passed to
--- @{State:run}.
-- @tparam string ... any arguments
-- @treturn int argc
-- @treturn char** argv
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

--- A TCC compilation context
-- @type State
local State = {}
tcc.State = State
State.__index = State

--- Free the TCC compilation context.
---
--- Called automatically when collected.
function State:delete()
  tcc.clib.tcc_delete(self)
end

--- Set `CONFIG_TCCDIR` at runtime.
-- @tparam string path
function State:set_lib_path(path)
  tcc.clib.tcc_set_lib_path(self, path)
end

--- Set the error/warning display callback.
---
--- The passed `msg` strings will be formatted like
--- `<file or "tcc">:[<line>:] <severity> <message>`.
-- @tparam func error_func function(msg)
function State:set_error_func(error_func)
  tcc.clib.tcc_set_error_func(self, nil, function(_, msg)
    error_func(ffi.string(msg))
  end)
end

--- Set options as from the command line (multiple supported).
-- @tparam string str
-- @treturn bool success
function State:set_options(str)
  return tcc.clib.tcc_set_options(self, str) == 0
end

--- Preprocessor
-- @section

--- Add an include path.
-- @tparam string pathname
-- @treturn bool success
function State:add_include_path(pathname)
  return tcc.clib.tcc_add_include_path(self, pathname) == 0
end

--- Add a system include path.
-- @tparam string pathname
-- @treturn bool success
function State:add_sysinclude_path(pathname)
  return tcc.clib.tcc_add_sysinclude_path(self, pathname) == 0
end

--- Define preprocessor symbol `sym` with an optional value.
-- @tparam string sym
-- @tparam[opt] string value
function State:define_symbol(sym, value)
  tcc.clib.tcc_define_symbol(self, sym, value)
end

--- Undefine preprocessor symbol 'sym'.
-- @tparam string sym
function State:undefine_symbol(sym)
  tcc.clib.tcc_undefine_symbol(self, sym)
end

--- Compiling
-- @section

--- Add a file (C file, dll, object, library, ld script).
-- @tparam string filename
-- @treturn bool success
function State:add_file(filename)
  return tcc.clib.tcc_add_file(self, filename) == 0
end

--- Compile a string containing a C source.
-- @tparam string buf
-- @treturn bool success
function State:compile_string(buf)
  return tcc.clib.tcc_compile_string(self, buf) == 0
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

--- Equivalent to the `-Lpath` option.
-- @tparam string pathname
-- @treturn bool success
function State:add_library_path(pathname)
  return tcc.clib.tcc_add_library_path(self, pathname) == 0
end

--- Equivalent to the `-lpath` option.
-- @tparam string libraryname
-- @treturn bool success
function State:add_library(libraryname)
  return tcc.clib.tcc_add_library(self, libraryname) == 0
end

--- Add a symbol to the compiled program.
-- @tparam string name
-- @tparam void* val
-- @treturn bool success
-- @see ./examples/add_symbol.lua.html
function State:add_symbol(name, val)
  return tcc.clib.tcc_add_symbol(self, name, val) == 0
end

--- Output an executable, library or object file.
---
--- **Do not** call @{State:relocate} before.
-- @tparam string filename
-- @treturn bool success
function State:output_file(filename)
  return tcc.clib.tcc_output_file(self, filename) == 0
end

--- Link and run the `main()` function and return its return code.
---
--- **Do not** call @{State:relocate} before.
-- @tparam[opt] int argc
-- @tparam[opt] char** argv
-- @treturn int return code
-- @usage
--local argv = ffi.new("char*[2]")
--argv[0] = "foo"
--argv[1] = "bar"
--state:run(2, argv)
-- @see ./examples/run.lua.html
function State:run(argc, argv)
  return tcc.clib.tcc_run(self, argc, argv)
end

--- Do all relocations (needed before using @{State:get_symbol}).
-- @tparam void* ptr or one of @{RELOCATE}
-- @treturn[0] bool success
-- @treturn[1] int required memory size when @{RELOCATE|RELOCATE.SIZE} is passed
function State:relocate(ptr)
  if ptr == tcc.RELOCATE.SIZE then
    return tcc.clib.tcc_relocate(self, ptr)
  else
    return tcc.clib.tcc_relocate(self, ptr) == 0
  end
end

--- Return the pointer to a symbol or `NULL` if not found.
-- @tparam string name
-- @treturn void*
-- @see ./examples/get_symbol.lua.html
function State:get_symbol(name)
  return tcc.clib.tcc_get_symbol(self, name)
end

function State:__gc()
  self:delete()
end

return tcc
