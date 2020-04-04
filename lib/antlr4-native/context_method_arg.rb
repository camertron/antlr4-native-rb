module Antlr4Native
  class ContextMethodArg
    attr_reader :raw_arg

    def initialize(raw_arg)
      @raw_arg = raw_arg
    end

    def name
      @name ||= parts[1]
    end

    def type
      @type ||= parts[0].gsub(' ', '')
    end

    def pointer?
      type.end_with?('*')
    end

    private

    def parts
      @parts ||= raw_arg.scan(/([\w\d:]+\s?\*?\s?)/).flatten
    end
  end
end
