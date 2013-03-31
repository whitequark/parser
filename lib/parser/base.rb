require 'racc/parser'

module Parser
  class Base < Racc::Parser
    def self.parse(string, file='(string)', line=1)
      new.parse(string, file, line)
    end

    attr_reader :static_env

    def initialize(builder=nil)
      @lexer      = Lexer.new(version)
      @builder    = builder

      reset
    end

    def version
      raise NotImplementedError, "implement #{self.class}#version"
    end

    def reset
      @file       = nil
      @def_level  = 0 # count of nested def's.
      @static_env = StaticEnvironment.new
    end

    def parse(string, file='(string)', line=1)
      @file       = file

      do_parse
    end

    protected

    def next_token
      @lexer.advance
    end

    def on_error(error_token_id, error_value, value_stack)
      # TODO: emit a diagnostic
      super
    end
  end
end
