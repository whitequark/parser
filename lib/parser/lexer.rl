%%machine lex; # % fix highlighting

#
# === BEFORE YOU START ===
#
# Read the Ruby Hacking Guide chapter 11, available in English at
# http://whitequark.org/blog/2013/04/01/ruby-hacking-guide-ch-11-finite-state-lexer/
#
# Remember two things about Ragel scanners:
#
#   1) Longest match wins.
#
#   2) If two matches have the same length, the first
#      in source code wins.
#
# General rules of making Ragel and Bison happy:
#
#  * `p` (position) and `@te` contain the index of the character
#    they're pointing to ("current"), plus one. `@ts` contains the index
#    of the corresponding character. The code for extracting matched token is:
#
#       @source[@ts...@te]
#
#  * If your input is `foooooooobar` and the rule is:
#
#       'f' 'o'+
#
#    the result will be:
#
#       foooooooobar
#       ^ ts=0   ^ p=te=9
#
#  * A Ragel lexer action should not emit more than one token, unless
#    you know what you are doing.
#
#  * All Ragel commands (fnext, fgoto, ...) end with a semicolon.
#
#  * If an action emits the token and transitions to another state, use
#    these Ragel commands:
#
#       emit($whatever)
#       fnext $next_state; fbreak;
#
#  * If an action does not emit a token:
#
#       fgoto $next_state;
#
#  * If an action features lookbehind, i.e. matches characters with the
#    intent of passing them to another action:
#
#       p = @ts - 1
#       fgoto $next_state;
#
#    or, if the lookbehind consists of a single character:
#
#       fhold; fgoto $next_state;
#
#  * Ragel merges actions. So, if you have `e_lparen = '(' %act` and
#    `c_lparen = '('` and a lexer action `e_lparen | c_lparen`, the result
#    _will_ invoke the action `act`.
#
#  * EOF is explicit and is matched by `c_eof`. If you want to introspect
#    the state of the lexer, add this rule to the state:
#
#       c_eof => do_eof;
#
#  * If you proceed past EOF, the lexer will complain:
#
#       NoMethodError: undefined method `ord' for nil:NilClass
#

