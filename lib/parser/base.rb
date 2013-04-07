module Parser

  class Base < Racc::Parser
    def self.parse(string, file='(string)', line=1)
      parser = new

      parser.diagnostics.all_errors_are_fatal = true
      parser.diagnostics.ignore_warnings      = true

      # Temporary, for manual testing convenience
      parser.diagnostics.consumer = lambda do |diagnostic|
        $stderr.puts(diagnostic.render)
      end

      source_buffer = Source::Buffer.new(file, line)
      source_buffer.source = string

      parser.parse(source_buffer)
    end

    def self.parse_file(filename)
      parse(File.read(filename), filename)
    end

    attr_reader :diagnostics
    attr_reader :static_env

    # The source file currently being parsed.
    attr_reader :source_buffer

    def initialize(builder=Parser::Builders::Default.new)
      @diagnostics = Diagnostic::Engine.new

      @static_env  = StaticEnvironment.new

      @comments    = []

      @lexer = Lexer.new(version)
      @lexer.diagnostics = @diagnostics
      @lexer.static_env  = @static_env

      @builder = builder
      @builder.parser = self

      if self.class::Racc_debug_parser && ENV['RACC_DEBUG']
        @yydebug = true
      end

      reset
    end

    def version
      raise NotImplementedError, "implement #{self.class}#version"
    end

    def reset
      @source_buffer = nil
      @def_level   = 0 # count of nested def's.

      @lexer.reset
      @static_env.reset

      self
    end

    def parse(source_buffer)
      @source_buffer       = source_buffer
      @lexer.source_buffer = source_buffer

      do_parse
    ensure
      # Don't keep references to the source file.
      @source_buffer       = nil
      @lexer.source_buffer = nil
    end

    def in_def?
      @def_level > 0
    end

    protected

    def value_expr(v)
      #p 'value_expr', v
      v
    end

    def next_token
      @lexer.advance
    end

    def diagnostic(level, kind, location_tok, highlights_tok=[])
      _, location = location_tok

      highlights = highlights_tok.map do |token|
        _, range = token
        range
      end

      message = ERRORS[kind]
      @diagnostics.process(
          Diagnostic.new(level, message, location, highlights))

      if level == :error
        yyerror
      end
    end

    def on_error(error_token_id, error_value, value_stack)
      token_name = token_to_str(error_token_id)
      _, location = error_value

      # TODO add "expected: ..." here
      message = ERRORS[:unexpected_token] % { :token => token_name }
      @diagnostics.process(
          Diagnostic.new(:error, message, location))
    end
  end

end
