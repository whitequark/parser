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

    def reset
      @source_buffer = nil
      @def_level     = 0 # count of nested def's.

      @lexer.reset
      @static_env.reset

      self
    end

    def parse(source_buffer)
      @lexer.source_buffer = source_buffer
      @source_buffer       = source_buffer

      do_parse
    ensure
      # Don't keep references to the source file.
      @source_buffer       = nil
      @lexer.source_buffer = nil
    end

    def parse_with_comments(source_buffer)
      @lexer.comments = []

      [ parse(source_buffer), @lexer.comments ]
    ensure
      @lexer.comments = nil
    end

    # Currently, token stream format returned by #lex is not documented,
    # but is considered part of a public API and only changed according
    # to Semantic Versioning.
    #
    # However, note that the exact token composition of various constructs
    # might vary. For example, a string `"foo"` is represented equally well
    # by `:tSTRING_BEG " :tSTRING_CONTENT foo :tSTRING_END "` and
    # `:tSTRING "foo"`; such details must not be relied upon.
    #
    def tokenize(source_buffer)
      @lexer.tokens = []

      ast, comments = parse_with_comments(source_buffer)

      [ ast, comments, @lexer.tokens ]
    ensure
      @lexer.tokens = nil
    end

    # @api internal
    def in_def?
      @def_level > 0
    end

    protected

    def next_token
      @lexer.advance
    end

    def value_expr(v)
      #p 'value_expr', v
      v
    end

    def check_kwarg_name(name_t)
      case name_t[0]
      when /^[a-z_]/
        # OK
      when /^[A-Z]/
        diagnostic :error, :argument_const, name_t
      end
    end

    def diagnostic(level, kind, location_t, highlights_ts=[])
      _, location = location_t

      highlights = highlights_ts.map do |token|
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

      message = ERRORS[:unexpected_token] % { :token => token_name }
      @diagnostics.process(
          Diagnostic.new(:error, message, location))
    end
  end

end
