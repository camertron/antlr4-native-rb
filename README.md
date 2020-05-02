# antlr4-native

Create a Ruby native extension from (almost) any ANTLR4 grammar.

## What is this thing?

This gem generates native Ruby extensions from ANTLR grammars, enabling Ruby developers to generate parsers for numerous programming languages, file formats, etc.

## Who needs this?

If you're a Ruby programmer who wants to parse and traverse source code written in a plethora of programming languages, antlr4-native might be able to help you. A number of community-developed ANTLR grammars are available in ANTLR's [grammars-v4](https://github.com/antlr/grammars-v4) repo. Grab one, then use antlr4-native to generate a bunch of Ruby-compatible C++ code from it. The C++ code can be compiled and used as a native extension.

Rather than use antlr4-native directly, consider using its sister project, the [antlr-gemerator](https://github.com/camertron/antlr-gemerator), which can generate a complete rubygem from an ANTLR grammar.

## Code Generation

Here's how to generate a native extension for a given lexer and parser (Python in this case), defined in two .g4 files:

```ruby
require 'antlr4-native'

generator = Antlr4Native::Generator.new(
  grammar_files:      ['Python3Lexer.g4', 'Python3Parser.g4'],
  output_dir:         'ext',
  parser_root_method: 'file_input'
)

generator.generate
```

In the example above, the output directory is set to the standard Ruby native extensions directory, 'ext'. Antlr4-native will generate code into ext/<name>, where <name> is the name of the parser as defined in the grammar file(s). In this case, PythonParser.g4 contains:

```antlr
parser grammar Python3Parser;
```

so antlr4-native will generate code into the ext/python3-parser directory.

Finally, the `parser_root_method` option tells antlr4-native which context represents the root of the parse tree. This context functions as the starting point for visitors.

## Using extensions in Ruby

Parsers contain several methods for parsing source code. Use `#parse` to parse a string and `parse_file` to parse the contents of a file:


```ruby
parser = Python3Parser::Parser.parse(File.read('path/to/file.py'))

# equivalent to:
parser = Python3Parser::Parser.parse_file('path/to/file.py')
```

Use the `#visit` method on an instance of `Parser` to make use of a visitor:

```ruby
visitor = MyVisitor.new
parser.visit(visitor)
```

See the next section for more info regarding creating and using visitors.

## Visitors

A visitor class is automatically created during code generation. Visitors are just classes with a bunch of special methods, each corresponding to a specific part of the source language's syntax. The methods are essentially callbacks that are triggered in-order as the parser walks over the parse tree. For example, here's a visitor with a method that will be called whenever the parser walks over a Python function definition:


```ruby
class FuncDefVisitor < Python3Parser::Visitor
  def visit_func_def(ctx)
    puts ctx.NAME.text  # print the name of the method
    visit_children(ctx)
  end
end
```

Make sure to always call `#visit_children` at some point in your `visit_*` methods. If you don't, the subtree under the current context won't get visited.

Finally, if you override `#initialize` in your visitor subclasses, don't forget to call `super`. If you don't, you'll get a nice big segfault.

## License

Licensed under the MIT license. See LICENSE for details.

## Authors

* Cameron C. Dutro: http://github.com/camertron
