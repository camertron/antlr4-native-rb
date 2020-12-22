require 'fileutils'

module Antlr4Native
  class Generator
    ANTLR_VERSION = '4.8'.freeze

    ANTLR_JAR = File.expand_path(
      File.join('..', '..', 'vendor', 'antlr4-4.8-1-complete.jar'), __dir__
    ).freeze

    include StringHelpers

    attr_reader :grammar_files, :output_dir, :parser_root_method

    def initialize(grammar_files:, output_dir:, parser_root_method:)
      @grammar_files = grammar_files
      @output_dir = output_dir
      @parser_root_method = parser_root_method
    end

    def generate
      generate_antlr_code
      write_interop_file
    end

    def gem_name
      @gem_name ||= dasherize(parser_ns)
    end

    def antlr_ns
      grammar_names['parser'] || grammar_names['default']
    end

    def parser_ns
      @parser_ns ||= grammar_names['parser'] || "#{grammar_names['default']}Parser"
    end

    def lexer_ns
      @lexer_ns ||= grammar_names['lexer'] || "#{grammar_names['default']}Lexer"
    end

    def ext_name
      @ext_name ||= underscore(parser_ns)
    end

    private

    def generate_antlr_code
      FileUtils.mkdir_p(antlrgen_dir)

      system(<<~END)
        java -jar #{ANTLR_JAR} \
          -o #{antlrgen_dir} \
          -Dlanguage=Cpp \
          -visitor \
          #{grammar_files.join(' ')}
      END
    end

    def write_interop_file
      File.write(interop_file, interop_code)
    end

    def interop_code
      <<~END
        #include "iostream"

        #include "antlr4-runtime.h"

        #include "#{parser_ns}.h"
        #include "#{antlr_ns}BaseVisitor.h"
        #include "#{lexer_ns}.h"

        #include "rice/Array.hpp"
        #include "rice/Class.hpp"
        #include "rice/Constructor.hpp"
        #include "rice/Director.hpp"

        using namespace std;
        using namespace Rice;
        using namespace antlr4;

        #{proxy_class_declarations}

        template <>
        Object to_ruby<Token*>(Token* const &x) {
          if (!x) return Nil;
          return Data_Object<Token>(x, rb_cToken, nullptr, nullptr);
        }

        template <>
        Object to_ruby<tree::ParseTree*>(tree::ParseTree* const &x) {
          if (!x) return Nil;
          return Data_Object<tree::ParseTree>(x, rb_cParseTree, nullptr, nullptr);
        }

        template <>
        Object to_ruby<tree::TerminalNode*>(tree::TerminalNode* const &x) {
          if (!x) return Nil;
          return Data_Object<tree::TerminalNode>(x, rb_cTerminalNode, nullptr, nullptr);
        }

        class ContextProxy {
        public:
          ContextProxy(tree::ParseTree* orig) {
            this -> orig = orig;
          }

          tree::ParseTree* getOriginal() {
            return orig;
          }

          std::string getText() {
            return orig -> getText();
          }

          Object getStart() {
            auto token = ((ParserRuleContext*) orig) -> getStart();

            return to_ruby(token);
          }

          Object getStop() {
            auto token = ((ParserRuleContext*) orig) -> getStop();

            return to_ruby(token);
          }

          Array getChildren() {
            if (children == nullptr) {
              children = new Array();

              if (orig != nullptr) {
                for (auto it = orig -> children.begin(); it != orig -> children.end(); it ++) {
                  Object parseTree = ContextProxy::wrapParseTree(*it);

                  if (parseTree != Nil) {
                    children -> push(parseTree);
                  }
                }
              }
            }

            return *children;
          }

          Object getParent() {
            if (parent == Nil) {
              if (orig != nullptr) {
                parent = ContextProxy::wrapParseTree(orig -> parent);
              }
            }

            return parent;
          }

          size_t childCount() {
            if (orig == nullptr) {
              return 0;
            }

            return getChildren().size();
          }

          bool doubleEquals(Object other) {
            if (other.is_a(rb_cContextProxy)) {
              return from_ruby<ContextProxy*>(other) -> getOriginal() == getOriginal();
            } else {
              return false;
            }
          }

        private:

          static Object wrapParseTree(tree::ParseTree* node);

        protected:
          tree::ParseTree* orig = nullptr;
          Array* children = nullptr;
          Object parent = Nil;
        };

        class TerminalNodeProxy : public ContextProxy {
        public:
          TerminalNodeProxy(tree::ParseTree* tree) : ContextProxy(tree) { }
        };

        #{proxy_class_headers}

        #{conversions}

        #{proxy_class_methods}

        #{visitor_generator.visitor_proxy}

        #{parser_class}

        #{context_proxy_methods}

        #{init_function}
      END
    end

    def proxy_class_headers
      @proxy_class_headers ||= contexts
        .map(&:proxy_class_header)
        .join("\n")
    end

    def proxy_class_declarations
      @proxy_class_declarations ||= contexts
        .map { |ctx| "Class #{ctx.proxy_class_variable};" }
        .concat([
          'Class rb_cToken;',
          'Class rb_cParser;',
          'Class rb_cParseTree;',
          'Class rb_cTerminalNode;',
          'Class rb_cContextProxy;'
        ])
        .join("\n")
    end

    def conversions
      @conversions ||= contexts.map(&:conversions).join("\n")
    end

    def proxy_class_methods
      @proxy_class_methods ||= contexts.flat_map(&:proxy_class_methods).join("\n")
    end

    def parser_class
      @parser_class ||= <<~END
        class ParserProxy {
        public:
          static ParserProxy* parse(string code) {
            auto input = new ANTLRInputStream(code);
            return parseStream(input);
          }

          static ParserProxy* parseFile(string file) {
            ifstream stream;
            stream.open(file);

            auto input = new ANTLRInputStream(stream);
            auto parser = parseStream(input);

            stream.close();

            return parser;
          }

          VALUE visit(VisitorProxy* visitor) {
            visitor -> visit(this -> parser -> #{parser_root_method}());

            // reset for the next visit call
            this -> lexer -> reset();
            this -> parser -> reset();

            return Qnil;
          }

          ~ParserProxy() {
            delete this -> parser;
            delete this -> tokens;
            delete this -> lexer;
            delete this -> input;
          }

        private:
          static ParserProxy* parseStream(ANTLRInputStream* input) {
            ParserProxy* parser = new ParserProxy();

            parser -> input = input;
            parser -> lexer = new #{lexer_ns}(parser -> input);
            parser -> tokens = new CommonTokenStream(parser -> lexer);
            parser -> parser = new #{parser_ns}(parser -> tokens);

            return parser;
          }

          ParserProxy() {};

          ANTLRInputStream* input;
          #{lexer_ns}* lexer;
          CommonTokenStream* tokens;
          #{parser_ns}* parser;
        };

        template <>
        Object to_ruby<ParserProxy*>(ParserProxy* const &x) {
          if (!x) return Nil;
          return Data_Object<ParserProxy>(x, rb_cParser, nullptr, nullptr);
        }
      END
    end

    def init_function
      <<~END
        extern "C"
        void Init_#{ext_name}() {
          Module rb_m#{parser_ns} = define_module("#{parser_ns}");

          rb_cToken = rb_m#{parser_ns}
            .define_class<Token>("Token")
            .define_method("text", &Token::getText)
            .define_method("channel", &Token::getChannel)
            .define_method("token_index", &Token::getTokenIndex);

          rb_cParser = rb_m#{parser_ns}
            .define_class<ParserProxy>("Parser")
            .define_singleton_method("parse", &ParserProxy::parse)
            .define_singleton_method("parse_file", &ParserProxy::parseFile)
            .define_method("visit", &ParserProxy::visit);

          rb_cParseTree = rb_m#{parser_ns}
            .define_class<tree::ParseTree>("ParseTree");

          rb_cContextProxy = rb_m#{parser_ns}
            .define_class<ContextProxy>("Context")
            .define_method("children", &ContextProxy::getChildren)
            .define_method("child_count", &ContextProxy::childCount)
            .define_method("text", &ContextProxy::getText)
            .define_method("start", &ContextProxy::getStart)
            .define_method("stop", &ContextProxy::getStop)
            .define_method("parent", &ContextProxy::getParent)
            .define_method("==", &ContextProxy::doubleEquals);

          rb_cTerminalNode = rb_m#{parser_ns}
            .define_class<TerminalNodeProxy, ContextProxy>("TerminalNodeImpl");

          rb_m#{parser_ns}
            .define_class<#{visitor_generator.cpp_class_name}>("#{visitor_generator.class_name}")
            .define_director<#{visitor_generator.cpp_class_name}>()
            .define_constructor(Constructor<#{visitor_generator.cpp_class_name}, Object>())
            .define_method("visit", &#{visitor_generator.cpp_class_name}::ruby_visit)
            .define_method("visit_children", &#{visitor_generator.cpp_class_name}::ruby_visitChildren)
        #{visitor_generator.visitor_proxy_methods('    ').join("\n")};

        #{class_wrappers_str('  ')}
        }
      END
    end

    def context_proxy_methods
      @context_proxy_methods ||= begin
        wrapper_branches = contexts.flat_map.with_index do |context, idx|
          [
            "  #{idx == 0 ? 'if' : 'else if'} (antlrcpp::is<#{parser_ns}::#{context.name}*>(node)) {",
            "    #{context.name}Proxy proxy((#{parser_ns}::#{context.name}*)node);",
            "    return to_ruby(proxy);",
            "  }"
          ]
        end

        <<~END
          Object ContextProxy::wrapParseTree(tree::ParseTree* node) {
          #{wrapper_branches.join("\n")}
            else if (antlrcpp::is<tree::TerminalNodeImpl*>(node)) {
              TerminalNodeProxy proxy(node);
              return to_ruby(proxy);
            } else {
              return Nil;
            }
          }
        END
      end
    end

    def class_wrappers_str(indent)
      class_wrappers.map do |cw|
        ["#{indent}#{cw[0]}", *cw[1..-1].map { |line| "#{indent}  #{line}" }].join("\n")
      end.join("\n\n")
    end

    def class_wrappers
      @class_wrappers ||= contexts.map do |ctx|
        ctx.class_wrapper("rb_m#{parser_ns}")
      end
    end

    def contexts
      @contexts ||= cpp_parser_source
        .scan(/#{parser_ns}::([^\s:\(\)]+Context)/)
        .flatten
        .uniq
        .reject { |c| c == '_sharedContext' }
        .map { |name| Context.new(name, parser_ns, cpp_parser_source) }
    end

    def visitor_methods
      @visitor_methods ||= cpp_visitor_source
        .scan(/visit[A-Z][^\(\s]*/)
        .flatten
        .uniq
    end

    def visitor_generator
      @visitor_generator ||= VisitorGenerator.new(visitor_methods, antlr_ns, parser_ns)
    end

    def antlrgen_dir
      @antlrgen_dir ||= File.join(output_dir, gem_name, 'antlrgen')
    end

    def interop_file
      @interop_file ||= File.join(output_dir, gem_name, "#{ext_name}.cpp")
    end

    def grammar_names
      @grammar_names ||= begin
        grammar_files.each_with_object({}) do |grammar_file, ret|
          kind, name = File.read(grammar_file).scan(/^(parser|lexer)?\s*grammar\s*([^;]+);/).flatten
          ret[kind&.strip || 'default'] = name
        end
      end
    end

    def cpp_parser_source
      @cpp_parser_source ||= File.read(File.join(antlrgen_dir, "#{parser_ns}.cpp"))
    end

    def cpp_visitor_source
      @cpp_visitor_source ||= File.read(File.join(antlrgen_dir, "#{antlr_ns}BaseVisitor.h"))
    end
  end
end
