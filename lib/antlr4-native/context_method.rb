module Antlr4Native
  class ContextMethod
    RULE_METHODS = %w(enterRule exitRule getRuleIndex).freeze
    META_METHODS = %w(accept copyFrom).freeze

    attr_reader :name, :raw_args, :return_type, :context

    def initialize(name, raw_args, return_type, context)
      @name = name
      @raw_args = raw_args
      @return_type = return_type
      @context = context
    end

    def cpp_name
      @cpp_name ||=
        if args.size == 1 && args.first.name == 'i'
          # special case
          "#{name}At"
        else
          [name, *args.map(&:name)].join('_')
        end
    end

    def args
      @args ||= raw_args.split(',').map do |arg|
        ContextMethodArg.new(arg.strip)
      end
    end

    def returns_vector?
      return_type.start_with?('std::vector')
    end

    def fetches_token?
      name.upcase == name
    end

    def rule?
      RULE_METHODS.include?(name)
    end

    def meta?
      META_METHODS.include?(name)
    end

    def constructor?
      name == context.name
    end
  end
end
