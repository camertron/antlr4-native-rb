# frozen_string_literal: true

require "lua_parser"

class FuncVisitor < LuaParser::Visitor
  def visit_functioncall(ctx)
    puts ctx.var_or_exp.text
    visit_children(ctx)
  end
end

Dir.glob('lua/**/*.lua').each do |file_name|
  # this file contains some weird non-UTF8 strings, so let's just skip it
  next if File.basename(file_name) == "strings.lua"

  lua_code = File.read(file_name)
  parser = LuaParser::Parser.parse(lua_code)
  visitor = FuncVisitor.new
  parser.visit(visitor)
end
