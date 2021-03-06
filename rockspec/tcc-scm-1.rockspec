package = "tcc"
version = "scm"
source = {
  url = "git://github.com/nucular/tcclua",
  branch = "master"
}
description = {
  summary = "FFI bindings for the Tiny C Compiler",
  detailed = [[
    Provides semi-high-level bindings for libtcc, the library interface of the
    Tiny C Compiler.
  ]],
  homepage = "https://nucular.github.io/tcclua",
  license = "LGPL"
}
dependencies = {
  "lua >= 5.1" -- "luajit >= 2.0.0"
}
build = {
  type = "builtin",
  modules = {
    tcc = "tcc.lua"
  },
  copy_directories = {
    "docs"
  }
}
