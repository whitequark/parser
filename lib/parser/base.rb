module Parser
  class Base < Racc::Parser
    def self.parse(string, file='(string)', line=1)
      parser = new

      #parser.diagnostics.all_errors_are_fatal = true

      # Temporary, for manual testing convenience
      parser.diagnostics.consumer = ->(diagnostic) do
        $stderr.puts(diagnostic.render)
      end

      source_file = SourceFile.new(file, line)
      source_file.source = string

      parser.parse(source_file)
    end

    attr_reader :diagnostics
    attr_reader :static_env

    # The source file currently being parsed.
    attr_reader :source_file

    def initialize(builder=Parser::Builders::Sexp.new)
      @diagnostics = DiagnosticsEngine.new

      @static_env  = StaticEnvironment.new

      @lexer = Lexer.new(version)
      @lexer.diagnostics = @diagnostics
      @lexer.static_env  = @static_env

      @builder = builder
      @builder.parser = self

      reset
    end

    def version
      raise NotImplementedError, "implement #{self.class}#version"
    end

    def reset
      @source_file = nil
      @def_level   = 0 # count of nested def's.

      @lexer.reset
      @static_env.reset

      self
    end

    def parse(source_file)
      @source_file       = source_file
      @lexer.source_file = source_file

      do_parse
    ensure
      # Don't keep references to the source file.
      @source_file       = nil
      @lexer.source_file = nil
    end

    def in_def?
      @def_level > 0
    end

    protected

    def value_expr(v)
      p 'value_expr', v
      v
    end

    def arg_blk_pass(v1, v2)
      p 'arg_blk_pass', v1, v2
      v1
    end

    def next_token
      @lexer.advance
    end

    def syntax_error(kind, tokens)
      ranges = tokens.map do |token|
        value, range = token
        range
      end

      message    = Parser::ERRORS[kind]
      diagnostic = Diagnostic.new(:error, message,
                                  @source_file, ranges)

      @diagnostics.process(diagnostic)

      yyerror
    end

    def on_error(error_token_id, error_value, value_stack)
      token_name = token_to_str(error_token_id)
      _, token_range = error_value

      # TODO add "expected: ..." here
      message    = Parser::ERRORS[:unexpected_token] % { token: token_name }
      diagnostic = Diagnostic.new(:error, message,
                                  @source_file, [token_range])

      @diagnostics.process(diagnostic)
    end
  end
end
