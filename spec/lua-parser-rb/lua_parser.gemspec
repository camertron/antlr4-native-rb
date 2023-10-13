$:.unshift File.join(File.dirname(__FILE__), 'lib')
require 'lua_parser/version'

Gem::Specification.new do |s|
  s.name     = 'lua_parser'
  s.version  = ::LuaParser::VERSION
  s.authors  = ['Mickey Mouse']
  s.email    = ['mickey@disney.com']
  s.homepage = 'https://github.com/mickeymouse/lua-parser-rb'

  s.description = s.summary = 'A Lua parser for Ruby'

  s.platform = Gem::Platform::RUBY

  s.add_dependency 'rice', '~> 4.0'

  s.extensions = File.join(*%w(ext lua_parser extconf.rb))

  s.require_path = 'lib'
  s.files = Dir[
    '{lib,spec}/**/*',
    'ext/lua_parser/*.{cpp,h}',
    'ext/lua_parser/extconf.rb',
    'ext/lua_parser/antlrgen/*',
    'ext/lua_parser/antlr4-upstream/runtime/Cpp/runtime/src/**/*.{cpp,h}',
    'Gemfile',
    'README.md',
    'Rakefile',
    'lua_parser.gemspec'
  ]
end
