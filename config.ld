project = "tcc.lua"
format = "markdown"
not_luadoc = true
style = "!pale"
dir = "./docs"
file = "./tcc.lua"
examples = {
  "examples/run.lua",
  "examples/get_symbol.lua",
  "examples/add_symbol.lua",
  "examples/libtcc_test.lua"
}

backtick_references = false

custom_see_handler("%./(.+)", function(link)
  return link, ("./%s"):format(link)
end)