class Parser::Lexer

  %% write data nofinal;
  # %

  attr_reader   :version
  attr_reader   :source_file

  attr_accessor :diagnostics
  attr_accessor :static_env

  attr_reader   :comments

  def initialize(version)
    @version = version

    reset
  end

  def reset(reset_state=true)
    # Ragel-related variables:
    if reset_state
      # Unit tests set state prior to resetting lexer.
      @cs  = self.class.lex_en_line_begin
    end

    @p             = 0   # stream position (saved manually in #advance)
    @ts            = nil # token start
    @te            = nil # token end
    @act           = 0   # next action

    @stack         = []  # state stack
    @top           = 0   # state stack top pointer

    # Lexer state:
    @token_queue   = []
    @literal_stack = []

    @comments      = ""  # collected comments

    @newline_s     = nil # location of last encountered newline

    @num_base      = nil # last numeric base
    @num_digits_s  = nil # starting position of numeric digits

    @escape_s      = nil # starting position of current sequence
    @escape        = nil # last escaped sequence, as string

    # See below the section on parsing heredocs.
    @heredoc_e     = nil
    @herebody_s    = nil

    # Ruby 1.9 ->() lambdas emit a distinct token if do/{ is
    # encountered after a matching closing parenthesis.
    @paren_nest    = 0
    @lambda_stack  = []
  end

  def source_file=(source_file)
    @source_file = source_file

    # Heredoc processing coupled with weird newline quirks
    # require three '\0' (EOF) chars to be appended; after
    # `p = @heredoc_s`, if `p` points at EOF, the FSM could
    # not bail out early enough and will crash.
    #
    # Patches accepted.
    #
    @source = @source_file.source.gsub(/\r\n/, "\n") + "\0\0\0"
  end

  LEX_STATES = {
    :line_begin  => lex_en_line_begin,
    :expr_beg    => lex_en_expr_beg,
    :expr_value  => lex_en_expr_value,
    :expr_mid    => lex_en_expr_mid,
    :expr_dot    => lex_en_expr_dot,
    :expr_fname  => lex_en_expr_fname,
    :expr_end    => lex_en_expr_end,
    :expr_arg    => lex_en_expr_arg,
    :expr_endarg => lex_en_expr_endarg,
  }

  def state
    LEX_STATES.invert.fetch(@cs, @cs)
  end

  def state=(state)
    @cs = LEX_STATES.fetch(state)
  end

  # Return next token: [type, value].
  def advance
    if @token_queue.any?
      return @token_queue.shift
    end

    # Ugly, but dependent on Ragel output. Consider refactoring it somehow.
    _lex_trans_keys         = self.class.send :_lex_trans_keys
    _lex_actions            = self.class.send :_lex_actions
    _lex_key_offsets        = self.class.send :_lex_key_offsets
    _lex_index_offsets      = self.class.send :_lex_index_offsets
    _lex_single_lengths     = self.class.send :_lex_single_lengths
    _lex_range_lengths      = self.class.send :_lex_range_lengths
    _lex_indicies           = self.class.send :_lex_indicies
    _lex_trans_targs        = self.class.send :_lex_trans_targs
    _lex_trans_actions      = self.class.send :_lex_trans_actions
    _lex_to_state_actions   = self.class.send :_lex_to_state_actions
    _lex_from_state_actions = self.class.send :_lex_from_state_actions

    p, pe, eof = @p, @source.length + 1, nil

    %% write exec;
    # %

    @p = p

    if @token_queue.any?
      @token_queue.shift
    elsif @cs == self.class.lex_error
      [ false, [ '$error', p..p ] ]
    else
      [ false, [ '$eof',   p..p ] ]
    end
  end

  # Return the current collected comment block and clear the storage.
  def clear_comments
    comments  = @comments
    @comments = ""

    comments
  end

  protected

  def eof_char?(char)
    [0x04, 0x1a, 0x00].include? char.ord
  end

  def tok(s = @ts, e = @te)
    @source[s...e]
  end

  def emit(type, value = tok, s = @ts, e = @te)
    @token_queue << [ type, [ value, s...e ] ]
  end

  def emit_table(table, s = @ts, e = @te)
    value = tok(s, e)

    emit(table[value], value, s, e)
  end

  def diagnostic(type, message, *ranges)
    ranges = [@ts...@te] if ranges.empty?

    diagnostic = Parser::Diagnostic.
                    new(type, message, @source_file, ranges)

    @diagnostics.process(diagnostic)
  end

  #
  # === LITERAL STACK ===
  #

  def push_literal(*args)
    new_literal = Literal.new(self, *args)
    @literal_stack.push(new_literal)

    if    new_literal.type == :tWORDS_BEG
      self.class.lex_en_interp_words
    elsif new_literal.type == :tQWORDS_BEG
      self.class.lex_en_plain_words
    elsif new_literal.interpolate?
      self.class.lex_en_interp_string
    else
      self.class.lex_en_plain_string
    end
  end

  def literal
    @literal_stack.last
  end

  def pop_literal
    old_literal = @literal_stack.pop

    if old_literal.type == :tREGEXP_BEG
      # Fetch modifiers.
      self.class.lex_en_regexp_modifiers
    else
      self.class.lex_en_expr_end
    end
  end

  # Mapping of strings to parser tokens.

  PUNCTUATION = {
    '='   => :tEQL,     '&'   => :tAMPER2,  '|'   => :tPIPE,
    '!'   => :tBANG,    '^'   => :tCARET,   '+'   => :tPLUS,
    '-'   => :tMINUS,   '*'   => :tSTAR2,   '/'   => :tDIVIDE,
    '%'   => :tPERCENT, '~'   => :tTILDE,   ','   => :tCOMMA,
    ';'   => :tSEMI,    '.'   => :tDOT,     '..'  => :tDOT2,
    '...' => :tDOT3,    '['   => :tLBRACK2, ']'   => :tRBRACK,
    '('   => :tLPAREN2, ')'   => :tRPAREN,  '?'   => :tEH,
    ':'   => :tCOLON,   '&&'  => :tANDOP,   '||'  => :tOROP,
    '-@'  => :tUMINUS,  '+@'  => :tUPLUS,   '~@'  => :tTILDE,
    '**'  => :tPOW,     '->'  => :tLAMBDA,  '=~'  => :tMATCH,
    '!~'  => :tNMATCH,  '=='  => :tEQ,      '!='  => :tNEQ,
    '>'   => :tGT,      '>>'  => :tRSHFT,   '>='  => :tGEQ,
    '<'   => :tLT,      '<<'  => :tLSHFT,   '<='  => :tLEQ,
    '=>'  => :tASSOC,   '::'  => :tCOLON2,  '===' => :tEQQ,
    '<=>' => :tCMP,     '[]'  => :tAREF,    '[]=' => :tASET,
    '{'   => :tLCURLY,  '}'   => :tRCURLY,  '`'   => :tBACK_REF2,
    'do'  => :kDO
  }

  PUNCTUATION_BEGIN = {
    '&'   => :tAMPER,   '*'   => :tSTAR,   '+'   => :tUPLUS,
    '-'   => :tUMINUS,  '::'  => :tCOLON3, '('   => :tLPAREN,
    '{'   => :tLBRACE,  '['   => :tLBRACK,
  }

  KEYWORDS = {
    'if'     => :kIF_MOD,      'unless'   => :kUNLESS_MOD,
    'while'  => :kWHILE_MOD,   'until'    => :kUNTIL_MOD,
    'rescue' => :kRESCUE_MOD,  'defined?' => :kDEFINED,
    'BEGIN'  => :klBEGIN,      'END'      => :klEND,
  }

  %w(class module def undef begin end then elsif else ensure case when
     for break next redo retry in do return yield super self nil true
     false and or not alias __FILE__ __LINE__ __ENCODING__).each do |keyword|
    KEYWORDS[keyword] = :"k#{keyword.upcase}"
  end

  KEYWORDS_BEGIN = {
    'if'     => :kIF,          'unless' => :kUNLESS,
    'while'  => :kWHILE,       'until'  => :kUNTIL,
    'rescue' => :kRESCUE
  }

  %%{
  # %

  access @;
  getkey @source[p].ord;

  # === CHARACTER CLASSES ===
  #
  # Pay close attention to the differences between c_any and any.
  # c_any does not include EOF and so will cause incorrect behavior
  # for machine subtraction (any-except rules) and default transitions
  # for scanners.

  action do_nl {
    # Record position of a newline for precise line and column reporting.
    #
    # This action is embedded directly into c_nl, as it is idempotent and
    # there are no cases when we need to skip it.
    @newline_s = p
  }

  c_nl       = '\n' $ do_nl;
  c_space    = [ \t\r\f\v];
  c_space_nl = c_space | c_nl;
  c_eof      = 0x04 | 0x1a | 0; # ^D, ^Z, EOF
  c_eol      = c_nl | c_eof;
  c_any      = any - c_eof - zlen;
  c_line     = c_any - c_nl;

  c_unicode  = c_any - 0x00..0x7f;
  c_lower    = [a-z_]  | c_unicode;
  c_upper    = [A-Z]   | c_unicode;
  c_alpha    = c_lower | c_upper;
  c_alnum    = c_alpha | [0-9];

  action do_eof {
    # Sit at EOF indefinitely. #advance would return $eof each time.
    # This allows to feed the lexer more data if needed; this is only used
    # in tests.
    #
    # Note that this action is not embedded into e_eof like e_nl and e_bs
    # below. This is due to the fact that scanner state at EOF is observed
    # by tests, and encapsulating it in a rule would break the introspection.
    fhold; fbreak;
  }

  #
  # === TOKEN DEFINITIONS ===
  #

  # All operators are punctuation. There is more to punctuation
  # than just operators. Operators can be overridden by user;
  # punctuation can not.

  # A list of operators which are valid in the function name context, but
  # have different semantics in others.
  operator_fname      = '[]' | '[]=' | '`'  | '-@' | '+@' | '~@' ;

  # A list of operators which can occur within an assignment shortcut (+ → +=).
  operator_arithmetic = '&'  | '|'   | '&&' | '||' | '^'  | '+'   | '-'  |
                        '*'  | '/'   | '**' | '~'  | '**' | '<<'  | '>>' |
                        '%'  ;

  # A list of all user-definable operators not covered by groups above.
  operator_rest       = '=~' | '!~' | '==' | '!=' | '!'   | '===' |
                        '<'  | '<=' | '>'  | '>=' | '<=>' | '=>'  ;

  # Note that `{` and `}` need to be referred to as e_lbrace and e_rbrace,
  # as they are ambiguous with interpolation `#{}` and should be counted.
  # These braces are not present in punctuation lists.

  # A list of punctuation which has different meaning when used at the
  # beginning of expression.
  punctuation_begin   = '-'  | '+'  | '::' | '('  | '['  | '*'   | '&' ;

  # A list of all punctuation except punctuation_begin.
  punctuation_end     = ','  | '='  | '->' | '('  | '['  | ']'   |
                        '::' | '?'  | ':'  | '.'  | '..' | '...' ;

  # A list of keywords which have different meaning at the beginning of expression.
  keyword_modifier    = 'if'     | 'unless' | 'while'  | 'until' | 'rescue' ;

  # A list of keywords which accept an argument-like expression, i.e. have the
  # same post-processing as method calls or commands. Example: `yield 1`,
  # `yield (1)`, `yield(1)`, are interpreted as if `yield` was a function.
  keyword_with_arg    = 'yield'  | 'super'  | 'not'    | 'defined?' ;

  # A list of keywords which accept a literal function name as an argument.
  keyword_with_fname  = 'def'    | 'undef'  | 'alias'  ;

  # A list of keywords which accept an expression after them.
  keyword_with_value  = 'else'   | 'case'   | 'ensure' | 'module' | 'elsif' | 'then'  |
                        'for'    | 'in'     | 'do'     | 'when'   | 'begin' | 'class' |
                        'and'    | 'or'     ;

  # A list of keywords which accept a value, and treat the keywords from
  # `keyword_modifier` list as modifiers.
  keyword_with_mid    = 'rescue' | 'return' | 'break'  | 'next'   ;

  # A list of keywords which do not accept an expression after them.
  keyword_with_end    = 'end'    | 'self'   | 'true'   | 'false'  | 'retry'    |
                        'redo'   | 'nil'    | 'BEGIN'  | 'END'    | '__FILE__' |
                        '__LINE__' | '__ENCODING__';

  # All keywords.
  keyword             = keyword_with_value | keyword_with_mid |
                        keyword_with_end   | keyword_with_arg |
                        keyword_with_fname | keyword_modifier ;

  constant       = [A-Z] c_alnum*;
  bareword       = c_alpha c_alnum*;

  call_or_var    = c_lower c_alnum*;
  class_var      = '@@' bareword;
  instance_var   = '@' bareword;
  global_var     = '$'
      ( bareword | digit+
      | [`'+~*$&?!@/\\;,.=:<>"] # `
      | '-' [A-Za-z0-9_]?
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
    @escape = ""

    codepoints = tok(@escape_s + 2, p - 1)
    codepoints.split(/[ \t]/).each do |codepoint_str|
      codepoint = codepoint_str.to_i(16)

      if codepoint >= 0x110000
        @escape = lambda do
          # TODO better location reporting
          diagnostic :error, "invalid Unicode codepoint (too large)", @escape_s...p
        end

        break
      end

      @escape += codepoint.chr(Encoding::UTF_8)
    end
  }

  action unescape_char {
    @escape = {
      'a' => "\a", 'b'  => "\b", 'e'  => "\e", 'f' => "\f",
      'n' => "\n", 'r'  => "\r", 's'  => "\s", 't' => "\t",
      'v' => "\v", '\\' => "\\"
    }.fetch(@source[p - 1], @source[p - 1])
  }

  action invalid_complex_escape {
    @escape = lambda do
      diagnostic :error, "invalid escape character syntax"
    end
  }

  action slash_c_char {
    @escape = (@escape.ord & 0x9f).chr
  }

  action slash_m_char {
    @escape = (@escape.ord | 0x80).chr
  }

  maybe_escaped_char = (
        '\\' c_any      %unescape_char
    | ( c_any - [\\] )  % { @escape = @source[p - 1] }
  );

  maybe_escaped_ctrl_char = ( # why?!
        '\\' c_any      %unescape_char %slash_c_char
    |   '?'             % { @escape = "\x7f" }
    | ( c_any - [\\?] ) % { @escape = @source[p - 1] } %slash_c_char
  );

  escape = (
      # \377
      [0-7]{1,3}
      % { @escape = tok(@escape_s, p).to_i(8).chr }

      # \xff
    | ( 'x' xdigit{1,2}
        % { @escape = tok(@escape_s + 1, p).to_i(16).chr }
      # \u263a
      | 'u' xdigit{4}
        % { @escape = tok(@escape_s + 1, p).to_i(16).chr(Encoding::UTF_8) }
      )

      # %q[\x]
    | 'x' ( c_any - xdigit )
      % {
        @escape = lambda do
          diagnostic :error, "invalid hex escape", @escape_s...p
        end
      }

      # %q[\u123] %q[\u{12]
    | 'u' ( c_any{0,4}  -
            xdigit{4}   -          # \u1234 is valid
            ( '{' xdigit{1,3}      # \u{1 \u{12 \u{123 are valid
            | '{' xdigit [ \t}]    # \u{1. \u{1} are valid
            | '{' xdigit{2} [ \t}] # \u{12. \u{12} are valid
            )
          )
      % {
        @escape = lambda do
          diagnostic :error, "invalid Unicode escape", @escape_s...p
        end
      }

      # \u{123 456}
    | 'u{' ( xdigit{1,6} [ \t] )*
      ( xdigit{1,6} '}'
        %unicode_points
      | ( xdigit* ( c_any - xdigit - '}' )+ '}'
        | ( c_any - '}' )* c_eof
        | xdigit{7,}
        ) % {
          @escape = lambda do
            diagnostic :fatal, "unterminated Unicode escape", p - 1...p
          end
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
    | ( 'M-\\C' | 'C-\\M' | 'cM' ) c_any %invalid_complex_escape

    | ( c_any - [0-7xuCMc] ) %unescape_char

    | c_eof % {
      diagnostic :fatal, "escape sequence meets end of file", p - 1...p
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
  # of positions in the input stream, namely @heredoc_e
  # (HEREDOC declaration End) and @herebody_s (HEREdoc BODY line Start).
  #
  # @heredoc_e is simply contained inside the corresponding Literal, and
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

  e_heredoc_nl = c_nl $ {
    # After every heredoc was parsed, @herebody_s contains the
    # position of next token after all heredocs.
    if @herebody_s
      p = @herebody_s
      @herebody_s = nil
    end
  };

  action extend_string {
    if literal.nest_and_try_closing tok, @ts, @te
      fgoto *pop_literal;
    else
      literal.extend_string tok, @ts, @te
    end
  }

  action extend_string_escaped {
    if literal.nest_and_try_closing('\\', @ts, @ts + 1)
      # If the literal is actually closed by the backslash,
      # rewind the input prior to consuming the escape sequence.
      p = @escape_s - 1
      fgoto *pop_literal;
    else
      # Get the first character after the backslash.
      escaped_char = @source[@escape_s]

      if literal.munge_escape? escaped_char
        # If this particular literal uses this character as an opening
        # or closing delimiter, it is an escape sequence for that
        # particular character. Write it without the backslash.

        if literal.regexp?
          # Regular expressions should have every escape sequence in its
          # raw form.
          literal.extend_string(tok, @ts, @te)
        else
          literal.extend_string(escaped_char, @ts, @te)
        end
      else
        # It does not. So this is an actual escape sequence, yay!
        # Two things to consider here.
        #
        # 1. The `escape' rule should be pure and so won't raise any
        #    errors by itself. Instead, it stores them in lambdas.
        #
        # 2. Non-interpolated literals do not go through the aforementioned
        #    rule. As \\ and \' (and variants) are munged, the full token
        #    should always be written for such literals.

        @escape.call if @escape.respond_to? :call

        if literal.regexp?
          # Ditto. Also, expand escaped newlines.
          literal.extend_string(tok.gsub("\\\n", ''), @ts, @te)
        else
          literal.extend_string(@escape || tok, @ts, @te)
        end
      end
    end
  }

  # Extend a string with a newline or a EOF character.
  # As heredoc closing line can immediately precede EOF, this action
  # has to handle such case specially.
  action extend_string_eol {
    is_eof = eof_char? @source[p]

    if literal.heredoc?
      # Try ending the heredoc with the complete most recently
      # scanned line. @herebody_s always refers to the start of such line.
      if literal.nest_and_try_closing(tok(@herebody_s, @te - 1),
                                      @herebody_s, @te - 1)
        # Adjust @herebody_s to point to the next line.
        @herebody_s = @te

        # Continue regular lexing after the heredoc reference (<<END).
        p = literal.heredoc_e - 1
        fgoto *pop_literal;
      else
        # Ditto.
        @herebody_s = @te
      end
    end

    if is_eof
      diagnostic :fatal, "unterminated string meets end of file", p - 1...p
    end

    # A literal newline is appended if the heredoc was _not_ closed
    # this time. See also Literal#nest_and_try_closing for rationale of
    # calling #flush_string here.
    literal.extend_string tok, @ts, @te
    literal.flush_string
  }

  #
  # === INTERPOLATION PARSING ===
  #

  # Interpolations with immediate variable names simply call into
  # the corresponding machine.

  interp_var = '#' ( global_var | class_var_v | instance_var_v );

  action extend_interp_var {
    literal.flush_string
    emit(:tSTRING_DVAR, nil, @ts, @ts + 1)

    p = @ts
    fcall expr_variable;
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

  e_lbrace = '{' % {
    if literal
      literal.start_interp_brace
    end
  };

  e_rbrace = '}' % {
    if literal
      if literal.end_interp_brace_and_try_closing
        emit(:tRCURLY, '}')

        if literal.words?
          emit(:tSPACE, nil)
        end

        if literal.saved_herebody_s
          @herebody_s = literal.saved_herebody_s
        end

        fhold;
        fnext *@stack.pop;
        fbreak;
      end
    end
  };

  action extend_interp_code {
    literal.flush_string
    emit(:tSTRING_DBEG, '#{')

    literal.saved_herebody_s = @herebody_s
    @herebody_s = nil

    literal.start_interp_brace
    fcall expr_beg;
  }

  # Actual string parsers are simply combined from the primitives defined
  # above.

  interp_words := |*
      interp_code => extend_interp_code;
      interp_var  => extend_interp_var;
      e_bs escape => extend_string_escaped;
      c_space_nl  => { literal.flush_string };
      c_eol       => extend_string_eol;
      c_any       => extend_string;
  *|;

  interp_string := |*
      interp_code => extend_interp_code;
      interp_var  => extend_interp_var;
      e_bs escape => extend_string_escaped;
      c_eol       => extend_string_eol;
      c_any       => extend_string;
  *|;

  plain_words := |*
      e_bs c_any  => extend_string_escaped;
      c_space_nl  => { literal.flush_string };
      c_eol       => extend_string_eol;
      c_any       => extend_string;
  *|;

  plain_string := |*
      e_bs c_any  => extend_string_escaped;
      c_eol       => extend_string_eol;
      c_any       => extend_string;
  *|;

  regexp_modifiers := |*
      [A-Za-z]+
      => {
        unknown_options = tok.scan(/[^imxouesn]/)
        if unknown_options.any?
          diagnostic :error, "unknown regexp options: #{unknown_options.join}"
        end

        emit(:tREGEXP_OPT)
        fgoto expr_end;
      };

      any
      => {
        emit(:tREGEXP_OPT, tok(@ts, @te - 1), @ts, @te - 1)
        fhold; fgoto expr_end;
      };
  *|;

  #
  # === EXPRESSION PARSING ===
  #

  # These rules implement a form of manually defined lookahead.
  # The default longest-match scanning does not work here due
  # to sheer ambiguity.

  ambiguous_ident_suffix =     # actual    parsed
      [?!=] %{ tm = p } |      # a?        a?
      '=='  %{ tm = p - 2 } |  # a==b      a == b
      '=~'  %{ tm = p - 2 } |  # a=~b      a =~ b
      '=>'  %{ tm = p - 2 } |  # a=>b      a => b
      '===' %{ tm = p - 3 }    # a===b     a === b
  ;

  ambiguous_symbol_suffix =    # actual    parsed
      ambiguous_ident_suffix |
      '==>' %{ tm = p - 2 }    # :a==>b    :a= => b
  ;

  # Ambiguous with 1.9 hash labels.
  ambiguous_const_suffix =     # actual    parsed
      '::'  %{ tm = p - 2 }    # A::B      A :: B
  ;

  # Ruby 1.9 lambdas require parentheses counting in order to
  # emit correct opening kDO/tLBRACE.

  e_lparen = '(' % {
      @paren_nest += 1
  };

  e_rparen = ')' % {
      @paren_nest -= 1
  };

  # Variable lexing code is accessed from both expressions and
  # string interpolation related code.
  #
  expr_variable := |*
      global_var
      => {
        if    tok =~ /^\$([1-9][0-9]*)$/
          emit(:tNTH_REF, $1.to_i)
        elsif tok =~ /^\$([&`'+])$/
          emit(:tBACK_REF, $1.to_sym)
        else
          emit(:tGVAR)
        end

        fnext *@stack.pop; fbreak;
      };

      class_var_v
      => {
        if tok =~ /^@@[0-9]/
          diagnostic :error, "`#{tok}' is not allowed as a class variable name"
        end

        emit(:tCVAR)
        fnext *@stack.pop; fbreak;
      };

      instance_var_v
      => {
        if tok =~ /^@[0-9]/
          diagnostic :error, "`#{tok}' is not allowed as an instance variable name"
        end

        emit(:tIVAR)
        fnext *@stack.pop; fbreak;
      };
  *|;

  # Literal function name in definition (e.g. `def class`).
  # Keywords are returned as their respective tokens; this is used
  # to support singleton def `def self.foo`. Global variables are
  # returned as `tGVAR`; this is used in global variable alias
  # statements `alias $a $b`. Symbols are returned verbatim; this
  # is used in `alias :a :"b#{foo}"` and `undef :a`.
  #
  # Transitions to `expr_end` afterwards.
  #
  expr_fname := |*
      keyword
      => { emit(KEYWORDS[tok]);
           fnext expr_end; fbreak; };

      bareword
      => { emit(:tIDENTIFIER)
           fnext expr_end; fbreak; };

      bareword ambiguous_ident_suffix
      => { emit(:tIDENTIFIER, tok(@ts, tm), @ts, tm)
           fnext expr_end; p = tm - 1; fbreak; };

      operator_fname      |
      operator_arithmetic |
      operator_rest
      => { emit_table(PUNCTUATION)
           fnext expr_end; fbreak; };

      ':'
      => { fhold; fgoto expr_end; };

      global_var
      => { p = @ts - 1
           fcall expr_variable; };

      c_space_nl+;

      c_any
      => { fhold; fgoto expr_end; };

      c_eof => do_eof;
  *|;

  # Literal function name in method call (e.g. `a.class`).
  #
  # Transitions to `expr_arg` afterwards.
  #
  expr_dot := |*
      bareword
      => { emit(:tIDENTIFIER)
           fnext expr_arg; fbreak; };

      bareword ambiguous_ident_suffix
      => { emit(:tIDENTIFIER, tok(@ts, tm), @ts, tm)
           fnext expr_arg; p = tm - 1; fbreak; };

      operator_fname      |
      operator_arithmetic |
      operator_rest
      => { emit_table(PUNCTUATION)
           fnext expr_arg; fbreak; };

      c_space_nl+;

      c_any
      => { fhold; fgoto expr_end; };

      c_eof => do_eof;
  *|;

  # The previous token emitted was a `tIDENTIFIER` or `tFID`; no space
  # is consumed; the current expression is a command or method call.
  #
  expr_arg := |*
      #
      # COMMAND MODE SPECIFIC TOKENS
      #

      # cmd (1 + 2)
      # See below the rationale about expr_endarg.
      c_space+ e_lparen
      => { emit(:tLPAREN_ARG, '(', @te - 1, @te)
           fnext expr_beg; fbreak; };

      # meth(1 + 2)
      # Regular method call.
      e_lparen
      => { emit(:tLPAREN2)
           fnext expr_beg; fbreak; };

      # meth [...]
      # Array argument. Compare with indexing `meth[...]`.
      c_space+ '['
      => { emit(:tLBRACK, '[', @te - 1, @te);
           fnext expr_beg; fbreak; };

      # cmd {}
      # Command: method call without parentheses.
      c_space* e_lbrace
      => {
        if @lambda_stack.last == @paren_nest
          p = @ts - 1
          fgoto expr_end;
        else
          emit(:tLCURLY, '{', @te - 1, @te)
          fnext expr_value; fbreak;
        end
      };

      # a.b
      # Dot-call.
      '.' | '::'
      => { emit_table(PUNCTUATION);
           fnext expr_dot; fbreak; };

      #
      # AMBIGUOUS TOKENS RESOLVED VIA EXPR_BEG
      #

      # a ?b
      # Character literal.
      c_space+ '?'
      => { fhold; fgoto expr_beg; };

      # x +1
      # Ambiguous unary operator or regexp literal.
      c_space+ [+\-/]
      => {
        diagnostic :warning,
                   "ambiguous first argument; put parentheses or even spaces",
                   @te - 1...@te

        fhold; fhold; fgoto expr_beg;
      };

      # x *1
      # Ambiguous splat or block-pass.
      c_space+ [*&]
      => {
        what = tok(@te - 1, @te)
        diagnostic :warning,
                   "`#{what}' interpreted as argument prefix",
                   @te - 1...@te

        fhold; fgoto expr_beg;
      };

      #
      # AMBIGUOUS TOKENS RESOLVED VIA EXPR_END
      #

      # a ? b
      # Ternary operator.
      c_space+ '?' c_space_nl
      => { fhold; fhold; fgoto expr_end; };

      # x + 1: Binary operator or operator-assignment.
      c_space* operator_arithmetic
                  ( '=' | c_space_nl )?    |
      # x rescue y: Modifier keyword.
      c_space+ keyword_modifier            |
      # Miscellanea.
      c_space* punctuation_end
      => {
        p = @ts - 1
        fgoto expr_end;
      };

      c_space* c_nl
      => { fhold; fgoto expr_end; };

      c_any
      => { fhold; fgoto expr_beg; };

      c_eof => do_eof;
  *|;

  # The rationale for this state is pretty complex. Normally, if an argument
  # is passed to a command and then there is a block (tLCURLY...tRCURLY),
  # the block is attached to the innermost argument (`f` in `m f {}`), or it
  # is a parse error (`m 1 {}`). But there is a special case for passing a single
  # primary expression grouped with parentheses: if you write `m (1) {}` or
  # (2.0 only) `m () {}`, then the block is attached to `m`.
  #
  # Thus, we recognize the opening `(` of a command (remember, a command is
  # a method call without parens) as a tLPAREN_ARG; then, in parser, we recognize
  # `tLPAREN_ARG expr rparen` as a `primary_expr` and before rparen, set the
  # lexer's state to `expr_endarg`, which makes it emit the possibly following
  # `{` as `tLBRACE_ARG`.
  #
  # The default post-`expr_endarg` state is `expr_end`, so this state also handles
  # `do` (as `kDO_BLOCK` in `expr_beg`). (I have no clue why the parser cannot
  # just handle `kDO`.)
  expr_endarg := |*
      e_lbrace
      => { emit(:tLBRACE_ARG)
           fnext expr_value; };

      'do'
      => { emit(:kDO_BLOCK)
           fnext expr_value; };

      c_space*;

      c_any
      => { fhold; fgoto expr_end; };

      c_eof => do_eof;
  *|;

  # The rationale for this state is that several keywords accept value
  # (i.e. should transition to `expr_beg`), do not accept it like a command
  # (i.e. not an `expr_arg`), and must behave like a statement, that is,
  # accept a modifier if/while/etc.
  #
  expr_mid := |*
      keyword_modifier
      => { emit_table(KEYWORDS)
           fnext expr_beg; fbreak; };

      c_space+;

      c_nl
      => { fhold; fgoto expr_end; };

      c_any
      => { fhold; fgoto expr_beg; };

      c_eof => do_eof;
  *|;

  # Beginning of an expression.
  #
  # Don't fallthrough to this state from `c_any`; make sure to handle
  # `c_space* c_nl` and let `expr_end` handle the newline.
  # Otherwise code like `f\ndef x` gets glued together and the parser
  # explodes.
  #
  expr_beg := |*
      # Numeric processing. Converts:
      #   +5 to [tINTEGER, 5]
      #   -5 to [tUMINUS_NUM] [tINTEGER, 5]
      [+\-][0-9]
      => {
        fhold;
        if tok.start_with? '-'
          emit(:tUMINUS_NUM, '-')
          fnext expr_end; fbreak;
        end
      };

      # splat *a
      '*'
      => { emit(:tSTAR)
           fbreak; };

      #
      # STRING AND REGEXP LITERALS
      #

      # a / 42
      # a % 42
      # a %= 42 (disambiguation with %=string=)
      [/%] c_space_nl | '%=' # /
      => {
        fhold; fhold;
        fgoto expr_end;
      };

      # /regexp/oui
      '/'
      => {
        type, delimiter = tok, tok
        fgoto *push_literal(type, delimiter, @ts);
      };

      # %<string>
      '%' ( c_any - [A-Za-z] )
      => {
        type, delimiter = tok[0], tok[-1]
        fgoto *push_literal(type, delimiter, @ts);
      };

      # %w(we are the people)
      '%' [A-Za-z]+ c_any
      => {
        type, delimiter = tok[0..-2], tok[-1]
        fgoto *push_literal(type, delimiter, @ts);
      };

      '%' c_eof
      => {
        diagnostic :fatal, "unterminated string meets end of file", @ts..@ts
      };

      # Heredoc start.
      # <<EOF | <<-END | <<"FOOBAR" | <<-`SMTH`
      '<<' '-'?
        ( '"' ( c_any - c_nl - '"' )* '"'
        | "'" ( c_any - c_nl - "'" )* "'"
        | "`" ( c_any - c_nl - "`" )* "`"
        | bareword )           % { @heredoc_e     = p }
        ( c_any - c_nl )* c_nl % { new_herebody_s = p }
      => {
        tok(@ts, @heredoc_e) =~ /^<<(-?)(["'`]?)(.*)\2$/

        indent    = !$1.empty?
        type      =  $2.empty? ? '"' : $2
        delimiter =  $3

        fnext *push_literal(type, delimiter, @ts, @heredoc_e, indent);

        if @herebody_s.nil?
          @herebody_s = new_herebody_s
        end

        p = @herebody_s - 1
      };

      #
      # AMBIGUOUS TERNARY OPERATOR
      #

      '?' ( e_bs escape
          | c_any - c_space_nl - e_bs % { @escape = nil }
          )
      => {
        # Show an error if memorized.
        @escape.call if @escape.respond_to? :call

        value = @escape || tok(@ts + 1)

        if version.ruby18?
          emit(:tINTEGER, value.ord)
        else
          emit(:tSTRING, value)
        end

        fbreak;
      };

      '?' c_space_nl
      => {
        escape = { " "  => '\s', "\r" => '\r', "\n" => '\n', "\t" => '\t',
                   "\v" => '\v', "\f" => '\f' }[tok[@ts + 1]]
        diagnostic :warning, "invalid character syntax; use ?#{escape}", @ts..@ts

        p = @ts - 1
        fgoto expr_end;
      };

      '?' c_eof
      => {
        diagnostic :fatal, "incomplete character syntax", @ts..@ts
      };

      # f ?aa : b: Disambiguate with a character literal.
      '?' [A-Za-z_] bareword
      => {
        p = @ts - 1
        fgoto expr_end;
      };

      #
      # KEYWORDS AND PUNCTUATION
      #

      # a(+b)
      punctuation_begin |
      # a({b=>c})
      e_lbrace          |
      # a()
      e_lparen
      => { emit_table(PUNCTUATION_BEGIN)
           fbreak; };

      # rescue Exception => e: Block rescue.
      # Special because it should transition to expr_mid.
      'rescue'
      => { emit_table(KEYWORDS_BEGIN)
           fnext expr_mid; fbreak; };

      # if a: Statement if.
      keyword_modifier
      => { emit_table(KEYWORDS_BEGIN)
           fnext expr_value; fbreak; };

      #
      # RUBY 1.9 HASH LABELS
      #

      bareword ':' ( c_any - ':' )
      => {
        fhold;

        if version.ruby18?
          emit(:tIDENTIFIER, tok(@ts, @te - 2), @ts, @te - 2)
          fhold; # continue as a symbol
        else
          emit(:tLABEL, tok(@ts, @te - 2), @ts, @te - 1)
        end

        fbreak;
      };

      #
      # CONTEXT-DEPENDENT VARIABLE LOOKUP OR COMMAND INVOCATION
      #

      # foo= bar:  Disambiguate with bareword rule below.
      bareword ambiguous_ident_suffix |
      # def foo:   Disambiguate with bareword rule below.
      keyword
      => { p = @ts - 1
           fgoto expr_end; };

      # a = 42;     a [42]: Indexing.
      # def a; end; a [42]: Array argument.
      call_or_var
      => {
        emit(:tIDENTIFIER)

        if @static_env && @static_env.declared?(tok)
          fgoto expr_end;
        else
          fgoto expr_arg;
        end
      };

      c_space_nl+;

      # The following rules match most binary and all unary operators.
      # Rules for binary operators provide better error reporting.
      operator_arithmetic '='    |
      operator_rest              |
      punctuation_end            |
      c_any
      => { p = @ts - 1; fgoto expr_end; };

      c_eof => do_eof;
  *|;

  # Like expr_beg, but no 1.9 label possible.
  #
  expr_value := |*
      # a:b: a(:b), a::B, A::B
      bareword ':'
      => { p = @ts - 1
           fgoto expr_end; };

      c_space_nl+;

      c_any
      => { fhold; fgoto expr_beg; };

      c_eof => do_eof;
  *|;

  expr_end := |*
      #
      # STABBY LAMBDA
      #

      '->'
      => {
        emit_table(PUNCTUATION)

        @lambda_stack.push @paren_nest
        fbreak;
      };

      e_lbrace | 'do'
      => {
        if @lambda_stack.last == @paren_nest
          @lambda_stack.pop

          if tok == '{'
            emit(:tLAMBEG)
          else
            emit(:kDO_LAMBDA)
          end
        else
          emit_table(PUNCTUATION)
        end

        fnext expr_value; fbreak;
      };

      #
      # KEYWORDS
      #

      keyword_with_fname
      => { emit_table(KEYWORDS)
           fnext expr_fname; fbreak; };

      'class' c_space_nl '<<'
      => { emit(:kCLASS, 'class', @ts, @ts + 5)
           emit(:tLSHFT, '<<',    @te - 2, @te)
           fnext expr_beg; fbreak; };

      # a if b:c: Syntax error.
      keyword_modifier
      => { emit_table(KEYWORDS)
           fnext expr_beg; fbreak; };

      # elsif b:c: elsif b(:c)
      keyword_with_value
      => { emit_table(KEYWORDS)
           fnext expr_value; fbreak; };

      keyword_with_mid
      => { emit_table(KEYWORDS)
           fnext expr_mid; fbreak; };

      keyword_with_arg
      => {
        emit_table(KEYWORDS)

        if version.ruby18? && tok == 'not'
          fnext expr_beg; fbreak;
        else
          fnext expr_arg; fbreak;
        end
      };

      keyword_with_end
      => { emit_table(KEYWORDS)
           fbreak; };

      #
      # NUMERIC LITERALS
      #

      ( '0' [Xx]  %{ @num_base = 16; @num_digits_s = p }
               ( xdigit+ '_' )* xdigit* '_'?
      | '0' [Dd]  %{ @num_base = 10; @num_digits_s = p }
               ( digit+ '_' )* digit* '_'?
      | '0' [Oo]  %{ @num_base = 8;  @num_digits_s = p }
               ( digit+ '_' )* digit* '_'?
      | '0' [Bb]  %{ @num_base = 2;  @num_digits_s = p }
               ( [01]+ '_' )* [01]* '_'?
      | [1-9]     %{ @num_base = 10; @num_digits_s = @ts }
               ( '_' digit+ )* digit* '_'?
      | '0'       %{ @num_base = 8;  @num_digits_s = @ts }
               ( '_' digit+ )* digit* '_'?
      )
      => {
        digits = tok(@num_digits_s)

        if digits.end_with? '_'
          diagnostic :error, "trailing `_' in number", @te - 1...@te
        elsif digits.empty? && @num_base == 8 && version.ruby18?
          # 1.8 did not raise an error on 0o.
          digits = "0"
        elsif digits.empty?
          diagnostic :error, "numeric literal without digits"
        elsif @num_base == 8 && digits =~ /[89]/
          # TODO better location reporting
          diagnostic :error, "invalid octal digit"
        end

        emit(:tINTEGER, digits.to_i(@num_base))
        fbreak;
      };

      # Floating point literals cannot start with 0 except when a dot
      # follows immediately, probably to avoid confusion with octal literals.
      ( [1-9] [0-9]* ( '_' digit+ )* |
        '0'
      )?
      (
          '.' ( digit+ '_' )* digit+ |
        ( '.' ( digit+ '_' )* digit+ )? [eE] [+\-]? ( digit+ '_' )* digit+
      )
      => {
        if tok.start_with? '.'
          diagnostic :error, "no .<digit> floating literal anymore; put 0 before dot"
        elsif tok =~ /^[eE]/
          # The rule above allows to specify floats as just `e10', which is
          # certainly not a float. Send a patch if you can do this better.
          emit(:tIDENTIFIER, tok)
          fbreak;
        end

        emit(:tFLOAT, tok.to_f)
        fbreak;
      };

      #
      # SYMBOL LITERALS
      #

      # `echo foo` | :"bar" | :'baz'
      '`' | ':'? ['"] # '
      => {
        type, delimiter = tok, tok[-1]
        fgoto *push_literal(type, delimiter, @ts);
      };

      ':' bareword ambiguous_symbol_suffix
      => { emit(:tSYMBOL, tok(@ts + 1, tm), @ts + 1, tm)
           p = tm - 1; fbreak; };

      ':' ( bareword | global_var | class_var | instance_var |
            operator_fname | operator_arithmetic | operator_rest )
      => { emit(:tSYMBOL, tok(@ts + 1), @ts + 1)
           fbreak; };

      #
      # CONSTANTS AND VARIABLES
      #

      constant
      => { emit(:tCONSTANT)
           fbreak; };

      constant ambiguous_const_suffix
      => { emit(:tCONSTANT, tok(@ts, tm))
           p = tm - 1; fbreak; };

      global_var | class_var_v | instance_var_v
      => { p = @ts - 1; fcall expr_variable; };

      #
      # METHOD CALLS
      #

      '.'
      => { emit_table(PUNCTUATION)
           fnext expr_dot; fbreak; };

      call_or_var
      => { emit(:tIDENTIFIER)
           fnext expr_arg; fbreak; };

      call_or_var [?!]
      => { emit(:tFID)
           fnext expr_arg; fbreak; };

      #
      # OPERATORS
      #

      ( e_lparen            |
        operator_arithmetic |
        operator_rest
      ) %{ tm = p } c_space_nl*
      => { emit_table(PUNCTUATION, @ts, tm)
           fnext expr_beg; fbreak; };

      e_rbrace | e_rparen | ']'
      => { emit_table(PUNCTUATION)
           fbreak; };

      operator_arithmetic '='
      => { emit(:tOP_ASGN, tok(@ts, @te - 1))
           fnext expr_beg; fbreak; };

      '?'
      => { emit_table(PUNCTUATION)
           fnext expr_value; fbreak; };

      punctuation_end
      => { emit_table(PUNCTUATION)
           fnext expr_beg; fbreak; };

      #
      # WHITESPACE
      #

      '\\' e_heredoc_nl;

      '\\' ( any - c_nl ) {
        diagnostic :error, "bare backslash only allowed before newline", @ts...@ts + 1
        fhold;
      };

      '#' ( c_any - c_nl )*
      => { @comments << tok(@ts, @te + 1) };

      e_heredoc_nl
      => { fgoto leading_dot; };

      ';'
      => { emit_table(PUNCTUATION)
           fnext expr_value; fbreak; };

      c_space+;

      c_any
      => {
        diagnostic :fatal, "unexpected #{tok.inspect}"
      };

      c_eof => do_eof;
  *|;

  leading_dot := |*
      # Insane leading dots:
      # a #comment
      #  .b: a.b
      c_space* '.' ( c_any - '.' )
      => { fhold; fhold;
           fgoto expr_end; };

      any
      => { emit(:tNL, nil, @newline_s, @newline_s + 1)
           fnext line_begin; fhold; fbreak; };
  *|;

  #
  # === EMBEDDED DOCUMENT (aka BLOCK COMMENT) PARSING ===
  #

  line_comment := |*
      '=end' c_line* c_nl
      => { @comments << tok
           fgoto line_begin; };

      c_line* c_nl
      => { @comments << tok };

      c_eof
      => {
        diagnostic :fatal, "embedded document meats end of file (and they embark on a romantic journey)"
      };
  *|;

  line_begin := |*
      c_space_nl+;

      '#' c_line* c_eol
      => { @comments << tok
           fhold; };

      '=begin' ( c_space | c_eol )
      => { @comments << tok(@ts, @te)
           fgoto line_comment; };

      '__END__' c_eol
      => { p = pe - 1 };

      c_any
      => { fhold; fgoto expr_value; };

      c_eof => do_eof;
  *|;

  }%%
  # %
end
