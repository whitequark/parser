# encoding: utf-8
# frozen_string_literal: true

require 'helper'
require 'parse_helper'

Parser::Builders::Default.modernize

class TestParser < Minitest::Test
  include ParseHelper

  def parser_for_ruby_version(version)
    parser = super
    parser.diagnostics.all_errors_are_fatal = true

    %w(foo bar baz).each do |metasyntactic_var|
      parser.static_env.declare(metasyntactic_var)
    end

    parser
  end

  SINCE_1_9 = ALL_VERSIONS - %w(1.8)
  SINCE_2_0 = SINCE_1_9 - %w(1.9 mac ios)
  SINCE_2_1 = SINCE_2_0 - %w(2.0)
  SINCE_2_2 = SINCE_2_1 - %w(2.1)
  SINCE_2_3 = SINCE_2_2 - %w(2.2)
  SINCE_2_4 = SINCE_2_3 - %w(2.3)
  SINCE_2_5 = SINCE_2_4 - %w(2.4)
  SINCE_2_6 = SINCE_2_5 - %w(2.5)
  SINCE_2_7 = SINCE_2_6 - %w(2.6)
  SINCE_3_0 = SINCE_2_7 - %w(2.7)
  SINCE_3_1 = SINCE_3_0 - %w(3.0)
  SINCE_3_2 = SINCE_3_1 - %w(3.1)
  SINCE_3_3 = SINCE_3_2 - %w(3.2)
  SINCE_3_4 = SINCE_3_3 - %w(3.3)

  # Guidelines for test naming:
  #  * Test structure follows structure of AST_FORMAT.md.
  #  * Test names follow node names.
  #  * Structurally similar sources may be grouped into one test.
  #  * If, following the guidelines above, names clash, append
  #    an abbreviated disambiguator. E.g. `test_class` and
  #    `test_class_super`.
  #  * When writing a test for a bug, append unabbreviated (but
  #    concise) bug description. E.g. `test_class_bug_missing_newline`.
  #  * Do not append Ruby language version to the name.
  #  * When in doubt, look at existing test names.
  #
  # Guidelines for writing assertions:
  #  * Don't check for structurally same source mapping information
  #    more than once or twice in the entire file. It clutters the
  #    source for no reason.
  #  * Don't forget to check for optional delimiters. `()`, `then`, etc.
  #  * When in doubt, look at existing assertions.

  #
  # Literals
  #

  def test_empty_stmt
    assert_parses(
      nil,
      %q{})
  end

  def test_nil
    assert_parses(
      s(:nil),
      %q{nil},
      %q{~~~ expression})
  end

  def test_nil_expression
    assert_parses(
      s(:begin),
      %q{()},
      %q{^ begin
        | ^ end
        |~~ expression})

    assert_parses(
      s(:kwbegin),
      %q{begin end},
      %q{~~~~~ begin
        |      ~~~ end
        |~~~~~~~~~ expression})
  end

  def test_true
    assert_parses(
      s(:true),
      %q{true},
      %q{~~~~ expression})
  end

  def test_false
    assert_parses(
      s(:false),
      %q{false},
      %q{~~~~~ expression})
  end

  def test_int
    assert_parses(
      s(:int, 42),
      %q{42},
      %q{~~ expression})

    assert_parses(
      s(:int, 42),
      %q{+42},
      %q{^ operator
        |~~~ expression})

    assert_parses(
      s(:int, -42),
      %q{-42},
      %q{^ operator
        |~~~ expression})
  end

  def test_int___LINE__
    assert_parses(
      s(:int, 1),
      %q{__LINE__},
      %q{~~~~~~~~ expression})
  end

  def test_float
    assert_parses(
      s(:float, 1.33),
      %q{1.33},
      %q{~~~~ expression})

    assert_parses(
      s(:float, -1.33),
      %q{-1.33},
      %q{^ operator
        |~~~~~ expression})
  end

  def test_rational
    assert_parses(
      s(:rational, Rational(42)),
      %q{42r},
      %q{~~~ expression},
      SINCE_2_1)

    assert_parses(
      s(:rational, Rational(421, 10)),
      %q{42.1r},
      %q{~~~~~ expression},
      SINCE_2_1)
  end

  def test_complex
    assert_parses(
      s(:complex, Complex(0, 42)),
      %q{42i},
      %q{~~~ expression},
      SINCE_2_1)

    assert_parses(
      s(:complex, Complex(0, Rational(42))),
      %q{42ri},
      %q{~~~~ expression},
      SINCE_2_1)

    assert_parses(
      s(:complex, Complex(0, 42.1)),
      %q{42.1i},
      %q{~~~~~ expression},
      SINCE_2_1)

    assert_parses(
      s(:complex, Complex(0, Rational(421, 10))),
      %q{42.1ri},
      %q{~~~~~~ expression},
      SINCE_2_1)
  end

  # Strings

  def test_string_plain
    assert_parses(
      s(:str, 'foobar'),
      %q{'foobar'},
      %q{^ begin
        |       ^ end
        |~~~~~~~~ expression})

    assert_parses(
      s(:str, 'foobar'),
      %q{%q(foobar)},
      %q{^^^ begin
        |         ^ end
        |~~~~~~~~~~ expression})
  end

  def test_string_interp
    assert_parses(
      s(:dstr,
        s(:str, 'foo'),
        s(:begin, s(:lvar, :bar)),
        s(:str, 'baz')),
      %q{"foo#{bar}baz"},
      %q{^ begin
        |             ^ end
        |    ^^ begin (begin)
        |         ^ end (begin)
        |    ~~~~~~ expression (begin)
        |~~~~~~~~~~~~~~ expression})
  end

  def test_string_dvar
    assert_parses(
      s(:dstr,
        s(:ivar, :@a),
        s(:str, ' '),
        s(:cvar, :@@a),
        s(:str, ' '),
        s(:gvar, :$a)),
      %q{"#@a #@@a #$a"})
  end

  def test_string_concat
    assert_parses(
      s(:dstr,
        s(:dstr,
          s(:str, 'foo'),
          s(:ivar, :@a)),
        s(:str, 'bar')),
      %q{"foo#@a" "bar"},
      %q{^ begin (dstr)
        |       ^ end (dstr)
        |         ^ begin (str)
        |             ^ end (str)
        |~~~~~~~~~~~~~~ expression})
  end

  def test_string___FILE__
    assert_parses(
      s(:str, '(assert_parses)'),
      %q{__FILE__},
      %q{~~~~~~~~ expression})
  end

  def test_character
    assert_parses(
      s(:str, 'a'),
      %q{?a},
      %q{^ begin
        |~~ expression},
      SINCE_1_9)

    assert_parses(
      s(:int, 97),
      %q{?a},
      %q{~~ expression},
      %w(1.8))
  end

  def test_heredoc
    assert_parses(
      s(:dstr, s(:str, "foo\n"), s(:str, "bar\n")),
      %Q{<<HERE!foo!bar!HERE}.gsub('!', "\n"),
      %q{~~~~~~ expression
        |       ~~~~~~~~ heredoc_body
        |               ~~~~ heredoc_end})

    assert_parses(
      s(:dstr, s(:str, "foo\n"), s(:str, "bar\n")),
      %Q{<<'HERE'!foo!bar!HERE}.gsub('!', "\n"),
      %q{~~~~~~~~ expression
        |         ~~~~~~~~ heredoc_body
        |                 ~~~~ heredoc_end})

    assert_parses(
      s(:xstr, s(:str, "foo\n"), s(:str, "bar\n")),
      %Q{<<`HERE`!foo!bar!HERE}.gsub('!', "\n"),
      %q{~~~~~~~~ expression
        |         ~~~~~~~~ heredoc_body
        |                 ~~~~ heredoc_end})
  end

  def test_dedenting_heredoc
    assert_parses(
      s(:begin,
        s(:send,
          s(:send, nil, :p), :<<,
          s(:send,
            s(:const, nil, :E), :~)),
        s(:const, nil, :E)),
      %Q{p <<~E\nE},
      %q{},
      %w(1.8 1.9 2.0 2.1 2.2 ios mac))

    assert_parses(
      s(:send, nil, :p,
        s(:dstr)),
      %Q{p <<~E\nE},
      %q{},
      SINCE_2_3)

    assert_parses(
      s(:send, nil, :p,
        s(:dstr)),
      %Q{p <<~E\n  E},
      %q{},
      SINCE_2_3)

    assert_parses(
      s(:send, nil, :p,
        s(:str, "x\n")),
      %Q{p <<~E\n  x\nE},
      %q{},
      SINCE_2_3)

    assert_parses(
      s(:send, nil, :p,
        s(:str, "ð\n")),
      %Q{p <<~E\n  ð\nE},
      %q{},
      SINCE_2_3)

    assert_parses(
      s(:send, nil, :p,
        s(:dstr,
          s(:str, "x\n"),
          s(:str, "  y\n"))),
      %Q{p <<~E\n  x\n    y\nE},
      %q{},
      SINCE_2_3)

    assert_parses(
      s(:send, nil, :p,
        s(:dstr,
          s(:str, "\tx\n"),
          s(:str, "y\n"))),
      %Q{p <<~E\n\tx\n    y\nE},
      %q{},
      SINCE_2_3)

    assert_parses(
      s(:send, nil, :p,
        s(:dstr,
          s(:str, "x\n"),
          s(:str, "y\n"))),
      %Q{p <<~E\n\tx\n        y\nE},
      %q{},
      SINCE_2_3)

    assert_parses(
      s(:send, nil, :p,
        s(:dstr,
          s(:str, "x\n"),
          s(:str, "y\n"))),
      %Q{p <<~E\n    \tx\n        y\nE},
      %q{},
      SINCE_2_3)

    assert_parses(
      s(:send, nil, :p,
        s(:dstr,
          s(:str, "\tx\n"),
          s(:str, "y\n"))),
      %Q{p <<~E\n        \tx\n\ty\nE},
      %q{},
      SINCE_2_3)

    assert_parses(
      s(:send, nil, :p,
        s(:dstr,
          s(:str, "  x\n"),
          s(:str, "\n"),
          s(:str, "y\n"))),
      %Q{p <<~E\n  x\n\ny\nE},
      %q{},
      SINCE_2_3)

    assert_parses(
      s(:send, nil, :p,
        s(:dstr,
          s(:str, "x\n"),
          s(:str, "  \n"),
          s(:str, "y\n"))),
      %Q{p <<~E\n  x\n    \n  y\nE},
      %q{},
      SINCE_2_3)

    assert_parses(
      s(:send, nil, :p,
        s(:dstr,
          s(:str, "  x\n"),
          s(:str, "  y\n"))),
      %Q{p <<~E\n    x\n  \\  y\nE},
      %q{},
      SINCE_2_3)

    assert_parses(
      s(:send, nil, :p,
        s(:dstr,
          s(:str, "  x\n"),
          s(:str, "\ty\n"))),
      %Q{p <<~E\n    x\n  \\\ty\nE},
      %q{},
      SINCE_2_3)

    assert_parses(
      s(:send, nil, :p,
        s(:dstr,
          s(:str, "  x\n"),
          s(:begin,
            s(:lvar, :foo)),
          s(:str, "\n"))),
      %Q{p <<~"E"\n    x\n  \#{foo}\nE},
      %q{},
      SINCE_2_3)

    assert_parses(
      s(:send, nil, :p,
        s(:xstr,
          s(:str, "  x\n"),
          s(:begin,
            s(:lvar, :foo)),
          s(:str, "\n"))),
      %Q{p <<~`E`\n    x\n  \#{foo}\nE},
      %q{},
      SINCE_2_3)

    assert_parses(
      s(:send, nil, :p,
        s(:dstr,
          s(:str, "  x\n"),
          s(:begin,
            s(:str, "  y")),
          s(:str, "\n"))),
      %Q{p <<~"E"\n    x\n  \#{"  y"}\nE},
      %q{},
      SINCE_2_3)
  end

  def test_parser_bug_640
    assert_parses(
      s(:str, "bazqux\n"),
      %Q{<<~FOO\n  baz\\\n  qux\nFOO},
      %q{},
      SINCE_2_3)
  end

  def test_dedenting_non_interpolating_heredoc_line_continuation
    assert_parses(
      s(:dstr, s(:str, "baz\\\n"), s(:str, "qux\n")),
      %Q{<<~'FOO'\n  baz\\\n  qux\nFOO},
      %q{},
      SINCE_2_3)
  end

  def test_dedenting_interpolating_heredoc_fake_line_continuation
    assert_parses(
      s(:dstr, s(:str, "baz\\\n"), s(:str, "qux\n")),
      %Q{<<~'FOO'\n  baz\\\\\n  qux\nFOO},
      %q{},
      SINCE_2_3)
  end

  # Symbols

  def test_symbol_plain
    assert_parses(
      s(:sym, :foo),
      %q{:foo},
      %q{~ begin
        |~~~~ expression})

    assert_parses(
      s(:sym, :foo),
      %q{:'foo'},
      %q{^^ begin
        |     ^ end
        |~~~~~~ expression})
  end

  def test_symbol_interp
    assert_parses(
      s(:dsym,
        s(:str, 'foo'),
        s(:begin, s(:lvar, :bar)),
        s(:str, 'baz')),
      %q{:"foo#{bar}baz"},
      %q{^^ begin
        |              ^ end
        |     ^^ begin (begin)
        |          ^ end (begin)
        |     ~~~~~~ expression (begin)
        |~~~~~~~~~~~~~~~ expression})
  end

  def test_symbol_empty
    assert_diagnoses(
      [:error, :empty_symbol],
      %q{:''},
      %q{^^^ location},
      %w(1.8))

    assert_diagnoses(
      [:error, :empty_symbol],
      %q{:""},
      %q{^^^ location},
      %w(1.8))
  end

  # Execute-strings

  def test_xstring_plain
    assert_parses(
      s(:xstr, s(:str, 'foobar')),
      %q{`foobar`},
      %q{^ begin
        |       ^ end
        |~~~~~~~~ expression})
  end

  def test_xstring_interp
    assert_parses(
      s(:xstr,
        s(:str, 'foo'),
        s(:begin, s(:lvar, :bar)),
        s(:str, 'baz')),
      %q{`foo#{bar}baz`},
      %q{^ begin
        |             ^ end
        |    ^^ begin (begin)
        |         ^ end (begin)
        |    ~~~~~~ expression (begin)
        |~~~~~~~~~~~~~~ expression})
  end

  # Regexp

  def test_regex_plain
    assert_parses(
      s(:regexp, s(:str, 'source'), s(:regopt, :i, :m)),
      %q{/source/im},
      %q{^ begin
        |       ^ end
        |        ~~ expression (regopt)
        |~~~~~~~~~~ expression})
  end

  def test_regex_interp
    assert_parses(
      s(:regexp,
        s(:str, 'foo'),
        s(:begin, s(:lvar, :bar)),
        s(:str, 'baz'),
        s(:regopt)),
      %q{/foo#{bar}baz/},
      %q{^ begin
        |    ^^ begin (begin)
        |         ^ end (begin)
        |    ~~~~~~ expression (begin)
        |             ^ end
        |~~~~~~~~~~~~~~ expression})
  end

  def test_regex_error
    begin
      Regexp.new("?")
    rescue RegexpError => e
      message = e.message
    end

    assert_diagnoses(
      [:error, :invalid_regexp, {:message => message}],
      %q[/?/],
      %q(~~~ location),
      SINCE_1_9)

    assert_diagnoses(
      [:error, :invalid_regexp, {:message => message}],
      %q[/#{""}?/],
      %q(~~~~~~~~ location),
      SINCE_1_9)
  end

  def test_regexp_error_invalid_encoding_conversion
    message = if defined?(JRUBY_VERSION)
      '"\\xE3\\x81\\x82" from UTF-8 to ASCII-8BIT'
    else
      'U+3042 from UTF-8 to ASCII-8BIT'
    end
    assert_diagnoses(
      [:error, :invalid_regexp, { message: message }],
      %q[/あ/n],
      %q(~~~ location))
  end

  # Arrays

  def test_array_plain
    assert_parses(
      s(:array, s(:int, 1), s(:int, 2)),
      %q{[1, 2]},
      %q{^ begin
        |     ^ end
        |~~~~~~ expression})
  end

  def test_array_splat
    assert_parses(
      s(:array,
        s(:int, 1),
        s(:splat, s(:lvar, :foo)),
        s(:int, 2)),
      %q{[1, *foo, 2]},
      %q{^ begin
        |           ^ end
        |    ^ operator (splat)
        |    ~~~~ expression (splat)
        |~~~~~~~~~~~~ expression},
      SINCE_1_9)

    assert_parses(
      s(:array,
        s(:int, 1),
        s(:splat, s(:lvar, :foo))),
      %q{[1, *foo]},
      %q{^ begin
        |        ^ end
        |    ^ operator (splat)
        |    ~~~~ expression (splat)
        |~~~~~~~~~ expression})

    assert_parses(
      s(:array,
        s(:splat, s(:lvar, :foo))),
      %q{[*foo]})
  end

  def test_array_assocs
    assert_parses(
      s(:array,
        s(:hash, s(:pair, s(:int, 1), s(:int, 2)))),
      %q{[ 1 => 2 ]},
      %q{    ~~ operator (hash.pair)
        |  ~~~~~~ expression (hash.pair)
        |  ~~~~~~ expression (hash)})

    assert_parses(
      s(:array,
        s(:int, 1),
        s(:hash, s(:pair, s(:int, 2), s(:int, 3)))),
      %q{[ 1, 2 => 3 ]},
      %q{},
      SINCE_1_9)
  end

  def test_array_words
    assert_parses(
      s(:array, s(:str, 'foo'), s(:str, 'bar')),
      %q{%w[foo bar]},
      %q{^^^ begin
        |          ^ end
        |   ~~~ expression (str)
        |~~~~~~~~~~~ expression})
  end

  def test_array_words_interp
    assert_parses(
      s(:array,
        s(:str, 'foo'),
        s(:dstr, s(:begin, s(:lvar, :bar)))),
      %q{%W[foo #{bar}]},
      %q{^^^ begin
        |       ^^ begin (dstr.begin)
        |            ^ end (dstr.begin)
        |       ~~~~~~ expression (dstr.begin)
        |             ^ end
        |   ~~~ expression (str)
        |         ~~~ expression (dstr.begin.lvar)
        |~~~~~~~~~~~~~~ expression})

    assert_parses(
      s(:array,
        s(:str, 'foo'),
        s(:dstr,
          s(:begin, s(:lvar, :bar)),
          s(:str, 'foo'),
          s(:ivar, :@baz))),
      %q{%W[foo #{bar}foo#@baz]})
  end

  def test_array_words_empty
    assert_parses(
      s(:array),
      %q{%w[]},
      %q{^^^ begin
        |   ^ end
        |~~~~ expression})

    assert_parses(
      s(:array),
      %q{%W()})
  end

  def test_array_symbols
    assert_parses(
      s(:array, s(:sym, :foo), s(:sym, :bar)),
      %q{%i[foo bar]},
      %q{^^^ begin
        |          ^ end
        |   ~~~ expression (sym)
        |~~~~~~~~~~~ expression},
      SINCE_2_0)
  end

  def test_array_symbols_interp
    assert_parses(
      s(:array,
        s(:sym, :foo),
        s(:dsym, s(:begin, s(:lvar, :bar)))),
      %q{%I[foo #{bar}]},
      %q{^^^ begin
        |             ^ end
        |   ~~~ expression (sym)
        |       ^^ begin (dsym.begin)
        |            ^ end (dsym.begin)
        |       ~~~~~~ expression (dsym.begin)
        |         ~~~ expression (dsym.begin.lvar)
        |~~~~~~~~~~~~~~ expression},
      SINCE_2_0)

    assert_parses(
      s(:array,
        s(:dsym,
          s(:str, 'foo'),
          s(:begin, s(:lvar, :bar)))),
      %q{%I[foo#{bar}]},
      %q{},
      SINCE_2_0)
  end

  def test_array_symbols_empty
    assert_parses(
      s(:array),
      %q{%i[]},
      %q{^^^ begin
        |   ^ end
        |~~~~ expression},
      SINCE_2_0)

    assert_parses(
      s(:array),
      %q{%I()},
      %q{},
      SINCE_2_0)
  end

  # Hashes

  def test_hash_empty
    assert_parses(
      s(:hash),
      %q[{ }],
      %q{^ begin
        |  ^ end
        |~~~ expression})
  end

  def test_hash_hashrocket
    assert_parses(
      s(:hash, s(:pair, s(:int, 1), s(:int, 2))),
      %q[{ 1 => 2 }],
      %q{^ begin
        |         ^ end
        |    ^^ operator (pair)
        |  ~~~~~~ expression (pair)
        |~~~~~~~~~~ expression})

    assert_parses(
      s(:hash,
        s(:pair, s(:int, 1), s(:int, 2)),
        s(:pair, s(:sym, :foo), s(:str, 'bar'))),
      %q[{ 1 => 2, :foo => "bar" }])
  end

  def test_hash_label
    assert_parses(
      s(:hash, s(:pair, s(:sym, :foo), s(:int, 2))),
      %q[{ foo: 2 }],
      %q{^ begin
        |         ^ end
        |     ^ operator (pair)
        |  ~~~ expression (pair.sym)
        |  ~~~~~~ expression (pair)
        |~~~~~~~~~~ expression},
      SINCE_1_9)
  end

  def test_hash_label_end
    assert_parses(
      s(:hash, s(:pair, s(:sym, :foo), s(:int, 2))),
      %q[{ 'foo': 2 }],
      %q{^ begin
        |           ^ end
        |       ^ operator (pair)
        |  ^ begin (pair.sym)
        |      ^ end (pair.sym)
        |  ~~~~~ expression (pair.sym)
        |  ~~~~~~~~ expression (pair)
        |~~~~~~~~~~~~ expression},
      SINCE_2_2)

    assert_parses(
      s(:hash,
        s(:pair, s(:sym, :foo), s(:int, 2)),
        s(:pair, s(:sym, :bar), s(:hash))),
      %q[{ 'foo': 2, 'bar': {}}],
      %q{},
      SINCE_2_2)

    assert_parses(
      s(:send, nil, :f,
        s(:if, s(:send, nil, :a),
          s(:str, "a"),
          s(:int, 1))),
      %q{f(a ? "a":1)},
      %q{},
      SINCE_2_2)
  end

  def test_hash_kwsplat
    assert_parses(
      s(:hash,
        s(:pair, s(:sym, :foo), s(:int, 2)),
        s(:kwsplat, s(:lvar, :bar))),
      %q[{ foo: 2, **bar }],
      %q{          ^^ operator (kwsplat)
        |          ~~~~~ expression (kwsplat)},
      SINCE_2_0)
  end

  def test_hash_no_hashrocket
    assert_parses(
      s(:hash, s(:pair, s(:int, 1), s(:int, 2))),
      %q[{ 1, 2 }],
      %q{^ begin
        |       ^ end
        |  ~~~~ expression (pair)
        |~~~~~~~~ expression},
      %w(1.8))
  end

  def test_hash_no_hashrocket_odd
    assert_diagnoses(
      [:error, :odd_hash],
      %q[{ 1, 2, 3 }],
      %q(        ~ location),
      %w(1.8))
  end

  # Range

  def test_range_inclusive
    assert_parses(
      s(:irange, s(:int, 1), s(:int, 2)),
      %q{1..2},
      %q{ ~~ operator
        |~~~~ expression})
  end

  def test_range_exclusive
    assert_parses(
      s(:erange, s(:int, 1), s(:int, 2)),
      %q{1...2},
      %q{ ~~~ operator
        |~~~~~ expression})
  end

  def test_range_endless
    assert_parses(
      s(:irange,
        s(:int, 1), nil),
      %q{1..},
      %q{~~~ expression
        | ~~ operator},
      SINCE_2_6)

    assert_parses(
      s(:erange,
        s(:int, 1), nil),
      %q{1...},
      %q{~~~~ expression
        | ~~~ operator},
      SINCE_2_6)
  end

  def test_beginless_range_before_27
    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tDOT2' }],
      %q{..42},
      %q{^^ location},
      ALL_VERSIONS - SINCE_2_7
    )

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tDOT3' }],
      %q{...42},
      %q{^^^ location},
      ALL_VERSIONS - SINCE_2_7
    )
  end

  def test_beginless_range
    assert_parses(
      s(:irange, nil,
        s(:int, 100)),
      %q{..100},
      %q{~~~~~ expression
        |~~ operator},
      SINCE_2_7
    )

    assert_parses(
      s(:erange, nil,
        s(:int, 100)),
      %q{...100},
      %q{~~~~~~ expression
        |~~~ operator},
      SINCE_2_7
    )
  end

  def test_beginless_irange_after_newline
    assert_parses(
      s(:begin,
        s(:lvar, :foo),
        s(:irange, nil,
          s(:int, 100))),
      %Q{foo\n..100},
      %q{},
      SINCE_2_7
    )
  end

  def test_beginless_erange_after_newline
    assert_parses(
      s(:begin,
        s(:lvar, :foo),
        s(:erange, nil,
          s(:int, 100))),
      %Q{foo\n...100},
      %q{},
      SINCE_2_7
    )
  end
  #
  # Access
  #

  # Variables and pseudovariables

  def test_self
    assert_parses(
      s(:self),
      %q{self},
      %q{~~~~ expression})
  end

  def test_lvar
    assert_parses(
      s(:lvar, :foo),
      %q{foo},
      %q{~~~ expression})
  end

  def test_ivar
    assert_parses(
      s(:ivar, :@foo),
      %q{@foo},
      %q{~~~~ expression})
  end

  def test_cvar
    assert_parses(
      s(:cvar, :@@foo),
      %q{@@foo},
      %q{~~~~~ expression})
  end

  def test_gvar
    assert_parses(
      s(:gvar, :$foo),
      %q{$foo},
      %q{~~~~ expression})
  end

  def test_gvar_dash_empty
    assert_diagnoses(
      [:fatal, :unexpected, { :character => '$' }],
      %q{$- },
      %q{^ location},
      %w(2.1))
  end

  def test_back_ref
    assert_parses(
      s(:back_ref, :$+),
      %q{$+},
      %q{~~ expression})
  end

  def test_nth_ref
    assert_parses(
      s(:nth_ref, 10),
      %q{$10},
      %q{~~~ expression})
  end

  # Constants

  def test_const_toplevel
    assert_parses(
      s(:const, s(:cbase), :Foo),
      %q{::Foo},
      %q{  ~~~ name
        |~~ double_colon
        |~~~~~ expression})
  end

  def test_const_scoped
    assert_parses(
      s(:const, s(:const, nil, :Bar), :Foo),
      %q{Bar::Foo},
      %q{     ~~~ name
        |   ~~ double_colon
        |~~~~~~~~ expression})
  end

  def test_const_unscoped
    assert_parses(
      s(:const, nil, :Foo),
      %q{Foo},
      %q{~~~ name
        |~~~ expression})
  end

  def test___ENCODING__
    assert_parses(
      s(:__ENCODING__),
      %q{__ENCODING__},
      %q{~~~~~~~~~~~~ expression},
      SINCE_1_9)
  end

  def test___ENCODING___legacy_
    Parser::Builders::Default.emit_encoding = false
    assert_parses(
      s(:const, s(:const, nil, :Encoding), :UTF_8),
      %q{__ENCODING__},
      %q{~~~~~~~~~~~~ expression},
      SINCE_1_9)
  ensure
    Parser::Builders::Default.emit_encoding = true
  end

  # defined?

  def test_defined
    assert_parses(
      s(:defined?, s(:lvar, :foo)),
      %q{defined? foo},
      %q{~~~~~~~~ keyword
        |~~~~~~~~~~~~ expression})

    assert_parses(
      s(:defined?, s(:lvar, :foo)),
      %q{defined?(foo)},
      %q{~~~~~~~~ keyword
        |        ^ begin
        |            ^ end
        |~~~~~~~~~~~~~ expression})

    assert_parses(
      s(:defined?, s(:ivar, :@foo)),
      %q{defined? @foo})
  end

  #
  # Assignment
  #

  # Variables

  def test_lvasgn
    assert_parses(
      s(:begin,
        s(:lvasgn, :var, s(:int, 10)),
        s(:lvar, :var)),
      %q{var = 10; var},
      %q{~~~ name (lvasgn)
        |    ^ operator (lvasgn)
        |~~~~~~~~ expression (lvasgn)
        })
  end

  def test_ivasgn
    assert_parses(
      s(:ivasgn, :@var, s(:int, 10)),
      %q{@var = 10},
      %q{~~~~ name
        |     ^ operator
        |~~~~~~~~~ expression
        })
  end

  def test_cvasgn
    assert_parses(
      s(:cvasgn, :@@var, s(:int, 10)),
      %q{@@var = 10},
      %q{~~~~~ name
        |      ^ operator
        |~~~~~~~~~~ expression
        })
  end

  def test_gvasgn
    assert_parses(
      s(:gvasgn, :$var, s(:int, 10)),
      %q{$var = 10},
      %q{~~~~ name
        |     ^ operator
        |~~~~~~~~~ expression
        })
  end

  def test_asgn_cmd
    assert_parses(
      s(:lvasgn, :foo, s(:send, nil, :m, s(:lvar, :foo))),
      %q{foo = m foo})

    assert_parses(
      s(:lvasgn, :foo,
        s(:lvasgn, :bar,
          s(:send, nil, :m, s(:lvar, :foo)))),
      %q{foo = bar = m foo},
      %q{},
      ALL_VERSIONS - %w(1.8 mac ios))
  end

  def test_asgn_keyword_invalid
    assert_diagnoses(
      [:error, :invalid_assignment],
      %q{nil = foo},
      %q{~~~ location})

    assert_diagnoses(
      [:error, :invalid_assignment],
      %q{self = foo},
      %q{~~~~ location})

    assert_diagnoses(
      [:error, :invalid_assignment],
      %q{true = foo},
      %q{~~~~ location})

    assert_diagnoses(
      [:error, :invalid_assignment],
      %q{false = foo},
      %q{~~~~~ location})

    assert_diagnoses(
      [:error, :invalid_assignment],
      %q{__FILE__ = foo},
      %q{~~~~~~~~ location})

    assert_diagnoses(
      [:error, :invalid_assignment],
      %q{__LINE__ = foo},
      %q{~~~~~~~~ location})
  end

  def test_asgn_backref_invalid
    assert_diagnoses(
      [:error, :backref_assignment],
      %q{$1 = foo},
      %q{~~ location})
  end

  # Constants

  def test_casgn_toplevel
    assert_parses(
      s(:casgn, s(:cbase), :Foo, s(:int, 10)),
      %q{::Foo = 10},
      %q{  ~~~ name
        |      ^ operator
        |~~ double_colon
        |~~~~~~~~~~ expression
        })
  end

  def test_casgn_scoped
    assert_parses(
      s(:casgn, s(:const, nil, :Bar), :Foo, s(:int, 10)),
      %q{Bar::Foo = 10},
      %q{     ~~~ name
        |         ^ operator
        |   ~~ double_colon
        |~~~~~~~~~~~~~ expression
        })
  end

  def test_casgn_unscoped
    assert_parses(
      s(:casgn, nil, :Foo, s(:int, 10)),
      %q{Foo = 10},
      %q{~~~ name
        |    ^ operator
        |~~~~~~~~ expression
        })
  end

  def test_casgn_invalid
    assert_diagnoses(
      [:error, :dynamic_const],
      %q{def f; Foo = 1; end},
      %q{       ~~~ location})

    assert_diagnoses(
      [:error, :dynamic_const],
      %q{def f; Foo::Bar = 1; end},
      %q{       ~~~~~~~~ location})

    assert_diagnoses(
      [:error, :dynamic_const],
      %q{def f; ::Bar = 1; end},
      %q{       ~~~~~ location})

    assert_diagnoses(
      [:error, :dynamic_const],
      %q{def self.f; Foo = 1; end},
      %q{            ~~~ location})

    assert_diagnoses(
      [:error, :dynamic_const],
      %q{def self.f; Foo::Bar = 1; end},
      %q{            ~~~~~~~~ location})

    assert_diagnoses(
      [:error, :dynamic_const],
      %q{def self.f; ::Bar = 1; end},
      %q{            ~~~~~ location})
  end

  # Multiple assignment

  def test_masgn
    assert_parses(
      s(:masgn,
        s(:mlhs, s(:lvasgn, :foo), s(:lvasgn, :bar)),
        s(:array, s(:int, 1), s(:int, 2))),
      %q{foo, bar = 1, 2},
      %q{         ^ operator
        |~~~~~~~~ expression (mlhs)
        |           ~~~~ expression (array)
        |~~~~~~~~~~~~~~~ expression
        })

    assert_parses(
      s(:masgn,
        s(:mlhs, s(:lvasgn, :foo), s(:lvasgn, :bar)),
        s(:array, s(:int, 1), s(:int, 2))),
      %q{(foo, bar) = 1, 2},
      %q{^ begin (mlhs)
        |         ^ end (mlhs)
        |~~~~~~~~~~ expression (mlhs)
        |~~~~~~~~~~~~~~~~~ expression})

    assert_parses(
      s(:masgn,
        s(:mlhs,
          s(:lvasgn, :foo),
          s(:lvasgn, :bar),
          s(:lvasgn, :baz)),
        s(:array, s(:int, 1), s(:int, 2))),
      %q{foo, bar, baz = 1, 2})
  end

  def test_masgn_splat
    assert_parses(
      s(:masgn,
        s(:mlhs, s(:ivasgn, :@foo), s(:cvasgn, :@@bar)),
        s(:array, s(:splat, s(:lvar, :foo)))),
      %q{@foo, @@bar = *foo},
      %q{              ^ operator (array.splat)
        |              ~~~~ expression (array.splat)
        })

    assert_parses(
      s(:masgn,
        s(:mlhs, s(:lvasgn, :a), s(:lvasgn, :b)),
        s(:array, s(:splat, s(:lvar, :foo)), s(:lvar, :bar))),
      %q{a, b = *foo, bar},
      %q{},
      SINCE_1_9)

    assert_parses(
      s(:masgn,
        s(:mlhs, s(:lvasgn, :a), s(:splat, s(:lvasgn, :b))),
        s(:lvar, :bar)),
      %q{a, *b = bar})

    assert_parses(
      s(:masgn,
        s(:mlhs,
          s(:lvasgn, :a),
          s(:splat, s(:lvasgn, :b)),
          s(:lvasgn, :c)),
        s(:lvar, :bar)),
      %q{a, *b, c = bar},
      %q{},
      SINCE_1_9)

    assert_parses(
      s(:masgn,
        s(:mlhs, s(:lvasgn, :a), s(:splat)),
        s(:lvar, :bar)),
      %q{a, * = bar})

    assert_parses(
      s(:masgn,
        s(:mlhs,
          s(:lvasgn, :a),
          s(:splat),
          s(:lvasgn, :c)),
        s(:lvar, :bar)),
      %q{a, *, c = bar},
      %q{},
      SINCE_1_9)

    assert_parses(
      s(:masgn,
        s(:mlhs, s(:splat, s(:lvasgn, :b))),
        s(:lvar, :bar)),
      %q{*b = bar})

    assert_parses(
      s(:masgn,
        s(:mlhs,
          s(:splat, s(:lvasgn, :b)),
          s(:lvasgn, :c)),
        s(:lvar, :bar)),
      %q{*b, c = bar},
      %q{},
      SINCE_1_9)

    assert_parses(
      s(:masgn,
        s(:mlhs, s(:splat)),
        s(:lvar, :bar)),
      %q{* = bar})

    assert_parses(
      s(:masgn,
        s(:mlhs,
          s(:splat),
          s(:lvasgn, :c),
          s(:lvasgn, :d)),
        s(:lvar, :bar)),
      %q{*, c, d = bar},
      %q{},
      SINCE_1_9)
  end

  def test_masgn_nested
    assert_parses(
      s(:masgn,
        s(:mlhs,
          s(:lvasgn, :a),
          s(:mlhs,
            s(:lvasgn, :b),
            s(:lvasgn, :c))),
        s(:lvar, :foo)),
      %q{a, (b, c) = foo},
      %q{   ^ begin (mlhs.mlhs)
        |        ^ end (mlhs.mlhs)
        |   ~~~~~~ expression (mlhs.mlhs)
        })

    assert_parses(
      s(:masgn,
        s(:mlhs,
          s(:lvasgn, :b)),
        s(:lvar, :foo)),
      %q{((b, )) = foo},
      %q{^ begin (mlhs)
        |      ^ end (mlhs)})
  end

  def test_masgn_attr
    assert_parses(
      s(:masgn,
        s(:mlhs,
          s(:send, s(:self), :a=),
          s(:indexasgn, s(:self), s(:int, 1), s(:int, 2))),
        s(:lvar, :foo)),
      %q{self.a, self[1, 2] = foo},
      %q{~~~~~~ expression (mlhs.send)
        |     ~ selector (mlhs.send)
        |            ^ begin (mlhs.indexasgn)
        |                 ^ end (mlhs.indexasgn)
        |        ~~~~~~~~~~ expression (mlhs.indexasgn)})

    assert_parses(
      s(:masgn,
        s(:mlhs,
          s(:send, s(:self), :a=),
          s(:lvasgn, :foo)),
        s(:lvar, :foo)),
      %q{self::a, foo = foo})

    assert_parses(
      s(:masgn,
        s(:mlhs,
          s(:send, s(:self), :A=),
          s(:lvasgn, :foo)),
        s(:lvar, :foo)),
      %q{self.A, foo = foo})
  end

  def test_masgn_const
    assert_parses(
      s(:masgn,
        s(:mlhs,
          s(:casgn, s(:self), :A),
          s(:lvasgn, :foo)),
        s(:lvar, :foo)),
      %q{self::A, foo = foo})

    assert_parses(
      s(:masgn,
        s(:mlhs,
          s(:casgn, s(:cbase), :A),
          s(:lvasgn, :foo)),
        s(:lvar, :foo)),
      %q{::A, foo = foo})
  end

  def test_masgn_cmd
    assert_parses(
      s(:masgn,
        s(:mlhs,
          s(:lvasgn, :foo),
          s(:lvasgn, :bar)),
        s(:send, nil, :m, s(:lvar, :foo))),
      %q{foo, bar = m foo})
  end

  def test_asgn_mrhs
    assert_parses(
      s(:lvasgn, :foo,
        s(:array, s(:lvar, :bar), s(:int, 1))),
      %q{foo = bar, 1},
      %q{      ~~~~~~ expression (array)
        |~~~~~~~~~~~~ expression})

    assert_parses(
      s(:lvasgn, :foo,
        s(:array, s(:splat, s(:lvar, :bar)))),
      %q{foo = *bar})

    assert_parses(
      s(:lvasgn, :foo,
        s(:array,
          s(:lvar, :baz),
          s(:splat, s(:lvar, :bar)))),
      %q{foo = baz, *bar})
  end

  def test_masgn_keyword_invalid
    assert_diagnoses(
      [:error, :invalid_assignment],
      %q{nil, foo = bar},
      %q{~~~ location})
  end

  def test_masgn_backref_invalid
    assert_diagnoses(
      [:error, :backref_assignment],
      %q{$1, = foo},
      %q{~~ location})
  end

  def test_masgn_const_invalid
    assert_diagnoses(
      [:error, :dynamic_const],
      %q{def f; self::A, foo = foo; end},
      %q{       ~~~~~~~ location})

    assert_diagnoses(
      [:error, :dynamic_const],
      %q{def f; ::A, foo = foo; end},
      %q{       ~~~ location})
  end

  # Variable binary operator-assignment

  def test_var_op_asgn
    assert_parses(
      s(:op_asgn, s(:lvasgn, :a), :+, s(:int, 1)),
      %q{a += 1},
      %q{  ^^ operator
        |~~~~~~ expression})

    assert_parses(
      s(:op_asgn, s(:ivasgn, :@a), :|, s(:int, 1)),
      %q{@a |= 1},
      %q{   ^^ operator
        |~~~~~~~ expression})

    assert_parses(
      s(:op_asgn, s(:cvasgn, :@@var), :|, s(:int, 10)),
      %q{@@var |= 10})

    assert_parses(
      s(:def, :a, s(:args),
        s(:op_asgn, s(:cvasgn, :@@var), :|, s(:int, 10))),
      %q{def a; @@var |= 10; end})
  end

  def test_var_op_asgn_cmd
    assert_parses(
      s(:op_asgn,
        s(:lvasgn, :foo), :+,
        s(:send, nil, :m, s(:lvar, :foo))),
      %q{foo += m foo})
  end

  def test_var_op_asgn_keyword_invalid
    assert_diagnoses(
      [:error, :invalid_assignment],
      %q{nil += foo},
      %q{~~~ location})
  end

  def test_const_op_asgn
    assert_parses(
      s(:op_asgn,
        s(:casgn, nil, :A), :+,
        s(:int, 1)),
      %q{A += 1})

    assert_parses(
      s(:op_asgn,
        s(:casgn, s(:cbase), :A), :+,
        s(:int, 1)),
      %q{::A += 1},
      %q{},
      SINCE_2_0)

    assert_parses(
      s(:op_asgn,
        s(:casgn, s(:const, nil, :B), :A), :+,
        s(:int, 1)),
      %q{B::A += 1},
      %q{},
      SINCE_2_0)

    assert_parses(
      s(:def, :x, s(:args),
        s(:or_asgn,
          s(:casgn, s(:self), :A),
          s(:int, 1))),
      %q{def x; self::A ||= 1; end},
      %q{},
      SINCE_2_0)

    assert_parses(
      s(:def, :x, s(:args),
        s(:or_asgn,
          s(:casgn, s(:cbase), :A),
          s(:int, 1))),
      %q{def x; ::A ||= 1; end},
      %q{},
      SINCE_2_0)
  end

  def test_const_op_asgn_invalid
    assert_diagnoses(
      [:error, :dynamic_const],
      %q{Foo::Bar += 1},
      %q{     ~~~ location},
      %w(1.8 1.9 mac ios))

    assert_diagnoses(
      [:error, :dynamic_const],
      %q{::Bar += 1},
      %q{  ~~~ location},
      %w(1.8 1.9 mac ios))

    assert_diagnoses(
      [:error, :dynamic_const],
      %q{def foo; Foo::Bar += 1; end},
      %q{              ~~~ location},
      %w(1.8 1.9 mac ios))

    assert_diagnoses(
      [:error, :dynamic_const],
      %q{def foo; ::Bar += 1; end},
      %q{           ~~~ location},
      %w(1.8 1.9 mac ios))
  end

  # Method binary operator-assignment

  def test_op_asgn
    assert_parses(
      s(:op_asgn,
        s(:send, s(:lvar, :foo), :a), :+,
        s(:int, 1)),
      %q{foo.a += 1},
      %q{      ^^ operator
        |    ~ selector (send)
        |~~~~~ expression (send)
        |~~~~~~~~~~ expression})

    assert_parses(
      s(:op_asgn,
        s(:send, s(:lvar, :foo), :a), :+,
        s(:int, 1)),
      %q{foo::a += 1})

    assert_parses(
      s(:op_asgn,
        s(:send, s(:lvar, :foo), :A), :+,
        s(:int, 1)),
      %q{foo.A += 1})
  end

  def test_op_asgn_cmd
    assert_parses(
      s(:op_asgn,
        s(:send, s(:lvar, :foo), :a), :+,
        s(:send, nil, :m, s(:lvar, :foo))),
      %q{foo.a += m foo})

    assert_parses(
      s(:op_asgn,
        s(:send, s(:lvar, :foo), :a), :+,
        s(:send, nil, :m, s(:lvar, :foo))),
      %q{foo::a += m foo})

    assert_parses(
      s(:op_asgn,
        s(:send, s(:lvar, :foo), :A), :+,
        s(:send, nil, :m, s(:lvar, :foo))),
      %q{foo.A += m foo})

    assert_diagnoses(
      [:error, :const_reassignment],
      %q{foo::A += m foo},
      %q{       ~~ location},
      %w(1.9 mac))

    assert_parses(
      s(:op_asgn,
        s(:casgn, s(:lvar, :foo), :A), :+,
        s(:send, nil, :m, s(:lvar, :foo))),
      %q{foo::A += m foo},
      %q{},
      SINCE_2_0)
  end

  def test_op_asgn_index
    assert_parses(
      s(:op_asgn,
        s(:indexasgn, s(:lvar, :foo),
          s(:int, 0), s(:int, 1)), :+,
        s(:int, 2)),
      %q{foo[0, 1] += 2},
      %q{          ^^ operator
        |   ^ begin (indexasgn)
        |        ^ end (indexasgn)
        |~~~~~~~~~ expression (indexasgn)
        |~~~~~~~~~~~~~~ expression})
  end

  def test_op_asgn_index_cmd
    assert_parses(
      s(:op_asgn,
        s(:indexasgn, s(:lvar, :foo),
          s(:int, 0), s(:int, 1)), :+,
        s(:send, nil, :m, s(:lvar, :foo))),
      %q{foo[0, 1] += m foo})
  end

  def test_op_asgn_invalid
    assert_diagnoses(
      [:error, :backref_assignment],
      %q{$1 |= 1},
      %q{~~ location})

    assert_diagnoses(
      [:error, :backref_assignment],
      %q{$+ |= 1},
      %q{~~ location})

    assert_diagnoses(
      [:error, :backref_assignment],
      %q{$+ |= m foo},
      %q{~~ location})
  end

  # Variable logical operator-assignment

  def test_var_or_asgn
    assert_parses(
      s(:or_asgn, s(:lvasgn, :a), s(:int, 1)),
      %q{a ||= 1},
      %q{  ^^^ operator
        |~~~~~~~ expression})
  end

  def test_var_and_asgn
    assert_parses(
      s(:and_asgn, s(:lvasgn, :a), s(:int, 1)),
      %q{a &&= 1},
      %q{  ^^^ operator
        |~~~~~~~ expression})
  end

  # Method logical operator-assignment

  def test_or_asgn
    assert_parses(
      s(:or_asgn,
        s(:send, s(:lvar, :foo), :a),
        s(:int, 1)),
      %q{foo.a ||= 1},
      %q{      ^^^ operator
        |    ~ selector (send)
        |~~~~~ expression (send)
        |~~~~~~~~~~~ expression})

    assert_parses(
      s(:or_asgn,
        s(:indexasgn, s(:lvar, :foo),
          s(:int, 0), s(:int, 1)),
        s(:int, 2)),
      %q{foo[0, 1] ||= 2},
      %q{          ^^^ operator
        |   ^ begin (indexasgn)
        |        ^ end (indexasgn)
        |~~~~~~~~~ expression (indexasgn)
        |~~~~~~~~~~~~~~~ expression})
  end

  def test_and_asgn
    assert_parses(
      s(:and_asgn,
        s(:send, s(:lvar, :foo), :a),
        s(:int, 1)),
      %q{foo.a &&= 1},
      %q{      ^^^ operator
        |    ~ selector (send)
        |~~~~~ expression (send)
        |~~~~~~~~~~~ expression})

    assert_parses(
      s(:and_asgn,
        s(:indexasgn, s(:lvar, :foo),
          s(:int, 0), s(:int, 1)),
        s(:int, 2)),
      %q{foo[0, 1] &&= 2},
      %q{          ^^^ operator
        |   ^ begin (indexasgn)
        |        ^ end (indexasgn)
        |~~~~~~~~~ expression (indexasgn)
        |~~~~~~~~~~~~~~~ expression})
  end

  def test_log_asgn_invalid
    assert_diagnoses(
      [:error, :backref_assignment],
      %q{$1 &&= 1},
      %q{~~ location})

    assert_diagnoses(
      [:error, :backref_assignment],
      %q{$+ ||= 1},
      %q{~~ location})
  end


  #
  # Class and module definitions
  #

  def test_module
    assert_parses(
      s(:module,
        s(:const, nil, :Foo),
        nil),
      %q{module Foo; end},
      %q{~~~~~~ keyword
        |       ~~~ name
        |            ~~~ end})
  end

  def test_module_invalid
    assert_diagnoses(
      [:error, :module_in_def],
      %q{def a; module Foo; end; end},
      %q{       ^^^^^^ location})
  end

  def test_cpath
    assert_parses(
      s(:module,
        s(:const, s(:cbase), :Foo),
        nil),
      %q{module ::Foo; end})

    assert_parses(
      s(:module,
        s(:const, s(:const, nil, :Bar), :Foo),
        nil),
      %q{module Bar::Foo; end})
  end

  def test_cpath_invalid
    assert_diagnoses(
      [:error, :module_name_const],
      %q{module foo; end})
  end

  def test_class
    assert_parses(
      s(:class,
        s(:const, nil, :Foo),
        nil,
        nil),
      %q{class Foo; end},
      %q{~~~~~ keyword
        |      ~~~ name
        |           ~~~ end})

    assert_parses(
      s(:class,
        s(:const, nil, :Foo),
        nil,
        nil),
      %q{class Foo end},
      %q{},
      SINCE_2_3)
  end

  def test_class_super
    assert_parses(
      s(:class,
        s(:const, nil, :Foo),
        s(:const, nil, :Bar),
        nil),
      %q{class Foo < Bar; end},
      %q{~~~~~ keyword
        |          ^ operator
        |                 ~~~ end})
  end

  def test_class_super_label
    assert_parses(
      s(:class,
        s(:const, nil, :Foo),
        s(:send, nil, :a,
          s(:sym, :b)),
        nil),
      %q{class Foo < a:b; end},
      %q{},
      SINCE_2_0)
  end

  def test_class_invalid
    assert_diagnoses(
      [:error, :class_in_def],
      %q{def a; class Foo; end; end},
      %q{       ^^^^^ location})

    assert_diagnoses(
      [:error, :class_in_def],
      %q{def self.a; class Foo; end; end},
      %q{            ^^^^^ location})
  end

  def test_sclass
    assert_parses(
      s(:sclass,
        s(:lvar, :foo),
        s(:nil)),
      %q{class << foo; nil; end},
      %q{~~~~~ keyword
        |      ^^ operator
        |                   ~~~ end})
  end

  #
  # Method (un)definition
  #

  def test_def
    assert_parses(
      s(:def, :foo, s(:args), nil),
      %q{def foo; end},
      %q{~~~ keyword
        |    ~~~ name
        |! assignment
        |         ~~~ end})

    assert_parses(
      s(:def, :String, s(:args), nil),
      %q{def String; end})

    assert_parses(
      s(:def, :String=, s(:args), nil),
      %q{def String=; end})

    assert_parses(
      s(:def, :until, s(:args), nil),
      %q{def until; end})

    assert_parses(
      s(:def, :BEGIN, s(:args), nil),
      %q{def BEGIN; end})

    assert_parses(
      s(:def, :END, s(:args), nil),
      %q{def END; end})
  end

  def test_defs
    assert_parses(
      s(:defs, s(:self), :foo, s(:args), nil),
      %q{def self.foo; end},
      %q{~~~ keyword
        |        ^ operator
        |         ~~~ name
        |              ~~~ end})

    assert_parses(
      s(:defs, s(:self), :foo, s(:args), nil),
      %q{def self::foo; end},
      %q{~~~ keyword
        |        ^^ operator
        |          ~~~ name
        |               ~~~ end})

    assert_parses(
      s(:defs, s(:lvar, :foo), :foo, s(:args), nil),
      %q{def (foo).foo; end})

    assert_parses(
      s(:defs, s(:const, nil, :String), :foo,
        s(:args), nil),
      %q{def String.foo; end})

    assert_parses(
      s(:defs, s(:const, nil, :String), :foo,
        s(:args), nil),
      %q{def String::foo; end})
  end

  def test_defs_invalid
    assert_diagnoses(
      [:error, :singleton_literal],
      %q{def (1).foo; end},
      %q{     ~ location})

    assert_diagnoses(
      [:error, :singleton_literal],
      %q{def ("foo").foo; end},
      %q{     ~~~~~ location})

    assert_diagnoses(
      [:error, :singleton_literal],
      %q{def ("foo#{bar}").foo; end},
      %q{     ~~~~~~~~~~~ location})

    assert_diagnoses(
      [:error, :singleton_literal],
      %q{def (:foo).foo; end},
      %q{     ~~~~ location})

    assert_diagnoses(
      [:error, :singleton_literal],
      %q{def (:"foo#{bar}").foo; end},
      %q{     ~~~~~~~~~~~~ location})

    assert_diagnoses(
      [:error, :singleton_literal],
      %q{def ([]).foo; end},
      %q{     ~~ location})

    assert_diagnoses(
      [:error, :singleton_literal],
      %q{def ({}).foo; end},
      %q{     ~~ location})

    assert_diagnoses(
      [:error, :singleton_literal],
      %q{def (/foo/).foo; end},
      %q{     ~~~~~ location})
  end

  def test_undef
    assert_parses(
      s(:undef,
        s(:sym, :foo),
        s(:sym, :bar),
        s(:dsym, s(:str, 'foo'), s(:begin, s(:int, 1)))),
      %q{undef foo, :bar, :"foo#{1}"},
      %q{~~~~~ keyword
        |      ~~~ expression (sym/1)
        |           ~~~~ expression (sym/2)
        |~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression})
  end

  #
  # Aliasing
  #

  def test_alias
    assert_parses(
      s(:alias, s(:sym, :foo), s(:sym, :bar)),
      %q{alias :foo bar},
      %q{~~~~~ keyword
        |      ~~~~ expression (sym/1)
        |      ^ begin (sym/1)
        |           ~~~ expression (sym/2)
        |           ! begin (sym/2)
        |~~~~~~~~~~~~~~ expression})
  end

  def test_alias_gvar
    assert_parses(
      s(:alias, s(:gvar, :$a), s(:gvar, :$b)),
      %q{alias $a $b},
      %q{      ~~ expression (gvar/1)})

    assert_parses(
      s(:alias, s(:gvar, :$a), s(:back_ref, :$+)),
      %q{alias $a $+},
      %q{         ~~ expression (back_ref)})
  end

  def test_alias_nth_ref
    assert_diagnoses(
      [:error, :nth_ref_alias],
      %q{alias $a $1},
      %q{         ~~ location})
  end

  #
  # Formal arguments
  #

  def test_arg
    assert_parses(
      s(:def, :f,
        s(:args, s(:arg, :foo)),
        nil),
      %q{def f(foo); end},
      %q{      ~~~ name (args.arg)
        |      ~~~ expression (args.arg)
        |     ^ begin (args)
        |         ^ end (args)
        |     ~~~~~ expression (args)})

    assert_parses(
      s(:def, :f,
        s(:args, s(:arg, :foo), s(:arg, :bar)),
        nil),
      %q{def f(foo, bar); end})
  end

  def test_optarg
    assert_parses(
      s(:def, :f,
        s(:args, s(:optarg, :foo, s(:int, 1))),
        nil),
      %q{def f foo = 1; end},
      %q{      ~~~ name (args.optarg)
        |          ^ operator (args.optarg)
        |      ~~~~~~~ expression (args.optarg)
        |      ~~~~~~~ expression (args)})

    assert_parses(
      s(:def, :f,
        s(:args,
          s(:optarg, :foo, s(:int, 1)),
          s(:optarg, :bar, s(:int, 2))),
        nil),
      %q{def f(foo=1, bar=2); end})
  end

  def test_restarg_named
    assert_parses(
      s(:def, :f,
        s(:args, s(:restarg, :foo)),
        nil),
      %q{def f(*foo); end},
      %q{       ~~~ name (args.restarg)
        |      ~~~~ expression (args.restarg)})
  end

  def test_restarg_unnamed
    assert_parses(
      s(:def, :f,
        s(:args, s(:restarg)),
        nil),
      %q{def f(*); end},
      %q{      ~ expression (args.restarg)})
  end

  def test_kwarg
    assert_parses(
      s(:def, :f,
        s(:args, s(:kwarg, :foo)),
        nil),
      %q{def f(foo:); end},
      %q{      ~~~ name (args.kwarg)
        |      ~~~~ expression (args.kwarg)},
      SINCE_2_1)
  end

  def test_kwoptarg
    assert_parses(
      s(:def, :f,
        s(:args, s(:kwoptarg, :foo, s(:int, 1))),
        nil),
      %q{def f(foo: 1); end},
      %q{      ~~~ name (args.kwoptarg)
        |      ~~~~~~ expression (args.kwoptarg)},
      SINCE_2_0)
  end

  def test_kwrestarg_named
    assert_parses(
      s(:def, :f,
        s(:args, s(:kwrestarg, :foo)),
        nil),
      %q{def f(**foo); end},
      %q{        ~~~ name (args.kwrestarg)
        |      ~~~~~ expression (args.kwrestarg)},
      SINCE_2_0)
  end

  def test_kwrestarg_unnamed
    assert_parses(
      s(:def, :f,
        s(:args, s(:kwrestarg)),
        nil),
      %q{def f(**); end},
      %q{      ~~ expression (args.kwrestarg)},
      SINCE_2_0)
  end

  def test_kwnilarg
    assert_parses(
      s(:def, :f,
        s(:args, s(:kwnilarg)),
        nil),
      %q{def f(**nil); end},
      %q{      ~~~~~ expression (args.kwnilarg)
        |        ~~~ name (args.kwnilarg)},
      SINCE_2_7)

    assert_parses(
      s(:block,
        s(:send, nil, :m),
        s(:args,
          s(:kwnilarg)), nil),
      %q{m { |**nil| }},
      %q{     ~~~~~ expression (args.kwnilarg)
        |       ~~~ name (args.kwnilarg)},
      SINCE_2_7)

    assert_parses(
      s(:block,
        s(:lambda),
        s(:args,
          s(:kwnilarg)), nil),
      %q{->(**nil) {}},
      %q{   ~~~~~ expression (args.kwnilarg)
        |     ~~~ name (args.kwnilarg)},
      SINCE_2_7)
  end

  def test_blockarg
    assert_parses(
      s(:def, :f,
        s(:args, s(:blockarg, :block)),
        nil),
      %q{def f(&block); end},
      %q{       ~~~~~ name (args.blockarg)
        |      ~~~~~~ expression (args.blockarg)})
  end

  def test_objc_arg
    assert_parses(
      s(:def, :f,
        s(:args, s(:arg, :a), s(:objc_kwarg, :b, :c)),
        nil),
      %q{def f(a, b: c); end},
      %q{         ~ keyword (args.objc_kwarg)
        |          ~ operator (args.objc_kwarg)
        |            ~ argument (args.objc_kwarg)
        |         ~~~~ expression (args.objc_kwarg)},
      %w(mac))

    assert_parses(
      s(:def, :f,
        s(:args, s(:arg, :a), s(:objc_kwarg, :b, :c)),
        nil),
      %q{def f(a, b => c); end},
      %q{         ~ keyword (args.objc_kwarg)
        |           ~~ operator (args.objc_kwarg)
        |              ~ argument (args.objc_kwarg)
        |         ~~~~~~ expression (args.objc_kwarg)},
      %w(mac))
  end

  def test_arg_scope
    # [ruby-core:61299] [Bug #9593]
    assert_parses(
      s(:def, :f,
        s(:args, s(:optarg, :var, s(:defined?, s(:lvar, :var)))),
        s(:lvar, :var)),
      %q{def f(var = defined?(var)) var end},
      %q{},
      SINCE_2_1 - SINCE_2_7)

    assert_parses(
      s(:def, :f,
        s(:args, s(:kwoptarg, :var, s(:defined?, s(:lvar, :var)))),
        s(:lvar, :var)),
      %q{def f(var: defined?(var)) var end},
      %q{},
      SINCE_2_1 - SINCE_2_7)

    assert_parses(
      s(:block,
        s(:send, nil, :lambda),
        s(:args, s(:shadowarg, :a)),
        s(:lvar, :a)),
      %q{lambda{|;a|a}},
      %q{},
      SINCE_1_9)
  end

  def assert_parses_args(ast, code, versions=ALL_VERSIONS)
    assert_parses(
      s(:def, :f, ast, nil),
      %Q{def f #{code}; end},
      %q{},
      versions)
  end

  def test_arg_combinations
    # f_arg tCOMMA f_optarg tCOMMA f_rest_arg              opt_f_block_arg
    assert_parses_args(
      s(:args,
        s(:arg, :a),
        s(:optarg, :o, s(:int, 1)),
        s(:restarg, :r),
        s(:blockarg, :b)),
      %q{a, o=1, *r, &b})

    # f_arg tCOMMA f_optarg tCOMMA f_rest_arg tCOMMA f_arg opt_f_block_arg
    assert_parses_args(
      s(:args,
        s(:arg, :a),
        s(:optarg, :o, s(:int, 1)),
        s(:restarg, :r),
        s(:arg, :p),
        s(:blockarg, :b)),
      %q{a, o=1, *r, p, &b},
      SINCE_1_9)

    # f_arg tCOMMA f_optarg                                opt_f_block_arg
    assert_parses_args(
      s(:args,
        s(:arg, :a),
        s(:optarg, :o, s(:int, 1)),
        s(:blockarg, :b)),
      %q{a, o=1, &b})

    # f_arg tCOMMA f_optarg tCOMMA                   f_arg opt_f_block_arg
    assert_parses_args(
      s(:args,
        s(:arg, :a),
        s(:optarg, :o, s(:int, 1)),
        s(:arg, :p),
        s(:blockarg, :b)),
      %q{a, o=1, p, &b},
      SINCE_1_9)

    # f_arg tCOMMA                 f_rest_arg              opt_f_block_arg
    assert_parses_args(
      s(:args,
        s(:arg, :a),
        s(:restarg, :r),
        s(:blockarg, :b)),
      %q{a, *r, &b})

    # f_arg tCOMMA                 f_rest_arg tCOMMA f_arg opt_f_block_arg
    assert_parses_args(
      s(:args,
        s(:arg, :a),
        s(:restarg, :r),
        s(:arg, :p),
        s(:blockarg, :b)),
      %q{a, *r, p, &b},
      SINCE_1_9)

    # f_arg                                                opt_f_block_arg
    assert_parses_args(
      s(:args,
        s(:arg, :a),
        s(:blockarg, :b)),
      %q{a, &b})

    #              f_optarg tCOMMA f_rest_arg              opt_f_block_arg
    assert_parses_args(
      s(:args,
        s(:optarg, :o, s(:int, 1)),
        s(:restarg, :r),
        s(:blockarg, :b)),
      %q{o=1, *r, &b})

    #              f_optarg tCOMMA f_rest_arg tCOMMA f_arg opt_f_block_arg
    assert_parses_args(
      s(:args,
        s(:optarg, :o, s(:int, 1)),
        s(:restarg, :r),
        s(:arg, :p),
        s(:blockarg, :b)),
      %q{o=1, *r, p, &b},
      SINCE_1_9)

    #              f_optarg                                opt_f_block_arg
    assert_parses_args(
      s(:args,
        s(:optarg, :o, s(:int, 1)),
        s(:blockarg, :b)),
      %q{o=1, &b})

    #              f_optarg tCOMMA                   f_arg opt_f_block_arg
    assert_parses_args(
      s(:args,
        s(:optarg, :o, s(:int, 1)),
        s(:arg, :p),
        s(:blockarg, :b)),
      %q{o=1, p, &b},
      SINCE_1_9)

    #                              f_rest_arg              opt_f_block_arg
    assert_parses_args(
      s(:args,
        s(:restarg, :r),
        s(:blockarg, :b)),
      %q{*r, &b})

    #                              f_rest_arg tCOMMA f_arg opt_f_block_arg
    assert_parses_args(
      s(:args,
        s(:restarg, :r),
        s(:arg, :p),
        s(:blockarg, :b)),
      %q{*r, p, &b},
      SINCE_1_9)

    #                                                          f_block_arg
    assert_parses_args(
      s(:args,
        s(:blockarg, :b)),
      %q{&b})

    # (nothing)
    assert_parses_args(
      s(:args),
      %q{})
  end

  def test_kwarg_combinations
    # f_kwarg tCOMMA f_kwrest opt_f_block_arg
    assert_parses_args(
      s(:args,
        s(:kwoptarg, :foo, s(:int, 1)),
        s(:kwoptarg, :bar, s(:int, 2)),
        s(:kwrestarg, :baz),
        s(:blockarg, :b)),
      %q{(foo: 1, bar: 2, **baz, &b)},
      SINCE_2_0)

    # f_kwarg opt_f_block_arg
    assert_parses_args(
      s(:args,
        s(:kwoptarg, :foo, s(:int, 1)),
        s(:blockarg, :b)),
      %q{(foo: 1, &b)},
      SINCE_2_0)

    # f_kwrest opt_f_block_arg
    assert_parses_args(
      s(:args,
        s(:kwrestarg, :baz),
        s(:blockarg, :b)),
      %q{**baz, &b},
      SINCE_2_0)

    assert_parses_args(
      s(:args,
        s(:restarg),
        s(:kwrestarg)),
      %q{*, **},
      SINCE_2_0)
  end

  def test_kwarg_no_paren
    assert_parses_args(
      s(:args,
        s(:kwarg, :foo)),
      %Q{foo:\n},
      SINCE_2_1)

    assert_parses_args(
      s(:args,
        s(:kwoptarg, :foo, s(:int, -1))),
      %Q{foo: -1\n},
      SINCE_2_1)
  end

  def assert_parses_margs(ast, code, versions=SINCE_1_9)
    assert_parses_args(
      s(:args, ast),
      %Q{(#{code})},
      versions)
  end

  def test_marg_combinations
    # tLPAREN f_margs rparen
    assert_parses_margs(
      s(:mlhs,
        s(:mlhs, s(:arg, :a))),
      %q{((a))})

    # f_marg_list
    assert_parses_margs(
      s(:mlhs, s(:arg, :a), s(:arg, :a1)),
      %q{(a, a1)})

    # f_marg_list tCOMMA tSTAR f_norm_arg
    assert_parses_margs(
      s(:mlhs, s(:arg, :a), s(:restarg, :r)),
      %q{(a, *r)})

    # f_marg_list tCOMMA tSTAR f_norm_arg tCOMMA f_marg_list
    assert_parses_margs(
      s(:mlhs, s(:arg, :a), s(:restarg, :r), s(:arg, :p)),
      %q{(a, *r, p)})

    # f_marg_list tCOMMA tSTAR
    assert_parses_margs(
      s(:mlhs, s(:arg, :a), s(:restarg)),
      %q{(a, *)})

    # f_marg_list tCOMMA tSTAR            tCOMMA f_marg_list
    assert_parses_margs(
      s(:mlhs, s(:arg, :a), s(:restarg), s(:arg, :p)),
      %q{(a, *, p)})

    # tSTAR f_norm_arg
    assert_parses_margs(
      s(:mlhs, s(:restarg, :r)),
      %q{(*r)})

    # tSTAR f_norm_arg tCOMMA f_marg_list
    assert_parses_margs(
      s(:mlhs, s(:restarg, :r), s(:arg, :p)),
      %q{(*r, p)})

    # tSTAR
    assert_parses_margs(
      s(:mlhs, s(:restarg)),
      %q{(*)})

    # tSTAR tCOMMA f_marg_list
    assert_parses_margs(
      s(:mlhs, s(:restarg), s(:arg, :p)),
      %q{(*, p)})
  end

  def test_marg_objc_restarg
    assert_parses(
      s(:def, :f,
        s(:args,
          s(:arg, :a),
          s(:mlhs,
            s(:objc_restarg, s(:objc_kwarg, :b, :c)))),
        nil),
      %Q{def f(a, (*b: c)); end},
      %q{          ~ operator (args.mlhs.objc_restarg)
        |          ~~~~~ expression (args.mlhs.objc_restarg)},
      %w(mac))
  end

  def assert_parses_blockargs(ast, code, versions=ALL_VERSIONS)
    assert_parses(
      s(:block,
        s(:send, nil, :f),
        ast, nil),
      %Q{f{ #{code} }},
      %q{},
      versions)
  end

  def test_block_arg_combinations
    # none
    assert_parses_blockargs(
      s(:args),
      %q{})

    # tPIPE tPIPE
    # tPIPE opt_bv_decl tPIPE
    assert_parses_blockargs(
      s(:args),
      %q{| |})

    assert_parses_blockargs(
      s(:args, s(:shadowarg, :a)),
      %q{|;a|},
      SINCE_1_9)

    assert_parses_blockargs(
      s(:args, s(:shadowarg, :a)),
      %Q{|;\na\n|},
      SINCE_2_0)

    # tOROP before 2.7 / tPIPE+tPIPE after
    assert_parses_blockargs(
      s(:args),
      %q{||})

    # block_par
    # block_par tCOMMA
    # block_par tCOMMA tAMPER lhs
    # f_arg                                                      opt_f_block_arg
    # f_arg tCOMMA
    assert_parses_blockargs(
      s(:args, s(:procarg0, s(:arg, :a))),
      %q{|a|},
      SINCE_1_9)

    assert_parses_blockargs(
      s(:args, s(:arg, :a)),
      %q{|a|},
      %w(1.8))

    assert_parses_blockargs(
      s(:args, s(:arg, :a), s(:arg, :c)),
      %q{|a, c|})

    assert_parses_blockargs(
      s(:args, s(:arg_expr, s(:ivasgn, :@a))),
      %q{|@a|},
      %w(1.8))

    assert_parses_blockargs(
      s(:args, s(:arg, :a)),
      %q{|a,|}
    )

    assert_parses_blockargs(
      s(:args, s(:arg, :a), s(:blockarg, :b)),
      %q{|a, &b|})

    assert_parses_blockargs(
      s(:args, s(:arg, :a), s(:blockarg_expr, s(:ivasgn, :@b))),
      %q{|a, &@b|},
      %w(1.8))

    # block_par tCOMMA tSTAR lhs tCOMMA tAMPER lhs
    # block_par tCOMMA tSTAR tCOMMA tAMPER lhs
    # block_par tCOMMA tSTAR lhs
    # block_par tCOMMA tSTAR
    # f_arg tCOMMA                       f_rest_arg              opt_f_block_arg
    assert_parses_blockargs(
      s(:args, s(:arg, :a), s(:restarg, :s), s(:blockarg, :b)),
      %q{|a, *s, &b|})

    assert_parses_blockargs(
      s(:args, s(:arg, :a),
        s(:restarg_expr, s(:ivasgn, :@s)),
        s(:blockarg_expr, s(:ivasgn, :@b))),
      %q{|a, *@s, &@b|},
      %w(1.8))

    assert_parses_blockargs(
      s(:args, s(:arg, :a), s(:restarg), s(:blockarg, :b)),
      %q{|a, *, &b|})

    assert_parses_blockargs(
      s(:args, s(:arg, :a),
        s(:restarg),
        s(:blockarg_expr, s(:ivasgn, :@b))),
      %q{|a, *, &@b|},
      %w(1.8))

    assert_parses_blockargs(
      s(:args, s(:arg, :a), s(:restarg, :s)),
      %q{|a, *s|})

    assert_parses_blockargs(
      s(:args, s(:arg, :a),
        s(:restarg_expr, s(:ivasgn, :@s))),
      %q{|a, *@s|},
      %w(1.8))

    assert_parses_blockargs(
      s(:args, s(:arg, :a), s(:restarg)),
      %q{|a, *|})

    # tSTAR lhs tCOMMA tAMPER lhs
    # tSTAR lhs
    # tSTAR
    # tSTAR tCOMMA tAMPER lhs
    #                                    f_rest_arg              opt_f_block_arg
    assert_parses_blockargs(
      s(:args, s(:restarg, :s), s(:blockarg, :b)),
      %q{|*s, &b|})

    assert_parses_blockargs(
      s(:args,
        s(:restarg_expr, s(:ivasgn, :@s)),
        s(:blockarg_expr, s(:ivasgn, :@b))),
      %q{|*@s, &@b|},
      %w(1.8))

    assert_parses_blockargs(
      s(:args, s(:restarg), s(:blockarg, :b)),
      %q{|*, &b|})

    assert_parses_blockargs(
      s(:args,
        s(:restarg),
        s(:blockarg_expr, s(:ivasgn, :@b))),
      %q{|*, &@b|},
      %w(1.8))

    assert_parses_blockargs(
      s(:args, s(:restarg, :s)),
      %q{|*s|})

    assert_parses_blockargs(
      s(:args,
        s(:restarg_expr, s(:ivasgn, :@s))),
      %q{|*@s|},
      %w(1.8))

    assert_parses_blockargs(
      s(:args, s(:restarg)),
      %q{|*|})

    # tAMPER lhs
    #                                                                f_block_arg
    assert_parses_blockargs(
      s(:args, s(:blockarg, :b)),
      %q{|&b|})

    assert_parses_blockargs(
      s(:args,
        s(:blockarg_expr, s(:ivasgn, :@b))),
      %q{|&@b|},
      %w(1.8))

    # f_arg tCOMMA f_block_optarg tCOMMA f_rest_arg              opt_f_block_arg
    assert_parses_blockargs(
      s(:args,
        s(:arg, :a),
        s(:optarg, :o, s(:int, 1)),
        s(:optarg, :o1, s(:int, 2)),
        s(:restarg, :r),
        s(:blockarg, :b)),
      %q{|a, o=1, o1=2, *r, &b|},
      SINCE_1_9)

    # f_arg tCOMMA f_block_optarg tCOMMA f_rest_arg tCOMMA f_arg opt_f_block_arg
    assert_parses_blockargs(
      s(:args,
        s(:arg, :a),
        s(:optarg, :o, s(:int, 1)),
        s(:restarg, :r),
        s(:arg, :p),
        s(:blockarg, :b)),
      %q{|a, o=1, *r, p, &b|},
      SINCE_1_9)

    # f_arg tCOMMA f_block_optarg                                opt_f_block_arg
    assert_parses_blockargs(
      s(:args,
        s(:arg, :a),
        s(:optarg, :o, s(:int, 1)),
        s(:blockarg, :b)),
      %q{|a, o=1, &b|},
      SINCE_1_9)

    # f_arg tCOMMA f_block_optarg tCOMMA                   f_arg opt_f_block_arg
    assert_parses_blockargs(
      s(:args,
        s(:arg, :a),
        s(:optarg, :o, s(:int, 1)),
        s(:arg, :p),
        s(:blockarg, :b)),
      %q{|a, o=1, p, &b|},
      SINCE_1_9)

    # f_arg tCOMMA                       f_rest_arg tCOMMA f_arg opt_f_block_arg
    assert_parses_blockargs(
      s(:args,
        s(:arg, :a),
        s(:restarg, :r),
        s(:arg, :p),
        s(:blockarg, :b)),
      %q{|a, *r, p, &b|},
      SINCE_1_9)

    #              f_block_optarg tCOMMA f_rest_arg              opt_f_block_arg
    assert_parses_blockargs(
      s(:args,
        s(:optarg, :o, s(:int, 1)),
        s(:restarg, :r),
        s(:blockarg, :b)),
      %q{|o=1, *r, &b|},
      SINCE_1_9)

    #              f_block_optarg tCOMMA f_rest_arg tCOMMA f_arg opt_f_block_arg
    assert_parses_blockargs(
      s(:args,
        s(:optarg, :o, s(:int, 1)),
        s(:restarg, :r),
        s(:arg, :p),
        s(:blockarg, :b)),
      %q{|o=1, *r, p, &b|},
      SINCE_1_9)

    #              f_block_optarg                                opt_f_block_arg
    assert_parses_blockargs(
      s(:args,
        s(:optarg, :o, s(:int, 1)),
        s(:blockarg, :b)),
      %q{|o=1, &b|},
      SINCE_1_9)

    #              f_block_optarg tCOMMA                   f_arg opt_f_block_arg
    assert_parses_blockargs(
      s(:args,
        s(:optarg, :o, s(:int, 1)),
        s(:arg, :p),
        s(:blockarg, :b)),
      %q{|o=1, p, &b|},
      SINCE_1_9)

    #                                    f_rest_arg tCOMMA f_arg opt_f_block_arg
    assert_parses_blockargs(
      s(:args,
        s(:restarg, :r),
        s(:arg, :p),
        s(:blockarg, :b)),
      %q{|*r, p, &b|},
      SINCE_1_9)
  end

  def test_multiple_args_with_trailing_comma
    assert_parses_blockargs(
      s(:args,
        s(:arg, :a),
        s(:arg, :b)),
      %q(|a, b,|)
    )
  end

  def test_procarg0_legacy
    Parser::Builders::Default.emit_procarg0 = false
    assert_parses_blockargs(
      s(:args,
        s(:arg, :a)),
      %q{|a|}
    )
  ensure
    Parser::Builders::Default.emit_procarg0 = true
  end

  def test_emit_arg_inside_procarg0_legacy
    Parser::Builders::Default.emit_arg_inside_procarg0 = false
    assert_parses_blockargs(
      s(:args,
        s(:procarg0, :a)),
      %q{|a|},
      SINCE_1_9)
  ensure
    Parser::Builders::Default.emit_arg_inside_procarg0 = true
  end

  def test_procarg0
    assert_parses(
      s(:block,
        s(:send, nil, :m),
        s(:args,
          s(:procarg0, s(:arg, :foo))), nil),
      %q{m { |foo| } },
      %q{     ^^^ expression (args.procarg0)},
      SINCE_1_9)

    assert_parses(
      s(:block,
        s(:send, nil, :m),
        s(:args,
          s(:procarg0, s(:arg, :foo), s(:arg, :bar))), nil),
      %q{m { |(foo, bar)| } },
      %q{     ^ begin (args.procarg0)
        |              ^ end (args.procarg0)
        |     ^^^^^^^^^^ expression (args.procarg0)},
      SINCE_1_9)
  end

  def test_block_kwarg_combinations
    # f_block_kwarg tCOMMA f_kwrest opt_f_block_arg
    assert_parses_blockargs(
      s(:args,
        s(:kwoptarg, :foo, s(:int, 1)),
        s(:kwoptarg, :bar, s(:int, 2)),
        s(:kwrestarg, :baz),
        s(:blockarg, :b)),
      %q{|foo: 1, bar: 2, **baz, &b|},
      SINCE_2_0)

    # f_block_kwarg opt_f_block_arg
    assert_parses_blockargs(
      s(:args,
        s(:kwoptarg, :foo, s(:int, 1)),
        s(:blockarg, :b)),
      %q{|foo: 1, &b|},
      SINCE_2_0)

    # f_kwrest opt_f_block_arg
    assert_parses_blockargs(
      s(:args,
        s(:kwrestarg, :baz),
        s(:blockarg, :b)),
      %q{|**baz, &b|},
      SINCE_2_0)
  end

  def test_block_kwarg
    assert_parses_blockargs(
      s(:args,
        s(:kwarg, :foo)),
      %q{|foo:|},
      SINCE_2_1)
  end

  def test_arg_invalid
    assert_diagnoses(
      [:error, :argument_const],
      %q{def foo(Abc); end},
      %q{        ~~~ location})

    assert_diagnoses(
      [:error, :argument_ivar],
      %q{def foo(@abc); end},
      %q{        ~~~~ location})

    assert_diagnoses(
      [:error, :argument_gvar],
      %q{def foo($abc); end},
      %q{        ~~~~ location})

    assert_diagnoses(
      [:error, :argument_cvar],
      %q{def foo(@@abc); end},
      %q{        ~~~~~ location})
  end

  def test_arg_duplicate
    assert_diagnoses(
      [:error, :duplicate_argument],
      %q{def foo(aa, aa); end},
      %q{            ^^ location
        |        ~~ highlights (0)})

    assert_diagnoses(
      [:error, :duplicate_argument],
      %q{def foo(aa, aa=1); end},
      %q{            ^^ location
        |        ~~ highlights (0)})

    assert_diagnoses(
      [:error, :duplicate_argument],
      %q{def foo(aa, *aa); end},
      %q{             ^^ location
        |        ~~ highlights (0)})

    assert_diagnoses(
      [:error, :duplicate_argument],
      %q{def foo(aa, &aa); end},
      %q{             ^^ location
        |        ~~ highlights (0)})

    assert_diagnoses(
      [:error, :duplicate_argument],
      %q{def foo(aa, (bb, aa)); end},
      %q{                 ^^ location
        |        ~~ highlights (0)},
      SINCE_1_9)

    assert_diagnoses(
      [:error, :duplicate_argument],
      %q{def foo(aa, *r, aa); end},
      %q{                ^^ location
        |        ~~ highlights (0)},
      SINCE_1_9)


    assert_diagnoses(
      [:error, :duplicate_argument],
      %q{lambda do |aa; aa| end},
      %q{               ^^ location
        |           ~~ highlights (0)},
      SINCE_1_9)

    assert_diagnoses(
      [:error, :duplicate_argument],
      %q{def foo(aa, aa: 1); end},
      %q{            ^^ location
        |        ~~ highlights (0)},
      SINCE_2_0)

    assert_diagnoses(
      [:error, :duplicate_argument],
      %q{def foo(aa, **aa); end},
      %q{              ^^ location
        |        ~~ highlights (0)},
      SINCE_2_0)

    assert_diagnoses(
      [:error, :duplicate_argument],
      %q{def foo(aa, aa:); end},
      %q{            ^^ location
        |        ~~ highlights (0)},
      SINCE_2_1)
  end

  def test_arg_duplicate_ignored
    assert_diagnoses(
      [:error, :duplicate_argument],
      %q{def foo(_, _); end},
      %q{},
      %w(1.8))

    assert_parses(
      s(:def, :foo,
        s(:args, s(:arg, :_), s(:arg, :_)),
        nil),
      %q{def foo(_, _); end},
      %q{},
      SINCE_1_9)

    assert_diagnoses(
      [:error, :duplicate_argument],
      %q{def foo(_a, _a); end},
      %q{},
      %w(1.8 1.9 mac ios))

    assert_parses(
      s(:def, :foo,
        s(:args, s(:arg, :_a), s(:arg, :_a)),
        nil),
      %q{def foo(_a, _a); end},
      %q{},
      SINCE_2_0)
  end

  def test_arg_duplicate_proc
    assert_parses(
      s(:block, s(:send, nil, :proc),
        s(:args, s(:arg, :a), s(:arg, :a)),
        nil),
      %q{proc{|a,a|}},
      %q{},
      %w(1.8))

    assert_diagnoses(
      [:error, :duplicate_argument],
      %q{proc{|a,a|}},
      %q{},
      SINCE_1_9)
  end

  def test_kwarg_invalid
    assert_diagnoses(
      [:error, :argument_const],
      %q{def foo(Abc: 1); end},
      %q{        ~~~~ location},
      SINCE_2_0)

    assert_diagnoses(
      [:error, :argument_const],
      %q{def foo(Abc:); end},
      %q{        ~~~~ location},
      SINCE_2_1)
  end

  def test_arg_label
    assert_parses(
      s(:def, :foo, s(:args),
        s(:send, nil, :a, s(:sym, :b))),
      %q{def foo() a:b end},
      %q{},
      SINCE_1_9)

    assert_parses(
      s(:def, :foo, s(:args),
        s(:send, nil, :a, s(:sym, :b))),
      %Q{def foo\n a:b end},
      %q{},
      SINCE_1_9)

    assert_parses(
      s(:block,
        s(:send, nil, :f),
        s(:args),
        s(:send, nil, :a,
          s(:sym, :b))),
      %Q{f { || a:b }},
      %q{},
      SINCE_1_9)
  end

  #
  # Sends
  #

  # To self

  def test_send_self
    assert_parses(
      s(:send, nil, :fun),
      %q{fun},
      %q{~~~ selector
        |~~~ expression})

    assert_parses(
      s(:send, nil, :fun!),
      %q{fun!},
      %q{~~~~ selector
        |~~~~ expression})

    assert_parses(
      s(:send, nil, :fun, s(:int, 1)),
      %q{fun(1)},
      %q{~~~ selector
        |   ^ begin
        |     ^ end
        |~~~~~~ expression})
  end

  def test_send_self_block
    assert_parses(
      s(:block, s(:send, nil, :fun), s(:args), nil),
      %q{fun { }})

    assert_parses(
      s(:block, s(:send, nil, :fun), s(:args), nil),
      %q{fun() { }})

    assert_parses(
      s(:block, s(:send, nil, :fun, s(:int, 1)), s(:args), nil),
      %q{fun(1) { }})

    assert_parses(
      s(:block, s(:send, nil, :fun), s(:args), nil),
      %q{fun do end})
  end

  def test_send_block_blockarg
    assert_diagnoses(
      [:error, :block_and_blockarg],
      %q{fun(&bar) do end},
      %q{    ~~~~ location
        |          ~~ highlights (0)})
  end

  def test_send_objc_vararg
    assert_parses(
      s(:send, nil, :fun,
        s(:int, 1),
        s(:kwargs,
          s(:pair, s(:sym, :bar), s(:objc_varargs, s(:int, 2), s(:int, 3), s(:nil))))),
      %q{fun(1, bar: 2, 3, nil)},
      %q{            ~~~~~~~~~ expression (kwargs.pair.objc_varargs)},
      %w(mac))
  end

  # To receiver

  def test_send_plain
    assert_parses(
      s(:send, s(:lvar, :foo), :fun),
      %q{foo.fun},
      %q{    ~~~ selector
        |   ^ dot
        |~~~~~~~ expression})

    assert_parses(
      s(:send, s(:lvar, :foo), :fun),
      %q{foo::fun},
      %q{     ~~~ selector
        |   ^^ dot
        |~~~~~~~~ expression})

    assert_parses(
      s(:send, s(:lvar, :foo), :Fun),
      %q{foo::Fun()},
      %q{     ~~~ selector
        |   ^^ dot
        |~~~~~~~~~~ expression})
  end

  def test_send_plain_cmd
    assert_parses(
      s(:send, s(:lvar, :foo), :fun, s(:lvar, :bar)),
      %q{foo.fun bar},
      %q{    ~~~ selector
        |   ^ dot
        |~~~~~~~~~~~ expression})

    assert_parses(
      s(:send, s(:lvar, :foo), :fun, s(:lvar, :bar)),
      %q{foo::fun bar},
      %q{     ~~~ selector
        |   ^^ dot
        |~~~~~~~~~~~~ expression})

    assert_parses(
      s(:send, s(:lvar, :foo), :Fun, s(:lvar, :bar)),
      %q{foo::Fun bar},
      %q{     ~~~ selector
        |   ^^ dot
        |~~~~~~~~~~~~ expression})
  end

  def test_send_plain_cmd_ambiguous_literal
    assert_diagnoses(
      [:warning, :ambiguous_literal],
      %q{m /foo/},
      %q{  ^ location},
      ALL_VERSIONS - SINCE_3_0)

    refute_diagnoses(
      %q{m %[1]})
  end

  def test_send_plain_cmd_ambiguous_regexp
    assert_diagnoses(
      [:warning, :ambiguous_regexp],
      %q{m /foo/},
      %q{  ^ location},
      SINCE_3_0)

    refute_diagnoses(
      %q{m %[1]})
  end

  def test_send_plain_cmd_ambiguous_prefix
    assert_diagnoses(
      [:warning, :ambiguous_prefix, { :prefix => '+' }],
      %q{m +foo},
      %q{  ^ location})

    assert_diagnoses(
      [:warning, :ambiguous_prefix, { :prefix => '-' }],
      %q{m -foo},
      %q{  ^ location})

    assert_diagnoses(
      [:warning, :ambiguous_prefix, { :prefix => '&' }],
      %q{m &foo},
      %q{  ^ location})

    assert_diagnoses(
      [:warning, :ambiguous_prefix, { :prefix => '*' }],
      %q{m *foo},
      %q{  ^ location})

    assert_diagnoses(
      [:warning, :ambiguous_prefix, { :prefix => '**' }],
      %q{m **foo},
      %q{  ^^ location},
      SINCE_2_0)
  end

  def test_send_block_chain_cmd
    assert_parses(
      s(:send,
        s(:block,
          s(:send, nil, :meth, s(:int, 1)),
          s(:args), nil),
        :fun, s(:lvar, :bar)),
      %q{meth 1 do end.fun bar},
      %q{              ~~~ selector
        |             ^ dot
        |~~~~~~~~~~~~~~~~~~~~~ expression})

    assert_parses(
      s(:send,
        s(:block,
          s(:send, nil, :meth, s(:int, 1)),
          s(:args), nil),
        :fun, s(:lvar, :bar)),
      %q{meth 1 do end.fun(bar)},
      %q{              ~~~ selector
        |             ^ dot
        |                 ^ begin
        |                     ^ end
        |~~~~~~~~~~~~~~~~~~~~~~ expression})

    assert_parses(
      s(:send,
        s(:block,
          s(:send, nil, :meth, s(:int, 1)),
          s(:args), nil),
        :fun, s(:lvar, :bar)),
      %q{meth 1 do end::fun bar},
      %q{               ~~~ selector
        |             ^^ dot
        |~~~~~~~~~~~~~~~~~~~~~~ expression})

    assert_parses(
      s(:send,
        s(:block,
          s(:send, nil, :meth, s(:int, 1)),
          s(:args), nil),
        :fun, s(:lvar, :bar)),
      %q{meth 1 do end::fun(bar)},
      %q{               ~~~ selector
        |                  ^ begin
        |                      ^ end
        |             ^^ dot
        |~~~~~~~~~~~~~~~~~~~~~~~ expression})

    assert_parses(
      s(:block,
        s(:send,
          s(:block,
            s(:send, nil, :meth, s(:int, 1)),
            s(:args), nil),
          :fun, s(:lvar, :bar)),
        s(:args), nil),
      %q{meth 1 do end.fun bar do end},
      %q{},
      SINCE_2_0)

    assert_parses(
      s(:block,
        s(:send,
          s(:block,
            s(:send, nil, :meth, s(:int, 1)),
            s(:args), nil),
          :fun, s(:lvar, :bar)),
        s(:args), nil),
      %q{meth 1 do end.fun(bar) {}},
      %q{},
      SINCE_2_0)

    assert_parses(
      s(:block,
        s(:send,
          s(:block,
            s(:send, nil, :meth, s(:int, 1)),
            s(:args), nil),
          :fun),
        s(:args), nil),
      %q{meth 1 do end.fun {}},
      %q{},
      SINCE_2_0)
  end

  def test_send_paren_block_cmd
    assert_parses(
      s(:send, nil, :foo,
        s(:block,
          s(:send, nil, :meth, s(:int, 1)),
          s(:args), nil)),
      %q{foo(meth 1 do end)},
      %q{},
      %w(1.8))

    assert_parses(
      s(:send, nil, :foo,
        s(:int, 1),
        s(:block,
          s(:send, nil, :meth, s(:int, 1)),
          s(:args), nil)),
      %q{foo(1, meth 1 do end)},
      %q{},
      %w(1.8))
  end

  def test_send_binary_op
    assert_parses(
      s(:send, s(:lvar, :foo), :+, s(:int, 1)),
      %q{foo + 1},
      %q{    ~ selector
        |~~~~~~~ expression})

    assert_parses(
      s(:send, s(:lvar, :foo), :-, s(:int, 1)),
      %q{foo - 1})

    assert_parses(
      s(:send, s(:lvar, :foo), :*, s(:int, 1)),
      %q{foo * 1})

    assert_parses(
      s(:send, s(:lvar, :foo), :/, s(:int, 1)),
      %q{foo / 1})

    assert_parses(
      s(:send, s(:lvar, :foo), :%, s(:int, 1)),
      %q{foo % 1})

    assert_parses(
      s(:send, s(:lvar, :foo), :**, s(:int, 1)),
      %q{foo ** 1})

    assert_parses(
      s(:send, s(:lvar, :foo), :|, s(:int, 1)),
      %q{foo | 1})

    assert_parses(
      s(:send, s(:lvar, :foo), :^, s(:int, 1)),
      %q{foo ^ 1})

    assert_parses(
      s(:send, s(:lvar, :foo), :&, s(:int, 1)),
      %q{foo & 1})

    assert_parses(
      s(:send, s(:lvar, :foo), :<=>, s(:int, 1)),
      %q{foo <=> 1})

    assert_parses(
      s(:send, s(:lvar, :foo), :<, s(:int, 1)),
      %q{foo < 1})

    assert_parses(
      s(:send, s(:lvar, :foo), :<=, s(:int, 1)),
      %q{foo <= 1})

    assert_parses(
      s(:send, s(:lvar, :foo), :>, s(:int, 1)),
      %q{foo > 1})

    assert_parses(
      s(:send, s(:lvar, :foo), :>=, s(:int, 1)),
      %q{foo >= 1})

    assert_parses(
      s(:send, s(:lvar, :foo), :==, s(:int, 1)),
      %q{foo == 1})

    assert_parses(
      s(:not, s(:send, s(:lvar, :foo), :==, s(:int, 1))),
      %q{foo != 1},
      %q{},
      %w(1.8))

    assert_parses(
      s(:send, s(:lvar, :foo), :'!=', s(:int, 1)),
      %q{foo != 1},
      %q{},
      SINCE_1_9)

    assert_parses(
      s(:send, s(:lvar, :foo), :===, s(:int, 1)),
      %q{foo === 1})

    assert_parses(
      s(:send, s(:lvar, :foo), :=~, s(:int, 1)),
      %q{foo =~ 1})

    assert_parses(
      s(:not, s(:send, s(:lvar, :foo), :=~, s(:int, 1))),
      %q{foo !~ 1},
      %q{},
      %w(1.8))

    assert_parses(
      s(:send, s(:lvar, :foo), :'!~', s(:int, 1)),
      %q{foo !~ 1},
      %q{},
      SINCE_1_9)

    assert_parses(
      s(:send, s(:lvar, :foo), :<<, s(:int, 1)),
      %q{foo << 1})

    assert_parses(
      s(:send, s(:lvar, :foo), :>>, s(:int, 1)),
      %q{foo >> 1})
  end

  def test_send_unary_op
    assert_parses(
      s(:send, s(:lvar, :foo), :-@),
      %q{-foo},
      %q{~ selector
        |~~~~ expression})

    assert_parses(
      s(:send, s(:lvar, :foo), :+@),
      %q{+foo})

    assert_parses(
      s(:send, s(:lvar, :foo), :~),
      %q{~foo})
  end

  def test_bang
    assert_parses(
      s(:not, s(:lvar, :foo)),
      %q{!foo},
      %{},
      %w(1.8))

    assert_parses(
      s(:send, s(:lvar, :foo), :'!'),
      %q{!foo},
      %{},
      SINCE_1_9)
  end

  def test_bang_cmd
    assert_parses(
      s(:not, s(:send, nil, :m, s(:lvar, :foo))),
      %q{!m foo},
      %{},
      %w(1.8))

    assert_parses(
      s(:send, s(:send, nil, :m, s(:lvar, :foo)), :'!'),
      %q{!m foo},
      %{},
      SINCE_1_9)
  end

  def test_not
    assert_parses(
      s(:not, s(:lvar, :foo)),
      %q{not foo},
      %{},
      %w(1.8))

    assert_parses(
      s(:send, s(:lvar, :foo), :'!'),
      %q{not foo},
      %{},
      SINCE_1_9)

    assert_parses(
      s(:send, s(:lvar, :foo), :'!'),
      %q{not(foo)},
      %q{~~~~~~~~ expression},
      SINCE_1_9)

    assert_parses(
      s(:send, s(:begin), :'!'),
      %q{not()},
      %q{~~~~~ expression},
      SINCE_1_9)
  end

  def test_not_cmd
    assert_parses(
      s(:not, s(:send, nil, :m, s(:lvar, :foo))),
      %q{not m foo},
      %{},
      %w(1.8))

    assert_parses(
      s(:send, s(:send, nil, :m, s(:lvar, :foo)), :'!'),
      %q{not m foo},
      %{},
      SINCE_1_9)
  end

  def test_unary_num_pow_precedence
    assert_parses(
      s(:send,
        s(:send,
          s(:int, 2), :**, s(:int, 10)),
        :+@),
      %q{+2 ** 10},
      %{},
      %w{2.1})

    assert_parses(
      s(:send,
        s(:send,
          s(:float, 2.0), :**, s(:int, 10)),
        :+@),
      %q{+2.0 ** 10})

    assert_parses(
      s(:send,
        s(:send,
          s(:int, 2), :**, s(:int, 10)),
        :-@),
      %q{-2 ** 10})

    assert_parses(
      s(:send,
        s(:send,
          s(:float, 2.0), :**, s(:int, 10)),
        :-@),
      %q{-2.0 ** 10})
  end

  def test_send_attr_asgn
    assert_parses(
      s(:send, s(:lvar, :foo), :a=, s(:int, 1)),
      %q{foo.a = 1},
      %q{    ~ selector
        |   ^ dot
        |      ^ operator
        |~~~~~~~~~ expression})

    assert_parses(
      s(:send, s(:lvar, :foo), :a=, s(:int, 1)),
      %q{foo::a = 1},
      %q{     ~ selector
        |   ^^ dot
        |       ^ operator
        |~~~~~~~~~~ expression})

    assert_parses(
      s(:send, s(:lvar, :foo), :A=, s(:int, 1)),
      %q{foo.A = 1},
      %q{    ~ selector
        |   ^ dot
        |      ^ operator
        |~~~~~~~~~ expression})

    assert_parses(
      s(:casgn, s(:lvar, :foo), :A, s(:int, 1)),
      %q{foo::A = 1},
      %q{     ~ name
        |   ^^ double_colon
        |       ^ operator
        |~~~~~~~~~~ expression})
  end

  def test_send_index
    assert_parses(
      s(:index, s(:lvar, :foo),
        s(:int, 1), s(:int, 2)),
      %q{foo[1, 2]},
      %q{   ^ begin
        |        ^ end
        |~~~~~~~~~ expression})
  end

  def test_send_index_legacy
    Parser::Builders::Default.emit_index = false
    assert_parses(
      s(:send, s(:lvar, :foo), :[],
        s(:int, 1), s(:int, 2)),
      %q{foo[1, 2]},
      %q{   ~~~~~~ selector
        |~~~~~~~~~ expression})
  ensure
    Parser::Builders::Default.emit_index = true
  end

  def test_send_index_cmd
    assert_parses(
      s(:index, s(:lvar, :foo),
        s(:send, nil, :m, s(:lvar, :bar))),
      %q{foo[m bar]})
  end

  def test_send_index_asgn
    assert_parses(
      s(:indexasgn, s(:lvar, :foo),
        s(:int, 1), s(:int, 2), s(:int, 3)),
      %q{foo[1, 2] = 3},
      %q{   ^ begin
        |        ^ end
        |          ^ operator
        |~~~~~~~~~~~~~ expression})
  end

  def test_send_index_asgn_legacy
    Parser::Builders::Default.emit_index = false
    assert_parses(
      s(:send, s(:lvar, :foo), :[]=,
        s(:int, 1), s(:int, 2), s(:int, 3)),
      %q{foo[1, 2] = 3},
      %q{   ~~~~~~ selector
        |          ^ operator
        |~~~~~~~~~~~~~ expression})
  ensure
    Parser::Builders::Default.emit_index = true
  end

  def test_send_index_asgn_kwarg
    assert_parses(
      s(:indexasgn,
        s(:lvar, :foo),
        s(:kwargs,
          s(:pair,
            s(:sym, :kw),
            s(:send, nil, :arg))),
        s(:int, 3)),
      %q{foo[:kw => arg] = 3})
  end

  def test_send_index_asgn_kwarg_legacy
    Parser::Builders::Default.emit_kwargs = false
    assert_parses(
      s(:indexasgn,
        s(:lvar, :foo),
        s(:hash,
          s(:pair,
            s(:sym, :kw),
            s(:send, nil, :arg))),
        s(:int, 3)),
      %q{foo[:kw => arg] = 3})
  ensure
    Parser::Builders::Default.emit_kwargs = true
  end

  def test_send_lambda
    assert_parses(
      s(:block, s(:lambda),
        s(:args), nil),
      %q{->{ }},
      %q{~~ expression (lambda)
        |  ^ begin
        |    ^ end
        |~~~~~ expression},
      SINCE_1_9)

    assert_parses(
      s(:block, s(:lambda),
        s(:args, s(:restarg)), nil),
      %q{-> * { }},
      %q{~~ expression (lambda)
        |     ^ begin
        |       ^ end
        |   ^ expression (args.restarg)
        |~~~~~~~~ expression},
      SINCE_1_9)

    assert_parses(
      s(:block, s(:lambda),
        s(:args), nil),
      %q{-> do end},
      %q{~~ expression (lambda)
        |   ^^ begin
        |      ^^^ end
        |~~~~~~~~~ expression},
      SINCE_1_9)
  end

  def test_send_lambda_args
    assert_parses(
      s(:block, s(:lambda),
        s(:args,
          s(:arg, :a)),
        nil),
      %q{->(a) { }},
      %q{~~ expression (lambda)
        |  ^ begin (args)
        |    ^ end (args)
        |      ^ begin
        |        ^ end
        |~~~~~~~~~ expression},
      SINCE_1_9)

    assert_parses(
      s(:block, s(:lambda),
        s(:args,
          s(:arg, :a)),
        nil),
      %q{-> (a) { }},
      %q{},
      SINCE_2_0)
  end

  def test_send_lambda_args_shadow
    assert_parses(
      s(:block, s(:lambda),
        s(:args,
          s(:arg, :a),
          s(:shadowarg, :foo),
          s(:shadowarg, :bar)),
        nil),
      %q{->(a; foo, bar) { }},
      %q{      ~~~ expression (args.shadowarg)},
      SINCE_1_9)
  end

  def test_send_lambda_args_noparen
    assert_parses(
      s(:block, s(:lambda),
        s(:args,
          s(:kwoptarg, :a, s(:int, 1))),
        nil),
      %q{-> a: 1 { }},
      %q{},
      SINCE_2_0)

    assert_parses(
      s(:block, s(:lambda),
        s(:args,
          s(:kwarg, :a)),
        nil),
      %q{-> a: { }},
      %q{},
      SINCE_2_1)
  end

  def test_send_lambda_legacy
    Parser::Builders::Default.emit_lambda = false
    assert_parses(
      s(:block, s(:send, nil, :lambda),
        s(:args), nil),
      %q{->{ }},
      %q{~~ selector (send)
        |  ^ begin
        |    ^ end
        |~~~~~ expression},
      SINCE_1_9)
  ensure
    Parser::Builders::Default.emit_lambda = true
  end

  def test_send_call
    assert_parses(
      s(:send, s(:lvar, :foo), :call,
        s(:int, 1)),
      %q{foo.(1)},
      %q{    ^ begin
        |      ^ end
        |   ^ dot
        |~~~~~~~ expression},
      SINCE_1_9)

    assert_parses(
      s(:send, s(:lvar, :foo), :call,
        s(:int, 1)),
      %q{foo::(1)},
      %q{     ^ begin
        |       ^ end
        |   ^^ dot
        |~~~~~~~~ expression},
      SINCE_1_9)
  end

  def test_send_conditional
    assert_parses(
      s(:csend, s(:send, nil, :a), :b),
      %q{a&.b},
      %q{ ^^ dot},
      SINCE_2_3 + %w{ios})
  end

  def test_send_attr_asgn_conditional
    assert_parses(
      s(:csend, s(:send, nil, :a), :b=, s(:int, 1)),
      %q{a&.b = 1},
      %q{ ^^ dot},
      SINCE_2_3 + %w{ios})
  end

  def test_send_block_conditional
    assert_parses(
      s(:block,
        s(:csend,
          s(:lvar, :foo), :bar),
        s(:args), nil),
      %q{foo&.bar {}},
      %q{},
      SINCE_2_3 + %w{ios})
  end

  def test_send_op_asgn_conditional
    assert_parses(
      s(:and_asgn, s(:csend, s(:send, nil, :a), :b), s(:int, 1)),
      %q{a&.b &&= 1},
      %q{},
      SINCE_2_3 + %w{ios})
  end

  def test_lvar_injecting_match
    assert_parses(
      s(:begin,
        s(:match_with_lvasgn,
          s(:regexp,
            s(:str, '(?<match>bar)'),
            s(:regopt)),
          s(:str, 'bar')),
        s(:lvar, :match)),
      %q{/(?<match>bar)/ =~ 'bar'; match},
      %q{                ~~ selector (match_with_lvasgn)
        |~~~~~~~~~~~~~~~~~~~~~~~~ expression (match_with_lvasgn)},
      SINCE_1_9)

    assert_parses(
      s(:begin,
        s(:match_with_lvasgn,
          s(:regexp,
            s(:str, "(?<a>a)"),
            s(:regopt)),
          s(:str, "a")),
        s(:send,
          s(:regexp,
            s(:begin),
            s(:str, "(?<b>b)"),
            s(:regopt)), :=~,
          s(:str, "b")),
        s(:lvar, :a),
        s(:send, nil, :b)),
      %q{/(?<a>a)/ =~ 'a'; /#{}(?<b>b)/ =~ 'b'; a; b},
      %q{},
      SINCE_3_3)
  end

  def test_non_lvar_injecting_match
    assert_parses(
      s(:send,
        s(:regexp,
          s(:begin, s(:int, 1)),
          s(:str, '(?<match>bar)'),
          s(:regopt)),
        :=~,
        s(:str, 'bar')),
      %q{/#{1}(?<match>bar)/ =~ 'bar'})
  end

  # To superclass

  def test_super
    assert_parses(
      s(:super, s(:lvar, :foo)),
      %q{super(foo)},
      %q{~~~~~ keyword
        |     ^ begin
        |         ^ end
        |~~~~~~~~~~ expression})

    assert_parses(
      s(:super, s(:lvar, :foo)),
      %q{super foo},
      %q{~~~~~ keyword
        |~~~~~~~~~ expression})

    assert_parses(
      s(:super),
      %q{super()},
      %q{~~~~~ keyword
        |     ^ begin
        |      ^ end
        |~~~~~~~ expression})
  end

  def test_zsuper
    assert_parses(
      s(:zsuper),
      %q{super},
      %q{~~~~~ keyword
        |~~~~~ expression})
  end

  def test_super_block
    assert_parses(
      s(:block,
        s(:super, s(:lvar, :foo), s(:lvar, :bar)),
        s(:args), nil),
      %q{super foo, bar do end})

    assert_parses(
      s(:block,
        s(:zsuper),
        s(:args), nil),
      %q{super do end})
  end

  # To block argument

  def test_yield
    assert_parses(
      s(:yield, s(:lvar, :foo)),
      %q{yield(foo)},
      %q{~~~~~ keyword
        |     ^ begin
        |         ^ end
        |~~~~~~~~~~ expression})

    assert_parses(
      s(:yield, s(:lvar, :foo)),
      %q{yield foo},
      %q{~~~~~ keyword
        |~~~~~~~~~ expression})

    assert_parses(
      s(:yield),
      %q{yield()},
      %q{~~~~~ keyword
        |     ^ begin
        |      ^ end
        |~~~~~~~ expression})

    assert_parses(
      s(:yield),
      %q{yield},
      %q{~~~~~ keyword
        |~~~~~ expression})
  end

  def test_yield_block
    assert_diagnoses(
      [:error, :block_given_to_yield],
      %q{yield foo do end},
      %q{~~~~~ location
        |          ~~ highlights (0)})

    assert_diagnoses(
      [:error, :block_given_to_yield],
      %q{yield(&foo)},
      %q{~~~~~ location
        |      ~~~~ highlights (0)})
  end

  # Call arguments

  def test_args_cmd
    assert_parses(
      s(:send, nil, :fun,
        s(:send, nil, :f, s(:lvar, :bar))),
      %q{fun(f bar)})
  end

  def test_args_args_star
    assert_parses(
      s(:send, nil, :fun,
        s(:lvar, :foo), s(:splat, s(:lvar, :bar))),
      %q{fun(foo, *bar)})

    assert_parses(
      s(:send, nil, :fun,
        s(:lvar, :foo), s(:splat, s(:lvar, :bar)),
        s(:block_pass, s(:lvar, :baz))),
      %q{fun(foo, *bar, &baz)})
  end

  def test_args_star
    assert_parses(
      s(:send, nil, :fun,
        s(:splat, s(:lvar, :bar))),
      %q{fun(*bar)})

    assert_parses(
      s(:send, nil, :fun,
        s(:splat, s(:lvar, :bar)),
        s(:block_pass, s(:lvar, :baz))),
      %q{fun(*bar, &baz)})
  end

  def test_args_block_pass
    assert_parses(
      s(:send, nil, :fun,
        s(:block_pass, s(:lvar, :bar))),
      %q{fun(&bar)})
  end

  def test_args_args_comma
    assert_parses(
      s(:index, s(:lvar, :foo),
        s(:lvar, :bar)),
      %q{foo[bar,]},
      %q{},
      SINCE_1_9)
  end

  def test_args_assocs_legacy
    Parser::Builders::Default.emit_kwargs = false
    assert_parses(
      s(:send, nil, :fun,
        s(:hash, s(:pair, s(:sym, :foo), s(:int, 1)))),
      %q{fun(:foo => 1)})

    assert_parses(
      s(:send, nil, :fun,
        s(:hash, s(:pair, s(:sym, :foo), s(:int, 1))),
        s(:block_pass, s(:lvar, :baz))),
      %q{fun(:foo => 1, &baz)})

    assert_parses(
      s(:index,
      s(:self),
      s(:hash,
        s(:pair,
          s(:sym, :bar),
          s(:int, 1)))),
      %q{self[:bar => 1]})

    assert_parses(
      s(:send,
        s(:self), :[]=,
        s(:lvar, :foo),
        s(:hash,
          s(:pair,
            s(:sym, :a),
            s(:int, 1)))),
      %q{self.[]= foo, :a => 1})

    assert_parses(
      s(:yield,
        s(:hash,
          s(:pair,
            s(:sym, :foo),
            s(:int, 42)))),
      %q{yield(:foo => 42)})

    assert_parses(
      s(:super,
        s(:hash,
          s(:pair,
            s(:sym, :foo),
            s(:int, 42)))),
      %q{super(:foo => 42)})
  ensure
    Parser::Builders::Default.emit_kwargs = true
  end

  def test_args_assocs
    assert_parses(
      s(:send, nil, :fun,
        s(:kwargs, s(:pair, s(:sym, :foo), s(:int, 1)))),
      %q{fun(:foo => 1)})

    assert_parses(
      s(:send, nil, :fun,
        s(:kwargs, s(:pair, s(:sym, :foo), s(:int, 1))),
        s(:block_pass, s(:lvar, :baz))),
      %q{fun(:foo => 1, &baz)})

    assert_parses(
      s(:index,
      s(:self),
      s(:kwargs,
        s(:pair,
          s(:sym, :bar),
          s(:int, 1)))),
      %q{self[:bar => 1]})

    assert_parses(
      s(:send,
        s(:self), :[]=,
        s(:lvar, :foo),
        s(:kwargs,
          s(:pair,
            s(:sym, :a),
            s(:int, 1)))),
      %q{self.[]= foo, :a => 1})

    assert_parses(
      s(:yield,
        s(:kwargs,
          s(:pair,
            s(:sym, :foo),
            s(:int, 42)))),
      %q{yield(:foo => 42)})

    assert_parses(
      s(:super,
        s(:kwargs,
          s(:pair,
            s(:sym, :foo),
            s(:int, 42)))),
      %q{super(:foo => 42)})
  end

  def test_args_assocs_star
    assert_parses(
      s(:send, nil, :fun,
        s(:hash, s(:pair, s(:sym, :foo), s(:int, 1))),
        s(:splat, s(:lvar, :bar))),
      %q{fun(:foo => 1, *bar)},
      %q{},
      %w(1.8))

    assert_parses(
      s(:send, nil, :fun,
        s(:hash, s(:pair, s(:sym, :foo), s(:int, 1))),
        s(:splat, s(:lvar, :bar)),
        s(:block_pass, s(:lvar, :baz))),
      %q{fun(:foo => 1, *bar, &baz)},
      %q{},
      %w(1.8))
  end

  def test_args_assocs_comma
    assert_parses(
      s(:index, s(:lvar, :foo),
        s(:kwargs, s(:pair, s(:sym, :baz), s(:int, 1)))),
      %q{foo[:baz => 1,]},
      %q{},
      SINCE_1_9)
  end

  def test_args_args_assocs
    assert_parses(
      s(:send, nil, :fun,
        s(:lvar, :foo),
        s(:kwargs, s(:pair, s(:sym, :foo), s(:int, 1)))),
      %q{fun(foo, :foo => 1)})

    assert_parses(
      s(:send, nil, :fun,
        s(:lvar, :foo),
        s(:kwargs, s(:pair, s(:sym, :foo), s(:int, 1))),
        s(:block_pass, s(:lvar, :baz))),
      %q{fun(foo, :foo => 1, &baz)})
  end

  def test_args_args_assocs_comma
    assert_parses(
      s(:index, s(:lvar, :foo),
        s(:lvar, :bar),
        s(:kwargs, s(:pair, s(:sym, :baz), s(:int, 1)))),
      %q{foo[bar, :baz => 1,]},
      %q{},
      SINCE_1_9)
  end

  def test_args_args_assocs_star
    assert_parses(
      s(:send, nil, :fun,
        s(:lvar, :foo),
        s(:hash, s(:pair, s(:sym, :foo), s(:int, 1))),
        s(:splat, s(:lvar, :bar))),
      %q{fun(foo, :foo => 1, *bar)},
      %q{},
      %w(1.8))

    assert_parses(
      s(:send, nil, :fun,
        s(:lvar, :foo),
        s(:hash, s(:pair, s(:sym, :foo), s(:int, 1))),
        s(:splat, s(:lvar, :bar)),
        s(:block_pass, s(:lvar, :baz))),
      %q{fun(foo, :foo => 1, *bar, &baz)},
      %q{},
      %w(1.8))
  end

  # Call arguments with whitespace

  def test_space_args_cmd
    assert_parses(
      s(:send, nil, :fun,
        s(:begin, s(:send, nil, :f, s(:lvar, :bar)))),
      %q{fun (f bar)})
  end

  def test_space_args_arg
    assert_parses(
      s(:send, nil, :fun, s(:begin, s(:int, 1))),
      %q{fun (1)})
  end

  def test_space_args_arg_newline
    assert_parses(
      s(:send, nil, :fun, s(:begin, s(:int, 1))),
      %Q{fun (1\n)},
      %q{},
      ALL_VERSIONS - %w(mac))
  end

  def test_space_args_arg_block
    assert_parses(
      s(:block,
        s(:send, nil, :fun, s(:begin, s(:int, 1))),
        s(:args), nil),
      %q{fun (1) {}})

    assert_parses(
      s(:block,
        s(:send, s(:lvar, :foo), :fun, s(:int, 1)),
        s(:args), nil),
      %q{foo.fun (1) {}},
      %q{},
      %w(1.8))

    assert_parses(
      s(:block,
        s(:send, s(:lvar, :foo), :fun, s(:begin, s(:int, 1))),
        s(:args), nil),
      %q{foo.fun (1) {}},
      %q{},
      SINCE_1_9)

    assert_parses(
      s(:block,
        s(:send, s(:lvar, :foo), :fun, s(:int, 1)),
        s(:args), nil),
      %q{foo::fun (1) {}},
      %q{},
      %w(1.8))

    assert_parses(
      s(:block,
        s(:send, s(:lvar, :foo), :fun, s(:begin, s(:int, 1))),
        s(:args), nil),
      %q{foo::fun (1) {}},
      %q{},
      SINCE_1_9)
  end

  def test_space_args_hash_literal_then_block
    # This code only parses if the lexer enters expr_endarg state correctly
    assert_parses(
      s(:block,
        s(:send, nil, :f, s(:int, 1), s(:hash, s(:pair, s(:int, 1), s(:int, 2)))),
        s(:args),
        s(:int, 1)),
      %q{f 1, {1 => 2} {1}},
      %q{},
      ALL_VERSIONS - SINCE_2_5)
  end

  def test_space_args_arg_call
    assert_parses(
      s(:send, nil, :fun,
        s(:send, s(:begin, s(:int, 1)), :to_i)),
      %q{fun (1).to_i})
  end

  def test_space_args_block_pass
    assert_parses(
      s(:send, nil, :fun,
        s(:block_pass, s(:lvar, :foo))),
      %q{fun (&foo)},
      %q{},
      %w(1.8))
  end

  def test_space_args_arg_block_pass
    assert_parses(
      s(:send, nil, :fun,
        s(:lvar, :foo),
        s(:block_pass, s(:lvar, :bar))),
      %q{fun (foo, &bar)},
      %q{},
      %w(1.8))
  end

  def test_space_args_args_star
    assert_parses(
      s(:send, nil, :fun,
        s(:lvar, :foo), s(:splat, s(:lvar, :bar))),
      %q{fun (foo, *bar)},
      %q{},
      %w(1.8))

    assert_parses(
      s(:send, nil, :fun,
        s(:lvar, :foo), s(:splat, s(:lvar, :bar)),
        s(:block_pass, s(:lvar, :baz))),
      %q{fun (foo, *bar, &baz)},
      %q{},
      %w(1.8))

    assert_parses(
      s(:send, nil, :fun,
        s(:lvar, :foo), s(:int, 1),
        s(:splat, s(:lvar, :bar))),
      %q{fun (foo, 1, *bar)},
      %q{},
      %w(1.8))

    assert_parses(
      s(:send, nil, :fun,
        s(:lvar, :foo), s(:int, 1),
        s(:splat, s(:lvar, :bar)),
        s(:block_pass, s(:lvar, :baz))),
      %q{fun (foo, 1, *bar, &baz)},
      %q{},
      %w(1.8))
  end

  def test_space_args_star
    assert_parses(
      s(:send, nil, :fun,
        s(:splat, s(:lvar, :bar))),
      %q{fun (*bar)},
      %q{},
      %w(1.8))

    assert_parses(
      s(:send, nil, :fun,
        s(:splat, s(:lvar, :bar)),
        s(:block_pass, s(:lvar, :baz))),
      %q{fun (*bar, &baz)},
      %q{},
      %w(1.8))
  end

  def test_space_args_assocs
    assert_parses(
      s(:send, nil, :fun,
        s(:kwargs, s(:pair, s(:sym, :foo), s(:int, 1)))),
      %q{fun (:foo => 1)},
      %q{},
      %w(1.8))

    assert_parses(
      s(:send, nil, :fun,
        s(:kwargs, s(:pair, s(:sym, :foo), s(:int, 1))),
        s(:block_pass, s(:lvar, :baz))),
      %q{fun (:foo => 1, &baz)},
      %q{},
      %w(1.8))
  end

  def test_space_args_assocs_star
    assert_parses(
      s(:send, nil, :fun,
        s(:hash, s(:pair, s(:sym, :foo), s(:int, 1))),
        s(:splat, s(:lvar, :bar))),
      %q{fun (:foo => 1, *bar)},
      %q{},
      %w(1.8))

    assert_parses(
      s(:send, nil, :fun,
        s(:hash, s(:pair, s(:sym, :foo), s(:int, 1))),
        s(:splat, s(:lvar, :bar)),
        s(:block_pass, s(:lvar, :baz))),
      %q{fun (:foo => 1, *bar, &baz)},
      %q{},
      %w(1.8))
  end

  def test_space_args_args_assocs
    assert_parses(
      s(:send, nil, :fun,
        s(:lvar, :foo),
        s(:kwargs, s(:pair, s(:sym, :foo), s(:int, 1)))),
      %q{fun (foo, :foo => 1)},
      %q{},
      %w(1.8))

    assert_parses(
      s(:send, nil, :fun,
        s(:lvar, :foo),
        s(:kwargs, s(:pair, s(:sym, :foo), s(:int, 1))),
        s(:block_pass, s(:lvar, :baz))),
      %q{fun (foo, :foo => 1, &baz)},
      %q{},
      %w(1.8))

    assert_parses(
      s(:send, nil, :fun,
        s(:lvar, :foo), s(:int, 1),
        s(:kwargs, s(:pair, s(:sym, :foo), s(:int, 1)))),
      %q{fun (foo, 1, :foo => 1)},
      %q{},
      %w(1.8))

    assert_parses(
      s(:send, nil, :fun,
        s(:lvar, :foo), s(:int, 1),
        s(:kwargs, s(:pair, s(:sym, :foo), s(:int, 1))),
        s(:block_pass, s(:lvar, :baz))),
      %q{fun (foo, 1, :foo => 1, &baz)},
      %q{},
      %w(1.8))
  end

  def test_space_args_args_assocs_star
    assert_parses(
      s(:send, nil, :fun,
        s(:lvar, :foo),
        s(:hash, s(:pair, s(:sym, :foo), s(:int, 1))),
        s(:splat, s(:lvar, :bar))),
      %q{fun (foo, :foo => 1, *bar)},
      %q{},
      %w(1.8))

    assert_parses(
      s(:send, nil, :fun,
        s(:lvar, :foo),
        s(:hash, s(:pair, s(:sym, :foo), s(:int, 1))),
        s(:splat, s(:lvar, :bar)),
        s(:block_pass, s(:lvar, :baz))),
      %q{fun (foo, :foo => 1, *bar, &baz)},
      %q{},
      %w(1.8))

    assert_parses(
      s(:send, nil, :fun,
        s(:lvar, :foo), s(:int, 1),
        s(:hash, s(:pair, s(:sym, :foo), s(:int, 1))),
        s(:splat, s(:lvar, :bar))),
      %q{fun (foo, 1, :foo => 1, *bar)},
      %q{},
      %w(1.8))

    assert_parses(
      s(:send, nil, :fun,
        s(:lvar, :foo), s(:int, 1),
        s(:hash, s(:pair, s(:sym, :foo), s(:int, 1))),
        s(:splat, s(:lvar, :bar)),
        s(:block_pass, s(:lvar, :baz))),
      %q{fun (foo, 1, :foo => 1, *bar, &baz)},
      %q{},
      %w(1.8))
  end

  def test_space_args_arg_arg
    assert_parses(
      s(:send, nil, :fun, s(:int, 1), s(:int, 2)),
      %q{fun (1, 2)},
      %q{},
      %w(1.8))
  end

  def test_space_args_none
    assert_parses(
      s(:send, nil, :fun),
      %q{fun ()},
      %q{},
      %w(1.8))
  end

  def test_space_args_block
    assert_parses(
      s(:block,
        s(:send, nil, :fun),
        s(:args), nil),
      %q{fun () {}},
      %q{    ^ begin (send)
        |     ^ end (send)},
      %w(1.8))

    assert_parses(
      s(:block,
        s(:send, s(:lvar, :foo), :fun),
        s(:args), nil),
      %q{foo.fun () {}},
      %q{        ^ begin (send)
        |         ^ end (send)},
      %w(1.8))

    assert_parses(
      s(:block,
        s(:send, s(:lvar, :foo), :fun),
        s(:args), nil),
      %q{foo::fun () {}},
      %q{         ^ begin (send)
        |          ^ end (send)},
      %w(1.8))

    assert_parses(
      s(:block,
        s(:send, nil, :fun,
          s(:begin)),
        s(:args), nil),
      %q{fun () {}},
      %q{    ~~ expression (send.begin)},
      SINCE_2_0)
  end

  #
  # Control flow
  #

  # Operators

  def test_and
    assert_parses(
      s(:and, s(:lvar, :foo), s(:lvar, :bar)),
      %q{foo and bar},
      %q{    ~~~ operator
        |~~~~~~~~~~~ expression})

    assert_parses(
      s(:and, s(:lvar, :foo), s(:lvar, :bar)),
      %q{foo && bar},
      %q{    ~~ operator
        |~~~~~~~~~~ expression})
  end

  def test_or
    assert_parses(
      s(:or, s(:lvar, :foo), s(:lvar, :bar)),
      %q{foo or bar},
      %q{    ~~ operator
        |~~~~~~~~~~ expression})

    assert_parses(
      s(:or, s(:lvar, :foo), s(:lvar, :bar)),
      %q{foo || bar},
      %q{    ~~ operator
        |~~~~~~~~~~ expression})
  end

  def test_and_or_masgn
    assert_parses(
      s(:and,
        s(:lvar, :foo),
        s(:begin,
          s(:masgn,
            s(:mlhs, s(:lvasgn, :a), s(:lvasgn, :b)),
            s(:lvar, :bar)))),
      %q{foo && (a, b = bar)})

    assert_parses(
      s(:or,
        s(:lvar, :foo),
        s(:begin,
          s(:masgn,
            s(:mlhs, s(:lvasgn, :a), s(:lvasgn, :b)),
            s(:lvar, :bar)))),
      %q{foo || (a, b = bar)})
  end

  # Branching

  def test_if
    assert_parses(
      s(:if, s(:lvar, :foo), s(:lvar, :bar), nil),
      %q{if foo then bar; end},
      %q{~~ keyword
        |       ~~~~ begin
        |                 ~~~ end
        |~~~~~~~~~~~~~~~~~~~~ expression})

    assert_parses(
      s(:if, s(:lvar, :foo), s(:lvar, :bar), nil),
      %q{if foo; bar; end},
      %q{~~ keyword
        |             ~~~ end
        |~~~~~~~~~~~~~~~~ expression})
  end

  def test_if_nl_then
    assert_parses(
      s(:if, s(:lvar, :foo), s(:lvar, :bar), nil),
      %Q{if foo\nthen bar end},
       %q{       ~~~~ begin})
  end

  def test_if_mod
    assert_parses(
      s(:if, s(:lvar, :foo), s(:lvar, :bar), nil),
      %q{bar if foo},
      %q{    ~~ keyword
        |~~~~~~~~~~ expression})
  end

  def test_unless
    assert_parses(
      s(:if, s(:lvar, :foo), nil, s(:lvar, :bar)),
      %q{unless foo then bar; end},
      %q{~~~~~~ keyword
        |           ~~~~ begin
        |                     ~~~ end
        |~~~~~~~~~~~~~~~~~~~~~~~~ expression})

    assert_parses(
      s(:if, s(:lvar, :foo), nil, s(:lvar, :bar)),
      %q{unless foo; bar; end},
      %q{~~~~~~ keyword
        |                 ~~~ end
        |~~~~~~~~~~~~~~~~~~~~ expression})
  end

  def test_unless_mod
    assert_parses(
      s(:if, s(:lvar, :foo), nil, s(:lvar, :bar)),
      %q{bar unless foo},
      %q{    ~~~~~~ keyword
        |~~~~~~~~~~~~~~ expression})
  end

  def test_if_else
    assert_parses(
      s(:if, s(:lvar, :foo), s(:lvar, :bar), s(:lvar, :baz)),
      %q{if foo then bar; else baz; end},
      %q{~~ keyword
        |       ~~~~ begin
        |                 ~~~~ else
        |                           ~~~ end
        |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression})

    assert_parses(
      s(:if, s(:lvar, :foo), s(:lvar, :bar), s(:lvar, :baz)),
      %q{if foo; bar; else baz; end},
      %q{~~ keyword
        |             ~~~~ else
        |                       ~~~ end
        |~~~~~~~~~~~~~~~~~~~~~~~~~~ expression})
  end

  def test_unless_else
    assert_parses(
      s(:if, s(:lvar, :foo), s(:lvar, :baz), s(:lvar, :bar)),
      %q{unless foo then bar; else baz; end},
      %q{~~~~~~ keyword
        |           ~~~~ begin
        |                     ~~~~ else
        |                               ~~~ end
        |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression})

    assert_parses(
      s(:if, s(:lvar, :foo), s(:lvar, :baz), s(:lvar, :bar)),
      %q{unless foo; bar; else baz; end},
      %q{~~~~~~ keyword
        |                 ~~~~ else
        |                           ~~~ end
        |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression})
  end

  def test_if_elsif
    assert_parses(
      s(:if, s(:lvar, :foo), s(:lvar, :bar),
        s(:if, s(:lvar, :baz), s(:int, 1), s(:int, 2))),
      %q{if foo; bar; elsif baz; 1; else 2; end},
      %q{~~ keyword
        |             ~~~~~ else
        |             ~~~~~ keyword (if)
        |                           ~~~~ else (if)
        |                                   ~~~ end
        |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression})
  end

  def test_ternary
    assert_parses(
      s(:if, s(:lvar, :foo), s(:int, 1), s(:int, 2)),
      %q{foo ? 1 : 2},
      %q{    ^ question
        |        ^ colon
        |~~~~~~~~~~~ expression})
  end

  def test_ternary_ambiguous_symbol
    assert_parses(
      s(:begin,
        s(:lvasgn, :t, s(:int, 1)),
        s(:if, s(:begin, s(:lvar, :foo)),
          s(:lvar, :t),
          s(:const, nil, :T))),
      %q{t=1;(foo)?t:T},
      %q{},
      SINCE_1_9)
  end

  def test_if_masgn
    assert_diagnoses(
      [:error, :masgn_as_condition],
      %q{if (a, b = foo); end},
      %q{    ~~~~~~~~~~ location},
      %w(1.8 1.9 2.0 2.1 2.2 2.3 ios mac))
  end

  def test_if_masgn__24
    assert_parses(
      s(:if,
        s(:begin,
          s(:masgn,
            s(:mlhs,
              s(:lvasgn, :a),
              s(:lvasgn, :b)),
          s(:lvar, :foo))), nil, nil),
      %q{if (a, b = foo); end},
      %q{},
      SINCE_2_4)
  end

  def test_if_mod_masgn
    assert_diagnoses(
      [:error, :masgn_as_condition],
      %q{1 if (a, b = foo)},
      %q{      ~~~~~~~~~~ location},
      %w(1.8 1.9 2.0 2.1 2.2 2.3 ios mac))
  end

  def test_tern_masgn
    assert_diagnoses(
      [:error, :masgn_as_condition],
      %q{(a, b = foo) ? 1 : 2},
      %q{ ~~~~~~~~~~ location},
      %w(1.8 1.9 2.0 2.1 2.2 2.3 ios mac))
  end

  def test_not_masgn
    assert_diagnoses(
      [:error, :masgn_as_condition],
      %q{!(a, b = foo)},
      %q{  ~~~~~~~~~~  location},
      %w(1.8 1.9 2.0 2.1 2.2 2.3 ios mac))
  end

  def test_not_masgn__24
    assert_parses(
      s(:send,
        s(:begin,
          s(:masgn,
            s(:mlhs,
              s(:lvasgn, :a),
              s(:lvasgn, :b)),
          s(:lvar, :foo))), :'!'),
      %q{!(a, b = foo)},
      %q{},
      SINCE_2_4)
  end

  def test_cond_begin
    assert_parses(
      s(:if,
        s(:begin, s(:lvar, :bar)),
        s(:lvar, :foo),
        nil),
      %q{if (bar); foo; end})
  end

  def test_cond_begin_masgn
    assert_parses(
      s(:if,
        s(:begin,
          s(:lvar, :bar),
          s(:masgn,
            s(:mlhs, s(:lvasgn, :a), s(:lvasgn, :b)),
            s(:lvar, :foo))),
        nil, nil),
      %q{if (bar; a, b = foo); end})
  end

  def test_cond_begin_and_or_masgn
    assert_diagnoses(
      [:error, :masgn_as_condition],
      %q{if foo && (a, b = bar); end},
      %q{           ~~~~~~~~~~ location},
      %w(1.9 2.0 2.1 2.2 2.3 ios mac))

    assert_diagnoses(
      [:error, :masgn_as_condition],
      %q{if foo || (a, b = bar); end},
      %q{           ~~~~~~~~~~ location},
      %w(1.9 2.0 2.1 2.2 2.3 ios mac))

    assert_parses(
      s(:if,
        s(:and,
          s(:begin,
            s(:masgn,
              s(:mlhs,
                s(:lvasgn, :a), s(:lvasgn, :b)),
              s(:lvar, :foo))),
          s(:lvar, :bar)),
        nil, nil),
      %q{if (a, b = foo) && bar; end},
      %q{},
      %w(1.8))
  end

  def test_cond_iflipflop
    assert_parses(
      s(:if, s(:iflipflop, s(:lvar, :foo), s(:lvar, :bar)),
        nil, nil),
      %q{if foo..bar; end},
      %q{   ~~~~~~~~ expression (iflipflop)
        |      ~~ operator (iflipflop)})

    assert_parses(
      s(:if, s(:iflipflop, s(:lvar, :foo), s(:nil)),
        nil, nil),
      %q{if foo..nil; end},
      %q{   ~~~~~~~~ expression (iflipflop)
        |      ~~ operator (iflipflop)},
      %w(1.8))

    assert_parses(
      s(:if, s(:iflipflop, s(:nil), s(:lvar, :bar)),
        nil, nil),
      %q{if nil..bar; end},
      %q{   ~~~~~~~~ expression (iflipflop)
        |      ~~ operator (iflipflop)},
      %w(1.8))

    assert_parses(
      s(:not, s(:begin, s(:iflipflop, s(:lvar, :foo), s(:lvar, :bar)))),
      %q{!(foo..bar)},
      %q{  ~~~~~~~~ expression (begin.iflipflop)
        |     ~~ operator (begin.iflipflop)},
      %w(1.8))

    assert_parses(
      s(:send, s(:begin, s(:iflipflop, s(:lvar, :foo), s(:lvar, :bar))), :'!'),
      %q{!(foo..bar)},
      %q{  ~~~~~~~~ expression (begin.iflipflop)
        |     ~~ operator (begin.iflipflop)},
      SINCE_1_9)
  end

  def test_cond_iflipflop_with_endless_range
    assert_parses(
      s(:if, s(:iflipflop, s(:lvar, :foo), nil),
        nil, nil),
      %q{if foo..; end},
      %q{   ~~~~~ expression (iflipflop)
        |      ~~ operator (iflipflop)},
      SINCE_2_6)
  end

  def test_cond_iflipflop_with_beginless_range
    assert_parses(
      s(:if, s(:iflipflop, nil, s(:lvar, :bar)),
        nil, nil),
      %q{if ..bar; end},
      %q{   ~~~~~ expression (iflipflop)
        |   ~~ operator (iflipflop)},
      SINCE_2_7)
  end

  def test_cond_eflipflop
    assert_parses(
      s(:if, s(:eflipflop, s(:lvar, :foo), s(:lvar, :bar)),
        nil, nil),
      %q{if foo...bar; end},
      %q{   ~~~~~~~~~ expression (eflipflop)
        |      ~~~ operator (eflipflop)})

    assert_parses(
      s(:if, s(:eflipflop, s(:lvar, :foo), s(:nil)),
        nil, nil),
      %q{if foo...nil; end},
      %q{   ~~~~~~~~~ expression (eflipflop)
        |      ~~~ operator (eflipflop)},
      %w(1.8))

    assert_parses(
      s(:if, s(:eflipflop, s(:nil), s(:lvar, :bar)),
        nil, nil),
      %q{if nil...bar; end},
      %q{   ~~~~~~~~~ expression (eflipflop)
        |      ~~~ operator (eflipflop)},
      %w(1.8))

    assert_parses(
      s(:not, s(:begin, s(:eflipflop, s(:lvar, :foo), s(:lvar, :bar)))),
      %q{!(foo...bar)},
      %q{  ~~~~~~~~~ expression (begin.eflipflop)
        |     ~~~ operator (begin.eflipflop)},
      %w(1.8))

    assert_parses(
      s(:send, s(:begin, s(:eflipflop, s(:lvar, :foo), s(:lvar, :bar))), :'!'),
      %q{!(foo...bar)},
      %q{  ~~~~~~~~~ expression (begin.eflipflop)
        |     ~~~ operator (begin.eflipflop)},
      SINCE_1_9)
  end

  def test_cond_eflipflop_with_endless_range
    assert_parses(
      s(:if, s(:eflipflop, s(:lvar, :foo), nil),
        nil, nil),
      %q{if foo...; end},
      %q{   ~~~~~~ expression (eflipflop)
        |      ~~~ operator (eflipflop)},
      SINCE_2_6)
  end

  def test_cond_eflipflop_with_beginless_range
    assert_parses(
      s(:if, s(:eflipflop, nil, s(:lvar, :bar)),
        nil, nil),
      %q{if ...bar; end},
      %q{   ~~~~~~ expression (eflipflop)
        |   ~~~ operator (eflipflop)},
      SINCE_2_7)
  end

  def test_cond_match_current_line
    assert_parses(
      s(:if,
        s(:match_current_line,
          s(:regexp,
            s(:str, 'wat'),
            s(:regopt))),
        nil, nil),
      %q{if /wat/; end},
      %q{   ~~~~~ expression (match_current_line)})

    assert_parses(
      s(:not,
        s(:match_current_line,
          s(:regexp,
            s(:str, 'wat'),
            s(:regopt)))),
      %q{!/wat/},
      %q{ ~~~~~ expression (match_current_line)},
      %w(1.8))

    assert_parses(
      s(:send,
        s(:match_current_line,
          s(:regexp,
            s(:str, 'wat'),
            s(:regopt))),
        :'!'),
      %q{!/wat/},
      %q{ ~~~~~ expression (match_current_line)},
      SINCE_1_9)
  end

  # Case matching

  def test_case_expr
    assert_parses(
      s(:case, s(:lvar, :foo),
        s(:when, s(:str, 'bar'),
          s(:lvar, :bar)),
        nil),
      %q{case foo; when 'bar'; bar; end},
      %q{~~~~ keyword
        |          ~~~~ keyword (when)
        |                           ~~~ end
        |          ~~~~~~~~~~~~~~~ expression (when)
        |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression})
  end

  def test_case_expr_else
    assert_parses(
      s(:case, s(:lvar, :foo),
        s(:when, s(:str, 'bar'),
          s(:lvar, :bar)),
        s(:lvar, :baz)),
      %q{case foo; when 'bar'; bar; else baz; end},
      %q{~~~~ keyword
        |          ~~~~ keyword (when)
        |                           ~~~~ else
        |                                     ~~~ end
        |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression})
  end

  def test_case_cond
    assert_parses(
      s(:case, nil,
        s(:when, s(:lvar, :foo),
          s(:str, 'foo')),
        nil),
      %q{case; when foo; 'foo'; end},
      %q{~~~~ keyword
        |      ~~~~ keyword (when)
        |                       ~~~ end
        |~~~~~~~~~~~~~~~~~~~~~~~~~~ expression})
  end

  def test_case_cond_else
    assert_parses(
      s(:case, nil,
        s(:when, s(:lvar, :foo),
          s(:str, 'foo')),
        s(:str, 'bar')),
      %q{case; when foo; 'foo'; else 'bar'; end},
      %q{~~~~ keyword
        |      ~~~~ keyword (when)
        |                       ~~~~ else
        |                                   ~~~ end
        |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression})
  end

  def test_case_cond_just_else
    assert_parses(
      s(:case, nil,
        s(:str, 'bar')),
      %q{case; else 'bar'; end},
      %q{~~~~ keyword
        |      ~~~~ else
        |                  ~~~ end
        |~~~~~~~~~~~~~~~~~~~~~ expression},
      %w(1.8))
  end

  def test_when_then
    assert_parses(
      s(:case, s(:lvar, :foo),
        s(:when, s(:str, 'bar'),
          s(:lvar, :bar)),
        nil),
      %q{case foo; when 'bar' then bar; end},
      %q{          ~~~~ keyword (when)
        |                     ~~~~ begin (when)
        |          ~~~~~~~~~~~~~~~~~~~ expression (when)})
  end

  def test_when_multi
    assert_parses(
      s(:case, s(:lvar, :foo),
        s(:when, s(:str, 'bar'), s(:str, 'baz'),
          s(:lvar, :bar)),
        nil),
      %q{case foo; when 'bar', 'baz'; bar; end})
  end

  def test_when_splat
    assert_parses(
      s(:case, s(:lvar, :foo),
        s(:when,
          s(:int, 1),
          s(:splat, s(:lvar, :baz)),
          s(:lvar, :bar)),
        s(:when,
          s(:splat, s(:lvar, :foo)),
          nil),
        nil),
      %q{case foo; when 1, *baz; bar; when *foo; end},
      %q{                  ^ operator (when/1.splat)
        |                  ~~~~ expression (when/1.splat)
        |                                  ^ operator (when/2.splat)
        |                                  ~~~~ expression (when/2.splat)})
  end

  # Looping

  def test_while
    assert_parses(
      s(:while, s(:lvar, :foo), s(:send, nil, :meth)),
      %q{while foo do meth end},
      %q{~~~~~ keyword
        |          ~~ begin
        |                  ~~~ end
        |~~~~~~~~~~~~~~~~~~~~~ expression})

    assert_parses(
      s(:while, s(:lvar, :foo), s(:send, nil, :meth)),
      %q{while foo; meth end},
      %q{~~~~~ keyword
        |                ~~~ end
        |~~~~~~~~~~~~~~~~~~~ expression})
  end

  def test_while_mod
    assert_parses(
      s(:while, s(:lvar, :foo), s(:send, nil, :meth)),
      %q{meth while foo},
      %q{     ~~~~~ keyword})
  end

  def test_until
    assert_parses(
      s(:until, s(:lvar, :foo), s(:send, nil, :meth)),
      %q{until foo do meth end},
      %q{~~~~~ keyword
        |          ~~ begin
        |                  ~~~ end})

    assert_parses(
      s(:until, s(:lvar, :foo), s(:send, nil, :meth)),
      %q{until foo; meth end},
      %q{~~~~~ keyword
        |                ~~~ end})
  end

  def test_until_mod
    assert_parses(
      s(:until, s(:lvar, :foo), s(:send, nil, :meth)),
      %q{meth until foo},
      %q{     ~~~~~ keyword})
  end

  def test_while_post
    assert_parses(
      s(:while_post, s(:lvar, :foo),
        s(:kwbegin, s(:send, nil, :meth))),
      %q{begin meth end while foo},
      %q{               ~~~~~ keyword})
  end

  def test_until_post
    assert_parses(
      s(:until_post, s(:lvar, :foo),
        s(:kwbegin, s(:send, nil, :meth))),
      %q{begin meth end until foo},
      %q{               ~~~~~ keyword})
  end

  def test_while_masgn
    assert_diagnoses(
      [:error, :masgn_as_condition],
      %q{while (a, b = foo); end},
      %q{       ~~~~~~~~~~ location},
      %w(1.8 1.9 2.0 2.1 2.2 2.3 ios mac))
  end

  def test_while_mod_masgn
    assert_diagnoses(
      [:error, :masgn_as_condition],
      %q{foo while (a, b = foo)},
      %q{           ~~~~~~~~~~ location},
      %w(1.8 1.9 2.0 2.1 2.2 2.3 ios mac))
  end

  def test_for
    assert_parses(
      s(:for,
        s(:lvasgn, :a),
        s(:lvar, :foo),
        s(:send, nil, :p, s(:lvar, :a))),
      %q{for a in foo do p a; end},
      %q{~~~ keyword
        |      ~~ in
        |             ~~ begin
        |                     ~~~ end
        |~~~~~~~~~~~~~~~~~~~~~~~~ expression})

    assert_parses(
      s(:for,
        s(:lvasgn, :a),
        s(:lvar, :foo),
        s(:send, nil, :p, s(:lvar, :a))),
      %q{for a in foo; p a; end})
  end

  def test_for_mlhs
    assert_parses(
      s(:for,
        s(:mlhs,
          s(:lvasgn, :a),
          s(:lvasgn, :b)),
        s(:lvar, :foo),
        s(:send, nil, :p, s(:lvar, :a), s(:lvar, :b))),
      %q{for a, b in foo; p a, b; end},
      %q{    ~~~~ expression (mlhs)})
  end

  # Control flow commands

  def test_break
    assert_parses(
      s(:break, s(:begin, s(:lvar, :foo))),
      %q{break(foo)},
      %q{~~~~~ keyword
        |~~~~~~~~~~ expression},
      SINCE_1_9)

    assert_parses(
      s(:break, s(:begin, s(:lvar, :foo))),
      %q{break(foo)},
      %q{~~~~~ keyword
        |~~~~~~~~~~ expression},
      %w(1.8))

    assert_parses(
      s(:break, s(:lvar, :foo)),
      %q{break foo},
      %q{~~~~~ keyword
        |~~~~~~~~~ expression})

    assert_parses(
        s(:break, s(:begin)),
      %q{break()},
      %q{~~~~~ keyword
        |~~~~~~~ expression},
      SINCE_1_9)

    assert_parses(
      s(:break),
      %q{break},
      %q{~~~~~ keyword
        |~~~~~ expression})
  end

  def test_break_block
    assert_parses(
      s(:break,
        s(:block,
          s(:send, nil, :fun, s(:lvar, :foo)),
          s(:args), nil)),
      %q{break fun foo do end},
      %q{      ~~~~~~~~~~~~~~ expression (block)
        |~~~~~~~~~~~~~~~~~~~~ expression},
      ALL_VERSIONS - %w(1.8 ios))
  end

  def test_return
    assert_parses(
      s(:return, s(:begin, s(:lvar, :foo))),
      %q{return(foo)},
      %q{~~~~~~ keyword
        |~~~~~~~~~~~ expression},
      SINCE_1_9)

    assert_parses(
      s(:return, s(:begin, s(:lvar, :foo))),
      %q{return(foo)},
      %q{~~~~~~ keyword
        |~~~~~~~~~~~ expression},
      %w(1.8))

    assert_parses(
      s(:return, s(:lvar, :foo)),
      %q{return foo},
      %q{~~~~~~ keyword
        |~~~~~~~~~~ expression})

    assert_parses(
      s(:return, s(:begin)),
      %q{return()},
      %q{~~~~~~ keyword
        |~~~~~~~~ expression},
      SINCE_1_9)

    assert_parses(
      s(:return),
      %q{return},
      %q{~~~~~~ keyword
        |~~~~~~ expression})
  end

  def test_return_block
    assert_parses(
      s(:return,
        s(:block,
          s(:send, nil, :fun, s(:lvar, :foo)),
          s(:args), nil)),
      %q{return fun foo do end},
      %q{       ~~~~~~~~~~~~~~ expression (block)
        |~~~~~~~~~~~~~~~~~~~~~ expression},
      ALL_VERSIONS - %w(1.8 ios))
  end

  def test_next
    assert_parses(
      s(:next, s(:begin, s(:lvar, :foo))),
      %q{next(foo)},
      %q{~~~~ keyword
        |~~~~~~~~~ expression},
      SINCE_1_9)

    assert_parses(
      s(:next, s(:begin, s(:lvar, :foo))),
      %q{next(foo)},
      %q{~~~~ keyword
        |~~~~~~~~~ expression},
      %w(1.8))

    assert_parses(
      s(:next, s(:lvar, :foo)),
      %q{next foo},
      %q{~~~~ keyword
        |~~~~~~~~ expression})

    assert_parses(
        s(:next, s(:begin)),
      %q{next()},
      %q{~~~~ keyword
        |~~~~~~ expression},
      SINCE_1_9)

    assert_parses(
      s(:next),
      %q{next},
      %q{~~~~ keyword
        |~~~~ expression})
  end

  def test_next_block
    assert_parses(
      s(:next,
        s(:block,
          s(:send, nil, :fun, s(:lvar, :foo)),
          s(:args), nil)),
      %q{next fun foo do end},
      %q{     ~~~~~~~~~~~~~~ expression (block)
        |~~~~~~~~~~~~~~~~~~~ expression},
      ALL_VERSIONS - %w(1.8 ios))
  end

  def test_redo
    assert_parses(
      s(:redo),
      %q{redo},
      %q{~~~~ keyword
        |~~~~ expression})
  end

  # Exception handling

  def test_rescue
    assert_parses(
      s(:kwbegin,
        s(:rescue, s(:send, nil, :meth),
          s(:resbody, nil, nil, s(:lvar, :foo)),
          nil)),
      %q{begin; meth; rescue; foo; end},
      %q{~~~~~ begin
        |             ~~~~~~ keyword (rescue.resbody)
        |             ~~~~~~~~~~~ expression (rescue.resbody)
        |       ~~~~~~~~~~~~~~~~~ expression (rescue)
        |                          ~~~ end
        |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression})
  end

  def test_rescue_else
    assert_parses(
      s(:kwbegin,
        s(:rescue, s(:send, nil, :meth),
          s(:resbody, nil, nil, s(:lvar, :foo)),
          s(:lvar, :bar))),
      %q{begin; meth; rescue; foo; else; bar; end},
      %q{                          ~~~~ else (rescue)
        |       ~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression (rescue)})
  end

  def test_rescue_else_useless
    assert_parses(
      s(:kwbegin,
        s(:begin,
          s(:int, 2))),
      %q{begin; else; 2; end},
      %q{       ~~~~ begin (begin)},
      ALL_VERSIONS - SINCE_2_6)

    assert_parses(
      s(:kwbegin,
        s(:int, 1),
        s(:begin,
          s(:int, 2))),
      %q{begin; 1; else; 2; end},
      %q{          ~~~~ begin (begin)},
      ALL_VERSIONS - SINCE_2_6)

    assert_parses(
      s(:kwbegin,
        s(:int, 1),
        s(:int, 2),
        s(:begin,
          s(:int, 3))),
      %q{begin; 1; 2; else; 3; end},
      %q{             ~~~~ begin (begin)},
      ALL_VERSIONS - SINCE_2_6)

    assert_diagnoses(
      [:warning, :useless_else],
      %q{begin; 1; else; 2; end},
      %q{          ~~~~ location},
      ALL_VERSIONS - SINCE_2_6)

    assert_diagnoses(
      [:error, :useless_else],
      %q{begin; 1; else; 2; end},
      %q{          ~~~~ location},
      SINCE_2_6)

    assert_diagnoses(
      [:error, :useless_else],
      %q{begin; 1; else; end},
      %q{          ~~~~ location},
      SINCE_2_6)
  end

  def test_ensure
    assert_parses(
      s(:kwbegin,
        s(:ensure, s(:send, nil, :meth),
          s(:lvar, :bar))),
      %q{begin; meth; ensure; bar; end},
      %q{~~~~~ begin
        |             ~~~~~~ keyword (ensure)
        |       ~~~~~~~~~~~~~~~~~ expression (ensure)
        |                          ~~~ end
        |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression})
  end

  def test_ensure_empty
    assert_parses(
      s(:kwbegin,
        s(:ensure, nil, nil)),
      %q{begin ensure end},
      %q{~~~~~ begin
        |      ~~~~~~ keyword (ensure)
        |      ~~~~~~ expression (ensure)
        |             ~~~ end
        |~~~~~~~~~~~~~~~~ expression})
  end

  def test_rescue_ensure
    assert_parses(
      s(:kwbegin,
        s(:ensure,
          s(:rescue,
            s(:send, nil, :meth),
            s(:resbody, nil, nil, s(:lvar, :baz)),
            nil),
          s(:lvar, :bar))),
      %q{begin; meth; rescue; baz; ensure; bar; end},
      %q{                          ~~~~~~ keyword (ensure)
        |       ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression (ensure)
        |             ~~~~~~ keyword (ensure.rescue.resbody)
        |       ~~~~~~~~~~~~~~~~~ expression (ensure.rescue)})
  end

  def test_rescue_else_ensure
    assert_parses(
      s(:kwbegin,
        s(:ensure,
          s(:rescue,
            s(:send, nil, :meth),
            s(:resbody, nil, nil, s(:lvar, :baz)),
            s(:lvar, :foo)),
          s(:lvar, :bar))),
      %q{begin; meth; rescue; baz; else foo; ensure; bar end},
      %q{                                    ~~~~~~ keyword (ensure)
        |       ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression (ensure)
        |             ~~~~~~ keyword (ensure.rescue.resbody)
        |                          ~~~~ else (ensure.rescue)
        |       ~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression (ensure.rescue)})
  end

  def test_rescue_mod
    assert_parses(
      s(:rescue,
        s(:send, nil, :meth),
        s(:resbody, nil, nil, s(:lvar, :bar)),
        nil),
      %q{meth rescue bar},
      %q{     ~~~~~~ keyword (resbody)
        |     ~~~~~~~~~~ expression (resbody)
        |~~~~~~~~~~~~~~~ expression})
  end

  def test_rescue_mod_asgn
    assert_parses(
      s(:lvasgn, :foo,
        s(:rescue,
          s(:send, nil, :meth),
          s(:resbody, nil, nil, s(:lvar, :bar)),
          nil)),
      %q{foo = meth rescue bar},
      %q{           ~~~~~~ keyword (rescue.resbody)
        |           ~~~~~~~~~~ expression (rescue.resbody)
        |      ~~~~~~~~~~~~~~~ expression (rescue)
        |~~~~~~~~~~~~~~~~~~~~~ expression})
  end

  def test_rescue_mod_masgn
    assert_parses(
      s(:masgn,
        s(:mlhs,
          s(:lvasgn, :foo),
          s(:lvasgn, :bar)),
        s(:rescue,
          s(:send, nil, :meth),
          s(:resbody, nil, nil,
            s(:array,
              s(:int, 1),
              s(:int, 2))), nil)),
      %q{foo, bar = meth rescue [1, 2]},
      %q{                ~~~~~~ keyword (rescue.resbody)
        |                ~~~~~~~~~~~~~ expression (rescue.resbody)
        |           ~~~~~~~~~~~~~~~~~~ expression (rescue)
        |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression},
      SINCE_2_7)
  end

  def test_rescue_mod_op_assign
    assert_parses(
      s(:op_asgn,
        s(:lvasgn, :foo), :+,
        s(:rescue,
          s(:send, nil, :meth),
          s(:resbody, nil, nil, s(:lvar, :bar)),
          nil)),
      %q{foo += meth rescue bar},
      %q{            ~~~~~~ keyword (rescue.resbody)
        |            ~~~~~~~~~~ expression (rescue.resbody)
        |       ~~~~~~~~~~~~~~~ expression (rescue)
        |~~~~~~~~~~~~~~~~~~~~~~ expression},
      SINCE_1_9)
  end

  def test_rescue_without_begin_end
    assert_parses(
      s(:block,
        s(:send, nil, :meth),
        s(:args),
        s(:rescue,
          s(:lvar, :foo),
          s(:resbody, nil, nil,
            s(:lvar, :bar)),
          nil)),
      %q{meth do; foo; rescue; bar; end},
      %q{              ~~~~~~ keyword (rescue.resbody)
        |              ~~~~~~~~~~~ expression (rescue.resbody)
        |         ~~~~~~~~~~~~~~~~ expression (rescue)},
      SINCE_2_5)
  end

  def test_resbody_list
    assert_parses(
      s(:kwbegin,
        s(:rescue,
          s(:send, nil, :meth),
          s(:resbody,
            s(:array, s(:const, nil, :Exception)),
            nil,
            s(:lvar, :bar)),
          nil)),
      %q{begin; meth; rescue Exception; bar; end})
  end

  def test_resbody_list_mrhs
    assert_parses(
      s(:kwbegin,
        s(:rescue,
          s(:send, nil, :meth),
          s(:resbody,
            s(:array,
              s(:const, nil, :Exception),
              s(:lvar, :foo)),
            nil,
            s(:lvar, :bar)),
          nil)),
      %q{begin; meth; rescue Exception, foo; bar; end})
  end

  def test_resbody_var
    assert_parses(
      s(:kwbegin,
        s(:rescue,
          s(:send, nil, :meth),
          s(:resbody, nil, s(:lvasgn, :ex), s(:lvar, :bar)),
          nil)),
      %q{begin; meth; rescue => ex; bar; end})

    assert_parses(
      s(:kwbegin,
        s(:rescue,
          s(:send, nil, :meth),
          s(:resbody, nil, s(:ivasgn, :@ex), s(:lvar, :bar)),
          nil)),
      %q{begin; meth; rescue => @ex; bar; end})
  end

  def test_resbody_list_var
    assert_parses(
      s(:kwbegin,
        s(:rescue,
          s(:send, nil, :meth),
          s(:resbody,
            s(:array, s(:lvar, :foo)),
            s(:lvasgn, :ex),
            s(:lvar, :bar)),
          nil)),
      %q{begin; meth; rescue foo => ex; bar; end})
  end

  def test_retry
    assert_parses(
      s(:retry),
      %q{retry},
      %q{~~~~~ keyword
        |~~~~~ expression})
  end

  # BEGIN and END

  def test_preexe
    assert_parses(
      s(:preexe, s(:int, 1)),
      %q{BEGIN { 1 }},
      %q{~~~~~ keyword
        |      ^ begin
        |          ^ end
        |~~~~~~~~~~~ expression})
  end

  def test_preexe_invalid
    assert_diagnoses(
      [:error, :begin_in_method],
      %q{def f; BEGIN{}; end},
      %q{       ~~~~~ location},
      # Yes. *Exclude 1.9*. Sigh.
      ALL_VERSIONS - %w(1.9 mac ios))
  end

  def test_postexe
    assert_parses(
      s(:postexe, s(:int, 1)),
      %q{END { 1 }},
      %q{~~~ keyword
        |    ^ begin
        |        ^ end
        |~~~~~~~~~ expression})
  end

  #
  # Miscellanea
  #

  def test_kwbegin_compstmt
    assert_parses(
      s(:kwbegin,
        s(:send, nil, :foo!),
        s(:send, nil, :bar!)),
      %q{begin foo!; bar! end})
  end

  def test_crlf_line_endings
    with_versions(ALL_VERSIONS) do |_ver, parser|
      source_file = Parser::Source::Buffer.new('(comments)', source: "\r\nfoo")

      range = lambda do |from, to|
        Parser::Source::Range.new(source_file, from, to)
      end

      ast = parser.parse(source_file)

      assert_equal s(:lvar, :foo),
                   ast

      assert_equal range.call(1, 4),
                   ast.loc.expression
    end
  end

  def test_begin_cmdarg
    assert_parses(
      s(:send, nil, :p,
        s(:kwbegin,
          s(:block,
            s(:send, s(:int, 1), :times),
            s(:args),
            s(:int, 1)))),
      %q{p begin 1.times do 1 end end},
      %{},
      SINCE_2_0)
  end

  def test_bug_cmdarg
    assert_parses(
      s(:send, nil, :meth,
        s(:begin,
          s(:block,
            s(:send, nil, :lambda),
            s(:args), nil))),
      %q{meth (lambda do end)},
      %q{},
      %w(1.8))

    assert_parses(
      s(:send, nil, :assert,
        s(:send, nil, :dogs)),
      %q{assert dogs})

    assert_parses(
      s(:send, nil, :assert,
        s(:kwargs,
          s(:pair, s(:sym, :do), s(:true)))),
      %q{assert do: true},
      %q{},
      SINCE_1_9)

    assert_parses(
      s(:send, nil, :f,
        s(:kwargs,
          s(:pair,
            s(:sym, :x),
            s(:block,
              s(:lambda),
              s(:args),
              s(:block,
                s(:send, nil, :meth),
                s(:args), nil))))),
      %q{f x: -> do meth do end end},
      %q{},
      SINCE_1_9)
  end

  def test_file_line_non_literals
    with_versions(ALL_VERSIONS) do |_ver, parser|
      parser.builder.emit_file_line_as_literals = false

      source_file = Parser::Source::Buffer.new('(comments)', source: "[__FILE__, __LINE__]")

      ast = parser.parse(source_file)

      assert_equal s(:array, s(:__FILE__), s(:__LINE__)), ast
    end
  end

  def test_bom
    assert_parses(
      s(:int, 1),
      %Q{\xef\xbb\xbf1}.b,
      %q{},
      %w(1.9 2.0 2.1))
  end

  def test_magic_encoding_comment
    assert_parses(
      s(:begin,
        s(:lvasgn, :"проверка", s(:int, 42)),
        s(:send, nil, :puts, s(:lvar, :"проверка"))),
      %Q{# coding:koi8-r
         \xd0\xd2\xcf\xd7\xc5\xd2\xcb\xc1 = 42
         puts \xd0\xd2\xcf\xd7\xc5\xd2\xcb\xc1}.b,
      %q{},
      %w(1.9 2.0 2.1))
  end

  def test_regexp_encoding
    assert_parses(
      s(:match_with_lvasgn,
        s(:regexp,
          s(:str, "\\xa8"),
          s(:regopt, :n)),
        s(:str, "")),
      %q{/\xa8/n =~ ""}.dup.force_encoding(Encoding::UTF_8),
      %{},
      SINCE_1_9 - SINCE_3_1)
  end

  #
  # Error recovery
  #

  def test_unknown_percent_str
    assert_diagnoses(
      [:error, :unexpected_percent_str, { :type => '%k' }],
      %q{%k[foo]},
      %q{~~ location})
  end

  def test_unterminated_embedded_doc
    assert_diagnoses(
      [:fatal, :embedded_document],
      %Q{=begin\nfoo\nend},
      %q{~~~~~~ location})

    assert_diagnoses(
      [:fatal, :embedded_document],
      %Q{=begin\nfoo\nend\n},
      %q{~~~~~~ location})
  end

  def test_codepoint_too_large
    assert_diagnoses(
      [:error, :unicode_point_too_large],
      %q{"\u{120 120000}"},
      %q{        ~~~~~~ location},
      SINCE_1_9)
  end

  def test_codepoint_surrogate
    assert_diagnoses(
      [:error, :invalid_unicode_escape],
      %q{"\u{D800}"},
      %q{    ~~~~ location})

    assert_diagnoses(
      [:error, :invalid_unicode_escape],
      %q{"\u{DFFF}"},
      %q{    ~~~~ location})

    [
      %q{"\u{D7FF}"},
      %q{"\u{E000}"},
    ].each do |code|
      refute_diagnoses(code)
    end
  end

  def test_on_error
    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tIDENTIFIER' }],
      %q{def foo(bar baz); end},
      %q{            ~~~ location})
  end

  #
  # Token and comment extraction
  #

  def assert_parses_with_comments(ast_pattern, source, comments_pattern)
    with_versions(ALL_VERSIONS) do |_ver, parser|
      source_file = Parser::Source::Buffer.new('(comments)', source: source)

      comments_pattern_here = comments_pattern.map do |(from, to)|
        range = Parser::Source::Range.new(source_file, from, to)
        Parser::Source::Comment.new(range)
      end

      ast, comments = parser.parse_with_comments(source_file)

      assert_equal ast_pattern, ast

      assert_equal comments_pattern_here, comments
    end
  end

  def test_comment_interleaved
    assert_parses_with_comments(
      s(:send, s(:int, 1), :+, s(:int, 2)),
      %Q{1 + # foo\n 2},
      [ [4, 9] ])
  end

  def test_comment_single
    assert_parses_with_comments(
      s(:send, nil, :puts),
      %Q{puts # whatever},
      [ [5, 15] ])
  end

  def test_tokenize
    with_versions(ALL_VERSIONS) do |_ver, parser|
      source_file = Parser::Source::Buffer.new('(tokenize)',
        source: "1 + # foo\n 2")

      range = lambda do |from, to|
        Parser::Source::Range.new(source_file, from, to)
      end

      ast, comments, tokens = parser.tokenize(source_file)

      assert_equal s(:send, s(:int, 1), :+, s(:int, 2)),
                   ast

      assert_equal [
                     Parser::Source::Comment.new(range.call(4, 9))
                   ], comments

      assert_equal [
                     [:tINTEGER, [ 1,       range.call(0, 1) ]],
                     [:tPLUS,    [ '+',     range.call(2, 3) ]],
                     [:tCOMMENT, [ '# foo', range.call(4, 9) ]],
                     [:tINTEGER, [ 2,       range.call(11, 12) ]],
                   ], tokens
    end
  end

  def test_tokenize_recover
    with_versions(ALL_VERSIONS) do |_ver, parser|
      source_file = Parser::Source::Buffer.new('(tokenize)',
        source: "1 + # foo\n ")

      range = lambda do |from, to|
        Parser::Source::Range.new(source_file, from, to)
      end

      ast, comments, tokens = parser.tokenize(source_file, true)

      assert_nil ast

      assert_equal [
                     Parser::Source::Comment.new(range.call(4, 9))
                   ], comments

      assert_equal [
                     [:tINTEGER, [ 1,       range.call(0, 1) ]],
                     [:tPLUS,    [ '+',     range.call(2, 3) ]],
                     [:tCOMMENT, [ '# foo', range.call(4, 9) ]],
                   ], tokens
    end
  end

  #
  # Bug-specific tests
  #

  def test_bug_cmd_string_lookahead
    assert_parses(
      s(:block,
        s(:send, nil, :desc,
          s(:str, 'foo')),
        s(:args), nil),
      %q{desc "foo" do end})
  end

  def test_bug_do_block_in_call_args
    # [ruby-core:59342] [Bug #9308]
    assert_parses(
      s(:send, nil, :bar,
        s(:def, :foo,
          s(:args),
          s(:block,
            s(:send, s(:self), :each),
            s(:args),
            nil))),
      %q{bar def foo; self.each do end end},
      %q{},
      SINCE_1_9)
  end

  def test_bug_do_block_in_cmdarg
    # [ruby-core:61950] [Bug #9726]
    assert_parses(
      s(:send, nil, :tap,
        s(:begin,
          s(:block,
            s(:send, nil, :proc),
            s(:args), nil))),
      %q{tap (proc do end)},
      %q{},
      ALL_VERSIONS - %w(1.8 mac ios))
  end

  def test_bug_interp_single
    assert_parses(
      s(:dstr, s(:begin, s(:int, 1))),
      %q{"#{1}"})

    assert_parses(
      s(:array, s(:dstr, s(:begin, s(:int, 1)))),
      %q{%W"#{1}"})
  end

  def test_bug_def_no_paren_eql_begin
    assert_parses(
      s(:def, :foo, s(:args), nil),
      %Q{def foo\n=begin\n=end\nend})
  end

  def test_bug_while_not_parens_do
    assert_parses(
      s(:while, s(:send, s(:begin, s(:true)), :"!"), nil),
      %q{while not (true) do end},
      %q{},
      SINCE_1_9)
  end

  def test_bug_rescue_empty_else
    assert_parses(
      s(:kwbegin,
        s(:rescue, nil,
          s(:resbody,
            s(:array,
              s(:const, nil, :LoadError)), nil, nil), nil)),
      %q{begin; rescue LoadError; else; end},
      %q{                         ~~~~ else (rescue)
        |       ~~~~~~~~~~~~~~~~~~~~~~ expression (rescue)})
  end

  def test_bug_def_empty_else
    assert_parses(
      s(:def, :foo, s(:args),
        s(:begin,
          s(:begin, nil))),
      %q{def foo; else; end},
      %q{},
      ALL_VERSIONS - SINCE_2_6)
  end

  def test_bug_heredoc_do
    assert_parses(
      s(:block,
        s(:send, nil, :f,
          s(:dstr)),
        s(:args), nil),
      %Q{f <<-TABLE do\nTABLE\nend})
  end

  def test_bug_ascii_8bit_in_literal
    assert_diagnoses(
      [:error, :invalid_encoding],
      %q{".\xc3."},
      %q{^^^^^^^^ location},
      ALL_VERSIONS)

    assert_diagnoses(
      [:error, :invalid_encoding],
      %q{%W"x .\xc3."},
      %q{     ^^^^^^ location},
      ALL_VERSIONS)

    assert_diagnoses(
      [:error, :invalid_encoding],
      %q{:".\xc3."},
      %q{  ^^^^^^ location},
      ALL_VERSIONS)

    assert_diagnoses(
      [:error, :invalid_encoding],
      %q{%I"x .\xc3."},
      %q{     ^^^^^^ location},
      ALL_VERSIONS - %w(1.8 1.9 ios mac))

    assert_parses(
      s(:int, 0xc3),
      %q{?\xc3},
      %q{},
      %w(1.8))

    assert_diagnoses(
      [:error, :invalid_encoding],
      %q{?\xc3},
      %q{^^^^^ location},
      SINCE_1_9)

    assert_parses(
      s(:str, "проверка"),
      %q{# coding:utf-8
         "\xD0\xBF\xD1\x80\xD0\xBE\xD0\xB2\xD0\xB5\xD1\x80\xD0\xBA\xD0\xB0"},
      %q{},
      SINCE_1_9)
  end

  def test_ruby_bug_9669
    assert_parses(
      s(:def, :a, s(:args, s(:kwarg, :b)), s(:return)),
      %Q{def a b:\nreturn\nend},
      %q{},
      SINCE_2_1)

    assert_parses(
      s(:lvasgn, :o,
        s(:hash,
          s(:pair, s(:sym, :a), s(:int, 1)))),
      %Q{o = {\na:\n1\n}},
      %q{},
      SINCE_2_1)
  end

  def test_ruby_bug_10279
    assert_parses(
      s(:hash,
        s(:pair, s(:sym, :a),
        s(:if, s(:true), s(:int, 42), nil))),
      %q{{a: if true then 42 end}},
      %q{},
      SINCE_2_1)
  end

  def test_ruby_bug_10653
    assert_parses(
      s(:if,
        s(:true),
        s(:block,
          s(:send,
            s(:int, 1), :tap),
          s(:args,
            s(:procarg0, s(:arg, :n))),
          s(:send, nil, :p,
            s(:lvar, :n))),
        s(:int, 0)),
      %q{true ? 1.tap do |n| p n end : 0},
      %q{},
      SINCE_1_9)

    assert_parses(
      s(:if,
        s(:true),
        s(:block,
          s(:send,
            s(:int, 1), :tap),
          s(:args,
            s(:arg, :n)),
          s(:send, nil, :p,
            s(:lvar, :n))),
        s(:int, 0)),
      %q{true ? 1.tap do |n| p n end : 0},
      %q{},
      %w(1.8))

    assert_parses(
      s(:if,
        s(:false),
        s(:block,
          s(:send, nil, :raise),
          s(:args), nil),
        s(:block,
          s(:send, nil, :tap),
          s(:args), nil)),
      %q{false ? raise {} : tap {}},
      %q{},
      ALL_VERSIONS)

    assert_parses(
      s(:if,
        s(:false),
        s(:block,
          s(:send, nil, :raise),
          s(:args), nil),
        s(:block,
          s(:send, nil, :tap),
          s(:args), nil)),
      %q{false ? raise do end : tap do end},
      %q{},
      ALL_VERSIONS)
  end

  def test_ruby_bug_11107
    assert_parses(
      s(:send, nil, :p,
        s(:block,
          s(:lambda),
          s(:args),
          s(:block, s(:send, nil, :a), s(:args), nil))),
      %q{p ->() do a() do end end},
      %q{},
      SINCE_2_1) # no 1.9 backport
  end

  def test_ruby_bug_11380
    assert_parses(
      s(:block,
        s(:send, nil, :p,
          s(:block,
            s(:lambda),
            s(:args),
            s(:sym, :hello)),
          s(:kwargs,
            s(:pair, s(:sym, :a), s(:int, 1)))),
        s(:args),
        nil),
      %q{p -> { :hello }, a: 1 do end},
      %q{},
      SINCE_2_1) # no 1.9 backport
  end

  def test_ruby_bug_11873_a
    [[":e",   s(:sym, :e)],
     ["1",    s(:int, 1)],
     ["1.0",  s(:float, 1.0)],
     ["1.0r", s(:rational, Rational(1, 1))],
     ["1.0i", s(:complex,  Complex(0.0, 1.0))]].each do |code, node|
      expect_a = \
        s(:block,
          s(:send, nil, :a,
            s(:block,
              s(:send, nil, :b),
              s(:args),
              s(:send, nil, :c,
                s(:send, nil, :d))),
            node),
          s(:args), nil)
      assert_parses(
        expect_a,
        %Q{a b{c d}, #{code} do end},
        %q{},
        SINCE_2_4)
      assert_parses(
        expect_a,
        %Q{a b{c(d)}, #{code} do end},
        %q{},
        SINCE_2_4)

      expect_b = \
        s(:block,
          s(:send, nil, :a,
            s(:send, nil, :b,
              s(:send, nil, :c,
                s(:send, nil, :d))),
            node),
          s(:args), nil)
      assert_parses(
        expect_b,
        %Q{a b(c d), #{code} do end},
        %q{},
        SINCE_2_4)
      assert_parses(
        expect_b,
        %Q{a b(c(d)), #{code} do end},
        %q{},
        SINCE_2_4)
    end
  end

  def test_ruby_bug_11873_b
    assert_parses(
      s(:block,
        s(:send, nil, :p,
          s(:block,
            s(:send, nil, :p),
            s(:args),
            s(:begin,
              s(:send, nil, :p,
                s(:send, nil, :p)),
              s(:send, nil, :p,
                s(:send, nil, :p)))),
          s(:send, nil, :tap)),
        s(:args), nil),
      %q{p p{p(p);p p}, tap do end},
      %q{},
      SINCE_2_4)
  end

  def test_ruby_bug_11989
    assert_parses(
      s(:send, nil, :p,
        s(:str, "x\n   y\n")),
      %Q{p <<~"E"\n  x\\n   y\nE},
      %q{},
      SINCE_2_3)
  end

  def test_ruby_bug_11990
    assert_parses(
      s(:send, nil, :p,
        s(:dstr,
          s(:str, "x\n"),
          s(:str, "  y"))),
      %Q{p <<~E "  y"\n  x\nE},
      %q{},
      SINCE_2_3)
  end

  def test_ruby_bug_12073
    assert_parses(
      s(:begin,
        s(:lvasgn, :a,
          s(:int, 1)),
        s(:send, nil, :a,
          s(:kwargs,
            s(:pair,
              s(:sym, :b),
              s(:int, 1))))),
      %q{a = 1; a b: 1},
      %q{},
      SINCE_1_9)

    assert_parses(
      s(:def, :foo,
        s(:args,
          s(:arg, :raise)),
        s(:send, nil, :raise,
          s(:const,
            s(:const, nil, :A), :B),
          s(:str, ""))),
      %q{def foo raise; raise A::B, ''; end},
      %q{},
      SINCE_1_9)
  end

  def test_ruby_bug_12402
    assert_parses(
      s(:lvasgn, :foo,
        s(:rescue,
          s(:send, nil, :raise,
            s(:lvar, :bar)),
          s(:resbody, nil, nil,
            s(:nil)), nil)),
      %q{foo = raise(bar) rescue nil},
      %q{},
      SINCE_2_4)

    assert_parses(
      s(:op_asgn,
        s(:lvasgn, :foo), :+,
        s(:rescue,
          s(:send, nil, :raise,
            s(:lvar, :bar)),
          s(:resbody, nil, nil,
            s(:nil)), nil)),
      %q{foo += raise(bar) rescue nil},
      %q{},
      SINCE_2_4)

    assert_parses(
      s(:op_asgn,
        s(:indexasgn,
          s(:lvar, :foo),
          s(:int, 0)), :+,
        s(:rescue,
          s(:send, nil, :raise,
            s(:lvar, :bar)),
          s(:resbody, nil, nil,
            s(:nil)), nil)),
      %q{foo[0] += raise(bar) rescue nil},
      %q{},
      SINCE_2_4)

    assert_parses(
      s(:op_asgn,
        s(:send,
          s(:lvar, :foo), :m), :+,
        s(:rescue,
          s(:send, nil, :raise,
            s(:lvar, :bar)),
          s(:resbody, nil, nil,
            s(:nil)), nil)),
      %q{foo.m += raise(bar) rescue nil},
      %q{},
      SINCE_2_4)

    assert_parses(
      s(:op_asgn,
        s(:send,
          s(:lvar, :foo), :m), :+,
        s(:rescue,
          s(:send, nil, :raise,
            s(:lvar, :bar)),
          s(:resbody, nil, nil,
            s(:nil)), nil)),
      %q{foo::m += raise(bar) rescue nil},
      %q{},
      SINCE_2_4)

    assert_parses(
      s(:op_asgn,
        s(:send,
          s(:lvar, :foo), :C), :+,
        s(:rescue,
          s(:send, nil, :raise,
            s(:lvar, :bar)),
          s(:resbody, nil, nil,
            s(:nil)), nil)),
      %q{foo.C += raise(bar) rescue nil},
      %q{},
      SINCE_2_4)

    assert_parses(
      s(:or_asgn,
        s(:casgn,
          s(:lvar, :foo), :C),
        s(:rescue,
          s(:send, nil, :raise,
            s(:lvar, :bar)),
          s(:resbody, nil, nil,
            s(:nil)), nil)),
      %q{foo::C ||= raise(bar) rescue nil},
      %q{},
      SINCE_2_4)

    assert_parses(
      s(:lvasgn, :foo,
        s(:rescue,
          s(:send, nil, :raise,
            s(:lvar, :bar)),
          s(:resbody, nil, nil,
            s(:nil)), nil)),
      %q{foo = raise bar rescue nil},
      %q{},
      SINCE_2_4)

    assert_parses(
      s(:op_asgn,
        s(:lvasgn, :foo), :+,
        s(:rescue,
          s(:send, nil, :raise,
            s(:lvar, :bar)),
          s(:resbody, nil, nil,
            s(:nil)), nil)),
      %q{foo += raise bar rescue nil},
      %q{},
      SINCE_2_4)

    assert_parses(
      s(:op_asgn,
        s(:indexasgn,
          s(:lvar, :foo),
          s(:int, 0)), :+,
        s(:rescue,
          s(:send, nil, :raise,
            s(:lvar, :bar)),
          s(:resbody, nil, nil,
            s(:nil)), nil)),
      %q{foo[0] += raise bar rescue nil},
      %q{},
      SINCE_2_4)

    assert_parses(
      s(:op_asgn,
        s(:send,
          s(:lvar, :foo), :m), :+,
        s(:rescue,
          s(:send, nil, :raise,
            s(:lvar, :bar)),
          s(:resbody, nil, nil,
            s(:nil)), nil)),
      %q{foo.m += raise bar rescue nil},
      %q{},
      SINCE_2_4)

    assert_parses(
      s(:op_asgn,
        s(:send,
          s(:lvar, :foo), :m), :+,
        s(:rescue,
          s(:send, nil, :raise,
            s(:lvar, :bar)),
          s(:resbody, nil, nil,
            s(:nil)), nil)),
      %q{foo::m += raise bar rescue nil},
      %q{},
      SINCE_2_4)

    assert_parses(
      s(:op_asgn,
        s(:send,
          s(:lvar, :foo), :C), :+,
        s(:rescue,
          s(:send, nil, :raise,
            s(:lvar, :bar)),
          s(:resbody, nil, nil,
            s(:nil)), nil)),
      %q{foo.C += raise bar rescue nil},
      %q{},
      SINCE_2_4)

    assert_parses(
      s(:or_asgn,
        s(:casgn,
          s(:lvar, :foo), :C),
        s(:rescue,
          s(:send, nil, :raise,
            s(:lvar, :bar)),
          s(:resbody, nil, nil,
            s(:nil)), nil)),
      %q{foo::C ||= raise bar rescue nil},
      %q{},
      SINCE_2_4)
  end

  def test_ruby_bug_12669
    assert_parses(
      s(:lvasgn, :a,
        s(:lvasgn, :b,
          s(:send, nil, :raise,
            s(:sym, :x)))),
      %q{a = b = raise :x},
      %q{},
      SINCE_2_0)

    assert_parses(
      s(:op_asgn, s(:lvasgn, :a), :+,
        s(:lvasgn, :b,
          s(:send, nil, :raise,
            s(:sym, :x)))),
      %q{a += b = raise :x},
      %q{},
      SINCE_2_4)

    assert_parses(
      s(:lvasgn, :a,
        s(:op_asgn, s(:lvasgn, :b), :+,
          s(:send, nil, :raise,
            s(:sym, :x)))),
      %q{a = b += raise :x},
      %q{},
      SINCE_2_4)

    assert_parses(
      s(:op_asgn, s(:lvasgn, :a), :+,
        s(:op_asgn, s(:lvasgn, :b), :+,
          s(:send, nil, :raise,
            s(:sym, :x)))),
      %q{a += b += raise :x},
      %q{},
      SINCE_2_4)
  end

  def test_ruby_bug_12686
    assert_parses(
      s(:send, nil, :f,
        s(:begin,
          s(:rescue,
            s(:send, nil, :g),
            s(:resbody, nil, nil,
              s(:nil)), nil))),
      %q{f (g rescue nil)},
      %q{},
      SINCE_2_4)

    assert_diagnoses(
      [:error, :unexpected_token, {:token => 'kRESCUE_MOD'}],
      %q{f(g rescue nil)},
      %q{    ^^^^^^ location})
  end

  def test_ruby_bug_11873
    # strings
    assert_parses(
      s(:block,
        s(:send, nil, :a,
          s(:block,
            s(:send, nil, :b),
            s(:args),
            s(:send, nil, :c, s(:send, nil, :d))),
          s(:str, "x")),
        s(:args),
        nil),
      %q{a b{c d}, "x" do end},
      %q{},
      SINCE_2_4)

    assert_parses(
      s(:block,
        s(:send, nil, :a,
          s(:send, nil, :b,
            s(:send, nil, :c,
              s(:send, nil, :d))),
          s(:str, "x")),
        s(:args),
        nil),
      %q{a b(c d), "x" do end},
      %q{},
      SINCE_2_4)

    assert_parses(
      s(:block,
        s(:send, nil, :a,
          s(:block,
            s(:send, nil, :b),
            s(:args),
            s(:send, nil, :c,
              s(:send, nil, :d))),
          s(:str, "x")),
        s(:args), nil),
      %q{a b{c(d)}, "x" do end},
      %q{},
      SINCE_2_4)

    assert_parses(
      s(:block,
        s(:send, nil, :a,
          s(:send, nil, :b,
            s(:send, nil, :c,
              s(:send, nil, :d))),
          s(:str, "x")),
        s(:args), nil),
      %q{a b(c(d)), "x" do end},
      %q{},
      SINCE_2_4)

    # regexps without options
    assert_parses(
      s(:block,
        s(:send, nil, :a,
          s(:block,
            s(:send, nil, :b),
            s(:args),
            s(:send, nil, :c, s(:send, nil, :d))),
          s(:regexp, s(:str, "x"), s(:regopt))),
        s(:args),
        nil),
      %q{a b{c d}, /x/ do end},
      %q{},
      SINCE_2_4)

    assert_parses(
      s(:block,
        s(:send, nil, :a,
          s(:send, nil, :b,
            s(:send, nil, :c,
              s(:send, nil, :d))),
          s(:regexp, s(:str, "x"), s(:regopt))),
        s(:args),
        nil),
      %q{a b(c d), /x/ do end},
      %q{},
      SINCE_2_4)

    assert_parses(
      s(:block,
        s(:send, nil, :a,
          s(:block,
            s(:send, nil, :b),
            s(:args),
            s(:send, nil, :c,
              s(:send, nil, :d))),
          s(:regexp, s(:str, "x"), s(:regopt))),
        s(:args), nil),
      %q{a b{c(d)}, /x/ do end},
      %q{},
      SINCE_2_4)

    assert_parses(
      s(:block,
        s(:send, nil, :a,
          s(:send, nil, :b,
            s(:send, nil, :c,
              s(:send, nil, :d))),
          s(:regexp, s(:str, "x"), s(:regopt))),
        s(:args), nil),
      %q{a b(c(d)), /x/ do end},
      %q{},
      SINCE_2_4)

    # regexps with options
    assert_parses(
      s(:block,
        s(:send, nil, :a,
          s(:block,
            s(:send, nil, :b),
            s(:args),
            s(:send, nil, :c, s(:send, nil, :d))),
          s(:regexp, s(:str, "x"), s(:regopt, :m))),
        s(:args),
        nil),
      %q{a b{c d}, /x/m do end},
      %q{},
      SINCE_2_4)

    assert_parses(
      s(:block,
        s(:send, nil, :a,
          s(:send, nil, :b,
            s(:send, nil, :c,
              s(:send, nil, :d))),
          s(:regexp, s(:str, "x"), s(:regopt, :m))),
        s(:args),
        nil),
      %q{a b(c d), /x/m do end},
      %q{},
      SINCE_2_4)

    assert_parses(
      s(:block,
        s(:send, nil, :a,
          s(:block,
            s(:send, nil, :b),
            s(:args),
            s(:send, nil, :c,
              s(:send, nil, :d))),
          s(:regexp, s(:str, "x"), s(:regopt, :m))),
        s(:args), nil),
      %q{a b{c(d)}, /x/m do end},
      %q{},
      SINCE_2_4)

    assert_parses(
      s(:block,
        s(:send, nil, :a,
          s(:send, nil, :b,
            s(:send, nil, :c,
              s(:send, nil, :d))),
          s(:regexp, s(:str, "x"), s(:regopt, :m))),
        s(:args), nil),
      %q{a b(c(d)), /x/m do end},
      %q{},
      SINCE_2_4)
  end

  def test_parser_bug_198
    assert_parses(
      s(:array,
        s(:regexp,
          s(:str, "()\\1"),
          s(:regopt)),
        s(:str, "#")),
      %q{[/()\\1/, ?#]},
      %q{},
      SINCE_1_9 - SINCE_3_1)
  end

  def test_parser_bug_272
    assert_parses(
      s(:block,
        s(:send, nil, :a,
          s(:ivar, :@b)),
        s(:args,
          s(:procarg0, s(:arg, :c))), nil),
      %q{a @b do |c|;end},
      %q{},
      SINCE_1_9)

    assert_parses(
      s(:block,
        s(:send, nil, :a,
          s(:ivar, :@b)),
        s(:args,
          s(:arg, :c)), nil),
      %q{a @b do |c|;end},
      %q{},
      %w(1.8))
  end

  def test_bug_lambda_leakage
    assert_parses(
      s(:begin,
        s(:block,
          s(:lambda),
          s(:args,
            s(:arg, :scope)), nil),
        s(:send, nil, :scope)),
      %q{->(scope) {}; scope},
      %q{},
      SINCE_1_9)
  end

  def test_bug_regex_verification
    assert_parses(
      s(:regexp, s(:str, "#)"), s(:regopt, :x)),
      %Q{/#)/x})
  end

  def test_bug_do_block_in_hash_brace
    assert_parses(
      s(:send, nil, :p,
        s(:sym, :foo),
        s(:hash,
          s(:pair,
            s(:sym, :a),
            s(:block,
              s(:send, nil, :proc),
              s(:args), nil)),
          s(:pair,
            s(:sym, :b),
            s(:block,
              s(:send, nil, :proc),
              s(:args), nil)))),
      %q{p :foo, {a: proc do end, b: proc do end}},
      %q{},
      SINCE_2_3)

    assert_parses(
      s(:send, nil, :p,
        s(:sym, :foo),
        s(:hash,
          s(:pair,
            s(:sym, :a),
            s(:block,
              s(:send, nil, :proc),
              s(:args), nil)),
          s(:pair,
            s(:sym, :b),
            s(:block,
              s(:send, nil, :proc),
              s(:args), nil)))),
      %q{p :foo, {:a => proc do end, b: proc do end}},
      %q{},
      SINCE_2_3)

    assert_parses(
      s(:send, nil, :p,
        s(:sym, :foo),
        s(:hash,
          s(:pair,
            s(:sym, :a),
            s(:block,
              s(:send, nil, :proc),
              s(:args), nil)),
          s(:pair,
            s(:sym, :b),
            s(:block,
              s(:send, nil, :proc),
              s(:args), nil)))),
      %q{p :foo, {"a": proc do end, b: proc do end}},
      %q{},
      SINCE_2_3)

    assert_parses(
      s(:send, nil, :p,
        s(:sym, :foo),
        s(:hash,
          s(:pair,
            s(:block,
              s(:send, nil, :proc),
              s(:args), nil),
            s(:block,
              s(:send, nil, :proc),
              s(:args), nil)),
          s(:pair,
            s(:sym, :b),
            s(:block,
              s(:send, nil, :proc),
              s(:args), nil)))),
      %q{p :foo, {proc do end => proc do end, b: proc do end}},
      %q{},
      SINCE_2_3)

    assert_parses(
      s(:send, nil, :p,
        s(:sym, :foo),
        s(:hash,
          s(:kwsplat,
            s(:block,
              s(:send, nil, :proc),
              s(:args), nil)),
          s(:pair,
            s(:sym, :b),
            s(:block,
              s(:send, nil, :proc),
              s(:args), nil)))),
      %q{p :foo, {** proc do end, b: proc do end}},
      %q{},
      SINCE_2_3)
  end

  def test_lparenarg_after_lvar__since_25
    assert_parses(
      s(:send, nil, :meth,
        s(:send,
          s(:begin,
            s(:float, -1.3)), :abs)),
      %q{meth (-1.3).abs},
      %q{},
      ALL_VERSIONS - SINCE_2_5)

    assert_parses(
      s(:send,
        s(:send, nil, :foo,
          s(:float, -1.3)), :abs),
      %q{foo (-1.3).abs},
      %q{},
      ALL_VERSIONS - SINCE_2_5)

    assert_parses(
      s(:send, nil, :meth,
        s(:send,
          s(:begin,
            s(:float, -1.3)), :abs)),
      %q{meth (-1.3).abs},
      %q{},
      SINCE_2_5)

    assert_parses(
      s(:send, nil, :foo,
        s(:send,
          s(:begin,
            s(:float, -1.3)), :abs)),
      %q{foo (-1.3).abs},
      %q{},
      SINCE_2_5)
  end

  def test_context_class
    [
      %q{class A; get_context; end},
      %q{class A < B; get_context; end}
    ].each do |code|
      assert_context([:in_class], code, ALL_VERSIONS - SINCE_3_4)
      assert_context([:in_class, :cant_return], code, SINCE_3_4)
    end
  end

  def test_context_module
    assert_context(
      [:in_class],
      %q{module M; get_context; end},
      ALL_VERSIONS - SINCE_3_4)
    assert_context(
      [:in_class, :cant_return],
      %q{module M; get_context; end},
      SINCE_3_4)
  end

  def test_context_sclass
    [
      %q{class << foo; get_context; end},
      %q{class A; class << self; get_context; end; end}
    ].each do |code|
      assert_context([:cant_return], code, SINCE_3_4)
    end
  end

  def test_context_def
    assert_context(
      [:in_def],
      %q{def m; get_context; end},
      ALL_VERSIONS)

    assert_context(
      [:in_def],
      %q{def m() = get_context},
      SINCE_3_0)

    assert_context(
      [:in_def],
      %q{def self.m; get_context; end},
      ALL_VERSIONS)

    assert_context(
      [:in_def],
      %q{def self.m() = get_context},
      SINCE_3_0)
  end

  def test_context_cmd_brace_block
    [
      'tap foo { get_context }',
      'foo.tap foo { get_context }',
      'foo::tap foo { get_context }'
    ].each do |code|
      assert_context([:in_block], code, ALL_VERSIONS)
    end
  end

  def test_context_brace_block
    [
      'tap { get_context }',
      'foo.tap { get_context }',
      'foo::tap { get_context }',
      'tap do get_context end',
      'foo.tap do get_context end',
      'foo::tap do get_context end'
    ].each do |code|
      assert_context([:in_block], code, ALL_VERSIONS)
    end
  end

  def test_context_do_block
    [
      %q{tap 1 do get_context end},
      %q{foo.tap do get_context end},
      %q{foo::tap do get_context end}
    ].each do |code|
      assert_context([:in_block], code, ALL_VERSIONS)
    end
  end

  def test_context_lambda
    [
      '->() { get_context }',
      '->() do get_context end',
      '-> { get_context }',
      '-> do get_context end',
      '->(a = get_context) {}',
      '->(a = get_context) do end'
    ].each do |code|
      assert_context([:in_lambda], code, SINCE_1_9)
    end
  end

  def test_return_in_class
    assert_parses(
      s(:class,
        s(:const, nil, :A), nil,
        s(:return)),
      %q{class A; return; end},
      %q{},
      ALL_VERSIONS - SINCE_2_5)

    assert_diagnoses(
      [:error, :invalid_return, {}],
      %q{class A; return; end},
      %q{         ^^^^^^ location},
      SINCE_2_5)

    [
      %q{def m; return; end},
      %q{tap { return }},
      %q{class A; class << self; def m; return; end; end; end},
      %q{class A; def m; return; end; end},
    ].each do |code|
      refute_diagnoses(code, ALL_VERSIONS)
    end

    [
      %q{class << foo; return; end},
      %q{class A; class << self; return; end; end},
    ].each do |code|
      refute_diagnoses(code, ALL_VERSIONS - SINCE_3_4)
    end

    [
      %q{-> do return end},
      %q{class A; -> do return end; end},
    ].each do |code|
      refute_diagnoses(code, SINCE_1_9)
    end
  end

  def test_return_in_sclass_since_34
    assert_diagnoses(
      [:error, :invalid_return, {}],
      %q{class << foo; return; end},
      %q{              ^^^^^^ location},
      SINCE_3_4)
    
    assert_diagnoses(
      [:error, :invalid_return, {}],
      %q{class A; class << self; return; end; end},
      %q{                        ^^^^^^ location},
      SINCE_3_4)
  end

  def test_method_definition_in_while_cond
    assert_parses(
      s(:while,
        s(:def, :foo,
          s(:args),
          s(:block,
            s(:send, nil, :tap),
            s(:args), nil)),
        s(:break)),
      %q{while def foo; tap do end; end; break; end},
      %q{},
      SINCE_2_5)

    assert_parses(
      s(:while,
        s(:defs,
          s(:self), :foo,
          s(:args),
          s(:block,
            s(:send, nil, :tap),
            s(:args), nil)),
        s(:break)),
      %q{while def self.foo; tap do end; end; break; end},
      %q{},
      SINCE_2_5)

    assert_parses(
      s(:while,
        s(:def, :foo,
          s(:args,
            s(:optarg, :a,
              s(:block,
                s(:send, nil, :tap),
                s(:args), nil))), nil),
        s(:break)),
      %q{while def foo a = tap do end; end; break; end},
      %q{},
      SINCE_2_5)

    assert_parses(
      s(:while,
        s(:defs,
          s(:self), :foo,
          s(:args,
            s(:optarg, :a,
              s(:block,
                s(:send, nil, :tap),
                s(:args), nil))), nil),
        s(:break)),
      %q{while def self.foo a = tap do end; end; break; end},
      %q{},
      SINCE_2_5)
  end

  def test_class_definition_in_while_cond
    assert_parses(
      s(:while,
        s(:class,
          s(:const, nil, :Foo), nil,
          s(:block,
            s(:send, nil, :tap),
            s(:args), nil)),
        s(:break)),
      %q{while class Foo; tap do end; end; break; end},
      %q{},
      SINCE_2_5)

    assert_parses(
      s(:while,
        s(:class,
          s(:const, nil, :Foo), nil,
          s(:lvasgn, :a,
            s(:block,
              s(:send, nil, :tap),
              s(:args), nil))),
        s(:break)),
      %q{while class Foo a = tap do end; end; break; end},
      %q{},
      SINCE_2_5)

    assert_parses(
      s(:while,
        s(:sclass,
          s(:self),
          s(:block,
            s(:send, nil, :tap),
            s(:args), nil)),
        s(:break)),
      %q{while class << self; tap do end; end; break; end},
      %q{},
      SINCE_2_5)

    assert_parses(
      s(:while,
        s(:sclass,
          s(:self),
          s(:lvasgn, :a,
            s(:block,
              s(:send, nil, :tap),
              s(:args), nil))),
        s(:break)),
      %q{while class << self; a = tap do end; end; break; end},
      %q{},
      SINCE_2_5)
  end

  def test_rescue_in_lambda_block
    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'kRESCUE'}],
      %q{-> do rescue; end},
      %q{      ~~~~~~ location},
      SINCE_1_9 - SINCE_2_6)

    assert_parses(
      s(:block,
        s(:lambda),
        s(:args),
        s(:rescue, nil,
          s(:resbody, nil, nil, nil), nil)),
      %q{-> do rescue; end},
      %q{      ~~~~~~ keyword (rescue.resbody)},
      SINCE_2_6)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'kRESCUE'}],
      %q{-> { rescue; }},
      %q{     ~~~~~~ location},
      SINCE_1_9)
  end

  def test_ruby_bug_13547
    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tLCURLY' }],
      %q{m "x" {}},
      %q{      ^ location},
      SINCE_2_4)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tLCURLY' }],
      %q{m "#{'x'}" {}},
      %q{           ^ location},
      SINCE_2_4)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tLCURLY' }],
      %q{m 1 {}},
      %q{    ^ location},
      SINCE_2_4)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tLCURLY' }],
      %q{m 1.0 {}},
      %q{      ^ location},
      SINCE_2_4)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tLCURLY' }],
      %q{m 1r {}},
      %q{     ^ location},
      SINCE_2_4)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tLCURLY' }],
      %q{m 1i {}},
      %q{     ^ location},
      SINCE_2_4)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tLCURLY' }],
      %q{m :m {}},
      %q{     ^ location},
      SINCE_2_4)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tLCURLY' }],
      %q{m :"#{m}" {}},
      %q{          ^ location},
      SINCE_2_4)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tLCURLY' }],
      %q{m %[] {}},
      %q{      ^ location},
      SINCE_2_4)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tLCURLY' }],
      %q{m 0..1 {}},
      %q{       ^ location},
      SINCE_2_4)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tLCURLY' }],
      %q{m 0...1 {}},
      %q{        ^ location},
      SINCE_2_4)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tLCURLY' }],
      %q{m [] {}},
      %q{     ^ location},
      SINCE_2_5)

    assert_parses(
      s(:block,
        s(:index,
          s(:send, nil, :meth)),
        s(:args), nil),
      %q{meth[] {}},
      %q{},
      SINCE_2_5
    )

    assert_diagnoses_many(
      [
        [:warning, :ambiguous_literal],
        [:error, :unexpected_token, { :token => 'tLCURLY' }]
      ],
      %q{m /foo/ {}},
      %w(2.4 2.5 2.6 2.7))

    assert_diagnoses_many(
      [
        [:warning, :ambiguous_literal],
        [:error, :unexpected_token, { :token => 'tLCURLY' }]
      ],
      %q{m /foo/x {}},
      %w(2.4 2.5 2.6 2.7))
  end

  def test_bug_447
    assert_parses(
      s(:block,
        s(:send, nil, :m,
          s(:array)),
        s(:args), nil),
      %q{m [] do end},
      %q{},
      ALL_VERSIONS)

    assert_parses(
      s(:block,
        s(:send, nil, :m,
          s(:array),
          s(:int, 1)),
        s(:args), nil),
      %q{m [], 1 do end},
      %q{},
      ALL_VERSIONS)
  end

  def test_bug_435
    assert_parses(
      s(:dstr,
        s(:begin,
          s(:block,
            s(:lambda),
            s(:args,
              s(:arg, :foo)), nil))),
      %q{"#{-> foo {}}"},
      %q{},
      SINCE_1_9)
  end

  def test_bug_452
    assert_parses(
      s(:begin,
        s(:send, nil, :td,
          s(:send,
            s(:begin,
              s(:int, 1500)), :toString)),
        s(:block,
          s(:send,
            s(:send, nil, :td), :num),
          s(:args), nil)),
      %q{td (1_500).toString(); td.num do; end},
      %q{},
      ALL_VERSIONS)
  end

  def test_bug_466
    assert_parses(
      s(:block,
        s(:send, nil, :foo,
          s(:dstr,
            s(:begin,
              s(:send,
                s(:begin,
                  s(:send,
                    s(:int, 1), :+,
                    s(:int, 1))), :to_i)))),
        s(:args), nil),
      %q{foo "#{(1+1).to_i}" do; end},
      %q{},
      ALL_VERSIONS)
  end

  def test_bug_473
    assert_parses(
      s(:send, nil, :m,
        s(:dstr,
          s(:begin,
            s(:array)))),
      %q{m "#{[]}"},
      %q{},
      ALL_VERSIONS)
  end

  def test_bug_480
    assert_parses(
      s(:send, nil, :m,
        s(:dstr,
          s(:begin),
          s(:begin,
            s(:begin)))),
      %q{m "#{}#{()}"},
      %q{},
      ALL_VERSIONS)
  end

  def test_bug_481
    assert_parses(
      s(:begin,
        s(:send, nil, :m,
          s(:def, :x,
            s(:args), nil)),
        s(:block,
          s(:send,
            s(:int, 1), :tap),
          s(:args), nil)),
      %q{m def x(); end; 1.tap do end},
      %q{},
      ALL_VERSIONS)
  end

  def test_parser_bug_490
    assert_parses(
      s(:def, :m,
        s(:args),
        s(:sclass,
          s(:self),
          s(:class,
            s(:const, nil, :C), nil, nil))),
      %q{def m; class << self; class C; end; end; end},
      %q{},
      ALL_VERSIONS)

    assert_parses(
      s(:def, :m,
        s(:args),
        s(:sclass,
          s(:self),
          s(:module,
            s(:const, nil, :M), nil))),
      %q{def m; class << self; module M; end; end; end},
      %q{},
      ALL_VERSIONS)

    assert_parses(
      s(:def, :m,
        s(:args),
        s(:sclass,
          s(:self),
          s(:casgn, nil, :A,
            s(:nil)))),
      %q{def m; class << self; A = nil; end; end},
      %q{},
      ALL_VERSIONS)
  end

  def test_slash_newline_in_heredocs
    assert_parses(
      s(:dstr,
        s(:str, "1 2\n"),
        s(:str, "3\n")),
      %Q{<<~E\n    1 \\\n    2\n    3\nE\n},
      %q{},
      SINCE_2_3)

    assert_parses(
      s(:dstr,
        s(:str, "    1     2\n"),
        s(:str, "    3\n")),
      %Q{<<-E\n    1 \\\n    2\n    3\nE\n},
      %q{},
      ALL_VERSIONS)
  end

  def test_ambiuous_quoted_label_in_ternary_operator
    assert_parses(
      s(:if,
        s(:send, nil, :a),
        s(:send,
          s(:send, nil, :b), :&,
          s(:str, '')),
        s(:nil)),
      %q{a ? b & '': nil},
      %q{},
      ALL_VERSIONS)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tLABEL_END' }],
      %q{a ? b | '': nil},
      %q{         ^~ location},
      SINCE_2_2)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tTILDE' }],
      %q{a ? b ~ '': nil},
      %q{      ^ location},
      SINCE_2_2)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tBANG' }],
      %q{a ? b ! '': nil},
      %q{      ^ location},
      SINCE_2_2)
  end

  def test_lbrace_arg_after_command_args
    assert_parses(
      s(:block,
        s(:send, nil, :let,
          s(:begin,
            s(:sym, :a))),
        s(:args),
        s(:block,
          s(:send, nil, :m),
          s(:args), nil)),
      %q{let (:a) { m do; end }},
      %q{},
      ALL_VERSIONS)
  end

  def test_ruby_bug_14690
    assert_parses(
      s(:block,
        s(:send, nil, :let,
          s(:begin)),
        s(:args),
        s(:block,
          s(:send, nil, :m,
            s(:send, nil, :a)),
          s(:args), nil)),
      %q{let () { m(a) do; end }},
      %q{},
      SINCE_2_0)
  end

  def test_parser_bug_507
    assert_parses(
      s(:lvasgn, :m,
        s(:block,
          s(:lambda),
          s(:args,
            s(:restarg, :args)), nil)),
      %q{m = -> *args do end},
      %q{},
      SINCE_1_9)
  end

  def test_parser_bug_518
    assert_parses(
      s(:class,
        s(:const, nil, :A),
        s(:const, nil, :B), nil),
      "class A < B\nend",
      %q{},
      ALL_VERSIONS)
  end

  def test_parser_bug_525
    assert_parses(
      s(:block,
        s(:send, nil, :m1,
          s(:kwargs,
            s(:pair,
              s(:sym, :k),
              s(:send, nil, :m2)))),
        s(:args),
        s(:block,
          s(:send, nil, :m3),
          s(:args), nil)),
      'm1 :k => m2 do; m3() do end; end',
      %q{},
      ALL_VERSIONS)
  end

  def test_parser_slash_slash_n_escaping_in_literals
    [
      ["'",             "'",       s(:dstr, s(:str, "a\\\n"), s(:str, "b"))  ],
      ["<<-'HERE'\n",   "\nHERE",  s(:dstr, s(:str, "a\\\n"), s(:str, "b\n"))],
      ["%q{",           "}",       s(:dstr, s(:str, "a\\\n"), s(:str, "b"))  ],
      ['"',             '"',       s(:str, "ab")                             ],
      ["<<-\"HERE\"\n", "\nHERE",  s(:str, "ab\n")                           ],
      ["%{",            "}",       s(:str, "ab")                             ],
      ["%Q{",           "}",       s(:str, "ab")                             ],
      ["%w{",           "}",       s(:array, s(:str, "a\nb"))                ],
      ["%W{",           "}",       s(:array, s(:str, "a\nb"))                ],
      ["%i{",           "}",       s(:array, s(:sym, :"a\nb"))               ],
      ["%I{",           "}",       s(:array, s(:sym, :"a\nb"))               ],
      [":'",            "'",       s(:dsym, s(:str, "a\\\n"), s(:str, "b"))  ],
      ["%s{",           "}",       s(:dsym, s(:str, "a\\\n"), s(:str, "b"))  ],
      [':"',            '"',       s(:sym, :ab)                              ],
      ['/',             '/',       s(:regexp, s(:str, "ab"), s(:regopt))     ],
      ['%r{',           '}',       s(:regexp, s(:str, "ab"), s(:regopt))     ],
      ['%x{',           '}',       s(:xstr, s(:str, "ab"))                   ],
      ['`',             '`',       s(:xstr, s(:str, "ab"))                   ],
      ["<<-`HERE`\n",   "\nHERE",  s(:xstr, s(:str, "ab\n"))                 ],
    ].each do |literal_s, literal_e, expected|
      source = literal_s + "a\\\nb" + literal_e

      assert_parses(
        expected,
        source,
        %q{},
        SINCE_2_0)
    end
  end

  def test_unterimated_heredoc_id__27
    assert_diagnoses(
      [:error, :unterminated_heredoc_id],
      %Q{<<\"EOS\n\nEOS\n},
      %q{^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :unterminated_heredoc_id],
      %Q{<<\"EOS\n\"\nEOS\n},
      %q{^ location},
      SINCE_2_7)

    %W[\r\n \n].each do |nl|
      assert_diagnoses(
        [:error, :unterminated_heredoc_id],
        %Q{<<\"\r\"#{nl}\r#{nl}},
        %q{^ location},
        SINCE_2_7)
    end
  end

  def test_numbered_args_after_27
    assert_parses(
      s(:numblock,
        s(:send, nil, :m),
        9,
        s(:send,
          s(:lvar, :_1), :+,
          s(:lvar, :_9))),
      %q{m { _1 + _9 }},
      %q{^^^^^^^^^^^^^ expression
        |    ^^ name (send/2.lvar/1)
        |    ^^ expression (send/2.lvar/1)
        |         ^^ name (send/2.lvar/2)
        |         ^^ expression (send/2.lvar/2)},
      SINCE_2_7)

    assert_parses(
      s(:numblock,
        s(:send, nil, :m),
        9,
        s(:send,
          s(:lvar, :_1), :+,
          s(:lvar, :_9))),
      %q{m do _1 + _9 end},
      %q{^^^^^^^^^^^^^^^^ expression
        |     ^^ name (send/2.lvar/1)
        |     ^^ expression (send/2.lvar/1)
        |          ^^ name (send/2.lvar/2)
        |          ^^ expression (send/2.lvar/2)},
      SINCE_2_7)

    # Lambdas

    assert_parses(
      s(:numblock,
        s(:lambda),
        9,
        s(:send,
          s(:lvar, :_1), :+,
          s(:lvar, :_9))),
      %q{-> { _1 + _9}},
      %q{^^^^^^^^^^^^^ expression
        |     ^^ name (send.lvar/1)
        |     ^^ expression (send.lvar/1)
        |          ^^ name (send.lvar/2)
        |          ^^ expression (send.lvar/2)},
      SINCE_2_7)

    assert_parses(
      s(:numblock,
        s(:lambda),
        9,
        s(:send,
          s(:lvar, :_1), :+,
          s(:lvar, :_9))),
      %q{-> do _1 + _9 end},
      %q{^^^^^^^^^^^^^^^^^ expression
        |      ^^ name (send.lvar/1)
        |      ^^ expression (send.lvar/1)
        |           ^^ name (send.lvar/2)
        |           ^^ expression (send.lvar/2)},
      SINCE_2_7)
  end

  def test_numbered_and_ordinary_parameters
    # Blocks

    assert_diagnoses(
      [:error, :ordinary_param_defined],
      %q{m { || _1 } },
      %q{       ^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :ordinary_param_defined],
      %q{m { |a| _1 } },
      %q{        ^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :ordinary_param_defined],
      %q{m do || _1 end },
      %q{        ^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :ordinary_param_defined],
      %q{m do |a, b| _1 end },
      %q{            ^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :ordinary_param_defined],
      %q{m { |x = _1| }},
      %q{         ^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :ordinary_param_defined],
      %q{m { |x: _1| }},
      %q{        ^^ location},
      SINCE_2_7)

    # Lambdas

    assert_diagnoses(
      [:error, :ordinary_param_defined],
      %q{->() { _1 } },
      %q{       ^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :ordinary_param_defined],
      %q{->(a) { _1 } },
      %q{        ^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :ordinary_param_defined],
      %q{->() do _1 end },
      %q{        ^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :ordinary_param_defined],
      %q{->(a, b) do _1 end},
      %q{            ^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :ordinary_param_defined],
      %q{->(x=_1) {}},
      %q{     ^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :ordinary_param_defined],
      %q{->(x: _1) {}},
      %q{      ^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :ordinary_param_defined],
      %q{proc {|;a| _1}},
      %q{           ^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :ordinary_param_defined],
      "proc {|\n| _1}",
      %q{          ^^ location},
      SINCE_2_7)
  end

  def test_numparam_outside_block
    assert_parses(
      s(:class,
        s(:const, nil, :A), nil,
        s(:send, nil, :_1)),
      %q{class A; _1; end},
      %q{},
      SINCE_2_7)

    assert_parses(
      s(:module,
        s(:const, nil, :A),
        s(:send, nil, :_1)),
      %q{module A; _1; end},
      %q{},
      SINCE_2_7)

    assert_parses(
      s(:sclass,
        s(:lvar, :foo),
        s(:send, nil, :_1)),
      %q{class << foo; _1; end},
      %q{},
      SINCE_2_7)

    assert_parses(
      s(:defs,
        s(:self), :m,
        s(:args),
        s(:send, nil, :_1)),
      %q{def self.m; _1; end},
      %q{},
      SINCE_2_7)

    assert_parses(
      s(:send, nil, :_1),
      %q{_1},
      %q{},
      SINCE_2_7)
  end

  def test_assignment_to_numparams
    assert_parses(
      s(:block,
        s(:send, nil, :proc),
        s(:args),
        s(:lvasgn, :_1,
          s(:nil))),
      %q{proc {_1 = nil}},
      %q{},
      %w(2.7))

    assert_diagnoses(
      [:error, :cant_assign_to_numparam, { :name => '_1' }],
      %q{proc {_1; _1 = nil}},
      %q{          ^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :cant_assign_to_numparam, { :name => '_1' }],
      %q{proc {_1; _1, foo = [nil, nil]}},
      %q{          ^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :cant_assign_to_numparam, { :name => '_1' }],
      %q{proc {_9; _1 = nil}},
      %q{          ^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :cant_assign_to_numparam, { :name => '_9' }],
      %q{proc {_1; _9 = nil}},
      %q{          ^^ location},
      SINCE_2_7)

    refute_diagnoses(
      %q{proc { _1 = nil; _1}},
      %w(2.7))
  end

  def test_numparams_in_nested_blocks
    assert_diagnoses(
      [:error, :numparam_used_in_outer_scope],
      %q{foo { _1; bar { _2 }; }},
      %q{                ^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :numparam_used_in_outer_scope],
      %q{-> { _1; -> { _2 }; }},
      %q{              ^^ location},
      SINCE_2_7)

    [
      ['class A', 'end'],
      ['class << foo', 'end'],
      ['def m', 'end'],
      ['def self.m', 'end']
    ].each do |open_scope, close_scope|
      refute_diagnoses(
        "proc { _1; #{open_scope}; proc { _2 }; #{close_scope}; }",
        SINCE_2_7)

      refute_diagnoses(
        "-> { _1; #{open_scope}; -> { _2 }; #{close_scope}; }",
        SINCE_2_7)
    end
  end

  def test_ruby_bug_15789
    assert_parses(
      s(:send, nil, :m,
        s(:block,
          s(:lambda),
          s(:args,
            s(:optarg, :a,
              s(:numblock,
                s(:lambda), 1,
                s(:lvar, :_1)))),
          s(:lvar, :a))),
      %q{m ->(a = ->{_1}) {a}},
      %q{},
      SINCE_2_7)

    assert_parses(
      s(:send, nil, :m,
        s(:block,
          s(:lambda),
          s(:args,
            s(:kwoptarg, :a,
              s(:numblock,
                s(:lambda), 1,
                s(:lvar, :_1)))),
          s(:lvar, :a))),
      %q{m ->(a: ->{_1}) {a}},
      %q{},
      SINCE_2_7)
  end

  def test_ruby_bug_15839
    assert_diagnoses(
      [:error, :invalid_encoding],
      %q{# encoding: cp932
        <<-TEXT
        \xe9\x9d\u1234
        TEXT
      })

    assert_diagnoses(
      [:error, :invalid_encoding],
      %q{
        # encoding: cp932
        <<-TEXT
        \xe9\x9d
        \u1234
        TEXT
      })

    assert_diagnoses(
      [:error, :invalid_encoding],
      %q{
        # encoding: cp932
        <<-TEXT
        \u1234\xe9\x9d
        TEXT
      })

    assert_diagnoses(
      [:error, :invalid_encoding],
      %q{
        # encoding: cp932
        <<-TEXT
        \u1234
        \xe9\x9d
        TEXT
      })
  end

  def test_numparam_as_symbols
    assert_diagnoses(
      [:error, :ivar_name, { :name => '@' }],
      %q{:@},
      %q{ ^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :ivar_name, { :name => '@1' }],
      %q{:@1},
      %q{ ^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :cvar_name, { :name => '@@' }],
      %q{:@@},
      %q{ ^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :cvar_name, { :name => '@@1' }],
      %q{:@@1},
      %q{ ^^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :gvar_name, { :name => '$01234' }],
      %q{:$01234},
      %q{ ^^^^^^ location},
      SINCE_3_3)
  end

  def test_csend_inside_lhs_of_masgn__since_27
    assert_diagnoses(
      [:error, :csend_in_lhs_of_masgn],
      %q{*a&.x = 0},
      %q{  ^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :csend_in_lhs_of_masgn],
      %q{a&.x, = 0},
      %q{ ^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :csend_in_lhs_of_masgn],
      %q{*a&.A = 0},
      %q{  ^^ location},
      SINCE_2_7)
  end

  def test_parser_bug_604
    assert_parses(
      s(:block,
        s(:send, nil, :m,
          s(:send,
            s(:send, nil, :a), :+,
            s(:send, nil, :b))),
        s(:args), nil),
      %q{m a + b do end},
      %q{},
      ALL_VERSIONS)
  end

  def test_comments_before_leading_dot__27
    assert_parses(
      s(:send,
        s(:send, nil, :a), :foo),
      %Q{a #\n#\n.foo\n},
      %q{},
      SINCE_2_7)

    assert_parses(
      s(:send,
        s(:send, nil, :a), :foo),
      %Q{a #\n  #\n.foo\n},
      %q{},
      SINCE_2_7)

    assert_parses(
      s(:csend,
        s(:send, nil, :a), :foo),
      %Q{a #\n#\n&.foo\n},
      %q{},
      SINCE_2_7)

    assert_parses(
      s(:csend,
        s(:send, nil, :a), :foo),
      %Q{a #\n  #\n&.foo\n},
      %q{},
      SINCE_2_7)
  end

  def test_comments_before_leading_dot__before_27
    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tDOT' }],
      %q{a #!#!.foo!}.gsub('!', "\n"),
      %q{      ^ location},
      ALL_VERSIONS - SINCE_2_7)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tAMPER' }],
      %q{a #!#!&.foo!}.gsub('!', "\n"),
      %q{      ^ location},
      ALL_VERSIONS - SINCE_2_7)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tDOT' }],
      %q{a #!#!.:foo!}.gsub('!', "\n"),
      %q{      ^ location},
      ALL_VERSIONS - SINCE_2_7)
  end

  def test_circular_argument_reference_error
    assert_diagnoses(
      [:error, :circular_argument_reference, { :var_name => 'foo' }],
      %q{def m(foo = foo) end},
      %q{            ^^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :circular_argument_reference, { :var_name => 'foo' }],
      %q{def m(foo: foo) end},
      %q{           ^^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :circular_argument_reference, { :var_name => 'foo' }],
      %q{m { |foo = foo| } },
      %q{           ^^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :circular_argument_reference, { :var_name => 'foo' }],
      %q{m { |foo: foo| } },
      %q{          ^^^ location},
      SINCE_2_7)

    # Traversing

    assert_diagnoses(
      [:error, :circular_argument_reference, { :var_name => 'foo' }],
      %q{def m(foo = class << foo; end) end},
      %q{                     ^^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :circular_argument_reference, { :var_name => 'foo' }],
      %q{def m(foo = def foo.m; end); end},
      %q{                ^^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :circular_argument_reference, { :var_name => 'foo' }],
      %q{m { |foo = proc { 1 + foo }| } },
      %q{                      ^^^ location},
      SINCE_2_7)

    # Valid cases

    [
      'm { |foo = class A; foo; end| }',
      'm { |foo = class << self; foo; end| }',
      'm { |foo = def m(foo = bar); foo; end| }',
      'm { |foo = def m(bar = foo); foo; end| }',
      'm { |foo = def self.m(bar = foo); foo; end| }',
      'def m(foo = def m; foo; end) end',
      'def m(foo = def self.m; foo; end) end',
      'm { |foo = proc { |bar| 1 + foo }| }',
      'm { |foo = proc { || 1 + foo }| }'
    ].each do |code|
      refute_diagnoses(code, SINCE_2_7)
    end
  end

  def test_forward_args_legacy
    Parser::Builders::Default.emit_forward_arg = false
    assert_parses(
      s(:def, :foo,
        s(:forward_args),
        s(:send, nil, :bar,
          s(:forwarded_args))),
      %q{def foo(...); bar(...); end},
      %q{       ~ begin (forward_args)
        |       ~~~~~ expression (forward_args)
        |           ~ end (forward_args)
        |                  ~~~ expression (send.forwarded_args)},
      SINCE_2_7)

    assert_parses(
      s(:def, :foo,
        s(:forward_args),
        s(:super,
          s(:forwarded_args))),
      %q{def foo(...); super(...); end},
      %q{       ~ begin (forward_args)
        |       ~~~~~ expression (forward_args)
        |           ~ end (forward_args)
        |                    ~~~ expression (super.forwarded_args)},
      SINCE_2_7)

    assert_parses(
      s(:def, :foo,
        s(:forward_args),
        nil),
      %q{def foo(...); end},
      %q{},
      SINCE_2_7)
  ensure
    Parser::Builders::Default.emit_forward_arg = true
  end

  def test_forward_arg
    assert_parses(
      s(:def, :foo,
        s(:args,
          s(:forward_arg)),
        s(:send, nil, :bar,
          s(:forwarded_args))),
      %q{def foo(...); bar(...); end},
      %q{       ~ begin (args)
        |       ~~~~~ expression (args)
        |           ~ end (args)
        |        ~~~ expression (args.forward_arg)
        |                  ~~~ expression (send.forwarded_args)},
      SINCE_2_7)
  end

  def test_forward_args_invalid
    assert_diagnoses(
      [:error, :block_and_blockarg],
      %q{def foo(...) bar(...) { }; end},
      %q{                 ^^^ location
        |                      ~ highlights (0)},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tBDOT3' }],
      %q{foo do |...| end},
      %q{        ^^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tBDOT3' }],
      %q{foo { |...| }},
      %q{       ^^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tBDOT3' }],
      %q{def foo(x,y,z); bar(...); end},
      %q{                    ^^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tBDOT3' }],
      %q{def foo(x,y,z); bar(x, y, z, ...); end},
      %q{                             ^^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tBDOT3' }],
      %q{def foo(x,y,z); super(...); end},
      %q{                      ^^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tDOT3' }],
      %q{->... {}},
      %q{  ^^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tBDOT3' }],
      %q{->(...) {}},
      %q{   ^^^ location},
      ['2.7'])

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tDOT3' }],
      %q{->(...) {}},
      %q{   ^^^ location},
      SINCE_3_0)

    # Here and below the parser asssumes that
    # it can be a beginningless range, so the error comes after reducing right paren
    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tRPAREN' }],
      %q{def foo(...); yield(...); end},
      %q{                       ^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tRPAREN' }],
      %q{def foo(...); return(...); end},
      %q{                        ^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tRPAREN' }],
      %q{def foo(...); a = (...); end},
      %q{                      ^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tRBRACK' }],
      %q{def foo(...); [...]; end},
      %q{                  ^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tRBRACK' }],
      %q{def foo(...) bar[...]; end},
      %q{                    ^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tRBRACK' }],
      %q{def foo(...) bar[...] = x; end},
      %q{                    ^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tRPAREN' }],
      %q{def foo(...) defined?(...); end},
      %q{                         ^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tDOT3' }],
      %q{def foo ...; end},
      %q{        ^^^ location},
      SINCE_2_7 - SINCE_3_1)
  end

  def test_forward_args_super_with_block
    [
      %q{def foo(...) super(...) {}; end},
      %q{def foo(...) super(a, ...) {}; end},
      %q{def foo(...) super(a, b, ...) {}; end},
    ].each do |code|
      # https://bugs.ruby-lang.org/issues/20392
      refute_diagnoses(code, %w(3.3))
      assert_diagnoses(
        [:error, :block_and_blockarg],
        code,
        %q{},
        SINCE_2_7 - %w(3.3))
    end

    [
      %q{def foo(...) super {}; end},
      %q{def foo(...) super() {}; end},
      %q{def foo(...) super(a) {}; end},
      %q{def foo(...) super(a, b) {}; end},
    ].each do |code|
      refute_diagnoses(code, SINCE_2_7)
    end
  end
  def test_trailing_forward_arg
    assert_parses(
      s(:def, :foo,
        s(:args,
          s(:arg, :a),
          s(:arg, :b),
          s(:forward_arg)),
        s(:send, nil, :bar,
          s(:lvar, :a),
          s(:int, 42),
          s(:forwarded_args))),
      %q{def foo(a, b, ...); bar(a, 42, ...); end},
      %q{       ~ begin (args)
        |       ~~~~~~~~~~~ expression (args)
        |                 ~ end (args)
        |              ~~~ expression (args.forward_arg)},
      SINCE_2_7)
  end


  def test_erange_without_parentheses_at_eol
    assert_diagnoses(
      [:warning, :triple_dot_at_eol],
      %Q{1...\n2},
      %q{ ^^^ location},
      SINCE_2_7)

    refute_diagnoses('(1...)', SINCE_2_7)
    refute_diagnoses("(1...\n)", SINCE_2_7)
    refute_diagnoses("[1...\n]", SINCE_2_7)
    refute_diagnoses("{a: 1...\n2}", SINCE_2_7)
  end

  def test_embedded_document_with_eof
    refute_diagnoses("=begin\n""=end", SINCE_2_7)
    refute_diagnoses("=begin\n""=end\0", SINCE_2_7)
    refute_diagnoses("=begin\n""=end\C-d", SINCE_2_7)
    refute_diagnoses("=begin\n""=end\C-z", SINCE_2_7)

    assert_diagnoses(
      [:fatal, :embedded_document],
      "=begin\n",
      %q{},
      SINCE_2_7)

    assert_diagnoses(
      [:fatal, :embedded_document],
      "=begin",
      %q{},
      SINCE_2_7)
  end

  def test_interp_digit_var
    # '#@1'
    assert_parses(
      s(:str, '#@1'),
      %q{ '#@1' },
      %q{},
      ALL_VERSIONS)

    assert_parses(
      s(:str, '#@@1'),
      %q{ '#@@1' },
      %q{},
      ALL_VERSIONS)

    # <<-'HERE'
    #   #@1
    # HERE
    assert_parses(
      s(:str, '#@1' + "\n"),
      %q{<<-'HERE'!#@1!HERE}.gsub('!', "\n"),
      %q{},
      ALL_VERSIONS)

    assert_parses(
      s(:str, '#@@1' + "\n"),
      %q{<<-'HERE'!#@@1!HERE}.gsub('!', "\n"),
      %q{},
      ALL_VERSIONS)

    # %q{#@1}
    assert_parses(
      s(:str, '#@1'),
      %q{ %q{#@1} },
      %q{},
      ALL_VERSIONS)

    assert_parses(
      s(:str, '#@@1'),
      %q{ %q{#@@1} },
      %q{},
      ALL_VERSIONS)

    # "#@1"
    assert_diagnoses(
      [:error, :ivar_name, { :name => '@1' }],
      %q{ "#@1" },
      %q{   ^^ location},
      ALL_VERSIONS - SINCE_2_7)

    assert_diagnoses(
      [:error, :cvar_name, { :name => '@@1' }],
      %q{ "#@@1" },
      %q{   ^^^ location},
      ALL_VERSIONS - SINCE_2_7)

    assert_parses(
      s(:str, '#@1'),
      %q{ "#@1" },
      %q{},
      SINCE_2_7)

    assert_parses(
      s(:str, '#@@1'),
      %q{ "#@@1" },
      %q{},
      SINCE_2_7)

    # <<-"HERE"
    #   #@1
    # HERE
    assert_diagnoses(
      [:error, :ivar_name, { :name => '@1' }],
      %q{ <<-"HERE"!#@1!HERE }.gsub('!', "\n"),
      %q{            ^^ location},
      ALL_VERSIONS - SINCE_2_7)

    assert_diagnoses(
      [:error, :cvar_name, { :name => '@@1' }],
      %q{ <<-"HERE"!#@@1!HERE }.gsub('!', "\n"),
      %q{            ^^^ location},
      ALL_VERSIONS - SINCE_2_7)

    assert_parses(
      s(:str, '#@1' + "\n"),
      %q{<<-"HERE"!#@1!HERE}.gsub('!', "\n"),
      %q{},
      SINCE_2_7)

    assert_parses(
      s(:str, '#@@1' + "\n"),
      %q{<<-"HERE"!#@@1!HERE}.gsub('!', "\n"),
      %q{},
      SINCE_2_7)

    # %{#@1}
    assert_diagnoses(
      [:error, :ivar_name, { :name => '@1' }],
      %q{ %{#@1} },
      %q{    ^^ location},
      ALL_VERSIONS - SINCE_2_7)

    assert_diagnoses(
      [:error, :cvar_name, { :name => '@@1' }],
      %q{ %{#@@1} },
      %q{    ^^^ location},
      ALL_VERSIONS - SINCE_2_7)

    assert_parses(
      s(:str, '#@1'),
      %q{ %{#@1} },
      %q{},
      SINCE_2_7)

    assert_parses(
      s(:str, '#@@1'),
      %q{ %{#@@1} },
      %q{},
      SINCE_2_7)

    # %Q{#@1}
    assert_diagnoses(
      [:error, :ivar_name, { :name => '@1' }],
      %q{ %Q{#@1} },
      %q{     ^^ location},
      ALL_VERSIONS - SINCE_2_7)

    assert_diagnoses(
      [:error, :cvar_name, { :name => '@@1' }],
      %q{ %Q{#@@1} },
      %q{     ^^^ location},
      ALL_VERSIONS - SINCE_2_7)

    assert_parses(
      s(:str, '#@1'),
      %q{ %Q{#@1} },
      %q{},
      SINCE_2_7)

    assert_parses(
      s(:str, '#@@1'),
      %q{ %Q{#@@1} },
      %q{},
      SINCE_2_7)

    # %w[#@1]
    assert_parses(
      s(:array,
        s(:str, '#@1')),
      %q{ %w[ #@1 ] },
      %q{},
      ALL_VERSIONS)

    assert_parses(
      s(:array,
        s(:str, '#@@1')),
      %q{ %w[ #@@1 ] },
      %q{},
      ALL_VERSIONS)

    # %W[#@1]
    assert_diagnoses(
      [:error, :ivar_name, { :name => '@1' }],
      %q{ %W[#@1] },
      %q{     ^^ location},
      ALL_VERSIONS - SINCE_2_7)

    assert_diagnoses(
      [:error, :cvar_name, { :name => '@@1' }],
      %q{ %W[#@@1] },
      %q{     ^^^ location},
      ALL_VERSIONS - SINCE_2_7)

    assert_parses(
      s(:array,
        s(:str, '#@1')),
      %q{ %W[#@1] },
      %q{},
      SINCE_2_7)

    assert_parses(
      s(:array,
        s(:str, '#@@1')),
      %q{ %W[#@@1] },
      %q{},
      SINCE_2_7)

    # %i[#@1]
    assert_parses(
      s(:array,
        s(:sym, :'#@1')),
      %q{ %i[ #@1 ] },
      %q{},
      SINCE_2_0)

    assert_parses(
      s(:array,
        s(:sym, :'#@@1')),
      %q{ %i[ #@@1 ] },
      %q{},
      SINCE_2_0)

    # %I[#@1]
    assert_diagnoses(
      [:error, :ivar_name, { :name => '@1' }],
      %q{ %I[#@1] },
      %q{     ^^ location},
      SINCE_2_0 - SINCE_2_7)

    assert_diagnoses(
      [:error, :cvar_name, { :name => '@@1' }],
      %q{ %I[#@@1] },
      %q{     ^^^ location},
      SINCE_2_0 - SINCE_2_7)

    assert_parses(
      s(:array,
        s(:sym, :'#@1')),
      %q{ %I[#@1] },
      %q{},
      SINCE_2_7)

    assert_parses(
      s(:array,
        s(:sym, :'#@@1')),
      %q{ %I[#@@1] },
      %q{},
      SINCE_2_7)

    # :'#@1'
    assert_parses(
      s(:sym, :'#@1'),
      %q{ :'#@1' },
      %q{},
      ALL_VERSIONS)

    assert_parses(
      s(:sym, :'#@@1'),
      %q{ :'#@@1' },
      %q{},
      ALL_VERSIONS)

    # %s{#@1}
    assert_parses(
      s(:sym, :'#@1'),
      %q{ %s{#@1} },
      %q{},
      ALL_VERSIONS)

    assert_parses(
      s(:sym, :'#@@1'),
      %q{ %s{#@@1} },
      %q{},
      ALL_VERSIONS)

    # :"#@1"
    assert_diagnoses(
      [:error, :ivar_name, { :name => '@1' }],
      %q{ :"#@1" },
      %q{    ^^ location},
      ALL_VERSIONS - SINCE_2_7)

    assert_diagnoses(
      [:error, :cvar_name, { :name => '@@1' }],
      %q{ :"#@@1" },
      %q{    ^^^ location},
      ALL_VERSIONS - SINCE_2_7)

    assert_parses(
      s(:sym, :'#@1'),
      %q{ :"#@1" },
      %q{},
      SINCE_2_7)

    assert_parses(
      s(:sym, :'#@@1'),
      %q{ :"#@@1" },
      %q{},
      SINCE_2_7)

    # /#@1/
    assert_diagnoses(
      [:error, :ivar_name, { :name => '@1' }],
      %q{ /#@1/ },
      %q{   ^^ location},
      ALL_VERSIONS - SINCE_2_7)

    assert_diagnoses(
      [:error, :cvar_name, { :name => '@@1' }],
      %q{ /#@@1/ },
      %q{   ^^^ location},
      ALL_VERSIONS - SINCE_2_7)

    assert_parses(
      s(:regexp,
        s(:str, '#@1'),
        s(:regopt)),
      %q{ /#@1/ },
      %q{},
      SINCE_2_7)

    assert_parses(
      s(:regexp,
        s(:str, '#@@1'),
        s(:regopt)),
      %q{ /#@@1/ },
      %q{},
      SINCE_2_7)

    # %r{#@1}
    assert_diagnoses(
      [:error, :ivar_name, { :name => '@1' }],
      %q{ %r{#@1} },
      %q{     ^^ location},
      ALL_VERSIONS - SINCE_2_7)

    assert_diagnoses(
      [:error, :cvar_name, { :name => '@@1' }],
      %q{ %r{#@@1} },
      %q{     ^^^ location},
      ALL_VERSIONS - SINCE_2_7)

    assert_parses(
      s(:regexp,
        s(:str, '#@1'),
        s(:regopt)),
      %q{ %r{#@1} },
      %q{},
      SINCE_2_7)

    assert_parses(
      s(:regexp,
        s(:str, '#@@1'),
        s(:regopt)),
      %q{ %r{#@@1} },
      %q{},
      SINCE_2_7)

    # %x{#@1}
    assert_diagnoses(
      [:error, :ivar_name, { :name => '@1' }],
      %q{ %x{#@1} },
      %q{     ^^ location},
      ALL_VERSIONS - SINCE_2_7)

    assert_diagnoses(
      [:error, :cvar_name, { :name => '@@1' }],
      %q{ %x{#@@1} },
      %q{     ^^^ location},
      ALL_VERSIONS - SINCE_2_7)

    assert_parses(
      s(:xstr,
        s(:str, '#@1')),
      %q{ %x{#@1} },
      %q{},
      SINCE_2_7)

    assert_parses(
      s(:xstr,
        s(:str, '#@@1')),
      %q{ %x{#@@1} },
      %q{},
      SINCE_2_7)

    # `#@1`
    assert_diagnoses(
      [:error, :ivar_name, { :name => '@1' }],
      %q{ `#@1` },
      %q{   ^^ location},
      ALL_VERSIONS - SINCE_2_7)

    assert_diagnoses(
      [:error, :cvar_name, { :name => '@@1' }],
      %q{ `#@@1` },
      %q{   ^^^ location},
      ALL_VERSIONS - SINCE_2_7)

    assert_parses(
      s(:xstr,
        s(:str, '#@1')),
      %q{ `#@1` },
      %q{},
      SINCE_2_7)

    assert_parses(
      s(:xstr,
        s(:str, '#@@1')),
      %q{ `#@@1` },
      %q{},
      SINCE_2_7)

    # <<-`HERE`
    #   #@1
    # HERE
    assert_diagnoses(
      [:error, :ivar_name, { :name => '@1' }],
      %q{ <<-`HERE`!#@1!HERE }.gsub('!', "\n"),
      %q{            ^^ location},
      ALL_VERSIONS - SINCE_2_7)

    assert_diagnoses(
      [:error, :cvar_name, { :name => '@@1' }],
      %q{ <<-`HERE`!#@@1!HERE }.gsub('!', "\n"),
      %q{            ^^^ location},
      ALL_VERSIONS - SINCE_2_7)

    assert_parses(
      s(:xstr,
        s(:str, '#@1' + "\n")),
      %q{<<-`HERE`!#@1!HERE}.gsub('!', "\n"),
      %q{},
      SINCE_2_7)

    assert_parses(
      s(:xstr,
        s(:str, '#@@1' + "\n")),
      %q{<<-`HERE`!#@@1!HERE}.gsub('!', "\n"),
      %q{},
      SINCE_2_7)
  end

  def assert_parses_pattern_match(ast, code, source_maps = '', versions = SINCE_2_7)
    case_pre = "case foo; "
    source_maps_offset = case_pre.length
    source_maps_prefix = ' ' * source_maps_offset
    source_maps = source_maps
      .lines
      .map { |line| source_maps_prefix + line.sub(/^\s*\|/, '') }
      .join("\n")

    assert_parses(
      s(:case_match,
        s(:lvar, :foo),
        ast,
        nil),
      "#{case_pre}#{code}; end",
      source_maps,
      versions
    )
  end

  def test_pattern_matching_single_match
    assert_parses_pattern_match(
      s(:in_pattern,
        s(:match_var, :x),
        nil,
        s(:lvar, :x)),
      %q{in x then x},
      %q{~~ keyword (in_pattern)
        |~~~~~~~~~~~ expression (in_pattern)
        |     ~~~~ begin (in_pattern)
        |   ~ expression (in_pattern.match_var)
        |   ~ name (in_pattern.match_var)}
    )
  end

  def test_pattern_matching_no_body
    assert_parses_pattern_match(
      s(:in_pattern,
        s(:int, 1), nil, nil),
      %q{in 1}
    )
  end

  def test_pattern_matching_if_unless_modifiers
    assert_parses_pattern_match(
      s(:in_pattern,
        s(:match_var, :x),
        s(:if_guard, s(:true)),
        s(:nil)
      ),
      %q{in x if true; nil},
      %q{~~ keyword (in_pattern)
        |~~~~~~~~~~~~~~~~~ expression (in_pattern)
        |            ~ begin (in_pattern)
        |     ~~ keyword (in_pattern.if_guard)
        |     ~~~~~~~ expression (in_pattern.if_guard)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:match_var, :x),
        s(:unless_guard, s(:true)),
        s(:nil)
      ),
      %q{in x unless true; nil},
      %q{~~ keyword (in_pattern)
        |~~~~~~~~~~~~~~~~~~~~~ expression (in_pattern)
        |                ~ begin (in_pattern)
        |     ~~~~~~ keyword (in_pattern.unless_guard)
        |     ~~~~~~~~~~~ expression (in_pattern.unless_guard)}
    )
  end

  def test_pattern_matching_pin_variable
    assert_parses_pattern_match(
      s(:in_pattern,
        s(:pin, s(:lvar, :foo)),
        nil,
        s(:nil)),
      %q{in ^foo then nil},
      %q{   ~ selector (in_pattern.pin)
        |   ~~~~ expression (in_pattern.pin)
        |    ~~~ name (in_pattern.pin.lvar)}
    )
  end

  def test_pattern_matching_implicit_array_match
    assert_parses_pattern_match(
      s(:in_pattern,
        s(:array_pattern_with_tail,
          s(:match_var, :x)),
        nil,
        s(:nil)),
      %q{in x, then nil},
      %q{   ~~ expression (in_pattern.array_pattern_with_tail)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:array_pattern,
          s(:match_rest,
            s(:match_var, :x))),
        nil,
        s(:nil)),
      %q{in *x then nil},
      %q{   ~~ expression (in_pattern.array_pattern)
        |   ~ operator (in_pattern.array_pattern.match_rest)
        |    ~ name (in_pattern.array_pattern.match_rest.match_var)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:array_pattern,
          s(:match_rest)),
        nil,
        s(:nil)),
      %q{in * then nil},
      %q{   ~ expression (in_pattern.array_pattern)
        |   ~ operator (in_pattern.array_pattern.match_rest)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:array_pattern,
          s(:match_var, :x),
          s(:match_var, :y)),
        nil,
        s(:nil)),
      %q{in x, y then nil},
      %q{   ~~~~ expression (in_pattern.array_pattern)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:array_pattern_with_tail,
          s(:match_var, :x),
          s(:match_var, :y)),
        nil,
        s(:nil)),
      %q{in x, y, then nil},
      %q{   ~~~~~ expression (in_pattern.array_pattern_with_tail)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:array_pattern,
          s(:match_var, :x),
          s(:match_rest, s(:match_var, :y)),
          s(:match_var, :z)),
        nil,
        s(:nil)),
      %q{in x, *y, z then nil},
      %q{   ~~~~~~~~ expression (in_pattern.array_pattern)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:array_pattern,
          s(:match_rest, s(:match_var, :x)),
          s(:match_var, :y),
          s(:match_var, :z)),
        nil,
        s(:nil)),
      %q{in *x, y, z then nil},
      %q{   ~~~~~~~~ expression (in_pattern.array_pattern)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:array_pattern,
          s(:int, 1),
          s(:str, 'a'),
          s(:array_pattern),
          s(:hash_pattern)),
        nil,
        s(:nil)),
      %q{in 1, "a", [], {} then nil},
      %q{   ~~~~~~~~~~~~~~ expression (in_pattern.array_pattern)}
    )
  end

  def test_pattern_matching_explicit_array_match
    assert_parses_pattern_match(
      s(:in_pattern,
        s(:array_pattern,
          s(:match_var, :x)),
        nil,
        s(:nil)),
      %q{in [x] then nil},
      %q{   ~~~ expression (in_pattern.array_pattern)
        |   ~ begin (in_pattern.array_pattern)
        |     ~ end (in_pattern.array_pattern)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:array_pattern_with_tail,
          s(:match_var, :x)),
        nil,
        s(:nil)),
      %q{in [x,] then nil},
      %q{   ~~~~ expression (in_pattern.array_pattern_with_tail)
        |   ~ begin (in_pattern.array_pattern_with_tail)
        |      ~ end (in_pattern.array_pattern_with_tail)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:array_pattern,
          s(:match_var, :x),
          s(:match_var, :y)),
        nil,
        s(:true)),
      %q{in [x, y] then true},
      %q{   ~~~~~~ expression (in_pattern.array_pattern)
        |   ~ begin (in_pattern.array_pattern)
        |        ~ end (in_pattern.array_pattern)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:array_pattern_with_tail,
          s(:match_var, :x),
          s(:match_var, :y)),
        nil,
        s(:true)),
      %q{in [x, y,] then true},
      %q{   ~~~~~~~ expression (in_pattern.array_pattern_with_tail)
        |   ~ begin (in_pattern.array_pattern_with_tail)
        |         ~ end (in_pattern.array_pattern_with_tail)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:array_pattern,
          s(:match_var, :x),
          s(:match_var, :y),
          s(:match_rest)),
        nil,
        s(:true)),
      %q{in [x, y, *] then true},
      %q{   ~~~~~~~~~ expression (in_pattern.array_pattern)
        |   ~ begin (in_pattern.array_pattern)
        |           ~ end (in_pattern.array_pattern)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:array_pattern,
          s(:match_var, :x),
          s(:match_var, :y),
          s(:match_rest, s(:match_var, :z))),
        nil,
        s(:true)),
      %q{in [x, y, *z] then true},
      %q{   ~~~~~~~~~~ expression (in_pattern.array_pattern)
        |   ~ begin (in_pattern.array_pattern)
        |            ~ end (in_pattern.array_pattern)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:array_pattern,
          s(:match_var, :x),
          s(:match_rest, s(:match_var, :y)),
          s(:match_var, :z)),
        nil,
        s(:true)),
      %q{in [x, *y, z] then true},
      %q{   ~~~~~~~~~~ expression (in_pattern.array_pattern)
        |   ~ begin (in_pattern.array_pattern)
        |            ~ end (in_pattern.array_pattern)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:array_pattern,
          s(:match_var, :x),
          s(:match_rest),
          s(:match_var, :y)),
        nil,
        s(:true)),
      %q{in [x, *, y] then true},
      %q{   ~~~~~~~~~ expression (in_pattern.array_pattern)
        |   ~ begin (in_pattern.array_pattern)
        |           ~ end (in_pattern.array_pattern)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:array_pattern,
          s(:match_rest, s(:match_var, :x)),
          s(:match_var, :y)),
        nil,
        s(:true)),
      %q{in [*x, y] then true},
      %q{   ~~~~~~~ expression (in_pattern.array_pattern)
        |   ~ begin (in_pattern.array_pattern)
        |         ~ end (in_pattern.array_pattern)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:array_pattern,
          s(:match_rest),
          s(:match_var, :x)),
        nil,
        s(:true)),
      %q{in [*, x] then true},
      %q{   ~~~~~~ expression (in_pattern.array_pattern)
        |   ~ begin (in_pattern.array_pattern)
        |        ~ end (in_pattern.array_pattern)}
    )
  end

  def test_pattern_matching_hash
    assert_parses_pattern_match(
      s(:in_pattern,
        s(:hash_pattern),
        nil,
        s(:true)),
      %q{in {} then true},
      %q{   ~~ expression (in_pattern.hash_pattern)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:hash_pattern,
          s(:pair, s(:sym, :a), s(:int, 1))),
        nil,
        s(:true)),
      %q{in a: 1 then true},
      %q{   ~~~~ expression (in_pattern.hash_pattern)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:hash_pattern,
          s(:pair, s(:sym, :a), s(:int, 1))),
        nil,
        s(:true)),
      %q{in { a: 1 } then true},
      %q{   ~~~~~~~~ expression (in_pattern.hash_pattern)
        |   ~ begin (in_pattern.hash_pattern)
        |          ~ end (in_pattern.hash_pattern)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:hash_pattern,
          s(:pair, s(:sym, :a), s(:int, 1))),
        nil,
        s(:true)),
      %q{in { a: 1, } then true},
      %q{   ~~~~~~~~~ expression (in_pattern.hash_pattern)
        |   ~ begin (in_pattern.hash_pattern)
        |           ~ end (in_pattern.hash_pattern)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:hash_pattern,
          s(:match_var, :a)),
        nil,
        s(:true)),
      %q{in a: then true},
      %q{   ~~ expression (in_pattern.hash_pattern)
        |   ~ name (in_pattern.hash_pattern.match_var)
        |   ~~ expression (in_pattern.hash_pattern.match_var)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:hash_pattern,
          s(:match_rest, s(:match_var, :a))),
        nil,
        s(:true)),
      %q{in **a then true},
      %q{   ~~~ expression (in_pattern.hash_pattern)
        |   ~~~ expression (in_pattern.hash_pattern.match_rest)
        |   ~~ operator (in_pattern.hash_pattern.match_rest)
        |     ~ expression (in_pattern.hash_pattern.match_rest.match_var)
        |     ~ name (in_pattern.hash_pattern.match_rest.match_var)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:hash_pattern,
          s(:match_rest)),
        nil,
        s(:true)),
      %q{in ** then true},
      %q{   ~~ expression (in_pattern.hash_pattern)
        |   ~~ expression (in_pattern.hash_pattern.match_rest)
        |   ~~ operator (in_pattern.hash_pattern.match_rest)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:hash_pattern,
          s(:pair, s(:sym, :a), s(:int, 1)),
          s(:pair, s(:sym, :b), s(:int, 2))),
        nil,
        s(:true)),
      %q{in a: 1, b: 2 then true},
      %q{   ~~~~~~~~~~ expression (in_pattern.hash_pattern)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:hash_pattern,
          s(:match_var, :a),
          s(:match_var, :b)),
        nil,
        s(:true)),
      %q{in a:, b: then true},
      %q{   ~~~~~~ expression (in_pattern.hash_pattern)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:hash_pattern,
          s(:pair, s(:sym, :a), s(:int, 1)),
          s(:match_var, :_a),
          s(:match_rest)),
        nil,
        s(:true)),
      %q{in a: 1, _a:, ** then true},
      %q{   ~~~~~~~~~~~~~ expression (in_pattern.hash_pattern)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:hash_pattern,
          s(:pair,
            s(:sym, :a),
            s(:int, 1))), nil,
        s(:false)),
      %q{
        in {a: 1
        }
          false
      },
      %q{}
    )


    assert_parses_pattern_match(
      s(:in_pattern,
        s(:hash_pattern,
          s(:pair,
            s(:sym, :a),
            s(:int, 2))), nil,
        s(:false)),
      %q{
        in {a:
              2}
          false
      },
      %q{}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:hash_pattern,
          s(:pair,
             s(:sym, :Foo),
             s(:int, 42))), nil,
        s(:false)),
      %q{
        in {Foo: 42
        }
          false
      },
      %q{}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:hash_pattern,
          s(:pair,
            s(:sym, :a),
            s(:hash_pattern,
              s(:match_var, :b))),
          s(:match_var, :c)), nil,
        s(:send, nil, :p,
          s(:lvar, :c))),
      %q{
        in a: {b:}, c:
          p c
      },
      %q{}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:hash_pattern,
          s(:match_var, :a)), nil,
        s(:true)),
      %q{
        in {a:
        }
          true
      },
      %q{}
    )
  end

  def test_ruby_bug_19539
    assert_parses(
      s(:str, "[Bug #19539]\n"),
      "<<' FOO'\n""[Bug #19539]\n"" FOO\n",
      %q{},
      SINCE_3_3)

    assert_parses(
      s(:str, "[Bug #19539]\n"),
      "<<-' FOO'\n""[Bug #19539]\n"" FOO\n",
      %q{},
      SINCE_3_3)

    # closing identifier doesn't have enough leading spaces
    # so it's considered as a part of the string (and so we reach EOF)
    assert_diagnoses(
      [:fatal, :string_eof],
      "<<~'    E'\n  E",
      %q{},
      SINCE_3_3)
  end

  def test_pattern_matching_hash_with_string_keys
    # Match + assign

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:hash_pattern,
          s(:match_var, :a)),
        nil,
        s(:true)),
      %q{in "a": then true},
      %q{   ~~~~ expression (in_pattern.hash_pattern.match_var)
        |    ~ name (in_pattern.hash_pattern.match_var)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:hash_pattern,
          s(:match_var, :a)),
        nil,
        s(:true)),
      %q{in "#{ 'a' }": then true},
      %q{   ~~~~~~~~~~~ expression (in_pattern.hash_pattern.match_var)
        |        ~ name (in_pattern.hash_pattern.match_var)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:hash_pattern,
          s(:match_var, :a)),
        nil,
        s(:true)),
      %q{in "#{ %q{a} }": then true},
      %q{   ~~~~~~~~~~~~~ expression (in_pattern.hash_pattern.match_var)
        |          ~ name (in_pattern.hash_pattern.match_var)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:hash_pattern,
          s(:match_var, :a)),
        nil,
        s(:true)),
      %q{in "#{ %Q{a} }": then true},
      %q{   ~~~~~~~~~~~~~ expression (in_pattern.hash_pattern.match_var)
        |          ~ name (in_pattern.hash_pattern.match_var)}
    )

    # Only match

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:hash_pattern,
          s(:pair, s(:sym, :a), s(:int, 1))),
        nil,
        s(:true)),
      %q{in "a": 1 then true},
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:hash_pattern,
          s(:pair,
            s(:dsym, s(:begin, s(:str, "a"))),
            s(:int, 1))),
        nil,
        s(:true)),
      %q{in "#{ 'a' }": 1 then true},
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:hash_pattern,
          s(:pair,
            s(:dsym, s(:begin, s(:str, "a"))),
            s(:int, 1))),
        nil,
        s(:true)),
      %q{in "#{ %q{a} }": 1 then true},
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:hash_pattern,
          s(:pair,
            s(:dsym, s(:begin, s(:str, "a"))),
            s(:int, 1))),
        nil,
        s(:true)),
      %q{in "#{ %Q{a} }": 1 then true},
    )
  end

  def test_pattern_matching_hash_with_heredoc_keys
    # Ruby <3, the following case is acceptable by the MRI's grammar,
    # so it has to be reducable by parser.
    # We have a code for that in the builder.rb that reject it via
    # diagnostic error because of the wrong lvar name
    assert_diagnoses(
      [:error, :lvar_name, { name: "a\n" }],
      "case nil; in \"\#{ <<-HERE }\":;\na\nHERE\nelse\nend",
      %q{                 ~~~~~~~ location},
      SINCE_2_7
    )
  end

  def test_pattern_matching_hash_with_string_interpolation_keys
    assert_diagnoses(
      [:error, :pm_interp_in_var_name],
      %q{case a; in "#{a}": 1; end},
      %q{           ~~~~~~~ location},
      SINCE_2_7
    )

    assert_diagnoses(
      [:error, :pm_interp_in_var_name],
      %q{case a; in "#{a}": 1; end},
      %q{           ~~~~~~~ location},
      SINCE_2_7
    )
  end

  def test_pattern_matching_invalid_lvar_name
    assert_diagnoses(
      [:error, :lvar_name, { name: :a? }],
      %q{case a; in a?:; end},
      %q{           ~~ location},
      SINCE_2_7
    )
  end

  def test_pattern_matching_keyword_variable
    assert_parses_pattern_match(
      s(:in_pattern,
        s(:self),
        nil,
        s(:true)),
      %q{in self then true}
    )
  end

  def test_pattern_matching_lambda
    assert_parses_pattern_match(
      s(:in_pattern,
        s(:block,
          s(:lambda),
          s(:args),
          s(:int, 42)),
        nil,
        s(:true)),
      %q{in ->{ 42 } then true}
    )
  end

  def test_pattern_matching_ranges
    assert_parses_pattern_match(
      s(:in_pattern,
        s(:irange, s(:int, 1), s(:int, 2)),
        nil,
        s(:true)),
      %q{in 1..2 then true}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:irange, s(:int, 1), nil),
        nil,
        s(:true)),
      %q{in 1.. then true}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:irange, nil, s(:int, 2)),
        nil,
        s(:true)),
      %q{in ..2 then true}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:erange, s(:int, 1), s(:int, 2)),
        nil,
        s(:true)),
      %q{in 1...2 then true}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:erange, s(:int, 1), nil),
        nil,
        s(:true)),
      %q{in 1... then true}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:erange, nil, s(:int, 2)),
        nil,
        s(:true)),
      %q{in ...2 then true}
    )
  end

  def test_pattern_matching_expr_in_paren
    assert_parses_pattern_match(
      s(:in_pattern,
        s(:begin, s(:int, 1)),
        nil,
        s(:true)),
      %q{in (1) then true},
      %q{   ~~~ expression (in_pattern.begin)
        |   ~ begin (in_pattern.begin)
        |     ~ end (in_pattern.begin)}
    )
  end

  def test_pattern_matching_constants
    assert_parses_pattern_match(
      s(:in_pattern,
        s(:const, nil, :A),
        nil,
        s(:true)),
      %q{in A then true},
      %q{   ~ expression (in_pattern.const)
        |   ~ name (in_pattern.const)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:const, s(:const, nil, :A), :B),
        nil,
        s(:true)),
      %q{in A::B then true},
      %q{   ~~~~ expression (in_pattern.const)
        |    ~~ double_colon (in_pattern.const)
        |      ~ name (in_pattern.const)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:const, s(:cbase), :A),
        nil,
        s(:true)),
      %q{in ::A then true},
      %q{   ~~~ expression (in_pattern.const)
        |   ~~ double_colon (in_pattern.const)
        |     ~ name (in_pattern.const)}
    )
  end

  def test_pattern_matching_const_pattern
    assert_parses_pattern_match(
      s(:in_pattern,
        s(:const_pattern,
          s(:const, nil, :A),
          s(:array_pattern,
            s(:int, 1),
            s(:int, 2))),
        nil,
        s(:true)),
      %q{in A(1, 2) then true},
      %q{   ~~~~~~~ expression (in_pattern.const_pattern)
        |    ~ begin (in_pattern.const_pattern)
        |         ~ end (in_pattern.const_pattern)
        |   ~ expression (in_pattern.const_pattern.const)
        |     ~~~~ expression (in_pattern.const_pattern.array_pattern)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:const_pattern,
          s(:const, nil, :A),
          s(:hash_pattern,
            s(:match_var, :x))),
        nil,
        s(:true)),
      %q{in A(x:) then true},
      %q{   ~~~~~ expression (in_pattern.const_pattern)
        |    ~ begin (in_pattern.const_pattern)
        |       ~ end (in_pattern.const_pattern)
        |   ~ expression (in_pattern.const_pattern.const)
        |     ~~ expression (in_pattern.const_pattern.hash_pattern)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:const_pattern,
          s(:const, nil, :A),
          s(:array_pattern)),
        nil,
        s(:true)),
      %q{in A() then true},
      %q{   ~~~ expression (in_pattern.const_pattern)
        |    ~ begin (in_pattern.const_pattern)
        |     ~ end (in_pattern.const_pattern)
        |   ~ expression (in_pattern.const_pattern.const)
        |    ~~ expression (in_pattern.const_pattern.array_pattern)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:const_pattern,
          s(:const, nil, :A),
          s(:array_pattern,
            s(:int, 1),
            s(:int, 2))),
        nil,
        s(:true)),
      %q{in A[1, 2] then true},
      %q{   ~~~~~~~ expression (in_pattern.const_pattern)
        |    ~ begin (in_pattern.const_pattern)
        |         ~ end (in_pattern.const_pattern)
        |   ~ expression (in_pattern.const_pattern.const)
        |     ~~~~ expression (in_pattern.const_pattern.array_pattern)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:const_pattern,
          s(:const, nil, :A),
          s(:hash_pattern,
            s(:match_var, :x))),
        nil,
        s(:true)),
      %q{in A[x:] then true},
      %q{   ~~~~~ expression (in_pattern.const_pattern)
        |    ~ begin (in_pattern.const_pattern)
        |       ~ end (in_pattern.const_pattern)
        |   ~ expression (in_pattern.const_pattern.const)
        |     ~~ expression (in_pattern.const_pattern.hash_pattern)}
    )

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:const_pattern,
          s(:const, nil, :A),
          s(:array_pattern)),
        nil,
        s(:true)),
      %q{in A[] then true},
      %q{   ~~~ expression (in_pattern.const_pattern)
        |    ~ begin (in_pattern.const_pattern)
        |     ~ end (in_pattern.const_pattern)
        |    ~~ expression (in_pattern.const_pattern.array_pattern)}
    )
  end

  def test_pattern_matching_match_alt
    assert_parses_pattern_match(
      s(:in_pattern,
        s(:match_alt, s(:int, 1), s(:int, 2)),
        nil,
        s(:true)),
      %q{in 1 | 2 then true},
      %q{   ~~~~~ expression (in_pattern.match_alt)
        |     ~ operator (in_pattern.match_alt)}
    )
  end

  def test_pattern_matching_match_as
    assert_parses_pattern_match(
      s(:in_pattern,
        s(:match_as,
          s(:int, 1),
          s(:match_var, :a)),
        nil,
        s(:true)),
      %q{in 1 => a then true},
      %q{   ~~~~~~ expression (in_pattern.match_as)
        |     ~~ operator (in_pattern.match_as)}
    )
  end

  def test_pattern_matching_else
    assert_parses(
      s(:case_match,
        s(:int, 1),
        s(:in_pattern,
          s(:int, 2), nil,
          s(:int, 3)),
        s(:int, 4)),
      %q{case 1; in 2; 3; else; 4; end},
      %q{                 ~~~~ else},
      SINCE_2_7
    )
  end

  def test_pattern_matching_blank_else
    assert_parses(
      s(:case_match,
        s(:int, 1),
        s(:in_pattern,
          s(:int, 2), nil,
          s(:int, 3)),
        s(:empty_else)),
      %q{case 1; in 2; 3; else; end},
      %q{                 ~~~~ else},
      SINCE_2_7
    )
  end

  def test_pattern_matching_numbered_parameter
    assert_parses(
      s(:numblock,
        s(:send,
          s(:int, 1), :then), 1,
        s(:match_pattern,
          s(:int, 1),
          s(:pin,
            s(:lvar, :_1)))),
      %q{1.then { 1 in ^_1 }},
      %q{},
      %w(2.7)
    )

    assert_parses(
      s(:numblock,
        s(:send,
          s(:int, 1), :then), 1,
        s(:match_pattern_p,
          s(:int, 1),
          s(:pin,
            s(:lvar, :_1)))),
      %q{1.then { 1 in ^_1 }},
      %q{},
      SINCE_3_0
    )

    assert_parses(
      s(:case_match,
        s(:int, 0),
        s(:in_pattern,
          s(:match_var, :_1), nil, nil), nil),
      %q{case 0; in _1; end},
      %q{},
      %w(2.7)
    )

    assert_diagnoses(
      [:error, :reserved_for_numparam, { :name => '_1' }],
      %q{case 0; in _1; end},
      %q{           ^^ location},
      SINCE_3_0)

    assert_diagnoses(
      [:error, :undefined_lvar, { :name => '_1' }],
      %q{case 0; in ^_1; end},
      %q{            ^^ location},
      SINCE_2_7)
  end

  def assert_pattern_matching_defines_local_variables(match_code, lvar_names, versions = SINCE_2_7)
    code = "case 1; #{match_code}; then [#{lvar_names.join(', ')}]; end"

    with_versions(versions) do |version, parser|
      source_file = Parser::Source::Buffer.new('(assert_context)', source: code)

      lvar_names.each do |lvar_name|
        refute parser.static_env.declared?(lvar_name),
          "(#{version}) local variable #{lvar_name.to_s.inspect} has to be undefined before asserting"
      end

      before = parser.static_env.instance_variable_get(:@variables).to_a

      begin
        _parsed_ast = parser.parse(source_file)
      rescue Parser::SyntaxError => exc
        backtrace = exc.backtrace
        Exception.instance_method(:initialize).bind(exc).
          call("(#{version}) #{exc.message}")
        exc.set_backtrace(backtrace)
        raise
      end

      lvar_names.each do |lvar_name|
        assert parser.static_env.declared?(lvar_name),
          "(#{version}) expected local variable #{lvar_name.to_s.inspect} to be defined after parsing"
      end

      after = parser.static_env.instance_variable_get(:@variables).to_a
      extra = after - before - lvar_names

      assert extra.empty?,
             "(#{version}) expected only #{lvar_names.inspect} " \
             "to be defined during parsing, but also got #{extra.inspect}"
    end
  end

  def test_pattern_matching_creates_locals
    assert_pattern_matching_defines_local_variables(
      %q{in a, *b, c},
      [:a, :b, :c]
    )

    assert_pattern_matching_defines_local_variables(
      %q{in d | e | f},
      [:d, :e, :f]
    )

    assert_pattern_matching_defines_local_variables(
      %q{in { g:, **h }},
      [:g, :h]
    )

    assert_pattern_matching_defines_local_variables(
      %q{in A(i, *j, k)},
      [:i, :j, :k]
    )

    assert_pattern_matching_defines_local_variables(
      %q{in 1 => l},
      [:l]
    )

    assert_pattern_matching_defines_local_variables(
      %q{in "m":},
      [:m]
    )
  end

  def test_pattern_matching__FILE__LINE_literals
    assert_parses(
      s(:case_match,
        s(:array,
          s(:str, "(assert_parses)"),
          s(:send,
            s(:int, 1), :+,
            s(:int, 1)),
          s(:__ENCODING__)),
        s(:in_pattern,
          s(:array_pattern,
            s(:str, "(assert_parses)"),
            s(:int, 2),
            s(:__ENCODING__)), nil, nil), nil),
      <<-RUBY,
        case [__FILE__, __LINE__ + 1, __ENCODING__]
          in [__FILE__, __LINE__, __ENCODING__]
        end
      RUBY
      %q{},
      SINCE_2_7)
  end

  def test_pattern_matching_nil_pattern
    assert_parses_pattern_match(
      s(:in_pattern,
        s(:hash_pattern,
          s(:match_nil_pattern)),
        nil,
        s(:true)),
      %q{in **nil then true},
      %q{   ~~~~~ expression (in_pattern.hash_pattern.match_nil_pattern)
        |     ~~~ name (in_pattern.hash_pattern.match_nil_pattern)}
    )
  end

  def test_pattern_matching_single_line__27__legacy
    Parser::Builders::Default.emit_match_pattern = false
    assert_parses(
      s(:begin,
        s(:in_match,
          s(:int, 1),
          s(:array_pattern,
            s(:match_var, :a))),
        s(:lvar, :a)),
      %q{1 in [a]; a},
      %q{~~~~~~~~ expression (in_match)
        |  ~~ operator (in_match)},
      %w(2.7))
  ensure
    Parser::Builders::Default.emit_match_pattern = true
  end

  def test_pattern_matching_single_line__27
    assert_parses(
      s(:begin,
        s(:match_pattern,
          s(:int, 1),
          s(:array_pattern,
            s(:match_var, :a))),
        s(:lvar, :a)),
      %q{1 in [a]; a},
      %q{~~~~~~~~ expression (match_pattern)
        |  ~~ operator (match_pattern)},
      %w(2.7))
  end

  def test_pattern_matching_single_line
    assert_parses(
      s(:begin,
        s(:match_pattern,
          s(:int, 1),
          s(:array_pattern,
            s(:match_var, :a))),
        s(:lvar, :a)),
      %q{1 => [a]; a},
      %q{~~~~~~~~ expression (match_pattern)
        |  ~~ operator (match_pattern)},
      SINCE_3_0)

    assert_parses(
      s(:begin,
        s(:match_pattern_p,
          s(:int, 1),
          s(:array_pattern,
            s(:match_var, :a))),
        s(:lvar, :a)),
      %q{1 in [a]; a},
      %q{~~~~~~~~ expression (match_pattern_p)
        |  ~~ operator (match_pattern_p)},
      SINCE_3_0)
  end

  def test_pattern_matching_single_line_allowed_omission_of_parentheses
    assert_parses(
      s(:begin,
        s(:match_pattern,
          s(:array,
            s(:int, 1),
            s(:int, 2)),
          s(:array_pattern,
            s(:match_var, :a),
            s(:match_var, :b))),
        s(:lvar, :a)),
      %q{[1, 2] => a, b; a},
      %q{~~~~~~~~~~~~~~ expression (match_pattern)
        |       ~~ operator (match_pattern)},
      SINCE_3_1)

    assert_parses(
      s(:begin,
        s(:match_pattern,
          s(:hash,
            s(:pair,
              s(:sym, :a),
              s(:int, 1))),
          s(:hash_pattern,
            s(:match_var, :a))),
        s(:lvar, :a)),
      %q{{a: 1} => a:; a},
      %q{~~~~~~~~~~~~ expression (match_pattern)
        |       ~~ operator (match_pattern)},
      SINCE_3_1)

    assert_parses(
      s(:begin,
        s(:match_pattern_p,
          s(:array,
            s(:int, 1),
            s(:int, 2)),
          s(:array_pattern,
            s(:match_var, :a),
            s(:match_var, :b))),
        s(:lvar, :a)),
      %q{[1, 2] in a, b; a},
      %q{~~~~~~~~~~~~~~ expression (match_pattern_p)
        |       ~~ operator (match_pattern_p)},
      SINCE_3_1)

    assert_parses(
      s(:begin,
        s(:match_pattern_p,
          s(:hash,
            s(:pair,
              s(:sym, :a),
              s(:int, 1))),
          s(:hash_pattern,
            s(:match_var, :a))),
        s(:lvar, :a)),
      %q{{a: 1} in a:; a},
      %q{~~~~~~~~~~~~ expression (match_pattern_p)
        |       ~~ operator (match_pattern_p)},
      SINCE_3_1)

    assert_parses(
      s(:begin,
        s(:match_pattern_p,
          s(:hash,
            s(:pair,
              s(:sym, :key),
              s(:sym, :value))),
          s(:hash_pattern,
            s(:pair,
              s(:sym, :key),
              s(:match_var, :value)))),
        s(:lvar, :value)),
      %q{{key: :value} in key: value; value},
      %q{~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression (match_pattern_p)
        |              ~~ operator (match_pattern_p)},
      SINCE_3_1)

    assert_parses(
      s(:begin,
        s(:match_pattern,
          s(:hash,
            s(:pair,
              s(:sym, :key),
              s(:sym, :value))),
          s(:hash_pattern,
            s(:pair,
              s(:sym, :key),
              s(:match_var, :value)))),
        s(:lvar, :value)),
      %q{{key: :value} => key: value; value},
      %q{~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression (match_pattern)
        |              ~~ operator (match_pattern)},
      SINCE_3_1)
  end

  def test_ruby_bug_pattern_matching_restore_in_kwarg_flag
    refute_diagnoses(
      "p(({} in {a:}), a:\n 1)",
      %w(2.7))

    refute_diagnoses(
      "p(({} => {a:}), a:\n 1)",
      SINCE_3_0)
  end

  def test_pattern_matching_duplicate_variable_name
    assert_diagnoses(
      [:error, :duplicate_variable_name, { :name => 'a' }],
      %q{case 0; in a, a; end},
      %q{              ^ location},
      SINCE_2_7)

    refute_diagnoses(
      %q{case [0, 1, 2, 3]; in _, _, _a, _a; end},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :duplicate_variable_name, { :name => 'a' }],
      %q{case 0; in a, {a:}; end},
      %q{               ^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :duplicate_variable_name, { :name => 'a' }],
      %q{case 0; in a, {"a":}; end},
      %q{                ^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :duplicate_variable_name, { :name => 'a' }],
      %q{0 in [a, a]},
      %q{         ^ location},
      %w(2.7))

    assert_diagnoses(
      [:error, :duplicate_variable_name, { :name => 'a' }],
      %q{0 => [a, a]},
      %q{         ^ location},
      SINCE_3_0)

    assert_diagnoses(
      [:error, :duplicate_variable_name, { :name => 'a' }],
      %q{0 in [a, *a]},
      %q{          ^ location},
      SINCE_3_3)

    assert_diagnoses(
      [:error, :duplicate_variable_name, { :name => 'a' }],
      %q{0 in [*a, a, b, *b]},
      %q{          ^ location},
      SINCE_3_3)
  end

  def test_pattern_matching_duplicate_hash_keys
    assert_diagnoses(
      [:error, :duplicate_pattern_key, { :name => 'a' }],
      %q{ case 0; in a: 1, a: 2; end },
      %q{                  ^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :duplicate_pattern_key, { :name => 'a' }],
      %q{ case 0; in a: 1, "a": 2; end },
      %q{                  ^^^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :duplicate_pattern_key, { :name => 'a' }],
      %q{ case 0; in "a": 1, "a": 2; end },
      %q{                    ^^^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :duplicate_pattern_key, { :name => "a\0" }],
      %q{ case 0; in "a\x0":a1, "a\0":a2; end },
      %q{                       ^^^^^^ location},
      SINCE_2_7)

    assert_diagnoses(
      [:error, :duplicate_pattern_key, { :name => "abc" }],
      %q{ case 0; in "abc":a1, "a#{"b"}c":a2; end },
      %q{                      ^^^^^^^^^^^ location},
      SINCE_2_7)
  end

  def test_pattern_matching_required_parentheses_for_in_match
    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tCOMMA' }],
      %{1 in a, b},
      %{      ^ location},
      %w(2.7))

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tCOMMA' }],
      %{1 => a, b},
      %{      ^ location},
      %w(3.0))

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tASSOC' }],
      %{1 => a:},
      %{  ^^ location},
      %w(2.7))

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tLABEL' }],
      %{1 => a:},
      %{     ^^ location},
      %w(3.0))
  end

  def test_pattern_matching_required_bound_variable_before_pin
    assert_diagnoses(
      [:error, :undefined_lvar, { :name => 'a' }],
      %{case 0; in ^a; true; end},
      %{            ^ location},
      SINCE_2_7)
  end

  def test_parser_bug_645
    assert_parses(
      s(:block,
        s(:lambda),
        s(:args,
          s(:optarg, :arg,
            s(:hash))), nil),
      '-> (arg={}) {}',
      %{},
      SINCE_1_9)
  end

  def test_endless_method
    assert_parses(
      s(:def, :foo,
        s(:args),
        s(:int, 42)),
      %q{def foo() = 42},
      %q{~~~ keyword
        |    ~~~ name
        |          ^ assignment
        |! end
        |~~~~~~~~~~~~~~ expression},
      SINCE_3_0)

    assert_parses(
      s(:def, :inc,
        s(:args, s(:arg, :x)),
        s(:send,
          s(:lvar, :x), :+,
          s(:int, 1))),
      %q{def inc(x) = x + 1},
      %q{~~~ keyword
        |    ~~~ name
        |           ^ assignment
        |~~~~~~~~~~~~~~~~~~ expression},
      SINCE_3_0)

    assert_parses(
      s(:defs, s(:send, nil, :obj), :foo,
        s(:args),
        s(:int, 42)),
      %q{def obj.foo() = 42},
      %q{~~~ keyword
        |       ^ operator
        |        ~~~ name
        |              ^ assignment
        |~~~~~~~~~~~~~~~~~~ expression},
      SINCE_3_0)

    assert_parses(
      s(:defs, s(:send, nil, :obj), :inc,
        s(:args, s(:arg, :x)),
        s(:send,
          s(:lvar, :x), :+,
          s(:int, 1))),
      %q{def obj.inc(x) = x + 1},
      %q{~~~ keyword
        |        ~~~ name
        |       ^ operator
        |               ^ assignment
        |~~~~~~~~~~~~~~~~~~~~~~ expression},
      SINCE_3_0)
  end

  def test_endless_method_forwarded_args_legacy
    Parser::Builders::Default.emit_forward_arg = false
    assert_parses(
      s(:def, :foo,
        s(:forward_args),
        s(:send, nil, :bar,
          s(:forwarded_args))),
      %q{def foo(...) = bar(...)},
      %q{~~~ keyword
        |    ~~~ name
        |             ^ assignment
        |~~~~~~~~~~~~~~~~~~~~~~~ expression},
      SINCE_3_0)
    Parser::Builders::Default.emit_forward_arg = true
  end

  def test_endless_method_with_rescue_mod
    assert_parses(
      s(:def, :m,
        s(:args),
        s(:rescue,
          s(:int, 1),
          s(:resbody, nil, nil,
            s(:int, 2)), nil)),
      %q{def m() = 1 rescue 2},
      %q{},
      SINCE_3_0)

    assert_parses(
      s(:defs,
        s(:self), :m,
        s(:args),
        s(:rescue,
          s(:int, 1),
          s(:resbody, nil, nil,
            s(:int, 2)), nil)),
      %q{def self.m() = 1 rescue 2},
      %q{},
      SINCE_3_0)
  end

  def test_endless_method_command_syntax
    assert_parses(
      s(:def, :foo,
        s(:args),
        s(:send, nil, :puts,
          s(:str, "Hello"))),
      %q{def foo = puts "Hello"},
      %q{~~~ keyword
        |    ~~~ name
        |        ^ assignment
        |~~~~~~~~~~~~~~~~~~~~~~ expression},
      SINCE_3_1)

    assert_parses(
      s(:def, :foo,
        s(:args),
        s(:send, nil, :puts,
          s(:str, "Hello"))),
      %q{def foo() = puts "Hello"},
      %q{~~~ keyword
        |    ~~~ name
        |          ^ assignment
        |~~~~~~~~~~~~~~~~~~~~~~~~ expression},
      SINCE_3_1)

    assert_parses(
      s(:def, :foo,
        s(:args,
          s(:arg, :x)),
        s(:send, nil, :puts,
          s(:lvar, :x))),
      %q{def foo(x) = puts x},
      %q{~~~ keyword
        |    ~~~ name
        |           ^ assignment
        |~~~~~~~~~~~~~~~~~~~ expression},
      SINCE_3_1)

    assert_parses(
      s(:defs,
        s(:send, nil, :obj), :foo,
        s(:args),
        s(:send, nil, :puts,
          s(:str, "Hello"))),
      %q{def obj.foo = puts "Hello"},
      %q{~~~ keyword
        |       ^ operator
        |        ~~~ name
        |            ^ assignment
        |~~~~~~~~~~~~~~~~~~~~~~~~~~ expression},
      SINCE_3_1)

    assert_parses(
      s(:defs,
        s(:send, nil, :obj), :foo,
        s(:args),
        s(:send, nil, :puts,
          s(:str, "Hello"))),
      %q{def obj.foo() = puts "Hello"},
      %q{~~~ keyword
        |       ^ operator
        |        ~~~ name
        |              ^ assignment
        |~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression},
      SINCE_3_1)

    assert_parses(
      s(:def, :rescued,
        s(:args,
          s(:arg, :x)),
        s(:rescue,
          s(:send, nil, :raise,
            s(:str, "to be caught")),
          s(:resbody, nil, nil,
            s(:dstr,
              s(:str, "instance "),
              s(:begin,
                s(:lvar, :x)))), nil)),
      %q{def rescued(x) = raise "to be caught" rescue "instance #{x}"},
      %q{~~~ keyword
        |    ~~~~~~~ name
        |               ^ assignment
        |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression},
      SINCE_3_1)

    assert_parses(
      s(:defs,
        s(:self), :rescued,
        s(:args,
          s(:arg, :x)),
        s(:rescue,
          s(:send, nil, :raise,
            s(:str, "to be caught")),
          s(:resbody, nil, nil,
            s(:dstr,
              s(:str, "class "),
              s(:begin,
                s(:lvar, :x)))), nil)),
      %q{def self.rescued(x) = raise "to be caught" rescue "class #{x}"},
      %q{~~~ keyword
        |        ^ operator
        |         ~~~~~~~ name
        |                    ^ assignment
        |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression},
      SINCE_3_1)

    assert_parses(
      s(:defs,
        s(:send, nil, :obj), :foo,
        s(:args,
          s(:arg, :x)),
        s(:send, nil, :puts,
          s(:lvar, :x))),
      %q{def obj.foo(x) = puts x},
      %q{~~~ keyword
        |       ^ operator
        |        ~~~ name
        |               ^ assignment
        |~~~~~~~~~~~~~~~~~~~~~~~ expression},
      SINCE_3_1)
  end

  def test_private_endless_method_command_syntax
    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tSTRING' }],
      %q{private def foo = puts "Hello"},
      %q{                       ^^^^^^^ location},
      SINCE_3_1)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tSTRING' }],
      %q{private def foo() = puts "Hello"},
      %q{                         ^^^^^^^ location},
      SINCE_3_1)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tIDENTIFIER' }],
      %q{private def foo(x) = puts x},
      %q{                          ^ location},
      SINCE_3_1)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tSTRING' }],
      %q{private def obj.foo = puts "Hello"},
      %q{                           ^^^^^^^ location},
      SINCE_3_1)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tSTRING' }],
      %q{private def obj.foo() = puts "Hello"},
      %q{                             ^^^^^^^ location},
      SINCE_3_1)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tIDENTIFIER' }],
      %q{private def obj.foo(x) = puts x},
      %q{                              ^ location},
      SINCE_3_1)
  end

  def test_hash_pair_value_omission
    assert_parses(
      s(:hash,
        s(:pair, s(:sym, :a), s(:send, nil, :a)),
        s(:pair, s(:sym, :b), s(:send, nil, :b))),
      %q{{a:, b:}},
      %q{^ begin
        |       ^ end
        |  ^ operator (pair)
        | ~ expression (pair.sym)
        | ~ expression (pair.send)
        | ~~ expression (pair)
        |~~~~~~~~ expression},
      SINCE_3_1)

    assert_parses(
      s(:hash,
        s(:pair, s(:sym, :puts), s(:send, nil, :puts))),
      %q{{puts:}},
      %q{     ^ operator (pair)
        | ~~~~ expression (pair.sym)
        | ~~~~ expression (pair.send)
        | ~~~~ selector (pair.send)
        | ~~~~~ expression (pair)},
      SINCE_3_1)

    assert_parses(
      s(:begin,
        s(:lvasgn, :foo,
          s(:int, 1)),
        s(:hash,
          s(:pair,
            s(:sym, :foo),
            s(:lvar, :foo)))),
      %q{foo = 1; {foo:}},
      %q{},
      SINCE_3_1)

    assert_parses(
      s(:begin,
        s(:lvasgn, :_foo,
          s(:int, 1)),
        s(:hash,
          s(:pair,
            s(:sym, :_foo),
            s(:lvar, :_foo)))),
      %q{_foo = 1; {_foo:}},
      %q{},
      SINCE_3_1)

    assert_parses(
      s(:hash,
        s(:pair, s(:sym, :BAR), s(:const, nil, :BAR))),
      %q{{BAR:}},
      %q{    ^ operator (pair)
        | ~~~ expression (pair.sym)
        | ~~~ expression (pair.const)
        | ~~~ name (pair.const)
        | ~~~~ expression (pair)},
      SINCE_3_1)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tRCURLY' }],
      %q{{"#{x}":}},
      %q{        ^ location},
      SINCE_3_1)
  end

  def test_keyword_argument_omission
    assert_parses(
      s(:send, nil, :foo,
        s(:kwargs,
          s(:pair, s(:sym, :a), s(:send, nil, :a)),
          s(:pair, s(:sym, :b), s(:send, nil, :b)))),
      %q{foo(a:, b:)},
      %q{   ^ begin
        |          ^ end
        |     ^ operator (kwargs.pair)
        |    ~ expression (kwargs.pair.sym)
        |    ~ expression (kwargs.pair.send)
        |    ~~ expression (kwargs.pair)
        |    ~~~~~~ expression (kwargs)
        |~~~~~~~~~~~ expression},
      SINCE_3_1)
  end

  def test_hash_pair_value_omission_invalid_label
    assert_diagnoses(
      [:error, :invalid_id_to_get, { :identifier => 'foo?' }],
      %q{{ foo?: }},
      %q{  ^^^^ location},
      SINCE_3_1)

    assert_diagnoses(
      [:error, :invalid_id_to_get, { :identifier => 'bar!' }],
      %q{{ bar!: }},
      %q{  ^^^^ location},
      SINCE_3_1)
  end

  def test_rasgn_line_continuation
    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tASSOC' }],
      %Q{13.divmod(5)\n=> a,b; [a, b]},
      %{             ^^ location},
      SINCE_3_0)
  end

  def test_find_pattern
    assert_parses_pattern_match(
      s(:in_pattern,
        s(:find_pattern,
          s(:match_rest,
            s(:match_var, :x)),
          s(:match_as,
            s(:int, 1),
            s(:match_var, :a)),
          s(:match_rest,
            s(:match_var, :y))),
        nil,
        s(:true)),
      %q{in [*x, 1 => a, *y] then true},
      %q{   ~~~~~~~~~~~~~~~~ expression (in_pattern.find_pattern)
        |   ~ begin (in_pattern.find_pattern)
        |                  ~ end (in_pattern.find_pattern)
        |    ~~ expression (in_pattern.find_pattern.match_rest/1)
        |                ~~ expression (in_pattern.find_pattern.match_rest/2)},
      SINCE_3_0)

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:const_pattern,
          s(:const, nil, :String),
          s(:find_pattern,
            s(:match_rest),
            s(:int, 1),
            s(:match_rest))),
        nil,
        s(:true)),
      %q{in String(*, 1, *) then true},
      %q{          ~~~~~~~ expression (in_pattern.const_pattern.find_pattern)},
      SINCE_3_0)

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:const_pattern,
          s(:const, nil, :Array),
          s(:find_pattern,
            s(:match_rest),
            s(:int, 1),
            s(:match_rest))),
        nil,
        s(:true)),
      %q{in Array[*, 1, *] then true},
      %q{         ~~~~~~~ expression (in_pattern.const_pattern.find_pattern)},
      SINCE_3_0)

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:find_pattern,
          s(:match_rest),
          s(:int, 42),
          s(:match_rest)),
        nil,
        s(:true)),
      %q{in *, 42, * then true},
      %q{   ~~~~~~~~ expression (in_pattern.find_pattern)},
      SINCE_3_0)
  end

  def test_invalid_source
    with_versions(ALL_VERSIONS) do |_ver, parser|
      source_file = Parser::Source::Buffer.new('(comments)', source: "def foo; en")

      parser.diagnostics.all_errors_are_fatal = false
      ast = parser.parse(source_file)
      assert_nil(ast)
    end
  end

  def test_reserved_for_numparam__before_30
    assert_parses(
      s(:block,
        s(:send, nil, :proc),
        s(:args),
        s(:lvasgn, :_1,
          s(:nil))),
      %q{proc {_1 = nil}},
      %q{},
      ALL_VERSIONS - SINCE_3_0)

    assert_parses(
      s(:lvasgn, :_2,
        s(:int, 1)),
      %q{_2 = 1},
      %q{},
      ALL_VERSIONS - SINCE_3_0)

    assert_parses(
      s(:block,
        s(:send, nil, :proc),
        s(:args,
          s(:procarg0,
            s(:arg, :_3))), nil),
      %q{proc {|_3|}},
      %q{},
      SINCE_1_9 - SINCE_3_0)

    assert_parses(
      s(:def, :x,
        s(:args,
          s(:arg, :_4)), nil),
      %q{def x(_4) end},
      %q{},
      ALL_VERSIONS - SINCE_3_0)

    assert_parses(
      s(:def, :_5,
        s(:args), nil),
      %q{def _5; end},
      %q{},
      ALL_VERSIONS - SINCE_3_0)

    assert_parses(
      s(:defs,
        s(:self), :_6,
        s(:args), nil),
      %q{def self._6; end},
      %q{},
      ALL_VERSIONS - SINCE_3_0)
  end

  def test_reserved_for_numparam__since_30
    # Regular assignments:

    assert_diagnoses(
      [:error, :reserved_for_numparam, { :name => '_1' }],
      %q{proc {_1 = nil}},
      %q{      ^^ location},
      SINCE_3_0)

    assert_diagnoses(
      [:error, :reserved_for_numparam, { :name => '_2' }],
      %q{_2 = 1},
      %q{^^ location},
      SINCE_3_0)

    # Arguments:

    [
      # req (procarg0)
      [
        %q{proc {|_3|}},
        %q{       ^^ location},
      ],

      # req
      [
        %q{proc {|_3,|}},
        %q{       ^^ location},
      ],

      # opt
      [
        %q{proc {|_3 = 42|}},
        %q{       ^^ location},
      ],

      # mlhs
      [
        %q{proc {|(_3)|}},
        %q{        ^^ location},
      ],

      # rest
      [
        %q{proc {|*_3|}},
        %q{        ^^ location},
      ],

      # kwarg
      [
        %q{proc {|_3:|}},
        %q{       ^^^ location},
      ],

      # kwoptarg
      [
        %q{proc {|_3: 42|}},
        %q{       ^^^ location},
      ],

      # kwrestarg
      [
        %q{proc {|**_3|}},
        %q{         ^^ location},
      ],

      # block
      [
        %q{proc {|&_3|}},
        %q{        ^^ location},
      ],

      # shadowarg
      [
        %q{proc {|;_3|}},
        %q{        ^^ location},
      ],
    ].each do |(code, location)|
      assert_diagnoses(
        [:error, :reserved_for_numparam, { :name => '_3' }],
        code,
        location,
        SINCE_3_0)
    end

    # Method definitions:

    [
      # regular method
      [
        %q{def _5; end},
        %q{    ^^ location}
      ],
      # regular singleton method
      [
        %q{def self._5; end},
        %q{         ^^ location}
      ],
      # endless method
      [
        %q{def _5() = nil},
        %q{    ^^ location}
      ],
      # endless singleton method
      [
        %q{def self._5() = nil},
        %q{         ^^ location}
      ],
    ].each do |(code, location)|
      assert_diagnoses(
        [:error, :reserved_for_numparam, { :name => '_5' }],
        code,
        location,
        SINCE_3_0)
    end
  end

  def test_numparam_ruby_bug_19025
    assert_diagnoses_many(
      [
        [:warning, :ambiguous_prefix, { :prefix => '**' }],
        [:error, :unexpected_token, { :token => 'tDSTAR' }]
      ],
      'p { [_1 **2] }',
      %w[3.0 3.1])

    assert_parses(
      s(:numblock,
        s(:send, nil, :p), 1,
        s(:array,
          s(:send,
            s(:lvar, :_1), :**,
            s(:int, 2)))),
      'p { [_1 **2] }',
      %q{},
      SINCE_3_2)
  end

  def test_endless_setter
    assert_diagnoses(
      [:error, :endless_setter],
      %q{def foo=() = 42},
      %q{    ^^^^ location},
      SINCE_3_0)

    assert_diagnoses(
      [:error, :endless_setter],
      %q{def obj.foo=() = 42},
      %q{        ^^^^ location},
      SINCE_3_0)

    assert_diagnoses(
      [:error, :endless_setter],
      %q{def foo=() = 42 rescue nil},
      %q{    ^^^^ location},
      SINCE_3_0)

    assert_diagnoses(
      [:error, :endless_setter],
      %q{def obj.foo=() = 42 rescue nil},
      %q{        ^^^^ location},
      SINCE_3_0)
  end

  def test_endless_comparison_method
    %i[=== == != <= >= !=].each do |method_name|
      assert_parses(
        s(:def, method_name,
          s(:args,
            s(:arg, :other)),
          s(:send, nil, :do_something)),
        %Q{def #{method_name}(other) = do_something},
        %q{},
        SINCE_3_0)
    end
  end

  def test_endless_method_without_args
    assert_parses(
      s(:def, :foo,
        s(:args),
        s(:int, 42)),
      %q{def foo = 42},
      %q{},
      SINCE_3_0)

    assert_parses(
      s(:def, :foo,
        s(:args),
        s(:rescue,
          s(:int, 42),
          s(:resbody, nil, nil,
            s(:nil)), nil)),
      %q{def foo = 42 rescue nil},
      %q{},
      SINCE_3_0)

    assert_parses(
      s(:defs,
        s(:self), :foo,
        s(:args),
        s(:int, 42)),
      %q{def self.foo = 42},
      %q{},
      SINCE_3_0)

    assert_parses(
      s(:defs,
        s(:self), :foo,
        s(:args),
        s(:rescue,
          s(:int, 42),
          s(:resbody, nil, nil,
            s(:nil)), nil)),
      %q{def self.foo = 42 rescue nil},
      %q{},
      SINCE_3_0)
  end

  def test_parser_drops_truncated_parts_of_squiggly_heredoc
    assert_parses(
      s(:dstr,
        s(:begin),
        s(:str, "\n")),
      "<<~HERE\n  \#{}\nHERE",
      %q{},
      SINCE_2_3)
  end

  def test_pin_expr
    assert_parses_pattern_match(
      s(:in_pattern,
        s(:pin,
          s(:begin,
            s(:int, 42))), nil,
        s(:nil)),
      %q{in ^(42) then nil},
      %q{   ~ selector (in_pattern.pin)
        |   ~~~~~ expression (in_pattern.pin)
        |    ~ begin (in_pattern.pin.begin)
        |       ~ end (in_pattern.pin.begin)
        |    ~~~~ expression (in_pattern.pin.begin)},
      SINCE_3_1)

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:hash_pattern,
          s(:pair,
            s(:sym, :foo),
            s(:pin,
              s(:begin,
                s(:int, 42))))), nil,
        s(:nil)),
      %q{in { foo: ^(42) } then nil},
      %q{          ~ selector (in_pattern.hash_pattern.pair.pin)
        |          ~~~~~ expression (in_pattern.hash_pattern.pair.pin)
        |           ~ begin (in_pattern.hash_pattern.pair.pin.begin)
        |              ~ end (in_pattern.hash_pattern.pair.pin.begin)
        |           ~~~~ expression (in_pattern.hash_pattern.pair.pin.begin)},
      SINCE_3_1)

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:pin,
          s(:begin,
            s(:send,
              s(:int, 0), :+,
              s(:int, 0)))), nil,
        s(:nil)),
      %q{in ^(0+0) then nil},
      %q{   ~ selector (in_pattern.pin)
        |   ~~~~~~ expression (in_pattern.pin)
        |    ~ begin (in_pattern.pin.begin)
        |        ~ end (in_pattern.pin.begin)
        |    ~~~~~ expression (in_pattern.pin.begin)},
      SINCE_3_1)

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:pin,
          s(:ivar, :@a)), nil, nil),
      %q{in ^@a},
      %q{   ~ selector (in_pattern.pin)
        |   ~~~ expression (in_pattern.pin)},
      SINCE_3_1)

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:pin,
          s(:cvar, :@@TestPatternMatching)), nil, nil),
      %q{in ^@@TestPatternMatching},
      %q{   ~ selector (in_pattern.pin)
        |   ~~~~~~~~~~~~~~~~~~~~~~ expression (in_pattern.pin)},
      SINCE_3_1)

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:pin,
          s(:gvar, :$TestPatternMatching)), nil, nil),
      %q{in ^$TestPatternMatching},
      %q{   ~ selector (in_pattern.pin)
        |   ~~~~~~~~~~~~~~~~~~~~~ expression (in_pattern.pin)},
      SINCE_3_1)

    assert_parses_pattern_match(
      s(:in_pattern,
        s(:pin,
          s(:begin,
          s(:int, 1))), nil, nil),
      %Q{in ^(1\n)},
      %q{   ~ selector (in_pattern.pin)
        |   ~~~~~ expression (in_pattern.pin)},
      SINCE_3_2)
  end

  def test_assignment_to_numparam_via_pattern_matching
    assert_diagnoses(
      [:error, :reserved_for_numparam, { :name => '_1' }],
      %q{proc { 1 in _1 }},
      %q{            ~~ location},
      SINCE_3_0)

    assert_diagnoses(
      [:error, :cant_assign_to_numparam, { :name => '_1' }],
      %q{proc { _1; 1 in _1 }},
      %q{                ~~ location},
      SINCE_2_7)
  end

  def test_warn_on_duplicate_hash_key
    # symbol
    assert_diagnoses(
      [:warning, :duplicate_hash_key],
      %q{ { :foo => 1, :foo => 2 } },
      %q{              ^^^^ location},
      ALL_VERSIONS)

    # string
    assert_diagnoses(
      [:warning, :duplicate_hash_key],
      %q{ { "foo" => 1, "foo" => 2 } },
      %q{               ^^^^^ location},
      ALL_VERSIONS)

    # small number
    assert_diagnoses(
      [:warning, :duplicate_hash_key],
      %q{ { 1000 => 1, 1000 => 2 } },
      %q{              ^^^^ location},
      ALL_VERSIONS)

    # float
    assert_diagnoses(
      [:warning, :duplicate_hash_key],
      %q{ { 1.0 => 1, 1.0 => 2 } },
      %q{             ^^^ location},
      ALL_VERSIONS)

    # bignum
    assert_diagnoses(
      [:warning, :duplicate_hash_key],
      %q{ { 1_000_000_000_000_000_000 => 1, 1_000_000_000_000_000_000 => 2 } },
      %q{                                   ^^^^^^^^^^^^^^^^^^^^^^^^^ location},
      ALL_VERSIONS)

    # rational (tRATIONAL exists starting from 2.7)
    refute_diagnoses(%q{ { 1.0r => 1, 1.0r => 2 } },
      SINCE_2_1 - SINCE_3_1)

    assert_diagnoses(
      [:warning, :duplicate_hash_key],
      %q{ { 1.0r => 1, 1.0r => 2 } },
      %q{              ~~~~ location},
      SINCE_3_1)

    # complex (tIMAGINARY exists starting from 2.7)
    refute_diagnoses(%q{ { 1.0i => 1, 1.0i => 2 } },
      SINCE_2_1 - SINCE_3_1)

    assert_diagnoses(
      [:warning, :duplicate_hash_key],
      %q{ { 1.0i => 1, 1.0i => 2 } },
      %q{              ~~~~ location},
      SINCE_3_1)

    # small float
    assert_diagnoses(
      [:warning, :duplicate_hash_key],
      %q{ { 1.72723e-77 => 1, 1.72723e-77 => 2 } },
      %q{                     ~~~~~~~~~~~ location},
      ALL_VERSIONS)

    # regexp
    refute_diagnoses(%q{ { /foo/ => 1, /foo/ => 2 } },
      ALL_VERSIONS - SINCE_3_1)

    assert_diagnoses(
      [:warning, :duplicate_hash_key],
      %q{ { /foo/ => 1, /foo/ => 2 } },
      %q{               ~~~~~ location},
      SINCE_3_1)
  end

  def test_parser_bug_830
    assert_parses(
      s(:regexp,
        s(:str, "\\("),
        s(:regopt)),
      %q{/\(/},
      %q{},
      ALL_VERSIONS)
  end

  def test_control_meta_escape_chars_in_regexp__before_31
    assert_parses(
      s(:regexp, s(:str, "\\c\\xFF"), s(:regopt)),
      %q{/\c\xFF/}.dup.force_encoding('ascii-8bit'),
      %q{},
      ALL_VERSIONS - SINCE_3_1)

    assert_parses(
      s(:regexp, s(:str, "\\c\\M-\\xFF"), s(:regopt)),
      %q{/\c\M-\xFF/}.dup.force_encoding('ascii-8bit'),
      %q{},
      ALL_VERSIONS - SINCE_3_1)

    assert_parses(
      s(:regexp, s(:str, "\\C-\\xFF"), s(:regopt)),
      %q{/\C-\xFF/}.dup.force_encoding('ascii-8bit'),
      %q{},
      ALL_VERSIONS - SINCE_3_1)

    assert_parses(
      s(:regexp, s(:str, "\\C-\\M-\\xFF"), s(:regopt)),
      %q{/\C-\M-\xFF/}.dup.force_encoding('ascii-8bit'),
      %q{},
      ALL_VERSIONS - SINCE_3_1)

    assert_parses(
      s(:regexp, s(:str, "\\M-\\xFF"), s(:regopt)),
      %q{/\M-\xFF/}.dup.force_encoding('ascii-8bit'),
      %q{},
      ALL_VERSIONS - SINCE_3_1)

    assert_parses(
      s(:regexp, s(:str, "\\M-\\C-\\xFF"), s(:regopt)),
      %q{/\M-\C-\xFF/}.dup.force_encoding('ascii-8bit'),
      %q{},
      ALL_VERSIONS - SINCE_3_1)

    assert_parses(
      s(:regexp, s(:str, "\\M-\\c\\xFF"), s(:regopt)),
      %q{/\M-\c\xFF/}.dup.force_encoding('ascii-8bit'),
      %q{},
      ALL_VERSIONS - SINCE_3_1)
  end

  def test_control_meta_escape_chars_in_regexp__since_31
    x9f = "\x9F".dup.force_encoding('ascii-8bit')

    assert_parses(
      s(:regexp, s(:str, x9f), s(:regopt)),
      %q{/\c\xFF/}.dup.force_encoding('ascii-8bit'),
      %q{},
      SINCE_3_1)

    assert_parses(
      s(:regexp, s(:str, x9f), s(:regopt)),
      %q{/\c\M-\xFF/}.dup.force_encoding('ascii-8bit'),
      %q{},
      SINCE_3_1)

    assert_parses(
      s(:regexp, s(:str, x9f), s(:regopt)),
      %q{/\C-\xFF/}.dup.force_encoding('ascii-8bit'),
      %q{},
      SINCE_3_1)

    assert_parses(
      s(:regexp, s(:str, x9f), s(:regopt)),
      %q{/\C-\M-\xFF/}.dup.force_encoding('ascii-8bit'),
      %q{},
      SINCE_3_1)

    assert_parses(
      s(:regexp, s(:str, x9f), s(:regopt)),
      %q{/\M-\xFF/}.dup.force_encoding('ascii-8bit'),
      %q{},
      SINCE_3_1)

    assert_parses(
      s(:regexp, s(:str, x9f), s(:regopt)),
      %q{/\M-\C-\xFF/}.dup.force_encoding('ascii-8bit'),
      %q{},
      SINCE_3_1)

    assert_parses(
      s(:regexp, s(:str, x9f), s(:regopt)),
      %q{/\M-\c\xFF/}.dup.force_encoding('ascii-8bit'),
      %q{},
      SINCE_3_1)
  end

  def test_forward_arg_with_open_args
    assert_diagnoses_many(
      [
        [:warning, :triple_dot_at_eol],
        [:error, :unexpected_token, { :token => 'tDOT3' }],
      ],
      %Q{def foo ...\nend},
      SINCE_2_7 - SINCE_3_1)

    assert_diagnoses_many(
      [
        [:error, :unexpected_token, { :token => 'tBDOT3' }],
      ],
      %Q{def foo a, b = 1, ...\nend},
      SINCE_2_7 - SINCE_3_1)

    assert_parses(
      s(:def, :foo,
        s(:args, s(:forward_arg)), nil),
      %Q{def foo ...\nend},
      %q{        ~~~ expression (args.forward_arg)},
      SINCE_3_1)

    assert_parses(
      s(:def, :foo,
        s(:args,
          s(:arg, :a),
          s(:optarg, :b,
            s(:int, 1)),
          s(:forward_arg)), nil),
      %Q{def foo a, b = 1, ...\nend},
      %q{                  ~~~ expression (args.forward_arg)},
      SINCE_3_1)

    assert_diagnoses(
      [:error, :forward_arg_after_restarg],
      %Q{def foo *rest, ...\nend},
      %q{               ~~~ location
        |        ~~~~~ highlights (0)},
      SINCE_3_1)

    assert_parses(
      s(:def, :foo,
        s(:args,
          s(:arg, :a),
          s(:forward_arg)),
        s(:send, nil, :bar,
          s(:forwarded_args))),
      "def foo(a, ...) bar(...) end",
      %q{},
      SINCE_3_1)

    assert_parses(
      s(:def, :foo,
        s(:args,
          s(:arg, :a),
          s(:forward_arg)),
        s(:send, nil, :bar,
          s(:forwarded_args))),
      "def foo a, ...\n  bar(...)\nend",
      %q{},
      SINCE_3_1)

    assert_parses(
      s(:def, :foo,
        s(:args,
          s(:optarg, :b,
            s(:int, 1)),
          s(:forward_arg)),
        s(:send, nil, :bar,
          s(:forwarded_args))),
      "def foo b = 1, ...\n  bar(...)\nend",
      %q{},
      SINCE_3_1)

    assert_parses(
      s(:def, :foo,
        s(:args,
          s(:forward_arg)),
        s(:send, nil, :bar,
          s(:forwarded_args))),
      "def foo ...; bar(...); end",
      %q{},
      SINCE_3_1)

    assert_parses(
      s(:def, :foo,
        s(:args,
          s(:arg, :a),
          s(:forward_arg)),
        s(:send, nil, :bar,
          s(:forwarded_args))),
      "def foo a, ...; bar(...); end",
      %q{},
      SINCE_3_1)

    assert_parses(
      s(:def, :foo,
        s(:args,
          s(:optarg, :b,
            s(:int, 1)),
          s(:forward_arg)),
        s(:send, nil, :bar,
          s(:forwarded_args))),
      "def foo b = 1, ...; bar(...); end",
      %q{},
      SINCE_3_1)

    assert_parses(
      s(:begin,
        s(:def, :foo,
          s(:args,
            s(:forward_arg)),
          s(:send, nil, :bar,
            s(:forwarded_args)))),
      "(def foo ...\n  bar(...)\nend)",
      %q{},
      SINCE_3_1)

    assert_parses(
      s(:begin,
        s(:def, :foo,
          s(:args,
            s(:forward_arg)),
          s(:send, nil, :bar,
            s(:forwarded_args)))),
      "(def foo ...; bar(...); end)",
      %q{},
      SINCE_3_1)
  end

  def test_anonymous_blockarg
    assert_parses(
      s(:def, :foo,
        s(:args,
          s(:blockarg, nil)),
        s(:send, nil, :bar,
          s(:block_pass, nil))),
      %q{def foo(&); bar(&); end},
      %q{        ~ expression (args.blockarg)
        |                ~ operator (send.block_pass)
        |                ~ expression (send.block_pass)},
      SINCE_3_1)

    assert_diagnoses(
      [:error, :no_anonymous_blockarg],
      %q{def foo(); bar(&); end},
      %q{               ^ location},
      SINCE_3_1)

    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tINTEGER' }],
      %q{def foo(&0); end},
      %q{         ^ location},
      SINCE_3_1)
  end

  def test_invalid_escape_sequence_in_regexp__before_32
    assert_diagnoses(
      [:fatal, :invalid_unicode_escape],
      %q{/foo-\\u-bar/},
      %q{},
      ALL_VERSIONS - SINCE_3_2)
  end

  if RUBY_ENGINE != 'truffleruby'
    def test_invalid_escape_sequence_in_regexp__since_32
      assert_diagnoses(
        [:error, :invalid_regexp, { :message => "invalid Unicode escape: /foo-\\u-bar/" }],
        %q{/foo-\\u-bar/},
        %q{},
        SINCE_3_2)
    end
  end

  def test_forwarded_restarg
    assert_parses(
      s(:def, :foo,
        s(:args,
          s(:restarg)),
        s(:send, nil, :bar,
          s(:forwarded_restarg))),
      %q{def foo(*); bar(*); end},
      %q{                ~ expression (send.forwarded_restarg)},
      SINCE_3_2)

    assert_diagnoses(
      [:error, :no_anonymous_restarg],
      %q{def foo; bar(*); end},
      %q{},
      SINCE_3_2)
  end

  def test_forwarded_argument_with_restarg
    assert_parses(
      s(:def, :foo,
        s(:args,
          s(:arg, :argument),
          s(:restarg)),
        s(:send, nil, :bar,
          s(:lvar, :argument),
          s(:forwarded_restarg))),
      %q{def foo(argument, *); bar(argument, *); end},
      %q{                                    ~ expression (send.forwarded_restarg)},
      SINCE_3_2)

    assert_diagnoses(
      [:error, :no_anonymous_restarg],
      %q{def foo; bar(argument, *); end},
      %q{},
      SINCE_3_2)
  end

  def test_forwarded_kwrestarg
    assert_parses(
      s(:def, :foo,
        s(:args,
          s(:kwrestarg)),
        s(:send, nil, :bar,
          s(:kwargs,
            s(:forwarded_kwrestarg)))),
      %q{def foo(**); bar(**); end},
      %q{                 ~~ expression (send.kwargs.forwarded_kwrestarg)},
      SINCE_3_2)

    assert_diagnoses(
      [:error, :no_anonymous_kwrestarg],
      %q{def foo; bar(**); end},
      %q{},
      SINCE_3_2)
  end

  def test_forwarded_kwrestarg_with_additional_kwarg
    assert_parses(
      s(:def, :foo,
        s(:args,
          s(:kwrestarg)),
        s(:send, nil, :bar,
          s(:kwargs,
            s(:forwarded_kwrestarg),
            s(:pair,
              s(:sym, :from_foo),
              s(:true))))),
      %q{def foo(**); bar(**, from_foo: true); end},
      %q{                 ~~ expression (send.kwargs.forwarded_kwrestarg)},
      SINCE_3_2)

    refute_diagnoses(
      %q{def foo(**); bar(**, from_foo: true); end},
      SINCE_3_2)

    assert_diagnoses(
      [:warning, :duplicate_hash_key],
      %q{def foo(**); bar(foo: 1, **, foo: 2); end},
      %q{                             ^^^ location},
      SINCE_3_2)
  end

  def test_forwarded_argument_with_kwrestarg
    assert_parses(
      s(:def, :foo,
        s(:args,
          s(:arg, :argument),
          s(:kwrestarg)),
        s(:send, nil, :bar,
          s(:lvar, :argument),
          s(:kwargs,
            s(:forwarded_kwrestarg)))),
      %q{def foo(argument, **); bar(argument, **); end},
      %q{                                     ~~ expression (send.kwargs.forwarded_kwrestarg)},
      SINCE_3_2)

    assert_diagnoses(
      [:error, :no_anonymous_kwrestarg],
      %q{def foo; bar(argument, **); end},
      %q{},
      SINCE_3_2)
  end

  def test_if_while_after_class__since_32
    assert_parses(
      s(:module,
        s(:const,
          s(:if,
            s(:true),
            s(:const, nil, :Object), nil), :Kernel), nil),
      %q{module if true; Object end::Kernel; end},
      %q{},
      SINCE_3_2)

    assert_parses(
      s(:module,
        s(:const,
          s(:while,
            s(:true),
            s(:break,
              s(:const, nil, :Object))), :Kernel), nil),
      %q{module while true; break Object end::Kernel; end},
      %q{},
      SINCE_3_2)

    assert_parses(
      s(:class,
        s(:const,
          s(:if,
            s(:true),
            s(:const, nil, :Object), nil), :Kernel), nil, nil),
      %q{class if true; Object end::Kernel; end},
      %q{},
      SINCE_3_2)

    assert_parses(
      s(:class,
        s(:const,
          s(:while,
            s(:true),
            s(:break,
              s(:const, nil, :Object))), :Kernel), nil, nil),
      %q{class while true; break Object end::Kernel; end},
      %q{},
      SINCE_3_2)
  end

  def test_bare_backslash
    assert_diagnoses(
      [:error, :bare_backslash],
      %q{x = \ 42},
      %q{    ^ location},
      ALL_VERSIONS)
  end

  def test_newline_in_hash_argument
    assert_parses(
      s(:send,
        s(:send, nil, :obj), :set,
        s(:kwargs,
          s(:pair,
            s(:sym, :foo),
            s(:int, 1)))),
      %Q{obj.set foo:\n1},
      %q{},
      SINCE_3_2)

    assert_parses(
      s(:send,
        s(:send, nil, :obj), :set,
        s(:kwargs,
          s(:pair,
            s(:sym, :foo),
            s(:int, 1)))),
      %Q{obj.set "foo":\n1},
      %q{},
      SINCE_3_2)

    assert_parses(
      s(:case_match,
        s(:lvar, :foo),
        s(:in_pattern,
          s(:hash_pattern,
            s(:match_var, :a)), nil,
          s(:begin,
            s(:int, 0),
            s(:true))),
        s(:in_pattern,
          s(:hash_pattern,
            s(:match_var, :b)), nil,
          s(:begin,
            s(:int, 0),
            s(:true))), nil),
      %Q{case foo\nin a:\n0\ntrue\nin "b":\n0\ntrue\nend},
      %q{},
      SINCE_3_2)
  end

  def test_multiple_pattern_matches
    code = '{a: 0} => a:'
    node = s(:match_pattern,
            s(:hash,
              s(:pair,
                s(:sym, :a),
                s(:int, 0))),
            s(:hash_pattern,
              s(:match_var, :a)))
    assert_parses(
      s(:begin,
        node,
        node),
      %Q{#{code}\n#{code}},
      %q{},
      SINCE_3_1)

    code = '{a: 0} in a:'
    node = s(:match_pattern_p,
            s(:hash,
              s(:pair,
                s(:sym, :a),
                s(:int, 0))),
            s(:hash_pattern,
              s(:match_var, :a)))
    assert_parses(
      s(:begin,
        node,
        node),
      %Q{#{code}\n#{code}},
      %q{},
      SINCE_3_1)
  end

  def test_kwoptarg_with_kwrestarg_and_forwarded_args
    assert_parses(
      s(:def, :f,
        s(:args,
          s(:kwoptarg, :a,
            s(:nil)),
          s(:kwrestarg)),
        s(:send, nil, :b,
          s(:kwargs,
            s(:forwarded_kwrestarg)))),
      %Q{def f(a: nil, **); b(**) end},
      %q{},
      SINCE_3_2)
  end

  def test_argument_forwarding_with_anon_rest_kwrest_and_block
    assert_diagnoses(
      [:error, :unexpected_token, { token: 'tBDOT3' }],
      %q{def f(*, **, &); g(...); end},
      %q{},
      SINCE_3_2)

    assert_diagnoses(
      [:error, :no_anonymous_restarg],
      %q{def f(...); g(*); end},
      %q{},
      SINCE_3_2)

    assert_diagnoses(
      [:error, :no_anonymous_restarg],
      %q{def f(...); g(0, *); end},
      %q{},
      SINCE_3_2)

    assert_diagnoses(
      [:error, :no_anonymous_kwrestarg],
      %q{def f(...); g(**); end},
      %q{},
      SINCE_3_2)

    assert_diagnoses(
      [:error, :no_anonymous_kwrestarg],
      %q{def f(...); g(x: 1, **); end},
      %q{},
      SINCE_3_2)
  end

  def test_ruby_bug_18878
    assert_parses(
      s(:block,
        s(:send,
          s(:const, nil, :Foo), :Bar),
        s(:args,
          s(:procarg0,
            s(:arg, :a))),
        s(:int, 42)),
      'Foo::Bar { |a| 42 }',
      %q{},
      SINCE_3_3)
  end

  def test_ruby_bug_19281
    assert_parses(
      s(:send, nil, :p,
        s(:begin,
          s(:int, 1),
          s(:int, 2)),
        s(:begin,
          s(:int, 3)),
        s(:begin,
          s(:int, 4))),
      'p (1;2),(3),(4)',
      %q{},
      SINCE_3_3)

    assert_parses(
      s(:send, nil, :p,
        s(:begin),
        s(:begin),
        s(:begin)),
      'p (;),(),()',
      %q{},
      SINCE_3_3)

    assert_parses(
      s(:send,
        s(:send, nil, :a), :b,
        s(:begin,
          s(:int, 1),
          s(:int, 2)),
        s(:begin,
          s(:int, 3)),
        s(:begin,
          s(:int, 4))),
      'a.b (1;2),(3),(4)',
      %q{},
      SINCE_3_3)

    assert_parses(
      s(:send,
        s(:send, nil, :a), :b,
        s(:begin),
        s(:begin),
        s(:begin)),
      'a.b (;),(),()',
      %q{},
      SINCE_3_3)
  end

  def test_ungettable_gvar
    assert_diagnoses(
      [:error, :gvar_name, { :name => '$01234' }],
      '$01234',
      '^^^^^^ location',
      ALL_VERSIONS)

    assert_diagnoses(
      [:error, :gvar_name, { :name => '$01234' }],
      '"#$01234"',
      '  ^^^^^^ location',
      ALL_VERSIONS)
  end

  def test_it_warning_in_33
    refute_diagnoses(
      'if false; it; end',
      ALL_VERSIONS)
    refute_diagnoses(
      'def foo; it; end',
      ALL_VERSIONS)
    assert_diagnoses(
      [:warning, :ambiguous_it_call, {}],
      '0.times { it }',
      '          ^^ location',
      ['3.3'])
    refute_diagnoses(
      '0.times { || it }',
      ALL_VERSIONS)
    refute_diagnoses(
      '0.times { |_n| it }',
      ALL_VERSIONS)
    assert_diagnoses(
      [:warning, :ambiguous_it_call, {}],
      '0.times { it; it = 1; it }',
      '          ^^ location',
      ['3.3'])
    refute_diagnoses(
      '0.times { it = 1; it }',
      ALL_VERSIONS)
    refute_diagnoses(
      'it = 1; 0.times { it }',
      ALL_VERSIONS)
  end

  def test_anonymous_params_in_nested_scopes
    assert_diagnoses(
      [:error, :ambiguous_anonymous_blockarg, {}],
      'def b(&) ->(&) {c(&)} end',
      '                  ^ location',
      SINCE_3_3)
    assert_diagnoses(
      [:error, :ambiguous_anonymous_restarg, {}],
      'def b(*) ->(*) {c(*)} end',
      '                  ^ location',
      SINCE_3_3)
    assert_diagnoses(
      [:error, :ambiguous_anonymous_restarg, {}],
      'def b(a, *) ->(*) {c(1, *)} end',
      '                        ^ location',
      SINCE_3_3)
    assert_diagnoses(
      [:error, :ambiguous_anonymous_restarg, {}],
      'def b(*) ->(a, *) {c(*)} end',
      '                     ^ location',
      SINCE_3_3)
    assert_diagnoses(
      [:error, :ambiguous_anonymous_kwrestarg, {}],
      'def b(**) ->(**) {c(**)} end',
      '                    ^^ location',
      SINCE_3_3)
    assert_diagnoses(
      [:error, :ambiguous_anonymous_kwrestarg, {}],
      'def b(k:, **) ->(**) {c(k: 1, **)} end',
      '                              ^^ location',
      SINCE_3_3)
    assert_diagnoses(
      [:error, :ambiguous_anonymous_kwrestarg, {}],
      'def b(**) ->(k:, **) {c(**)} end',
      '                        ^^ location',
      SINCE_3_3)

    refute_diagnoses(
      'def b(&) ->(&) {c()} end',
      SINCE_3_3)
    refute_diagnoses(
      'def b(*) ->(*) {c()} end',
      SINCE_3_3)
    refute_diagnoses(
      'def b(**) ->(**) {c()} end',
      SINCE_3_3)
  end

  def test_parser_bug_989
    assert_parses(
      s(:str, "\t\tcontent\n"),
      "\t<<-HERE\n\t\tcontent\n\tHERE",
      %q{},
      ALL_VERSIONS)
  end

  def test_parser_bug_19370
    refute_diagnoses(
      'def b(&) ->() {c(&)} end',
      SINCE_3_3)

    refute_diagnoses(
      'def b(*) ->() {c(*)} end',
      SINCE_3_3)

    refute_diagnoses(
      'def b(a, *) ->() {c(1, *)} end',
      SINCE_3_3)

    refute_diagnoses(
      'def b(*) ->(a) {c(*)} end',
      SINCE_3_3)

    refute_diagnoses(
      'def b(**) ->() {c(**)} end',
      SINCE_3_3)

    refute_diagnoses(
      'def b(k:, **) ->() {c(k: 1, **)} end',
      SINCE_3_3)

    refute_diagnoses(
      'def b(**) ->(k:) {c(**)} end',
      SINCE_3_3)
  end
end
