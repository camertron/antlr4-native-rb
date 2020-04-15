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

    # @TODO: consider revising this
    def context_method?
      !token_method? &&
        !rule_method? &&
        !meta_method? &&
        !constructor?
    end

    def token_method?
      name[0].upcase == name[0]
    end

    def rule_method?
      RULE_METHODS.include?(name)
    end

    def meta_method?
      META_METHODS.include?(name)
    end

    def constructor?
      name == context.name
    end
  end
end
