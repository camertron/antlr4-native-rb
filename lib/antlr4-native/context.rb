module Antlr4Native
  class Context
    include StringHelpers

    attr_reader :name, :parser_ns, :cpp_parser_source

    def initialize(name, parser_ns, cpp_parser_source)
      @name = name
      @parser_ns = parser_ns
      @cpp_parser_source = cpp_parser_source
    end

    def each_context_method
      return to_enum(__method__) unless block_given?

      mtds.each do |mtd|
        yield mtd if mtd.context_method?
      end
    end

    def each_token_method
      return to_enum(__method__) unless block_given?

      mtds.each do |mtd|
        yield mtd if mtd.token_method?
      end
    end

    def proxy_class_variable
      @proxy_class_variable ||= "rb_c#{name}"
    end

    def proxy_class_header
      @proxy_class_header ||= begin
        <<~END
          class #{name}Proxy : public ContextProxy {
          public:
            #{name}Proxy(tree::ParseTree* ctx) : ContextProxy(ctx) {};
          #{method_signatures_for(each_context_method)}
          #{method_signatures_for(each_token_method)}
          };
        END
      end
    end

    def method_signatures_for(mtds)
      mtds
        .map { |mtd| "  Object #{mtd.cpp_name}(#{mtd.raw_args});" }
        .join("\n")
    end

    def conversions
      @class_conversions ||= <<~END
        template <>
        Object to_ruby<#{parser_ns}::#{name}*>(#{parser_ns}::#{name}* const &x) {
          if (!x) return Nil;
          return Data_Object<#{parser_ns}::#{name}>(x, #{proxy_class_variable}, nullptr, nullptr);
        }

        template <>
        Object to_ruby<#{name}Proxy*>(#{name}Proxy* const &x) {
          if (!x) return Nil;
          return Data_Object<#{name}Proxy>(x, #{proxy_class_variable}, nullptr, nullptr);
        }
      END
    end

    def proxy_class_methods
      proxy_class_context_methods + proxy_class_token_methods
    end

    def proxy_class_context_methods
      each_context_method.map do |ctx_method|
        return_type = "#{capitalize(ctx_method.name)}Context"
        return_proxy_type = "#{return_type}Proxy"
        params = ctx_method.args.map(&:name).join(', ')

        if ctx_method.returns_vector?
          <<~END
            Object #{name}Proxy::#{ctx_method.cpp_name}(#{ctx_method.raw_args}) {
              Array a;

              if (orig != nullptr) {
                size_t count = ((#{parser_ns}::#{name}*)orig) -> #{ctx_method.name}(#{params}).size();

                for (size_t i = 0; i < count; i ++) {
                  a.push(#{ctx_method.name}At(i));
                }
              }

              return a;
            }
          END
        else
          <<~END
            Object #{name}Proxy::#{ctx_method.cpp_name}(#{ctx_method.raw_args}) {
              if (orig == nullptr) {
                return Qnil;
              }

              auto ctx = ((#{parser_ns}::#{name}*)orig) -> #{ctx_method.name}(#{params});

              if (ctx == nullptr) {
                return Qnil;
              }

              #{return_proxy_type} proxy(ctx);
              return to_ruby(proxy);
            }
          END
        end
      end
    end

    def proxy_class_token_methods
      each_token_method.map do |token_mtd|
        params = token_mtd.args.map(&:name).join(', ')

        if token_mtd.returns_vector?
          <<~END
            Object #{name}Proxy::#{token_mtd.cpp_name}(#{token_mtd.raw_args}) {
              Array a;

              if (orig == nullptr) {
                return a;
              }

              auto vec = ((#{parser_ns}::#{name}*)orig) -> #{token_mtd.name}(#{params});

              for (auto it = vec.begin(); it != vec.end(); it ++) {
                TerminalNodeProxy proxy(*it);
                a.push(proxy);
              }

              return a;
            }
          END
        else
          <<~END
            Object #{name}Proxy::#{token_mtd.cpp_name}(#{token_mtd.raw_args}) {
              if (orig == nullptr) {
                return Qnil;
              }

              auto token = ((#{parser_ns}::#{name}*)orig) -> #{token_mtd.name}(#{params});
              TerminalNodeProxy proxy(token);
              return to_ruby(proxy);
            }
          END
        end
      end
    end

    def class_wrapper(module_var)
      @class_wrapper ||= begin
        lines = [
          "#{proxy_class_variable} = #{module_var}",
          ".define_class<#{name}Proxy, ContextProxy>(\"#{name}\")"
        ]

        each_context_method do |ctx_method|
          lines << ".define_method(\"#{underscore(ctx_method.cpp_name)}\", &#{name}Proxy::#{ctx_method.cpp_name})"
        end

        each_token_method do |token_method|
          lines << ".define_method(\"#{token_method.cpp_name}\", &#{name}Proxy::#{token_method.name})"
        end

        lines[-1] << ';'

        lines
      end
    end

    private

    def mtds
      @mtds ||= begin
        puts "Finding methods for #{name}"

        cpp_parser_source
          .scan(/^([^\n]+) #{parser_ns}::#{name}::([^\(]*)\(([^\)]*)\)/).flat_map do |return_type, mtd_name, args|
            ContextMethod.new(mtd_name, args, return_type, self)
          end
      end
    end
  end
end
