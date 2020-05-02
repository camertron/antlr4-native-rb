$:.unshift File.join(File.dirname(__FILE__), 'lib')
require 'antlr4-native/version'

Gem::Specification.new do |s|
  s.name     = 'antlr4-native'
  s.version  = ::Antlr4Native::VERSION
  s.authors  = ['Cameron Dutro']
  s.email    = ['camertron@gmail.com']
  s.homepage = 'http://github.com/camertron/antlr4-native-rb'

  s.description = s.summary = 'Create a Ruby native extension from any ANTLR4 grammar.'

  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true

  s.require_path = 'lib'
  s.files = Dir['{lib,spec,vendor}/**/*', 'Gemfile', 'README.md', 'Rakefile', 'antlr4-native.gemspec']
end
