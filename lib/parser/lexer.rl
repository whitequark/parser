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
#       @source_buffer.slice(@ts...@te)
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
#    If you perform `fgoto` in an action which does not emit a token nor
#    rewinds the stream pointer, the parser's side-effectful,
#    context-sensitive lookahead actions will break in a hard to detect
#    and debug way.
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
#    e_something stands for "something with **e**mbedded action".
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

  attr_reader   :source_buffer

  attr_accessor :diagnostics
  attr_accessor :static_env
  attr_accessor :force_utf32

  attr_accessor :cond, :cmdarg, :context, :command_start

  attr_accessor :tokens, :comments

  attr_reader :paren_nest, :cmdarg_stack, :cond_stack, :lambda_stack, :version

  def initialize(version)
    @version    = version
    @static_env = nil
    @context    = nil

    @tokens     = nil
    @comments   = nil

    @_lex_actions =
      if self.class.respond_to?(:_lex_actions, true)
        self.class.send :_lex_actions
      else
        []
      end

    @emit_integer = lambda { |chars, p| emit(:tINTEGER,   chars); p }
    @emit_rational = lambda { |chars, p| emit(:tRATIONAL,  Rational(chars)); p }
    @emit_imaginary = lambda { |chars, p| emit(:tIMAGINARY, Complex(0, chars)); p }
    @emit_imaginary_rational = lambda { |chars, p| emit(:tIMAGINARY, Complex(0, Rational(chars))); p }
    @emit_integer_re = lambda { |chars, p| emit(:tINTEGER,   chars, @ts, @te - 2); p - 2 }
    @emit_integer_if = lambda { |chars, p| emit(:tINTEGER,   chars, @ts, @te - 2); p - 2 }
    @emit_integer_rescue = lambda { |chars, p| emit(:tINTEGER,   chars, @ts, @te - 6); p - 6 }

    @emit_float = lambda { |chars, p| emit(:tFLOAT,     Float(chars)); p }
    @emit_imaginary_float = lambda { |chars, p| emit(:tIMAGINARY, Complex(0, Float(chars))); p }
    @emit_float_if =     lambda { |chars, p| emit(:tFLOAT,     Float(chars), @ts, @te - 2); p - 2 }
    @emit_float_rescue = lambda { |chars, p| emit(:tFLOAT,     Float(chars), @ts, @te - 6); p - 6 }

    reset
  end

  def reset(reset_state=true)
    # Ragel state:
    if reset_state
      # Unit tests set state prior to resetting lexer.
      @cs     = self.class.lex_en_line_begin

      @cond   = StackState.new('cond')
      @cmdarg = StackState.new('cmdarg')
      @cond_stack   = []
      @cmdarg_stack = []
    end

    @force_utf32   = false # Set to true by some tests

    @source_pts    = nil # @source as a codepoint array

    @p             = 0   # stream position (saved manually in #advance)
    @ts            = nil # token start
    @te            = nil # token end
    @act           = 0   # next action

    @stack         = []  # state stack
    @top           = 0   # state stack top pointer

    # Lexer state:
    @token_queue   = []

    @eq_begin_s    = nil # location of last encountered =begin
    @sharp_s       = nil # location of last encountered #

    @newline_s     = nil # location of last encountered newline

    @num_base      = nil # last numeric base
    @num_digits_s  = nil # starting position of numeric digits
    @num_suffix_s  = nil # starting position of numeric suffix
    @num_xfrm      = nil # numeric suffix-induced transformation

    # Ruby 1.9 ->() lambdas emit a distinct token if do/{ is
    # encountered after a matching closing parenthesis.
    @paren_nest    = 0
    @lambda_stack  = []

    # If the lexer is in `command state' (aka expr_value)
    # at the entry to #advance, it will transition to expr_cmdarg
    # instead of expr_arg at certain points.
    @command_start = true

    # State before =begin / =end block comment
    @cs_before_block_comment = self.class.lex_en_line_begin

    @strings = Parser::LexerStrings.new(self, @version)
  end

  def source_buffer=(source_buffer)
    @source_buffer = source_buffer

    if @source_buffer
      source = @source_buffer.source

      if source.encoding == Encoding::UTF_8
        @source_pts = source.unpack('U*')
      else
        @source_pts = source.unpack('C*')
      end

      if @source_pts[0] == 0xfeff
        # Skip byte order mark.
        @p = 1
      end
    else
      @source_pts = nil
    end

    @strings.source_buffer = @source_buffer
    @strings.source_pts = @source_pts
  end

  def encoding
    @source_buffer.source.encoding
  end

  LEX_STATES = {
    :line_begin    => lex_en_line_begin,
    :expr_dot      => lex_en_expr_dot,
    :expr_fname    => lex_en_expr_fname,
    :expr_value    => lex_en_expr_value,
    :expr_beg      => lex_en_expr_beg,
    :expr_mid      => lex_en_expr_mid,
    :expr_arg      => lex_en_expr_arg,
    :expr_cmdarg   => lex_en_expr_cmdarg,
    :expr_end      => lex_en_expr_end,
    :expr_endarg   => lex_en_expr_endarg,
    :expr_endfn    => lex_en_expr_endfn,
    :expr_labelarg => lex_en_expr_labelarg,

    :inside_string => lex_en_inside_string
  }

  def state
    LEX_STATES.invert.fetch(@cs, @cs)
  end

  def state=(state)
    @cs = LEX_STATES.fetch(state)
  end

  def push_cmdarg
    @cmdarg_stack.push(@cmdarg)
    @cmdarg = StackState.new("cmdarg.#{@cmdarg_stack.count}")
  end

  def pop_cmdarg
    @cmdarg = @cmdarg_stack.pop
  end

  def push_cond
    @cond_stack.push(@cond)
    @cond = StackState.new("cond.#{@cond_stack.count}")
  end

  def pop_cond
    @cond = @cond_stack.pop
  end

  def dedent_level
    @strings.dedent_level
  end

  # Return next token: [type, value].
  def advance
    unless @token_queue.empty?
      return @token_queue.shift
    end

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

    pe = @source_pts.size + 2
    p, eof = @p, pe

    cmd_state = @command_start
    @command_start = false

    %% write exec;
    # %

    # Ragel creates a local variable called `testEof` but it doesn't use
    # it in any assignment. This dead code is here to swallow the warning.
    # It has no runtime cost because Ruby doesn't produce any instructions from it.
    if false
      testEof
    end

    @p = p

    if @token_queue.any?
      @token_queue.shift
    elsif @cs == klass.lex_error
      [ false, [ '$error'.freeze, range(p - 1, p) ] ]
    else
      eof = @source_pts.size
      [ false, [ '$eof'.freeze,   range(eof, eof) ] ]
    end
  end

  protected

  def version?(*versions)
    versions.include?(@version)
  end

  def stack_pop
    @top -= 1
    @stack[@top]
  end

  def tok(s = @ts, e = @te)
    @source_buffer.slice(s, e - s)
  end

  def range(s = @ts, e = @te)
    Parser::Source::Range.new(@source_buffer, s, e)
  end

  def emit(type, value = tok, s = @ts, e = @te)
    token = [ type, [ value, range(s, e) ] ]

    @token_queue.push(token)

    @tokens.push(token) if @tokens

    token
  end

  def emit_table(table, s = @ts, e = @te)
    value = tok(s, e)

    emit(table[value], value, s, e)
  end

  def emit_do(do_block=false)
    if @cond.active?
      emit(:kDO_COND, 'do'.freeze)
    elsif @cmdarg.active? || do_block
      emit(:kDO_BLOCK, 'do'.freeze)
    else
      emit(:kDO, 'do'.freeze)
    end
  end

  def arg_or_cmdarg(cmd_state)
    if cmd_state
      self.class.lex_en_expr_cmdarg
    else
      self.class.lex_en_expr_arg
    end
  end

  def emit_comment(s = @ts, e = @te)
    if @comments
      @comments.push(Parser::Source::Comment.new(range(s, e)))
    end

    if @tokens
      @tokens.push([ :tCOMMENT, [ tok(s, e), range(s, e) ] ])
    end

    nil
  end

  def emit_comment_from_range(p, pe)
    emit_comment(@sharp_s, p == pe ? p - 2 : p)
  end

  def diagnostic(type, reason, arguments=nil, location=range, highlights=[])
    @diagnostics.process(
        Parser::Diagnostic.new(type, reason, arguments, location, highlights))
  end


  def e_lbrace
    @cond.push(false); @cmdarg.push(false)

    current_literal = @strings.literal
    if current_literal
      current_literal.start_interp_brace
    end
  end

  def numeric_literal_int
    digits = tok(@num_digits_s, @num_suffix_s)

    if digits.end_with? '_'.freeze
      diagnostic :error, :trailing_in_number, { :character => '_'.freeze },
                 range(@te - 1, @te)
    elsif digits.empty? && @num_base == 8 && version?(18)
      # 1.8 did not raise an error on 0o.
      digits = '0'.freeze
    elsif digits.empty?
      diagnostic :error, :empty_numeric
    elsif @num_base == 8 && (invalid_idx = digits.index(/[89]/))
      invalid_s = @num_digits_s + invalid_idx
      diagnostic :error, :invalid_octal, nil,
                 range(invalid_s, invalid_s + 1)
    end
    digits
  end

  def on_newline(p)
    @strings.on_newline(p)
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

  def emit_global_var(ts = @ts, te = @te)
    if tok(ts, te) =~ /^\$([1-9][0-9]*)$/
      emit(:tNTH_REF, tok(ts + 1, te).to_i, ts, te)
    elsif tok =~ /^\$([&`'+])$/
      emit(:tBACK_REF, tok(ts, te), ts, te)
    else
      emit(:tGVAR, tok(ts, te), ts, te)
    end
  end

  def emit_class_var(ts = @ts, te = @te)
    if tok(ts, te) =~ /^@@[0-9]/
      diagnostic :error, :cvar_name, { :name => tok(ts, te) }
    end

    emit(:tCVAR, tok(ts, te), ts, te)
  end

  def emit_instance_var(ts = @ts, te = @te)
    if tok(ts, te) =~ /^@[0-9]/
      diagnostic :error, :ivar_name, { :name => tok(ts, te) }
    end

    emit(:tIVAR, tok(ts, te), ts, te)
  end

  def emit_rbrace_rparen_rbrack
    emit_table(PUNCTUATION)

    if @version < 24
      @cond.lexpop
      @cmdarg.lexpop
    else
      @cond.pop
      @cmdarg.pop
    end
  end

  def emit_colon_with_digits(p, tm, diag_msg)
    if @version >= 27
      diagnostic :error, diag_msg, { name: tok(tm, @te) }, range(tm, @te)
    else
      emit(:tCOLON, tok(@ts, @ts + 1), @ts, @ts + 1)
      p = @ts
    end
    p
  end

  def emit_singleton_class
    emit(:kCLASS, 'class'.freeze, @ts, @ts + 5)
    emit(:tLSHFT, '<<'.freeze,    @te - 2, @te)
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
    '!@'  => :tBANG,    '&.'  => :tANDDOT,
  }

  PUNCTUATION_BEGIN = {
    '&'   => :tAMPER,   '*'   => :tSTAR,    '**'  => :tDSTAR,
    '+'   => :tUPLUS,   '-'   => :tUMINUS,  '::'  => :tCOLON3,
    '('   => :tLPAREN,  '{'   => :tLBRACE,  '['   => :tLBRACK,
  }

  KEYWORDS = {
    'if'     => :kIF_MOD,      'unless'   => :kUNLESS_MOD,
    'while'  => :kWHILE_MOD,   'until'    => :kUNTIL_MOD,
    'rescue' => :kRESCUE_MOD,  'defined?' => :kDEFINED,
    'BEGIN'  => :klBEGIN,      'END'      => :klEND,
  }

  KEYWORDS_BEGIN = {
    'if'     => :kIF,          'unless'   => :kUNLESS,
    'while'  => :kWHILE,       'until'    => :kUNTIL,
    'rescue' => :kRESCUE,      'defined?' => :kDEFINED,
    'BEGIN'  => :klBEGIN,      'END'      => :klEND,
  }

  ESCAPE_WHITESPACE = {
    " "  => '\s', "\r" => '\r', "\n" => '\n', "\t" => '\t',
    "\v" => '\v', "\f" => '\f'
  }

  %w(class module def undef begin end then elsif else ensure case when
     for break next redo retry in do return yield super self nil true
     false and or not alias __FILE__ __LINE__ __ENCODING__).each do |keyword|
    KEYWORDS_BEGIN[keyword] = KEYWORDS[keyword] = :"k#{keyword.upcase}"
  end

  %%{
  # %

  access @;
  getkey (@source_pts[p] || 0);

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
  operator_fname      = '[]' | '[]=' | '`'  | '-@' | '+@' | '~@'  | '!@' ;

  # A list of operators which can occur within an assignment shortcut (+ → +=).
  operator_arithmetic = '&'  | '|'   | '&&' | '||' | '^'  | '+'   | '-'  |
                        '*'  | '/'   | '**' | '~'  | '<<' | '>>'  | '%'  ;

  # A list of all user-definable operators not covered by groups above.
  operator_rest       = '=~' | '!~' | '==' | '!=' | '!'   | '===' |
                        '<'  | '<=' | '>'  | '>=' | '<=>' | '=>'  ;

  # Note that `{` and `}` need to be referred to as e_lbrace and e_rbrace,
  # as they are ambiguous with interpolation `#{}` and should be counted.
  # These braces are not present in punctuation lists.

  # A list of punctuation which has different meaning when used at the
  # beginning of expression.
  punctuation_begin   = '-'  | '+'  | '::' | '('  | '['  |
                        '*'  | '**' | '&'  ;

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

  constant       = c_upper c_alnum*;
  bareword       = c_alpha c_alnum*;

  call_or_var    = c_lower c_alnum*;
  class_var      = '@@' bareword;
  instance_var   = '@' bareword;
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

  label          = bareword [?!]? ':';

  #
  # === NUMERIC PARSING ===
  #

  int_hex  = ( xdigit+ '_' )* xdigit* '_'? ;
  int_dec  = ( digit+ '_' )* digit* '_'? ;
  int_bin  = ( [01]+ '_' )* [01]* '_'? ;

  flo_int  = [1-9] [0-9]* ( '_' digit+ )* | '0';
  flo_frac = '.' ( digit+ '_' )* digit+;
  flo_pow  = [eE] [+\-]? ( digit+ '_' )* digit+;

  int_suffix =
    ''       % { @num_xfrm = @emit_integer }
  | 'r'      % { @num_xfrm = @emit_rational }
  | 'i'      % { @num_xfrm = @emit_imaginary }
  | 'ri'     % { @num_xfrm = @emit_imaginary_rational }
  | 're'     % { @num_xfrm = @emit_integer_re }
  | 'if'     % { @num_xfrm = @emit_integer_if }
  | 'rescue' % { @num_xfrm = @emit_integer_rescue };

  flo_pow_suffix =
    ''   % { @num_xfrm = @emit_float }
  | 'i'  % { @num_xfrm = @emit_imaginary_float }
  | 'if' % { @num_xfrm = @emit_float_if };

  flo_suffix =
    flo_pow_suffix
  | 'r'      % { @num_xfrm = @emit_rational }
  | 'ri'     % { @num_xfrm = @emit_imaginary_rational }
  | 'rescue' % { @num_xfrm = @emit_float_rescue };

  #
  # === INTERPOLATION PARSING ===
  #

  e_lbrace = '{' % {
    e_lbrace
  };

  e_rbrace = '}' % {
    if @strings.close_interp_on_current_literal(p)
      fhold;
      fnext inside_string;
      fbreak;
    end

    @paren_nest -= 1
  };

  #
  # === WHITESPACE HANDLING ===
  #

  # Various contexts in Ruby allow various kinds of whitespace
  # to be used. They are grouped to clarify the lexing machines
  # and ease collection of comments.

  # A line of code with inline #comment at end is always equivalent
  # to a line of code ending with just a newline, so an inline
  # comment is deemed equivalent to non-newline whitespace
  # (c_space character class).

  e_nl = c_nl % {
    p = on_newline(p)
  };

  w_space =
      c_space+
    | '\\' e_nl
    ;

  w_comment =
      '#'     %{ @sharp_s = p - 1 }
      # The (p == pe) condition compensates for added "\0" and
      # the way Ragel handles EOF.
      c_line* %{ emit_comment_from_range(p, pe) }
    ;

  w_space_comment =
      w_space
    | w_comment
    ;

  # A newline in non-literal context always interoperates with
  # here document logic and can always be escaped by a backslash,
  # still interoperating with here document logic in the same way,
  # yet being invisible to anything else.
  #
  # To demonstrate:
  #
  #     foo = <<FOO \
  #     bar
  #     FOO
  #      + 2
  #
  # is equivalent to `foo = "bar\n" + 2`.

  w_newline =
      e_nl;

  w_any =
      w_space
    | w_comment
    | w_newline
    ;


  #
  # === EXPRESSION PARSING ===
  #

  # These rules implement a form of manually defined lookahead.
  # The default longest-match scanning does not work here due
  # to sheer ambiguity.

  ambiguous_fid_suffix =         # actual    parsed
      [?!]    %{ tm = p }      | # a?        a?
      [?!]'=' %{ tm = p - 2 }    # a!=b      a != b
  ;

  ambiguous_ident_suffix =       # actual    parsed
      ambiguous_fid_suffix     |
      '='     %{ tm = p }      | # a=        a=
      '=='    %{ tm = p - 2 }  | # a==b      a == b
      '=~'    %{ tm = p - 2 }  | # a=~b      a =~ b
      '=>'    %{ tm = p - 2 }  | # a=>b      a => b
      '==='   %{ tm = p - 3 }    # a===b     a === b
  ;

  ambiguous_symbol_suffix =      # actual    parsed
      ambiguous_ident_suffix |
      '==>'   %{ tm = p - 2 }    # :a==>b    :a= => b
  ;

  # Ambiguous with 1.9 hash labels.
  ambiguous_const_suffix =       # actual    parsed
      '::'    %{ tm = p - 2 }    # A::B      A :: B
  ;

  # Resolving kDO/kDO_COND/kDO_BLOCK ambiguity requires embedding
  # @cond/@cmdarg-related code to e_lbrack, e_lparen and e_lbrace.

  e_lbrack = '[' % {
    @cond.push(false); @cmdarg.push(false)

    @paren_nest += 1
  };

  e_rbrack = ']' % {
    @paren_nest -= 1
  };

  # Ruby 1.9 lambdas require parentheses counting in order to
  # emit correct opening kDO/tLBRACE.

  e_lparen = '(' % {
    @cond.push(false); @cmdarg.push(false)

    @paren_nest += 1

    if version?(18)
      @command_start = true
    end
  };

  e_rparen = ')' % {
    @paren_nest -= 1
  };

  # Ruby is context-sensitive wrt/ local identifiers.
  action local_ident {
    emit(:tIDENTIFIER)

    if !@static_env.nil? && @static_env.declared?(tok)
      fnext expr_endfn; fbreak;
    else
      fnext *arg_or_cmdarg(cmd_state); fbreak;
    end
  }

  # Variable lexing code is accessed from both expressions and
  # string interpolation related code.
  #
  expr_variable := |*
      global_var
      => {
        emit_global_var

        fnext *stack_pop; fbreak;
      };

      class_var_v
      => {
        emit_class_var

        fnext *stack_pop; fbreak;
      };

      instance_var_v
      => {
        emit_instance_var

        fnext *stack_pop; fbreak;
      };
  *|;

  # Literal function name in definition (e.g. `def class`).
  # Keywords are returned as their respective tokens; this is used
  # to support singleton def `def self.foo`. Global variables are
  # returned as `tGVAR`; this is used in global variable alias
  # statements `alias $a $b`. Symbols are returned verbatim; this
  # is used in `alias :a :"b#{foo}"` and `undef :a`.
  #
  # Transitions to `expr_endfn` afterwards.
  #
  expr_fname := |*
      keyword
      => { emit_table(KEYWORDS_BEGIN);
           fnext expr_endfn; fbreak; };

      constant
      => { emit(:tCONSTANT)
           fnext expr_endfn; fbreak; };

      bareword [?=!]?
      => { emit(:tIDENTIFIER)
           fnext expr_endfn; fbreak; };

      global_var
      => { p = @ts - 1
           fnext expr_end; fcall expr_variable; };

      # If the handling was to be delegated to expr_end,
      # these cases would transition to something else than
      # expr_endfn, which is incorrect.
      operator_fname      |
      operator_arithmetic |
      operator_rest
      => { emit_table(PUNCTUATION)
           fnext expr_endfn; fbreak; };

      '::'
      => { fhold; fhold; fgoto expr_end; };

      ':'
      => { fhold; fgoto expr_beg; };

      '%s' (c_ascii - [A-Za-z0-9])
      => {
        if version?(23)
          type, delimiter = tok[0..-2], tok[-1].chr
          @strings.push_literal(type, delimiter, @ts)
          fgoto inside_string;
        else
          p = @ts - 1
          fgoto expr_end;
        end
      };

      w_any;

      c_any
      => { fhold; fgoto expr_end; };

      c_eof => do_eof;
  *|;

  # After literal function name in definition. Behaves like `expr_end`,
  # but allows a tLABEL.
  #
  # Transitions to `expr_end` afterwards.
  #
  expr_endfn := |*
      label ( any - ':' )
      => { emit(:tLABEL, tok(@ts, @te - 2), @ts, @te - 1)
           fhold; fnext expr_labelarg; fbreak; };

      '...'
      => {
        if @version >= 31 && @context.in_argdef
          emit(:tBDOT3, '...'.freeze)
          # emit(:tNL, "\n".freeze, @te - 1, @te)
          fnext expr_end; fbreak;
        else
          p -= 3;
          fgoto expr_end;
        end
      };

      w_space_comment;

      c_any
      => { fhold; fgoto expr_end; };

      c_eof => do_eof;
  *|;

  # Literal function name in method call (e.g. `a.class`).
  #
  # Transitions to `expr_arg` afterwards.
  #
  expr_dot := |*
      constant
      => { emit(:tCONSTANT)
           fnext *arg_or_cmdarg(cmd_state); fbreak; };

      call_or_var
      => { emit(:tIDENTIFIER)
           fnext *arg_or_cmdarg(cmd_state); fbreak; };

      bareword ambiguous_fid_suffix
      => { emit(:tFID, tok(@ts, tm), @ts, tm)
           fnext *arg_or_cmdarg(cmd_state); p = tm - 1; fbreak; };

      # See the comment in `expr_fname`.
      operator_fname      |
      operator_arithmetic |
      operator_rest
      => { emit_table(PUNCTUATION)
           fnext expr_arg; fbreak; };

      w_any;

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
      w_space+ e_lparen
      => {
        if version?(18)
          emit(:tLPAREN2, '('.freeze, @te - 1, @te)
          fnext expr_value; fbreak;
        else
          emit(:tLPAREN_ARG, '('.freeze, @te - 1, @te)
          fnext expr_beg; fbreak;
        end
      };

      # meth(1 + 2)
      # Regular method call.
      e_lparen
      => { emit(:tLPAREN2, '('.freeze)
           fnext expr_beg; fbreak; };

      # meth [...]
      # Array argument. Compare with indexing `meth[...]`.
      w_space+ e_lbrack
      => { emit(:tLBRACK, '['.freeze, @te - 1, @te)
           fnext expr_beg; fbreak; };

      # cmd {}
      # Command: method call without parentheses.
      w_space* e_lbrace
      => {
        if @lambda_stack.last == @paren_nest
          @lambda_stack.pop
          emit(:tLAMBEG, '{'.freeze, @te - 1, @te)
        else
          emit(:tLCURLY, '{'.freeze, @te - 1, @te)
        end
        @command_start = true
        @paren_nest += 1
        fnext expr_value; fbreak;
      };

      #
      # AMBIGUOUS TOKENS RESOLVED VIA EXPR_BEG
      #

      # a??
      # Ternary operator
      '?' c_space_nl
      => {
        # Unlike expr_beg as invoked in the next rule, do not warn
        p = @ts - 1
        fgoto expr_end;
      };

      # a ?b, a? ?
      # Character literal or ternary operator
      w_space* '?'
      => { fhold; fgoto expr_beg; };

      # a %{1}, a %[1] (but not "a %=1=" or "a % foo")
      # a /foo/ (but not "a / foo" or "a /=foo")
      # a <<HEREDOC
      w_space+ %{ tm = p }
      ( [%/] ( c_any - c_space_nl - '=' ) # /
      | '<<'
      )
      => {
        check_ambiguous_slash(tm)

        p = tm - 1
        fgoto expr_beg;
      };

      # x *1
      # Ambiguous splat, kwsplat or block-pass.
      w_space+ %{ tm = p } ( '+' | '-' | '*' | '&' | '**' )
      => {
        diagnostic :warning, :ambiguous_prefix, { :prefix => tok(tm, @te) },
                   range(tm, @te)

        p = tm - 1
        fgoto expr_beg;
      };

      # x ::Foo
      # Ambiguous toplevel constant access.
      w_space+ '::'
      => { fhold; fhold; fgoto expr_beg; };

      # x:b
      # Symbol.
      w_space* ':'
      => { fhold; fgoto expr_beg; };

      w_space+ label
      => { p = @ts - 1; fgoto expr_beg; };

      #
      # AMBIGUOUS TOKENS RESOLVED VIA EXPR_END
      #

      # a ? b
      # Ternary operator.
      w_space+ %{ tm = p } '?' c_space_nl
      => { p = tm - 1; fgoto expr_end; };

      # x + 1: Binary operator or operator-assignment.
      w_space* operator_arithmetic
                  ( '=' | c_space_nl )?    |
      # x rescue y: Modifier keyword.
      w_space* keyword_modifier            |
      # a &. b: Safe navigation operator.
      w_space* '&.'                        |
      # Miscellanea.
      w_space* punctuation_end
      => {
        p = @ts - 1
        fgoto expr_end;
      };

      w_space;

      w_comment
      => { fgoto expr_end; };

      w_newline
      => { fhold; fgoto expr_end; };

      c_any
      => { fhold; fgoto expr_beg; };

      c_eof => do_eof;
  *|;

  # The previous token was an identifier which was seen while in the
  # command mode (that is, the state at the beginning of #advance was
  # expr_value). This state is very similar to expr_arg, but disambiguates
  # two very rare and specific condition:
  #   * In 1.8 mode, "foo (lambda do end)".
  #   * In 1.9+ mode, "f x: -> do foo do end end".
  expr_cmdarg := |*
      w_space+ e_lparen
      => {
        emit(:tLPAREN_ARG, '('.freeze, @te - 1, @te)
        if version?(18)
          fnext expr_value; fbreak;
        else
          fnext expr_beg; fbreak;
        end
      };

      w_space* 'do'
      => {
        if @cond.active?
          emit(:kDO_COND, 'do'.freeze, @te - 2, @te)
        else
          emit(:kDO, 'do'.freeze, @te - 2, @te)
        end
        fnext expr_value; fbreak;
      };

      c_any             |
      # Disambiguate with the `do' rule above.
      w_space* bareword |
      w_space* label
      => { p = @ts - 1
           fgoto expr_arg; };

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
  # `do` (as `kDO_BLOCK` in `expr_beg`).
  expr_endarg := |*
      e_lbrace
      => {
        if @lambda_stack.last == @paren_nest
          @lambda_stack.pop
          emit(:tLAMBEG, '{'.freeze)
        else
          emit(:tLBRACE_ARG, '{'.freeze)
        end
        @paren_nest += 1
        @command_start = true
        fnext expr_value; fbreak;
      };

      'do'
      => { emit_do(true)
           fnext expr_value; fbreak; };

      w_space_comment;

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

      bareword
      => { p = @ts - 1; fgoto expr_beg; };

      w_space_comment;

      w_newline
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
      # +5, -5, -  5
      [+\-] w_any* [0-9]
      => {
        emit(:tUNARY_NUM, tok(@ts, @ts + 1), @ts, @ts + 1)
        fhold; fnext expr_end; fbreak;
      };

      # splat *a
      '*'
      => { emit(:tSTAR, '*'.freeze)
           fbreak; };

      #
      # STRING AND REGEXP LITERALS
      #

      # /regexp/oui
      # /=/ (disambiguation with /=)
      '/' c_any
      => {
        type = delimiter = tok[0].chr
        @strings.push_literal(type, delimiter, @ts)

        fhold;
        fgoto inside_string;
      };

      # %<string>
      '%' ( c_ascii - [A-Za-z0-9] )
      => {
        type, delimiter = @source_buffer.slice(@ts, 1).chr, tok[-1].chr
        @strings.push_literal(type, delimiter, @ts)
        fgoto inside_string;
      };

      # %w(we are the people)
      '%' [A-Za-z] (c_ascii - [A-Za-z0-9])
      => {
        type, delimiter = tok[0..-2], tok[-1].chr
        @strings.push_literal(type, delimiter, @ts)
        fgoto inside_string;
      };

      '%' c_eof
      => {
        diagnostic :fatal, :string_eof, nil, range(@ts, @ts + 1)
      };

      # Heredoc start.
      # <<END  | <<'END'  | <<"END"  | <<`END`  |
      # <<-END | <<-'END' | <<-"END" | <<-`END` |
      # <<~END | <<~'END' | <<~"END" | <<~`END`
      '<<' [~\-]?
        ( '"' ( any - '"' )* '"'
        | "'" ( any - "'" )* "'"
        | "`" ( any - "`" )* "`"
        | bareword ) % { heredoc_e      = p }
        c_line* c_nl % { new_herebody_s = p }
      => {
        tok(@ts, heredoc_e) =~ /^<<(-?)(~?)(["'`]?)(.*)\3$/m

        indent      = !$1.empty? || !$2.empty?
        dedent_body = !$2.empty?
        type        =  $3.empty? ? '<<"'.freeze : ('<<'.freeze + $3)
        delimiter   =  $4

        if @version >= 27
          if delimiter.count("\n") > 0 || delimiter.count("\r") > 0
            diagnostic :error, :unterminated_heredoc_id, nil, range(@ts, @ts + 1)
          end
        elsif @version >= 24
          if delimiter.count("\n") > 0
            if delimiter.end_with?("\n")
              diagnostic :warning, :heredoc_id_ends_with_nl, nil, range(@ts, @ts + 1)
              delimiter = delimiter.rstrip
            else
              diagnostic :fatal, :heredoc_id_has_newline, nil, range(@ts, @ts + 1)
            end
          end
        end

        if dedent_body && version?(18, 19, 20, 21, 22)
          emit(:tLSHFT, '<<'.freeze, @ts, @ts + 2)
          p = @ts + 1
          fnext expr_beg; fbreak;
        else
          @strings.push_literal(type, delimiter, @ts, heredoc_e, indent, dedent_body);
          @strings.herebody_s ||= new_herebody_s

          p = @strings.herebody_s - 1
          fnext inside_string;
        end
      };

      # Escaped unterminated heredoc start
      # <<'END  | <<"END  | <<`END  |
      # <<-'END | <<-"END | <<-`END |
      # <<~'END | <<~"END | <<~`END
      #
      # If the heredoc is terminated the rule above should handle it
      '<<' [~\-]?
        ('"' (any - c_nl - '"')*
        |"'" (any - c_nl - "'")*
        |"`" (any - c_nl - "`")
        )
      => {
        diagnostic :error, :unterminated_heredoc_id, nil, range(@ts, @ts + 1)
      };

      #
      # SYMBOL LITERALS
      #

      # :&&, :||
      ':' ('&&' | '||') => {
        fhold; fhold;
        emit(:tSYMBEG, tok(@ts, @ts + 1), @ts, @ts + 1)
        fgoto expr_fname;
      };

      # :"bar", :'baz'
      ':' ['"] # '
      => {
        type, delimiter = tok, tok[-1].chr
        @strings.push_literal(type, delimiter, @ts);

        fgoto inside_string;
      };

      # :!@ is :!
      # :~@ is :~
      ':' [!~] '@'
      => {
        emit(:tSYMBOL, tok(@ts + 1, @ts + 2))
        fnext expr_end; fbreak;
      };

      ':' bareword ambiguous_symbol_suffix
      => {
        emit(:tSYMBOL, tok(@ts + 1, tm), @ts, tm)
        p = tm - 1
        fnext expr_end; fbreak;
      };

      ':' ( bareword | global_var | class_var | instance_var |
            operator_fname | operator_arithmetic | operator_rest )
      => {
        emit(:tSYMBOL, tok(@ts + 1), @ts)
        fnext expr_end; fbreak;
      };

      ':' ( '@'  %{ tm = p - 1; diag_msg = :ivar_name }
          | '@@' %{ tm = p - 2; diag_msg = :cvar_name }
          ) [0-9]*
      => {
        emit_colon_with_digits(p, tm, diag_msg)

        fnext expr_end; fbreak;
      };

      #
      # AMBIGUOUS TERNARY OPERATOR
      #

      # Character constant, like ?a, ?\n, ?\u1000, and so on
      # Don't accept \u escape with multiple codepoints, like \u{1 2 3}
      '?' c_any
      => {
        p, next_state = @strings.read_character_constant(@ts)
        fhold; # Ragel will do `p += 1` to consume input, prevent it

        # If strings lexer founds a character constant (?a) emit it,
        # otherwise read ternary operator
        if @token_queue.empty?
          fgoto *next_state;
        else
          fnext *next_state;
          fbreak;
        end
      };

      '?' c_eof
      => {
        diagnostic :fatal, :incomplete_escape, nil, range(@ts, @ts + 1)
      };

      #
      # AMBIGUOUS EMPTY BLOCK ARGUMENTS
      #

      # Ruby >= 2.7 emits it as two tPIPE terminals
      # while Ruby < 2.7 as a single tOROP (like in `a || b`)
      '||'
      => {
        if @version >= 27
          emit(:tPIPE, tok(@ts, @ts + 1), @ts, @ts + 1)
          fhold;
          fnext expr_beg; fbreak;
        else
          p -= 2
          fgoto expr_end;
        end
      };

      #
      # KEYWORDS AND PUNCTUATION
      #

      # a({b=>c})
      e_lbrace
      => {
        if @lambda_stack.last == @paren_nest
          @lambda_stack.pop
          @command_start = true
          emit(:tLAMBEG, '{'.freeze)
        else
          emit(:tLBRACE, '{'.freeze)
        end
        @paren_nest += 1
        fbreak;
      };

      # a([1, 2])
      e_lbrack
      => { emit(:tLBRACK, '['.freeze)
           fbreak; };

      # a()
      e_lparen
      => { emit(:tLPAREN, '('.freeze)
           fbreak; };

      # a(+b)
      punctuation_begin
      => { emit_table(PUNCTUATION_BEGIN)
           fbreak; };

      # rescue Exception => e: Block rescue.
      # Special because it should transition to expr_mid.
      'rescue' %{ tm = p } '=>'?
      => { emit(:kRESCUE, 'rescue'.freeze, @ts, tm)
           p = tm - 1
           fnext expr_mid; fbreak; };

      # if a: Statement if.
      keyword_modifier
      => { emit_table(KEYWORDS_BEGIN)
           @command_start = true
           fnext expr_value; fbreak; };

      #
      # RUBY 1.9 HASH LABELS
      #

      label ( any - ':' )
      => {
        fhold;

        if version?(18)
          ident = tok(@ts, @te - 2)

          emit((@source_buffer.slice(@ts, 1) =~ /[A-Z]/) ? :tCONSTANT : :tIDENTIFIER,
               ident, @ts, @te - 2)
          fhold; # continue as a symbol

          if !@static_env.nil? && @static_env.declared?(ident)
            fnext expr_end;
          else
            fnext *arg_or_cmdarg(cmd_state);
          end
        else
          emit(:tLABEL, tok(@ts, @te - 2), @ts, @te - 1)
          fnext expr_labelarg;
        end

        fbreak;
      };

      #
      # RUBY 2.7 BEGINLESS RANGE

      '..'
      => {
        if @version >= 27
          emit(:tBDOT2)
        else
          emit(:tDOT2)
        end

        fnext expr_beg; fbreak;
      };

      '...' c_nl?
      => {
        # Here we scan and conditionally emit "\n":
        # + if it's there
        #   + and emitted we do nothing
        #   + and not emitted we return `p` to "\n" to process it on the next scan
        # + if it's not there we do nothing
        followed_by_nl = @te - 1 == @newline_s
        nl_emitted = false
        dots_te = followed_by_nl ? @te - 1 : @te

        if @version >= 30
          if @lambda_stack.any? && @lambda_stack.last + 1 == @paren_nest
            # To reject `->(...)` like `->...`
            emit(:tDOT3, '...'.freeze, @ts, dots_te)
          else
            emit(:tBDOT3, '...'.freeze, @ts, dots_te)

            if @version >= 31 && followed_by_nl && @context.in_argdef
              emit(:tNL, @te - 1, @te)
              nl_emitted = true
            end
          end
        elsif @version >= 27
          emit(:tBDOT3, '...'.freeze, @ts, dots_te)
        else
          emit(:tDOT3, '...'.freeze, @ts, dots_te)
        end

        if followed_by_nl && !nl_emitted
          # return "\n" to process it on the next scan
          fhold;
        end

        fnext expr_beg; fbreak;
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
      => local_ident;

      (call_or_var - keyword)
        % { ident_tok = tok; ident_ts = @ts; ident_te = @te; }
      w_space+ '('
      => {
        emit(:tIDENTIFIER, ident_tok, ident_ts, ident_te)
        p = ident_te - 1

        if !@static_env.nil? && @static_env.declared?(ident_tok) && @version < 25
          fnext expr_endfn;
        else
          fnext expr_cmdarg;
        end
        fbreak;
      };

      #
      # WHITESPACE
      #

      w_any;

      e_nl '=begin' ( c_space | c_nl_zlen )
      => {
        p = @ts - 1
        @cs_before_block_comment = @cs
        fgoto line_begin;
      };

      #
      # DEFAULT TRANSITION
      #

      # The following rules match most binary and all unary operators.
      # Rules for binary operators provide better error reporting.
      operator_arithmetic '='    |
      operator_rest              |
      punctuation_end            |
      c_any
      => { p = @ts - 1; fgoto expr_end; };

      c_eof => do_eof;
  *|;

  # Special newline handling for "def a b:"
  #
  expr_labelarg := |*
    w_space_comment;

    w_newline
    => {
      if @context.in_kwarg
        fhold; fgoto expr_end;
      else
        fgoto line_begin;
      end
    };

    c_any
    => { fhold; fgoto expr_beg; };

    c_eof => do_eof;
  *|;

  # Like expr_beg, but no 1.9 label or 2.2 quoted label possible.
  #
  expr_value := |*
      # a:b: a(:b), a::B, A::B
      label (any - ':')
      => { p = @ts - 1
           fgoto expr_end; };

      # "bar", 'baz'
      ['"] # '
      => {
        @strings.push_literal(tok, tok, @ts)
        fgoto inside_string;
      };

      w_space_comment;

      w_newline
      => { fgoto line_begin; };

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
        emit(:tLAMBDA, '->'.freeze, @ts, @ts + 2)

        @lambda_stack.push @paren_nest
        fnext expr_endfn; fbreak;
      };

      e_lbrace | 'do'
      => {
        if @lambda_stack.last == @paren_nest
          @lambda_stack.pop

          if tok == '{'.freeze
            emit(:tLAMBEG, '{'.freeze)
          else # 'do'
            emit(:kDO_LAMBDA, 'do'.freeze)
          end
        else
          if tok == '{'.freeze
            emit(:tLCURLY, '{'.freeze)
          else # 'do'
            emit_do
          end
        end
        if tok == '{'.freeze
          @paren_nest += 1
        end
        @command_start = true

        fnext expr_value; fbreak;
      };

      #
      # KEYWORDS
      #

      keyword_with_fname
      => { emit_table(KEYWORDS)
           fnext expr_fname; fbreak; };

      'class' w_any* '<<'
      => { emit_singleton_class
           fnext expr_value; fbreak; };

      # a if b:c: Syntax error.
      keyword_modifier
      => { emit_table(KEYWORDS)
           fnext expr_beg; fbreak; };

      # elsif b:c: elsif b(:c)
      keyword_with_value
      => { emit_table(KEYWORDS)
           @command_start = true
           fnext expr_value; fbreak; };

      keyword_with_mid
      => { emit_table(KEYWORDS)
           fnext expr_mid; fbreak; };

      keyword_with_arg
      => {
        emit_table(KEYWORDS)

        if version?(18) && tok == 'not'.freeze
          fnext expr_beg; fbreak;
        else
          fnext expr_arg; fbreak;
        end
      };

      '__ENCODING__'
      => {
        if version?(18)
          emit(:tIDENTIFIER)

          unless !@static_env.nil? && @static_env.declared?(tok)
            fnext *arg_or_cmdarg(cmd_state);
          end
        else
          emit(:k__ENCODING__, '__ENCODING__'.freeze)
        end
        fbreak;
      };

      keyword_with_end
      => { emit_table(KEYWORDS)
           fbreak; };

      #
      # NUMERIC LITERALS
      #

      ( '0' [Xx] %{ @num_base = 16; @num_digits_s = p } int_hex
      | '0' [Dd] %{ @num_base = 10; @num_digits_s = p } int_dec
      | '0' [Oo] %{ @num_base = 8;  @num_digits_s = p } int_dec
      | '0' [Bb] %{ @num_base = 2;  @num_digits_s = p } int_bin
      | [1-9] digit* '_'? %{ @num_base = 10; @num_digits_s = @ts } int_dec
      | '0'   digit* '_'? %{ @num_base = 8;  @num_digits_s = @ts } int_dec
      ) %{ @num_suffix_s = p } int_suffix
      => {
        digits = numeric_literal_int

        if version?(18, 19, 20)
          emit(:tINTEGER, digits.to_i(@num_base), @ts, @num_suffix_s)
          p = @num_suffix_s - 1
        else
          p = @num_xfrm.call(digits.to_i(@num_base), p)
        end
        fbreak;
      };

      flo_frac flo_pow?
      => {
        diagnostic :error, :no_dot_digit_literal
      };

      flo_int [eE]
      => {
        if version?(18, 19, 20)
          diagnostic :error,
                     :trailing_in_number, { :character => tok(@te - 1, @te) },
                     range(@te - 1, @te)
        else
          emit(:tINTEGER, tok(@ts, @te - 1).to_i, @ts, @te - 1)
          fhold; fbreak;
        end
      };

      flo_int flo_frac [eE]
      => {
        if version?(18, 19, 20)
          diagnostic :error,
                     :trailing_in_number, { :character => tok(@te - 1, @te) },
                     range(@te - 1, @te)
        else
          emit(:tFLOAT, tok(@ts, @te - 1).to_f, @ts, @te - 1)
          fhold; fbreak;
        end
      };

      flo_int
      ( flo_frac? flo_pow %{ @num_suffix_s = p } flo_pow_suffix
      | flo_frac          %{ @num_suffix_s = p } flo_suffix
      )
      => {
        digits = tok(@ts, @num_suffix_s)

        if version?(18, 19, 20)
          emit(:tFLOAT, Float(digits), @ts, @num_suffix_s)
          p = @num_suffix_s - 1
        else
          p = @num_xfrm.call(digits, p)
        end
        fbreak;
      };

      #
      # STRING AND XSTRING LITERALS
      #

      # `echo foo`, "bar", 'baz'
      '`' | ['"] # '
      => {
        type, delimiter = tok, tok[-1].chr
        @strings.push_literal(type, delimiter, @ts, nil, false, false, true);
        fgoto inside_string;
      };

      #
      # CONSTANTS AND VARIABLES
      #

      constant
      => { emit(:tCONSTANT)
           fnext *arg_or_cmdarg(cmd_state); fbreak; };

      constant ambiguous_const_suffix
      => { emit(:tCONSTANT, tok(@ts, tm), @ts, tm)
           p = tm - 1; fbreak; };

      global_var | class_var_v | instance_var_v
      => { p = @ts - 1; fcall expr_variable; };

      #
      # METHOD CALLS
      #

      '.' | '&.' | '::'
      => { emit_table(PUNCTUATION)
           fnext expr_dot; fbreak; };

      call_or_var
      => local_ident;

      bareword ambiguous_fid_suffix
      => {
        if tm == @te
          # Suffix was consumed, e.g. foo!
          emit(:tFID)
        else
          # Suffix was not consumed, e.g. foo!=
          emit(:tIDENTIFIER, tok(@ts, tm), @ts, tm)
          p = tm - 1
        end
        fnext expr_arg; fbreak;
      };

      #
      # OPERATORS
      #

      '*' | '=>'
      => {
        emit_table(PUNCTUATION)
        fnext expr_value; fbreak;
      };

      # When '|', '~', '!', '=>' are used as operators
      # they do not accept any symbols (or quoted labels) after.
      # Other binary operators accept it.
      ( operator_arithmetic | operator_rest ) - ( '|' | '~' | '!' | '*' )
      => {
        emit_table(PUNCTUATION);
        fnext expr_value; fbreak;
      };

      ( e_lparen | '|' | '~' | '!' )
      => { emit_table(PUNCTUATION)
           fnext expr_beg; fbreak; };

      e_rbrace | e_rparen | e_rbrack
      => {
        emit_rbrace_rparen_rbrack

        if tok == '}'.freeze || tok == ']'.freeze
          if @version >= 25
            fnext expr_end;
          else
            fnext expr_endarg;
          end
        else # )
          # fnext expr_endfn; ?
        end

        fbreak;
      };

      operator_arithmetic '='
      => { emit(:tOP_ASGN, tok(@ts, @te - 1))
           fnext expr_beg; fbreak; };

      '?'
      => { emit(:tEH, '?'.freeze)
           fnext expr_value; fbreak; };

      e_lbrack
      => { emit(:tLBRACK2, '['.freeze)
           fnext expr_beg; fbreak; };

      '...' c_nl
      => {
        if @paren_nest == 0
          diagnostic :warning, :triple_dot_at_eol, nil, range(@ts, @te - 1)
        end

        emit(:tDOT3, '...'.freeze, @ts, @te - 1)
        fhold;
        fnext expr_beg; fbreak;
      };

      punctuation_end
      => { emit_table(PUNCTUATION)
           fnext expr_beg; fbreak; };

      #
      # WHITESPACE
      #

      w_space_comment;

      w_newline
      => { fgoto leading_dot; };

      ';'
      => { emit(:tSEMI, ';'.freeze)
           @command_start = true
           fnext expr_value; fbreak; };

      '\\' c_line {
        diagnostic :error, :bare_backslash, nil, range(@ts, @ts + 1)
        fhold;
      };

      c_any
      => {
        diagnostic :fatal, :unexpected, { :character => tok.inspect[1..-2] }
      };

      c_eof => do_eof;
  *|;

  leading_dot := |*
      # Insane leading dots:
      # a #comment
      #  # post-2.7 comment
      #  .b: a.b

      # Here we use '\n' instead of w_newline to not modify @newline_s
      # and eventually properly emit tNL
      (c_space* w_space_comment '\n')+
      => {
        if @version < 27
          # Ruby before 2.7 doesn't support comments before leading dot.
          # If a line after "a" starts with a comment then "a" is a self-contained statement.
          # So in that case we emit a special tNL token and start reading the
          # next line as a separate statement.
          #
          # Note: block comments before leading dot are not supported on any version of Ruby.
          emit(:tNL, nil, @newline_s, @newline_s + 1)
          fhold; fnext line_begin; fbreak;
        end
      };

      c_space* '..'
      => {
        emit(:tNL, nil, @newline_s, @newline_s + 1)
        if @version < 27
          fhold; fnext line_begin; fbreak;
        else
          emit(:tBDOT2)
          fnext expr_beg; fbreak;
        end
      };

      c_space* '...'
      => {
        emit(:tNL, nil, @newline_s, @newline_s + 1)
        if @version < 27
          fhold; fnext line_begin; fbreak;
        else
          emit(:tBDOT3)
          fnext expr_beg; fbreak;
        end
      };

      c_space* %{ tm = p } ('.' | '&.')
      => { p = tm - 1; fgoto expr_end; };

      any
      => { emit(:tNL, nil, @newline_s, @newline_s + 1)
           fhold; fnext line_begin; fbreak; };
  *|;

  #
  # === EMBEDDED DOCUMENT (aka BLOCK COMMENT) PARSING ===
  #

  line_comment := |*
      '=end' c_line* c_nl_zlen
      => {
        emit_comment(@eq_begin_s, @te)
        fgoto *@cs_before_block_comment;
      };

      c_line* c_nl;

      c_line* zlen
      => {
        diagnostic :fatal, :embedded_document, nil,
                   range(@eq_begin_s, @eq_begin_s + '=begin'.length)
      };
  *|;

  line_begin := |*
      w_any;

      '=begin' ( c_space | c_nl_zlen )
      => { @eq_begin_s = @ts
           fgoto line_comment; };

      '__END__' ( c_eol - zlen )
      => { p = pe - 3 };

      c_any
      => { cmd_state = true; fhold; fgoto expr_value; };

      c_eof => do_eof;
  *|;

  inside_string := |*
      any
      => {
        p, next_state = @strings.advance(p)

        fhold; # Ragel will do `p += 1` to consume input, prevent it
        fnext *next_state;
        fbreak;
      };
  *|;

  }%%
  # %
end
