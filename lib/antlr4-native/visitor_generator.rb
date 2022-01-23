module Antlr4Native
  class VisitorGenerator
    VISITOR_METHOD_BLACKLIST = %w(visit visitChildren).freeze

    include StringHelpers

    attr_reader :visitor_methods, :antlr_ns, :parser_ns

    def initialize(visitor_methods, antlr_ns, parser_ns)
      @visitor_methods = visitor_methods
      @antlr_ns = antlr_ns
      @parser_ns = parser_ns
    end

    def class_name
      @class_name ||= 'Visitor'
    end

    def cpp_class_name
      @cpp_class_name ||= 'VisitorProxy'
    end

    def each_visitor_method
      return to_enum(__method__) unless block_given?

      visitor_methods.each do |visitor_method|
        yield visitor_method unless VISITOR_METHOD_BLACKLIST.include?(visitor_method)
      end
    end

    def visitor_proxy
      vms = each_visitor_method.flat_map do |visitor_method|
        context = "#{capitalize(visitor_method.sub(/\Avisit/, ''))}Context"

        [
          "  virtual antlrcpp::Any #{visitor_method}(#{parser_ns}::#{context} *ctx) override {",
          "    #{context}Proxy proxy(ctx);",
          "    return getSelf().call(\"#{underscore(visitor_method)}\", &proxy);",
          "  }\n"
        ]
      end

      <<~END
        class #{cpp_class_name} : public #{antlr_ns}BaseVisitor, public Director {
        public:
          #{cpp_class_name}(Object self) : Director(self) { }

          Object ruby_visit(ContextProxy* proxy) {
            auto result = visit(proxy -> getOriginal());
            try {
              return result.as<Object>();
            } catch(std::bad_cast) {
              return Qnil;
            }
          }

          Object ruby_visitChildren(ContextProxy* proxy) {
            auto result = visitChildren(proxy -> getOriginal());
            try {
              return result.as<Object>();
            } catch(std::bad_cast) {
              return Qnil;
            }
          }

        #{vms.join("\n")}
        };
      END
    end

    def visitor_proxy_methods(indent)
      @visitor_proxy_methods ||= each_visitor_method.map do |visitor_method|
        "#{indent}.define_method(\"#{underscore(visitor_method)}\", &#{cpp_class_name}::ruby_visitChildren)"
      end
    end
  end
end
