%%machine lex; # % fix highlighting

class Parser::LexerStrings

  %% write data nofinal;
  # %

  ESCAPES = {
    ?a.ord => "\a", ?b.ord  => "\b", ?e.ord => "\e", ?f.ord => "\f",
    ?n.ord => "\n", ?r.ord  => "\r", ?s.ord => "\s", ?t.ord => "\t",
    ?v.ord => "\v", ?\\.ord => "\\"
  }.freeze

  REGEXP_META_CHARACTERS = Regexp.union(*"\\$()*+.<>?[]^{|}".chars).freeze

  attr_accessor :herebody_s

  # Set by "main" lexer
  attr_accessor :source_buffer, :source_pts

  def initialize(lexer, version)
    @lexer = lexer
    @version = version

    @_lex_actions =
      if self.class.respond_to?(:_lex_actions, true)
        self.class.send :_lex_actions
      else
        []
      end

    reset
  end

  def reset
    @cs            = self.class.lex_en_unknown
    @literal_stack = []

    @escape_s      = nil # starting position of current sequence
    @escape        = nil # last escaped sequence, as string

    @herebody_s    = nil # starting position of current heredoc line

    # After encountering the closing line of <<~SQUIGGLY_HEREDOC,
    # we store the indentation level and give it out to the parser
    # on request. It is not possible to infer indentation level just
    # from the AST because escape sequences such as `\ ` or `\t` are
    # expanded inside the lexer, but count as non-whitespace for
    # indentation purposes.
    @dedent_level  = nil
  end

  LEX_STATES = {
    :interp_string => lex_en_interp_string,
    :interp_words  => lex_en_interp_words,
    :plain_string  => lex_en_plain_string,
    :plain_words   => lex_en_plain_string,
  }

  def advance(p)
    # Ugly, but dependent on Ragel output. Consider refactoring it somehow.
    klass = self.class
    _lex_trans_keys         = klass.send :_lex_trans_keys
    _lex_key_spans          = klass.send :_lex_key_spans
    _lex_index_offsets      = klass.send :_lex_index_offsets
    _lex_indicies           = klass.send :_lex_indicies
    _lex_trans_targs        = klass.send :_lex_trans_targs
    _lex_trans_actions      = klass.send :_lex_trans_actions
    _lex_to_state_actions   = klass.send :_lex_to_state_actions
    _lex_from_state_actions = klass.send :_lex_from_state_actions
    _lex_eof_trans          = klass.send :_lex_eof_trans
    _lex_actions            = @_lex_actions

    pe = source_pts.size + 2
    eof = pe

    %% write exec;
    # %

    # Ragel creates a local variable called `testEof` but it doesn't use
    # it in any assignment. This dead code is here to swallow the warning.
    # It has no runtime cost because Ruby doesn't produce any instructions from it.
    if false
      testEof
    end

    [p, @root_lexer_state]
  end

  def read_character_constant(p)
    @cs = self.class.lex_en_character

    advance(p)
  end

  #
  # === LITERAL STACK ===
  #

  def push_literal(*args)
    new_literal = Parser::Lexer::Literal.new(self, *args)
    @literal_stack.push(new_literal)
    @cs = next_state_for_literal(new_literal)
  end

  def next_state_for_literal(literal)
    if literal.words? && literal.backslash_delimited?
      if literal.interpolate?
        self.class.lex_en_interp_backslash_delimited_words
      else
        self.class.lex_en_plain_backslash_delimited_words
      end
    elsif literal.words? && !literal.backslash_delimited?
      if literal.interpolate?
        self.class.lex_en_interp_words
      else
        self.class.lex_en_plain_words
      end
    elsif !literal.words? && literal.backslash_delimited?
      if literal.interpolate?
        self.class.lex_en_interp_backslash_delimited
      else
        self.class.lex_en_plain_backslash_delimited
      end
    else
      if literal.interpolate?
        self.class.lex_en_interp_string
      else
        self.class.lex_en_plain_string
      end
    end
  end

  def continue_lexing(current_literal)
    @cs = next_state_for_literal(current_literal)
  end

  def literal
    @literal_stack.last
  end

  def pop_literal
    old_literal = @literal_stack.pop

    @dedent_level = old_literal.dedent_level

    if old_literal.type == :tREGEXP_BEG
      @root_lexer_state = @lexer.class.lex_en_inside_string

      # Fetch modifiers.
      self.class.lex_en_regexp_modifiers
    else
      @root_lexer_state = @lexer.class.lex_en_expr_end

      # Do nothing, yield to main lexer
      nil
    end
  end

  def close_interp_on_current_literal(p)
    current_literal = literal
    if current_literal
      if current_literal.end_interp_brace_and_try_closing
        if version?(18, 19)
          emit(:tRCURLY, '}'.freeze, p - 1, p)
          @lexer.cond.lexpop
          @lexer.cmdarg.lexpop
        else
          emit(:tSTRING_DEND, '}'.freeze, p - 1, p)
        end

        if current_literal.saved_herebody_s
          @herebody_s = current_literal.saved_herebody_s
        end

        continue_lexing(current_literal)

        return true
      end
    end
  end

  def dedent_level
    # We erase @dedent_level as a precaution to avoid accidentally
    # using a stale value.
    dedent_level, @dedent_level = @dedent_level, nil
    dedent_level
  end

  # This hook is triggered by "main" lexer on every newline character
  def on_newline(p)
    # After every heredoc was parsed, @herebody_s contains the
    # position of next token after all heredocs.
    if @herebody_s
      p = @herebody_s
      @herebody_s = nil
    end
    p
  end

  protected

  def eof_codepoint?(point)
    [0x04, 0x1a, 0x00].include? point
  end

  def version?(*versions)
    versions.include?(@version)
  end

  def tok(s = @ts, e = @te)
    @source_buffer.slice(s, e - s)
  end

  def range(s = @ts, e = @te)
    Parser::Source::Range.new(@source_buffer, s, e)
  end

  def emit(type, value = tok, s = @ts, e = @te)
    @lexer.send(:emit, type, value, s, e)
  end

  def diagnostic(type, reason, arguments=nil, location=range, highlights=[])
    @lexer.send(:diagnostic, type, reason, arguments, location, highlights)
  end

  def cond
    @lexer.cond
  end

  def emit_invalid_escapes?
    # always true for old Rubies
    return true if @version < 32

    # in "?\u123" case we don't push any literals
    # but we always emit invalid escapes
    return true if literal.nil?

    # Ruby >= 32, regexp, exceptional case
    !literal.regexp?
  end

  # String escaping

  def extend_string_escaped
    current_literal = literal
    # Get the first character after the backslash.
    escaped_char = source_buffer.slice(@escape_s, 1).chr

    if current_literal.munge_escape? escaped_char
      # If this particular literal uses this character as an opening
      # or closing delimiter, it is an escape sequence for that
      # particular character. Write it without the backslash.

      if current_literal.regexp? && REGEXP_META_CHARACTERS.match(escaped_char)
        # Regular expressions should include escaped delimiters in their
        # escaped form, except when the escaped character is
        # a closing delimiter but not a regexp metacharacter.
        #
        # The backslash itself cannot be used as a closing delimiter
        # at the same time as an escape symbol, but it is always munged,
        # so this branch also executes for the non-closing-delimiter case
        # for the backslash.
        current_literal.extend_string(tok, @ts, @te)
      else
        current_literal.extend_string(escaped_char, @ts, @te)
      end
    else
      # It does not. So this is an actual escape sequence, yay!
      if current_literal.squiggly_heredoc? && escaped_char == "\n".freeze
        # Squiggly heredocs like
        #   <<~-HERE
        #     1\
        #     2
        #   HERE
        # treat '\' as a line continuation, but still dedent the body, so the heredoc above becomes "12\n".
        # This information is emitted as is, without escaping,
        # later this escape sequence (\\\n) gets handled manually in the Lexer::Dedenter
        current_literal.extend_string(tok, @ts, @te)
      elsif current_literal.supports_line_continuation_via_slash? && escaped_char == "\n".freeze
        # Heredocs, regexp and a few other types of literals support line
        # continuation via \\\n sequence. The code like
        #   "a\
        #   b"
        # must be parsed as "ab"
        current_literal.extend_string(tok.gsub("\\\n".freeze, ''.freeze), @ts, @te)
      elsif current_literal.regexp? && @version >= 31 && %w[c C m M].include?(escaped_char)
        # Ruby >= 3.1 escapes \c- and \m chars, that's the only escape sequence
        # supported by regexes so far, so it needs a separate branch.
        current_literal.extend_string(@escape, @ts, @te)
      elsif current_literal.regexp?
        # Regular expressions should include escape sequences in their
        # escaped form. On the other hand, escaped newlines are removed (in cases like "\\C-\\\n\\M-x")
        current_literal.extend_string(tok.gsub("\\\n".freeze, ''.freeze), @ts, @te)
      else
        current_literal.extend_string(@escape || tok, @ts, @te)
      end
    end
  end

  def extend_interp_code(current_literal)
    current_literal.flush_string
    current_literal.extend_content

    emit(:tSTRING_DBEG, '#{'.freeze)

    if current_literal.heredoc?
      current_literal.saved_herebody_s = @herebody_s
      @herebody_s = nil
    end

    current_literal.start_interp_brace
    @lexer.command_start = true
  end

  def extend_interp_digit_var
    if @version >= 27
      literal.extend_string(tok, @ts, @te)
    else
      message = tok.start_with?('#@@') ? :cvar_name : :ivar_name
      diagnostic :error, message, { :name => tok(@ts + 1, @te) }, range(@ts + 1, @te)
    end
  end

  def extend_string_eol_check_eof(current_literal, pe)
    if @te == pe
      diagnostic :fatal, :string_eof, nil,
                 range(current_literal.str_s, current_literal.str_s + 1)
    end
  end

  def extend_string_eol_heredoc_line
    line = tok(@herebody_s, @ts).gsub(/\r+$/, ''.freeze)

    if version?(18, 19, 20)
      # See ruby:c48b4209c
      line = line.gsub(/\r.*$/, ''.freeze)
    end
    line
  end

  def extend_string_eol_heredoc_intertwined(p)
    if @herebody_s
      # This is a regular literal intertwined with a heredoc. Like:
      #
      #     p <<-foo+"1
      #     bar
      #     foo
      #     2"
      #
      # which, incidentally, evaluates to "bar\n1\n2".
      p = @herebody_s - 1
      @herebody_s = nil
    end
    p
  end

  def extend_string_eol_words(current_literal, p)
    if current_literal.words? && !eof_codepoint?(source_pts[p])
      current_literal.extend_space @ts, @te
    else
      # A literal newline is appended if the heredoc was _not_ closed
      # this time (see fbreak above). See also Literal#nest_and_try_closing
      # for rationale of calling #flush_string here.
      current_literal.extend_string tok, @ts, @te
      current_literal.flush_string
    end
  end

  def extend_string_slice_end(lookahead)
    # tLABEL_END is only possible in non-cond context on >= 2.2
    if @version >= 22 && !cond.active?
      lookahead = source_buffer.slice(@te, 2)
    end
    lookahead
  end

  def extend_string_for_token_range(current_literal, string)
    current_literal.extend_string(string, @ts, @te)
  end

  def encode_escape(ord)
    ord.chr.force_encoding(source_buffer.source.encoding)
  end

  def unescape_char(p)
    codepoint = source_pts[p - 1]

    if @version >= 30 && (codepoint == 117 || codepoint == 85) # 'u' or 'U'
      diagnostic :fatal, :invalid_escape
    end

    if (@escape = ESCAPES[codepoint]).nil?
      @escape = encode_escape(source_buffer.slice(p - 1, 1))
    end
  end

  def unicode_points(p)
    @escape = ""

    codepoints = tok(@escape_s + 2, p - 1)
    codepoint_s = @escape_s + 2

    if @version < 24
      if codepoints.start_with?(" ") || codepoints.start_with?("\t")
        diagnostic :fatal, :invalid_unicode_escape, nil,
                   range(@escape_s + 2, @escape_s + 3)
      end

      if spaces_p = codepoints.index(/[ \t]{2}/)
        diagnostic :fatal, :invalid_unicode_escape, nil,
                   range(codepoint_s + spaces_p + 1, codepoint_s + spaces_p + 2)
      end

      if codepoints.end_with?(" ") || codepoints.end_with?("\t")
        diagnostic :fatal, :invalid_unicode_escape, nil, range(p - 1, p)
      end
    end

    codepoints.scan(/([0-9a-fA-F]+)|([ \t]+)/).each do |(codepoint_str, spaces)|
      if spaces
        codepoint_s += spaces.length
      else
        codepoint = codepoint_str.to_i(16)

        if codepoint >= 0x110000
          diagnostic :error, :unicode_point_too_large, nil,
                     range(codepoint_s, codepoint_s + codepoint_str.length)
          break
        end

        @escape += codepoint.chr(Encoding::UTF_8)
        codepoint_s += codepoint_str.length
      end
    end
  end

  def read_post_meta_or_ctrl_char(p)
    @escape = source_buffer.slice(p - 1, 1).chr

    if @version >= 27 && ((0..8).include?(@escape.ord) || (14..31).include?(@escape.ord))
      diagnostic :fatal, :invalid_escape
    end
  end

  def extend_interp_var(current_literal)
    current_literal.flush_string
    current_literal.extend_content

    emit(:tSTRING_DVAR, nil, @ts, @ts + 1)

    @ts
  end

  def emit_interp_var(interp_var_kind)
    case interp_var_kind
    when :cvar
      @lexer.send(:emit_class_var, @ts + 1, @te)
    when :ivar
      @lexer.send(:emit_instance_var, @ts + 1, @te)
    when :gvar
      @lexer.send(:emit_global_var, @ts + 1, @te)
    end
  end

  def encode_escaped_char(p)
    @escape = encode_escape(tok(p - 2, p).to_i(16))
  end

  def slash_c_char
    @escape = encode_escape(@escape[0].ord & 0x9f)
  end

  def slash_m_char
    @escape = encode_escape(@escape[0].ord | 0x80)
  end

  def emit_character_constant
    value = @escape || tok(@ts + 1)

    if version?(18)
      emit(:tINTEGER, value.getbyte(0))
    else
      emit(:tCHARACTER, value)
    end
  end

  def check_ambiguous_slash(tm)
    if tok(tm, tm + 1) == '/'.freeze
      # Ambiguous regexp literal.
      if @version < 30
        diagnostic :warning, :ambiguous_literal, nil, range(tm, tm + 1)
      else
        diagnostic :warning, :ambiguous_regexp, nil, range(tm, tm + 1)
      end
    end
  end

  def check_invalid_escapes(p)
    if emit_invalid_escapes?
      diagnostic :fatal, :invalid_unicode_escape, nil, range(@escape_s - 1, p)
    end
  end

  ESCAPE_WHITESPACE = {
    " "  => '\s', "\r" => '\r', "\n" => '\n', "\t" => '\t',
    "\v" => '\v', "\f" => '\f'
  }

  %%{
  # %

  access @;
  getkey (source_pts[p] || 0);

  # TODO: extract into shared included lexer
  #
  # === CHARACTER CLASSES ===
  #
  # Pay close attention to the differences between c_any and any.
  # c_any does not include EOF and so will cause incorrect behavior
  # for machine subtraction (any-except rules) and default transitions
  # for scanners.

  action do_nl {
    # Record position of a newline for precise location reporting on tNL
    # tokens.
    #
    # This action is embedded directly into c_nl, as it is idempotent and
    # there are no cases when we need to skip it.
    @newline_s = p
  }

  c_nl       = '\n' $ do_nl;
  c_space    = [ \t\r\f\v];
  c_space_nl = c_space | c_nl;

  c_eof      = 0x04 | 0x1a | 0 | zlen; # ^D, ^Z, \0, EOF
  c_eol      = c_nl | c_eof;
  c_any      = any - c_eof;

  c_nl_zlen  = c_nl | zlen;
  c_line     = any - c_nl_zlen;

  c_ascii    = 0x00..0x7f;
  c_unicode  = c_any - c_ascii;
  c_upper    = [A-Z];
  c_lower    = [a-z_]  | c_unicode;
  c_alpha    = c_lower | c_upper;
  c_alnum    = c_alpha | [0-9];

  bareword       = c_alpha c_alnum*;

  # TODO: move to shared included lexer
  #
  # Interpolated variables via "#@foo" / "#$foo"
  global_var     = '$'
      ( bareword | digit+
      | [`'+~*$&?!@/\\;,.=:<>"] # `
      | '-' c_alnum
      )
  ;
  # Ruby accepts (and fails on) variables with leading digit
  # in literal context, but not in unquoted symbol body.
  class_var_v    = '@@' c_alnum+;
  instance_var_v = '@' c_alnum+;

  #
  # === ESCAPE SEQUENCE PARSING ===
  #

  # Escape parsing code is a Ragel pattern, not a scanner, and therefore
  # it shouldn't directly raise errors or perform other actions with side effects.
  # In reality this would probably just mess up error reporting in pathological
  # cases, through.

  # The amount of code required to parse \M\C stuff correctly is ridiculous.

  escaped_nl = "\\" c_nl;

  action unicode_points {
    unicode_points(p)
  }

  action unescape_char {
    unescape_char(p)
  }

  action invalid_complex_escape {
    diagnostic :fatal, :invalid_escape
  }

  action read_post_meta_or_ctrl_char {
    read_post_meta_or_ctrl_char(p)
  }

  action slash_c_char {
    slash_c_char
  }

  action slash_m_char {
    slash_m_char
  }

  maybe_escaped_char = (
        '\\' c_any      %unescape_char
    |   '\\x' xdigit{1,2} % { encode_escaped_char(p) } %slash_c_char
    | ( c_any - [\\] )  %read_post_meta_or_ctrl_char
  );

  maybe_escaped_ctrl_char = ( # why?!
        '\\' c_any      %unescape_char %slash_c_char
    |   '?'             % { @escape = "\x7f" }
    |   '\\x' xdigit{1,2} % { encode_escaped_char(p) } %slash_c_char
    | ( c_any - [\\?] ) %read_post_meta_or_ctrl_char %slash_c_char
  );

  escape = (
      # \377
      [0-7]{1,3}
      % { @escape = encode_escape(tok(@escape_s, p).to_i(8) % 0x100) }

      # \xff
    | 'x' xdigit{1,2}
        % { @escape = encode_escape(tok(@escape_s + 1, p).to_i(16)) }

      # %q[\x]
    | 'x' ( c_any - xdigit )
      % {
        diagnostic :fatal, :invalid_hex_escape, nil, range(@escape_s - 1, p + 2)
      }

      # \u263a
    | 'u' xdigit{4}
      % { @escape = tok(@escape_s + 1, p).to_i(16).chr(Encoding::UTF_8) }

      # \u123
    | 'u' xdigit{0,3}
      % {
        check_invalid_escapes(p)
      }

      # u{not hex} or u{}
    | 'u{' ( c_any - xdigit - [ \t}] )* '}'
      % {
        check_invalid_escapes(p)
      }

      # \u{  \t  123  \t 456   \t\t }
    | 'u{' [ \t]* ( xdigit{1,6} [ \t]+ )*
      (
        ( xdigit{1,6} [ \t]* '}'
          %unicode_points
        )
        |
        ( xdigit* ( c_any - xdigit - [ \t}] )+ '}'
          | ( c_any - [ \t}] )* c_eof
          | xdigit{7,}
        ) % {
          diagnostic :fatal, :unterminated_unicode, nil, range(p - 1, p)
        }
      )

      # \C-\a \cx
    | ( 'C-' | 'c' ) escaped_nl?
      maybe_escaped_ctrl_char

      # \M-a
    | 'M-' escaped_nl?
      maybe_escaped_char
      %slash_m_char

      # \C-\M-f \M-\cf \c\M-f
    | ( ( 'C-'   | 'c' ) escaped_nl?   '\\M-'
      |   'M-\\'         escaped_nl? ( 'C-'   | 'c' ) ) escaped_nl?
      maybe_escaped_ctrl_char
      %slash_m_char

    | 'C' c_any %invalid_complex_escape
    | 'M' c_any %invalid_complex_escape
    | ( 'M-\\C' | 'C-\\M' ) c_any %invalid_complex_escape

    | ( c_any - [0-7xuCMc] ) %unescape_char

    | c_eof % {
      diagnostic :fatal, :escape_eof, nil, range(p - 1, p)
    }
  );

  # Use rules in form of `e_bs escape' when you need to parse a sequence.
  e_bs = '\\' % {
    @escape_s = p
    @escape   = nil
  };

  #
  # === STRING AND HEREDOC PARSING ===
  #

  # Heredoc parsing is quite a complex topic. First, consider that heredocs
  # can be arbitrarily nested. For example:
  #
  #     puts <<CODE
  #     the result is: #{<<RESULT.inspect
  #       i am a heredoc
  #     RESULT
  #     }
  #     CODE
  #
  # which, incidentally, evaluates to:
  #
  #     the result is: "  i am a heredoc\n"
  #
  # To parse them, lexer refers to two kinds (remember, nested heredocs)
  # of positions in the input stream, namely heredoc_e
  # (HEREDOC declaration End) and @herebody_s (HEREdoc BODY line Start).
  #
  # heredoc_e is simply contained inside the corresponding Literal, and
  # when the heredoc is closed, the lexing is restarted from that position.
  #
  # @herebody_s is quite more complex. First, @herebody_s changes after each
  # heredoc line is lexed. This way, at '\n' tok(@herebody_s, @te) always
  # contains the current line, and also when a heredoc is started, @herebody_s
  # contains the position from which the heredoc will be lexed.
  #
  # Second, as (insanity) there are nested heredocs, we need to maintain a
  # stack of these positions. Each time #push_literal is called, it saves current
  # @heredoc_s to literal.saved_herebody_s, and after an interpolation (possibly
  # containing another heredocs) is closed, the previous value is restored.

  action extend_string {
    string = tok

    lookahead = extend_string_slice_end(lookahead)

    current_literal = literal
    if !current_literal.heredoc? &&
          (token = current_literal.nest_and_try_closing(string, @ts, @te, lookahead))
      if token[0] == :tLABEL_END
        p += 1
        pop_literal
        @root_lexer_state = @lexer.class.lex_en_expr_labelarg
      else
        if state = pop_literal
          fnext *state;
        end
      end
      fbreak;
    else
      extend_string_for_token_range(current_literal, string)
    end
  }

  action extend_string_escaped {
    extend_string_escaped
  }

  # Extend a string with a newline or a EOF character.
  # As heredoc closing line can immediately precede EOF, this action
  # has to handle such case specially.
  action extend_string_eol {
    current_literal = literal
    extend_string_eol_check_eof(current_literal, pe)

    if current_literal.heredoc?
      line = extend_string_eol_heredoc_line

      # Try ending the heredoc with the complete most recently
      # scanned line. @herebody_s always refers to the start of such line.
      if current_literal.nest_and_try_closing(line, @herebody_s, @ts)
        # Adjust @herebody_s to point to the next line.
        @herebody_s = @te

        # Continue regular lexing after the heredoc reference (<<END).
        p = current_literal.heredoc_e - 1
        fnext *pop_literal; fbreak;
      else
        # Calculate indentation level for <<~HEREDOCs.
        current_literal.infer_indent_level(line)

        # Ditto.
        @herebody_s = @te
      end
    else
      # Try ending the literal with a newline.
      if current_literal.nest_and_try_closing(tok, @ts, @te)
        fnext *pop_literal; fbreak;
      end

      p = extend_string_eol_heredoc_intertwined(p)
    end

    extend_string_eol_words(current_literal, p)
  }

  action extend_string_space {
    literal.extend_space @ts, @te
  }

  #
  # === INTERPOLATION PARSING ===
  #

  # Interpolations with immediate variable names simply call into
  # the corresponding machine.

  interp_var = '#' (
      global_var     % { interp_var_kind = :gvar }
    | class_var_v    % { interp_var_kind = :cvar }
    | instance_var_v % { interp_var_kind = :ivar }
  );

  action extend_interp_var {
    current_literal = literal
    extend_interp_var(current_literal)
    emit_interp_var(interp_var_kind)
  }

  # Special case for Ruby > 2.7
  # If interpolated instance/class variable starts with a digit we parse it as a plain substring
  # However, "#$1" is still a regular interpolation
  interp_digit_var = '#' ('@' | '@@') digit c_alpha*;

  action extend_interp_digit_var {
    extend_interp_digit_var
  }

  # Interpolations with code blocks must match nested curly braces, as
  # interpolation ending is ambiguous with a block ending. So, every
  # opening and closing brace should be matched with e_[lr]brace rules,
  # which automatically perform the counting.
  #
  # Note that interpolations can themselves be nested, so brace balance
  # is tied to the innermost literal.
  #
  # Also note that literals themselves should not use e_[lr]brace rules
  # when matching their opening and closing delimiters, as the amount of
  # braces inside the characters of a string literal is independent.

  interp_code = '#{';

  action extend_interp_code {
    current_literal = literal
    extend_interp_code(current_literal)
    @root_lexer_state = @lexer.class.lex_en_expr_value;
    fbreak;
  }

  # Actual string parsers are simply combined from the primitives defined
  # above.

  interp_words := |*
      interp_code      => extend_interp_code;
      interp_digit_var => extend_interp_digit_var;
      interp_var       => extend_interp_var;
      e_bs escape      => extend_string_escaped;
      c_space+         => extend_string_space;
      c_eol            => extend_string_eol;
      c_any            => extend_string;
  *|;

  interp_string := |*
      interp_code      => extend_interp_code;
      interp_digit_var => extend_interp_digit_var;
      interp_var       => extend_interp_var;
      e_bs escape      => extend_string_escaped;
      c_eol            => extend_string_eol;
      c_any            => extend_string;
  *|;

  plain_words := |*
      e_bs c_any       => extend_string_escaped;
      c_space+         => extend_string_space;
      c_eol            => extend_string_eol;
      c_any            => extend_string;
  *|;

  plain_string := |*
      '\\' c_nl        => extend_string_eol;
      e_bs c_any       => extend_string_escaped;
      c_eol            => extend_string_eol;
      c_any            => extend_string;
  *|;

  interp_backslash_delimited := |*
      interp_code      => extend_interp_code;
      interp_digit_var => extend_interp_digit_var;
      interp_var       => extend_interp_var;
      c_eol            => extend_string_eol;
      c_any            => extend_string;
  *|;

  plain_backslash_delimited := |*
      c_eol            => extend_string_eol;
      c_any            => extend_string;
  *|;

  interp_backslash_delimited_words := |*
      interp_code      => extend_interp_code;
      interp_digit_var => extend_interp_digit_var;
      interp_var       => extend_interp_var;
      c_space+         => extend_string_space;
      c_eol            => extend_string_eol;
      c_any            => extend_string;
  *|;

  plain_backslash_delimited_words := |*
      c_space+         => extend_string_space;
      c_eol            => extend_string_eol;
      c_any            => extend_string;
  *|;

  regexp_modifiers := |*
      [A-Za-z]+
      => {
        unknown_options = tok.scan(/[^imxouesn]/)
        if unknown_options.any?
          diagnostic :error, :regexp_options,
                     { :options => unknown_options.join }
        end

        emit(:tREGEXP_OPT)
        @root_lexer_state = @lexer.class.lex_en_expr_end;
        fbreak;
      };

      any
      => {
        emit(:tREGEXP_OPT, tok(@ts, @te - 1), @ts, @te - 1)
        fhold;
        @root_lexer_state = @lexer.class.lex_en_expr_end;
        fbreak;
      };
  *|;

  character := |*
      #
      # AMBIGUOUS TERNARY OPERATOR
      #

      # Character constant, like ?a, ?\n, ?\u1000, and so on
      # Don't accept \u escape with multiple codepoints, like \u{1 2 3}
      '?' ( e_bs ( escape - ( '\u{' (xdigit+ [ \t]+)+ xdigit+ '}' ))
          | (c_any - c_space_nl - e_bs) % { @escape = nil }
          )
      => {
        emit_character_constant

        @root_lexer_state = @lexer.class.lex_en_expr_end; fbreak;
      };

      '?' c_space_nl
      => {
        escape = ESCAPE_WHITESPACE[source_buffer.slice(@ts + 1, 1)]
        diagnostic :warning, :invalid_escape_use, { :escape => escape }, range

        p = @ts - 1
        @root_lexer_state = @lexer.class.lex_en_expr_end;
        fbreak;
      };

      # f ?aa : b: Disambiguate with a character literal.
      '?' [A-Za-z_] bareword
      => {
        p = @ts - 1
        @root_lexer_state = @lexer.class.lex_en_expr_end;
        fbreak;
      };
  *|;

  unknown := |*
      c_any => { raise 'bug' };
  *|;

  }%%
  # %

end
