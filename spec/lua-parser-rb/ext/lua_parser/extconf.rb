require 'mkmf-rice'

extension_name = 'lua_parser'
dir_config(extension_name)

have_library('stdc++')

$CFLAGS << ' -std=c++14'

if enable_config('static')
  $defs.push '-DANTLR4CPP_STATIC' unless $defs.include?('-DANTLR4CPP_STATIC')
end

include_paths = [
  '.',
  'antlrgen',
  'antlr4-upstream/runtime/Cpp/runtime/src',
  'antlr4-upstream/runtime/Cpp/runtime/src/atn',
  'antlr4-upstream/runtime/Cpp/runtime/src/dfa',
  'antlr4-upstream/runtime/Cpp/runtime/src/misc',
  'antlr4-upstream/runtime/Cpp/runtime/src/support',
  'antlr4-upstream/runtime/Cpp/runtime/src/tree',
  'antlr4-upstream/runtime/Cpp/runtime/src/tree/pattern',
  'antlr4-upstream/runtime/Cpp/runtime/src/tree/xpath'
]

$srcs = []

include_paths.each do |include_path|
  $INCFLAGS << " -I#{include_path}"
  $VPATH << include_path

  Dir.glob("#{include_path}/*.cpp").each do |path|
    $srcs << path
  end
end

create_makefile(extension_name)
