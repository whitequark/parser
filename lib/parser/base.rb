require 'racc/parser'

require 'parser/static_environment'
require 'parser/lexer'
require 'parser/builders/sexp'

module Parser
  class Base < Racc::Parser
    def self.parse(string, file='(string)', line=1)
      new.parse(string, file, line)
    end

    attr_reader :static_env

    def initialize(builder=Parser::Builders::Sexp.new)
      @lexer = Lexer.new(version)
      @static_env = StaticEnvironment.new
      @lexer.static_env = @static_env

      @builder = builder
      @builder.parser = self

      reset
    end

    def version
      raise NotImplementedError, "implement #{self.class}#version"
    end

    def reset
      @file       = nil
      @def_level  = 0 # count of nested def's.

      @lexer.reset
      @static_env.reset

      self
    end

    def parse(string, file='(string)', line=1)
      @file = file
      @lexer.source = string

      do_parse
    end

    def in_def?
      @def_level > 0
    end

    protected

    def next_token
      @lexer.advance
    end

    def handle_assignable(token)
      value, = token

      case
      if %w(self nil true false __LINE__ __FILE__).include?(value)
        error "Can't change the value of #{value}"
      elsif value =~ /^[a-z_]/
        @static_env.declare value
      end
    end

    def on_error(error_token_id, error_value, value_stack)
      # TODO: emit a diagnostic
      super
    end
  end
end
