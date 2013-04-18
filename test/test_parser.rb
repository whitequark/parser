require 'helper'
require 'parse_helper'

class TestParser < MiniTest::Unit::TestCase
  include ParseHelper

  def parser_for_ruby_version(version)
    parser = super
    parser.diagnostics.all_errors_are_fatal = true

    %w(foo bar baz).each do |metasyntactic_var|
      parser.static_env.declare(metasyntactic_var)
    end

    parser
  end

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
      s(:nil),
      %q{})
  end

  def test_nil
    assert_parses(
      s(:nil),
      %q{nil},
      %q{~~~ expression})
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
      s(:int, -42),
      %q{-42},
      %q{~~~ expression})
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
      %q{~~~~~ expression})
  end

  # Strings

  def test_string_plain
    assert_parses(
      s(:str, 'foobar'),
      %q{'foobar'},
      %q{^ begin
        |       ^ end
        |~~~~~~~~ expression})
  end

  def test_string_interp
    assert_parses(
      s(:dstr,
        s(:str, 'foo'),
        s(:lvar, :bar),
        s(:str, 'baz')),
      %q{"foo#{bar}baz"},
      %q{^ begin
        |             ^ end
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
      %q{^ begin
        |^ begin (dstr)
        |       ^ end (dstr)
        |         ^ begin (str)
        |             ^ end (str)
        |             ^ end
        |~~~~~~~~~~~~~~ expression})
  end

  def test_string___FILE__
    assert_parses(
      s(:str, '(assert_parses)'),
      %q{__FILE__},
      %q{~~~~~~~~ expression})
  end

  # Symbols

  def test_symbol_plain
    assert_parses(
      s(:sym, :foo),
      %q{:foo},
      %q{~~~~ expression})

    assert_parses(
      s(:sym, :foo),
      %q{:'foo'},
      %q{ ^ begin
        |     ^ end
        |~~~~~~ expression})
  end

  def test_symbol_interp
    assert_parses(
      s(:dsym,
        s(:str, 'foo'),
        s(:lvar, :bar),
        s(:str, 'baz')),
      %q{:"foo#{bar}baz"},
      %q{ ^ begin
        |              ^ end
        | ~~~~~~~~~~~~~~ expression})
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
        s(:lvar, :bar),
        s(:str, 'baz')),
      %q{`foo#{bar}baz`},
      %q{^ begin
        |             ^ end
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
        s(:lvar, :bar),
        s(:str, 'baz'),
        s(:regopt)),
      %q{/foo#{bar}baz/},
      %q{^ begin
        |             ^ end
        |~~~~~~~~~~~~~~ expression})
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
      ALL_VERSIONS - %w(1.8))

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
      ALL_VERSIONS - %w(1.8))
  end

  def test_array_words
    assert_parses(
      s(:array, s(:str, "foo"), s(:str, "bar")),
      %q{%w[foo bar]},
      %q{^^^ begin
        |          ^ end
        |   ~~~ expression (str)
        |~~~~~~~~~~~ expression})
  end

  def test_array_words_interp
    assert_parses(
      s(:array,
        s(:str, "foo"),
        s(:dstr, s(:lvar, :bar))),
      %q{%W[foo #{bar}]},
      %q{^^^ begin
        |             ^ end
        |   ~~~ expression (str)
        |         ~~~ expression (dstr.lvar)
        |~~~~~~~~~~~~~~ expression})

    assert_parses(
      s(:array,
        s(:str, "foo"),
        s(:dstr, s(:lvar, :bar), s(:str, 'foo'), s(:ivar, :@baz))),
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
      ALL_VERSIONS - %w(1.8 1.9))
  end

  def test_array_symbols_interp
    assert_parses(
      s(:array,
        s(:sym, :foo),
        s(:dsym, s(:lvar, :bar))),
      %q{%I[foo #{bar}]},
      %q{^^^ begin
        |             ^ end
        |   ~~~ expression (sym)
        |         ~~~ expression (dsym.lvar)
        |~~~~~~~~~~~~~~ expression},
      ALL_VERSIONS - %w(1.8 1.9))

    assert_parses(
      s(:array, s(:dsym, s(:str, "foo"),  s(:lvar, :bar))),
      %q{%I[foo#{bar}]},
      %q{},
      ALL_VERSIONS - %w(1.8 1.9))
  end

  def test_array_symbols_empty
    assert_parses(
      s(:array),
      %q{%i[]},
      %q{^^^ begin
        |   ^ end
        |~~~~ expression},
      ALL_VERSIONS - %w(1.8 1.9))

    assert_parses(
      s(:array),
      %q{%I()},
      %q{},
      ALL_VERSIONS - %w(1.8 1.9))
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
        ALL_VERSIONS - %w(1.8))
  end

  def test_hash_kwsplat
    assert_parses(
      s(:hash,
        s(:pair, s(:sym, :foo), s(:int, 2)),
        s(:kwsplat, s(:lvar, :bar))),
      %q[{ foo: 2, **bar }],
      %q{          ^^ operator (kwsplat)
        |          ~~~~~ expression (kwsplat)},
        %w(2.0))
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
        |~~~~~ expression})
  end

  def test_const_scoped
    assert_parses(
      s(:const, s(:const, nil, :Bar), :Foo),
      %q{Bar::Foo},
      %q{     ~~~ name
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
      s(:const, s(:const, nil, :Encoding), :UTF_8),
      %q{__ENCODING__},
      %q{~~~~~~~~~~~~ expression},
      ALL_VERSIONS - %w(1.8))
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

  def test_cvdecl
    assert_parses(
      s(:cvdecl, :@@var, s(:int, 10)),
      %q{@@var = 10},
      %q{~~~~~ name
        |      ^ operator
        |~~~~~~~~~~ expression
        })
  end

  def test_cvasgn
    assert_parses(
      s(:def, :a, s(:args),
        s(:cvasgn, :@@var, s(:int, 10))),
      %q{def a; @@var = 10; end},
      %q{       ~~~~~ name (cvasgn)
        |             ^ operator (cvasgn)
        |       ~~~~~~~~~~ expression (cvasgn)
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
      ALL_VERSIONS - %w(1.8))
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

  def test_cdecl_toplevel
    assert_parses(
      s(:cdecl, s(:cbase), :Foo, s(:int, 10)),
      %q{::Foo = 10},
      %q{  ~~~ name
        |      ^ operator
        |~~~~~~~~~~ expression
        })
  end

  def test_cdecl_scoped
    assert_parses(
      s(:cdecl, s(:const, nil, :Bar), :Foo, s(:int, 10)),
      %q{Bar::Foo = 10},
      %q{     ~~~ name
        |         ^ operator
        |~~~~~~~~~~~~~ expression
        })
  end

  def test_cdecl_unscoped
    assert_parses(
      s(:cdecl, nil, :Foo, s(:int, 10)),
      %q{Foo = 10},
      %q{~~~ name
        |    ^ operator
        |~~~~~~~~ expression
        })
  end

  def test_cdecl_invalid
    assert_diagnoses(
      [:error, :dynamic_const],
      %q{def f; Foo = 1; end},
      %q{       ~~~ location})

    assert_diagnoses(
      [:error, :dynamic_const],
      %q{def f; Foo::Bar = 1; end},
      %q{            ~~~ location})

    assert_diagnoses(
      [:error, :dynamic_const],
      %q{def f; ::Bar = 1; end},
      %q{         ~~~ location})
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
      %q{^ begin
        |         ^ end})

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
        s(:mlhs, s(:ivasgn, :@foo), s(:cvdecl, :@@bar)),
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
      ALL_VERSIONS - %w(1.8))

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
      ALL_VERSIONS - %w(1.8))

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
      ALL_VERSIONS - %w(1.8))

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
      ALL_VERSIONS - %w(1.8))

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
      ALL_VERSIONS - %w(1.8))
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
          s(:send, s(:self), :[]=, s(:int, 1), s(:int, 2))),
        s(:lvar, :foo)),
      %q{self.a, self[1, 2] = foo},
      %q{~~~~~~ expression (mlhs.send/1)
        |     ~ selector (mlhs.send/1)
        |            ~~~~~~ selector (mlhs.send/2)
        |        ~~~~~~~~~~ expression (mlhs.send/2)})

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
          s(:cdecl, s(:self), :A),
          s(:lvasgn, :foo)),
        s(:lvar, :foo)),
      %q{self::A, foo = foo})

    assert_parses(
      s(:masgn,
        s(:mlhs,
          s(:cdecl, s(:cbase), :A),
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
      %q{      ~~~~~~ array
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
      %q{             ~ location})

    assert_diagnoses(
      [:error, :dynamic_const],
      %q{def f; ::A, foo = foo; end},
      %q{         ~ location})
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
      s(:op_asgn, s(:cvdecl, :@@var), :|, s(:int, 10)),
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
        s(:cdecl, nil, :A), :+,
        s(:int, 1)),
      %q{A += 1})

    assert_parses(
      s(:op_asgn,
        s(:cdecl, s(:cbase), :A), :+,
        s(:int, 1)),
      %q{::A += 1},
      %q{},
      ALL_VERSIONS - %w(1.8 1.9))

    assert_parses(
      s(:op_asgn,
        s(:cdecl, s(:const, nil, :B), :A), :+,
        s(:int, 1)),
      %q{B::A += 1},
      %q{},
      ALL_VERSIONS - %w(1.8 1.9))
  end

  def test_const_op_asgn_invalid
    assert_diagnoses(
      [:error, :dynamic_const],
      %q{Foo::Bar += 1},
      %q{     ~~~ location},
      %w(1.8 1.9))

    assert_diagnoses(
      [:error, :dynamic_const],
      %q{::Bar += 1},
      %q{  ~~~ location},
      %w(1.8 1.9))

    assert_diagnoses(
      [:error, :dynamic_const],
      %q{def foo; Foo::Bar += 1; end},
      %q{              ~~~ location})

    assert_diagnoses(
      [:error, :dynamic_const],
      %q{def foo; ::Bar += 1; end},
      %q{           ~~~ location})
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

    assert_parses(
      s(:op_asgn,
        s(:send, s(:lvar, :foo), :A), :+,
        s(:send, nil, :m, s(:lvar, :foo))),
      %q{foo::A += m foo},
      %q{},
      ALL_VERSIONS - %w(1.8))
  end

  def test_op_asgn_index
    assert_parses(
      s(:op_asgn,
        s(:send, s(:lvar, :foo), :[],
          s(:int, 0), s(:int, 1)), :+,
        s(:int, 2)),
      %q{foo[0, 1] += 2},
      %q{          ^^ operator
        |   ~~~~~~ selector (send)
        |~~~~~~~~~ expression (send)
        |~~~~~~~~~~~~~~ expression})
  end

  def test_op_asgn_index_cmd
    assert_parses(
      s(:op_asgn,
        s(:send, s(:lvar, :foo), :[],
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
        s(:send, s(:lvar, :foo), :[],
          s(:int, 0), s(:int, 1)),
        s(:int, 2)),
      %q{foo[0, 1] ||= 2},
      %q{          ^^^ operator
        |   ~~~~~~ selector (send)
        |~~~~~~~~~ expression (send)
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
        s(:send, s(:lvar, :foo), :[],
          s(:int, 0), s(:int, 1)),
        s(:int, 2)),
      %q{foo[0, 1] &&= 2},
      %q{          ^^^ operator
        |   ~~~~~~ selector (send)
        |~~~~~~~~~ expression (send)
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
        s(:nil)),
      %q{module Foo; nil; end},
      %q{~~~~~~ keyword
        |                 ~~~ end})
  end

  def test_module_invalid
    assert_diagnoses(
      [:error, :module_in_def],
      %q{def a; module Foo; end; end})
  end

  def test_cpath
    assert_parses(
      s(:module,
        s(:const, s(:cbase), :Foo),
        s(:nil)),
      %q{module ::Foo; nil; end})

    assert_parses(
      s(:module,
        s(:const, s(:const, nil, :Bar), :Foo),
        s(:nil)),
      %q{module Bar::Foo; nil; end})
  end

  def test_cpath_invalid
    assert_diagnoses(
      [:error, :module_name_const],
      %q{module foo; nil; end})
  end

  def test_class
    assert_parses(
      s(:class,
        s(:const, nil, :Foo),
        nil,
        s(:nil)),
      %q{class Foo; nil; end},
      %q{~~~~~ keyword
        |                ~~~ end})
  end

  def test_class_super
    assert_parses(
      s(:class,
        s(:const, nil, :Foo),
        s(:const, nil, :Bar),
        s(:nil)),
      %q{class Foo < Bar; nil; end},
      %q{~~~~~ keyword
        |          ^ operator
        |                      ~~~ end})
  end

  def test_class_super_label
    assert_parses(
      s(:class,
        s(:const, nil, :Foo),
        s(:send, nil, :a,
          s(:sym, :b)),
        s(:nil)),
      %q{class Foo < a:b; end},
      %q{},
      ALL_VERSIONS - %w(1.8 1.9))
  end

  def test_class_invalid
    assert_diagnoses(
      [:error, :class_in_def],
      %q{def a; class Foo; end; end})
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
      s(:def, :foo, s(:args), s(:nil)),
      %q{def foo; nil; end},
      %q{~~~ keyword
        |    ~~~ name
        |              ~~~ end})
  end

  def test_defs
    assert_parses(
      s(:defs, s(:self), :foo, s(:args), s(:nil)),
      %q{def self.foo; nil; end},
      %q{~~~ keyword
        |        ^ operator
        |         ~~~ name
        |                   ~~~ end})

    assert_parses(
      s(:defs, s(:self), :foo, s(:args), s(:nil)),
      %q{def self::foo; nil; end},
      %q{~~~ keyword
        |        ^^ operator
        |          ~~~ name
        |                    ~~~ end})

    assert_parses(
      s(:defs, s(:lvar, :foo), :foo, s(:args), s(:nil)),
      %q{def (foo).foo; end})
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
      %q{     ~ location})

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
        s(:dsym, s(:str, "foo"), s(:int, 1))),
      %q{undef foo, :bar, :"foo#{1}"},
      %q{~~~~~ keyword
        |      ~~~ expression (sym/1)
        |          ~~~~ expression (sym/2)
        |~~~~~~~~~~~~~~~~~~~~~~~~ expression})
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
        |           ~~~ expression (sym/2)
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
        s(:nil)),
      %q{def f(foo); nil; end},
      %q{      ~~~ name (args.arg)
        |      ~~~ expression (args.arg)
        |     ^ begin (args)
        |         ^ end (args)
        |     ~~~~~ expression (args)})

    assert_parses(
      s(:def, :f,
        s(:args, s(:arg, :foo), s(:arg, :bar)),
        s(:nil)),
      %q{def f(foo, bar); nil; end})
  end

  def test_optarg
    assert_parses(
      s(:def, :f,
        s(:args, s(:optarg, :foo, s(:int, 1))),
        s(:nil)),
      %q{def f foo = 1; nil; end},
      %q{      ~~~ name (args.optarg)
        |          ^ operator (args.optarg)
        |      ~~~~~~~ expression (args.optarg)
        |      ~~~~~~~ expression (args)})

    assert_parses(
      s(:def, :f,
        s(:args,
          s(:optarg, :foo, s(:int, 1)),
          s(:optarg, :bar, s(:int, 2))),
        s(:nil)),
      %q{def f(foo=1, bar=2); nil; end})
  end

  def test_restarg_named
    assert_parses(
      s(:def, :f,
        s(:args, s(:restarg, :foo)),
        s(:nil)),
      %q{def f(*foo); nil; end},
      %q{       ~~~ name (args.restarg)
        |      ~~~~ expression (args.restarg)})
  end

  def test_restarg_unnamed
    assert_parses(
      s(:def, :f,
        s(:args, s(:restarg)),
        s(:nil)),
      %q{def f(*); nil; end},
      %q{      ~ expression (args.restarg)})
  end

  def test_kwarg
    assert_parses(
      s(:def, :f,
        s(:args, s(:kwarg, :foo)),
        s(:nil)),
      %q{def f(foo:); nil; end},
      %q{      ~~~ name (args.kwarg)
        |      ~~~~ expression (args.kwarg)},
      ALL_VERSIONS - %w(1.8 1.9 2.0))
  end

  def test_kwoptarg
    assert_parses(
      s(:def, :f,
        s(:args, s(:kwoptarg, :foo, s(:int, 1))),
        s(:nil)),
      %q{def f(foo: 1); nil; end},
      %q{      ~~~ name (args.kwoptarg)
        |      ~~~~~~ expression (args.kwoptarg)},
      ALL_VERSIONS - %w(1.8 1.9))
  end

  def test_kwrestarg_named
    assert_parses(
      s(:def, :f,
        s(:args, s(:kwrestarg, :foo)),
        s(:nil)),
      %q{def f(**foo); nil; end},
      %q{        ~~~ name (args.kwrestarg)
        |      ~~~~~ expression (args.kwrestarg)},
      ALL_VERSIONS - %w(1.8 1.9))
  end

  def test_kwrestarg_unnamed
    assert_parses(
      s(:def, :f,
        s(:args, s(:kwrestarg)),
        s(:nil)),
      %q{def f(**); nil; end},
      %q{      ~~ expression (args.kwrestarg)},
      ALL_VERSIONS - %w(1.8 1.9))
  end

  def test_blockarg
    assert_parses(
      s(:def, :f,
        s(:args, s(:blockarg, :block)),
        s(:nil)),
      %q{def f(&block); nil; end},
      %q{       ~~~~~ name (args.blockarg)
        |      ~~~~~~ expression (args.blockarg)})
  end

  def assert_parses_args(ast, code, versions=ALL_VERSIONS)
    assert_parses(
      s(:def, :f, ast, s(:nil)),
      %Q{def f #{code}; nil; end},
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
      ALL_VERSIONS - %w(1.8))

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
      ALL_VERSIONS - %w(1.8))

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
      ALL_VERSIONS - %w(1.8))

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
      ALL_VERSIONS - %w(1.8))

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
      ALL_VERSIONS - %w(1.8))

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
      ALL_VERSIONS - %w(1.8))

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
      ALL_VERSIONS - %w(1.8 1.9))

    # f_kwarg opt_f_block_arg
    assert_parses_args(
      s(:args,
        s(:kwoptarg, :foo, s(:int, 1)),
        s(:blockarg, :b)),
      %q{(foo: 1, &b)},
      ALL_VERSIONS - %w(1.8 1.9))

    # f_kwrest opt_f_block_arg
    assert_parses_args(
      s(:args,
        s(:kwrestarg, :baz),
        s(:blockarg, :b)),
      %q{**baz, &b},
      ALL_VERSIONS - %w(1.8 1.9))
  end

  def test_kwarg_no_paren
    assert_parses_args(
      s(:args,
        s(:kwarg, :foo)),
      %Q{foo:\n},
      ALL_VERSIONS - %w(1.8 1.9 2.0))
  end

  def assert_parses_margs(ast, code, versions=ALL_VERSIONS - %w(1.8))
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

  def assert_parses_blockargs(ast, code, versions=ALL_VERSIONS)
    assert_parses(
      s(:block,
        s(:send, nil, :f),
        ast, s(:nil)),
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
      ALL_VERSIONS - %w(1.8))

    assert_parses_blockargs(
      s(:args, s(:shadowarg, :a)),
      %Q{|;\na\n|},
      ALL_VERSIONS - %w(1.8 1.9))

    # tOROP
    assert_parses_blockargs(
      s(:args),
      %q{||})

    # block_par
    # block_par tCOMMA
    # block_par tCOMMA tAMPER lhs
    # f_arg                                                      opt_f_block_arg
    # f_arg tCOMMA
    assert_parses_blockargs(
      s(:args, s(:arg, :a)),
      %q{|a|})

    assert_parses_blockargs(
      s(:args, s(:arg, :a), s(:arg, :c)),
      %q{|a, c|})

    assert_parses_blockargs(
      s(:args, s(:arg_expr, s(:ivasgn, :@a))),
      %q{|@a|},
      %w(1.8))

    assert_parses_blockargs(
      s(:args, s(:arg, :a)),
      %q{|a,|})

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
      ALL_VERSIONS - %w(1.8))

    # f_arg tCOMMA f_block_optarg tCOMMA f_rest_arg tCOMMA f_arg opt_f_block_arg
    assert_parses_blockargs(
      s(:args,
        s(:arg, :a),
        s(:optarg, :o, s(:int, 1)),
        s(:restarg, :r),
        s(:arg, :p),
        s(:blockarg, :b)),
      %q{|a, o=1, *r, p, &b|},
      ALL_VERSIONS - %w(1.8))

    # f_arg tCOMMA f_block_optarg                                opt_f_block_arg
    assert_parses_blockargs(
      s(:args,
        s(:arg, :a),
        s(:optarg, :o, s(:int, 1)),
        s(:blockarg, :b)),
      %q{|a, o=1, &b|},
      ALL_VERSIONS - %w(1.8))

    # f_arg tCOMMA f_block_optarg tCOMMA                   f_arg opt_f_block_arg
    assert_parses_blockargs(
      s(:args,
        s(:arg, :a),
        s(:optarg, :o, s(:int, 1)),
        s(:arg, :p),
        s(:blockarg, :b)),
      %q{|a, o=1, p, &b|},
      ALL_VERSIONS - %w(1.8))

    # f_arg tCOMMA                       f_rest_arg tCOMMA f_arg opt_f_block_arg
    assert_parses_blockargs(
      s(:args,
        s(:arg, :a),
        s(:restarg, :r),
        s(:arg, :p),
        s(:blockarg, :b)),
      %q{|a, *r, p, &b|},
      ALL_VERSIONS - %w(1.8))

    #              f_block_optarg tCOMMA f_rest_arg              opt_f_block_arg
    assert_parses_blockargs(
      s(:args,
        s(:optarg, :o, s(:int, 1)),
        s(:restarg, :r),
        s(:blockarg, :b)),
      %q{|o=1, *r, &b|},
      ALL_VERSIONS - %w(1.8))

    #              f_block_optarg tCOMMA f_rest_arg tCOMMA f_arg opt_f_block_arg
    assert_parses_blockargs(
      s(:args,
        s(:optarg, :o, s(:int, 1)),
        s(:restarg, :r),
        s(:arg, :p),
        s(:blockarg, :b)),
      %q{|o=1, *r, p, &b|},
      ALL_VERSIONS - %w(1.8))

    #              f_block_optarg                                opt_f_block_arg
    assert_parses_blockargs(
      s(:args,
        s(:optarg, :o, s(:int, 1)),
        s(:blockarg, :b)),
      %q{|o=1, &b|},
      ALL_VERSIONS - %w(1.8))

    #              f_block_optarg tCOMMA                   f_arg opt_f_block_arg
    assert_parses_blockargs(
      s(:args,
        s(:optarg, :o, s(:int, 1)),
        s(:arg, :p),
        s(:blockarg, :b)),
      %q{|o=1, p, &b|},
      ALL_VERSIONS - %w(1.8))

    #                                    f_rest_arg tCOMMA f_arg opt_f_block_arg
    assert_parses_blockargs(
      s(:args,
        s(:restarg, :r),
        s(:arg, :p),
        s(:blockarg, :b)),
      %q{|*r, p, &b|},
      ALL_VERSIONS - %w(1.8))
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
      ALL_VERSIONS - %w(1.8 1.9))

    # f_block_kwarg opt_f_block_arg
    assert_parses_blockargs(
      s(:args,
        s(:kwoptarg, :foo, s(:int, 1)),
        s(:blockarg, :b)),
      %q{|foo: 1, &b|},
      ALL_VERSIONS - %w(1.8 1.9))

    # f_kwrest opt_f_block_arg
    assert_parses_blockargs(
      s(:args,
        s(:kwrestarg, :baz),
        s(:blockarg, :b)),
      %q{|**baz, &b|},
      ALL_VERSIONS - %w(1.8 1.9))
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
      ALL_VERSIONS - %w(1.8))

    assert_diagnoses(
      [:error, :duplicate_argument],
      %q{def foo(aa, *r, aa); end},
      %q{                ^^ location
        |        ~~ highlights (0)},
      ALL_VERSIONS - %w(1.8))


    assert_diagnoses(
      [:error, :duplicate_argument],
      %q{lambda do |aa; aa| end},
      %q{               ^^ location
        |           ~~ highlights (0)},
      ALL_VERSIONS - %w(1.8))

    assert_diagnoses(
      [:error, :duplicate_argument],
      %q{def foo(aa, aa: 1); end},
      %q{            ^^ location
        |        ~~ highlights (0)},
      ALL_VERSIONS - %w(1.8 1.9))

    assert_diagnoses(
      [:error, :duplicate_argument],
      %q{def foo(aa, **aa); end},
      %q{              ^^ location
        |        ~~ highlights (0)},
      ALL_VERSIONS - %w(1.8 1.9))

    assert_diagnoses(
      [:error, :duplicate_argument],
      %q{def foo(aa, aa:); end},
      %q{            ^^ location
        |        ~~ highlights (0)},
      ALL_VERSIONS - %w(1.8 1.9 2.0))
  end

  def test_kwarg_invalid
    assert_diagnoses(
      [:error, :argument_const],
      %q{def foo(Abc: 1); end},
      %q{        ~~~~ location},
      ALL_VERSIONS - %w(1.8 1.9))

    assert_diagnoses(
      [:error, :argument_const],
      %q{def foo(Abc:); end},
      %q{        ~~~~ location},
      ALL_VERSIONS - %w(1.8 1.9 2.0))
  end

  def test_arg_label
    assert_parses(
      s(:def, :foo, s(:args),
        s(:send, nil, :a, s(:sym, :b))),
      %q{def foo() a:b end},
      %q{},
      ALL_VERSIONS - %w(1.8))

    assert_parses(
      s(:def, :foo, s(:args),
        s(:send, nil, :a, s(:sym, :b))),
      %Q{def foo\n a:b end},
      %q{},
      ALL_VERSIONS - %w(1.8))

    assert_parses(
      s(:block,
        s(:send, nil, :f),
        s(:args),
        s(:send, nil, :a,
          s(:sym, :b))),
      %Q{f { || a:b }},
      %q{},
      ALL_VERSIONS - %w(1.8))
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
      s(:block, s(:send, nil, :fun), s(:args), s(:nil)),
      %q{fun { }})

    assert_parses(
      s(:block, s(:send, nil, :fun), s(:args), s(:nil)),
      %q{fun() { }})

    assert_parses(
      s(:block, s(:send, nil, :fun, s(:int, 1)), s(:args), s(:nil)),
      %q{fun(1) { }})

    assert_parses(
      s(:block, s(:send, nil, :fun), s(:args), s(:nil)),
      %q{fun do end})
  end

  def test_send_block_blockarg
    assert_diagnoses(
      [:error, :block_and_blockarg],
      %q{fun(&bar) do end},
      %q{    ~~~~ location})
  end

  # To receiver

  def test_send_plain
    assert_parses(
      s(:send, s(:lvar, :foo), :fun),
      %q{foo.fun},
      %q{    ~~~ selector
        |~~~~~~~ expression})

    assert_parses(
      s(:send, s(:lvar, :foo), :fun),
      %q{foo::fun},
      %q{     ~~~ selector
        |~~~~~~~~ expression})

    assert_parses(
      s(:send, s(:lvar, :foo), :Fun),
      %q{foo::Fun()},
      %q{     ~~~ selector
        |~~~~~~~~~~ expression})
  end

  def test_send_plain_cmd
    assert_parses(
      s(:send, s(:lvar, :foo), :fun, s(:lvar, :bar)),
      %q{foo.fun bar},
      %q{    ~~~ selector
        |~~~~~~~~~~~ expression})

    assert_parses(
      s(:send, s(:lvar, :foo), :fun, s(:lvar, :bar)),
      %q{foo::fun bar},
      %q{     ~~~ selector
        |~~~~~~~~~~~~ expression})

    assert_parses(
      s(:send, s(:lvar, :foo), :Fun, s(:lvar, :bar)),
      %q{foo::Fun bar},
      %q{     ~~~ selector
        |~~~~~~~~~~~~ expression})
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
      ALL_VERSIONS - %w(1.8 1.9))
  end

  def test_send_block_chain_cmd
    assert_parses(
      s(:send,
        s(:block,
          s(:send, nil, :meth, s(:int, 1)),
          s(:args), s(:nil)),
        :fun, s(:lvar, :bar)),
      %q{meth 1 do end.fun bar},
      %q{              ~~~ selector
        |~~~~~~~~~~~~~~~~~~~~~ expression})

    assert_parses(
      s(:send,
        s(:block,
          s(:send, nil, :meth, s(:int, 1)),
          s(:args), s(:nil)),
        :fun, s(:lvar, :bar)),
      %q{meth 1 do end.fun(bar)},
      %q{              ~~~ selector
        |                 ^ begin
        |                     ^ end
        |~~~~~~~~~~~~~~~~~~~~~~ expression})

    assert_parses(
      s(:send,
        s(:block,
          s(:send, nil, :meth, s(:int, 1)),
          s(:args), s(:nil)),
        :fun, s(:lvar, :bar)),
      %q{meth 1 do end::fun bar},
      %q{               ~~~ selector
        |~~~~~~~~~~~~~~~~~~~~~~ expression})

    assert_parses(
      s(:send,
        s(:block,
          s(:send, nil, :meth, s(:int, 1)),
          s(:args), s(:nil)),
        :fun, s(:lvar, :bar)),
      %q{meth 1 do end::fun(bar)},
      %q{               ~~~ selector
        |                  ^ begin
        |                      ^ end
        |~~~~~~~~~~~~~~~~~~~~~~~ expression})

    assert_parses(
      s(:block,
        s(:send,
          s(:block,
            s(:send, nil, :meth, s(:int, 1)),
            s(:args), s(:nil)),
          :fun, s(:lvar, :bar)),
        s(:args), s(:nil)),
      %q{meth 1 do end.fun bar do end},
      %q{},
      ALL_VERSIONS - %w(1.8 1.9))

    assert_parses(
      s(:block,
        s(:send,
          s(:block,
            s(:send, nil, :meth, s(:int, 1)),
            s(:args), s(:nil)),
          :fun, s(:lvar, :bar)),
        s(:args), s(:nil)),
      %q{meth 1 do end.fun(bar) {}},
      %q{},
      ALL_VERSIONS - %w(1.8 1.9))

    assert_parses(
      s(:block,
        s(:send,
          s(:block,
            s(:send, nil, :meth, s(:int, 1)),
            s(:args), s(:nil)),
          :fun),
        s(:args), s(:nil)),
      %q{meth 1 do end.fun {}},
      %q{},
      ALL_VERSIONS - %w(1.8 1.9))
  end

  def test_send_paren_block_cmd
    assert_parses(
      s(:send, nil, :foo,
        s(:block,
          s(:send, nil, :meth, s(:int, 1)),
          s(:args), s(:nil))),
      %q{foo(meth 1 do end)},
      %q{},
      %w(1.8))

    assert_parses(
      s(:send, nil, :foo,
        s(:int, 1),
        s(:block,
          s(:send, nil, :meth, s(:int, 1)),
          s(:args), s(:nil))),
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
      ALL_VERSIONS - %w(1.8))

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
      ALL_VERSIONS - %w(1.8))

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
      ALL_VERSIONS - %w(1.8))
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
      ALL_VERSIONS - %w(1.8))
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
      ALL_VERSIONS - %w(1.8))

    assert_parses(
      s(:send, s(:lvar, :foo), :'!'),
      %q{not(foo)},
      %{},
      ALL_VERSIONS - %w(1.8))

    assert_parses(
      s(:send, s(:nil), :'!'),
      %q{not()},
      %{},
      ALL_VERSIONS - %w(1.8))
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
      ALL_VERSIONS - %w(1.8))
  end

  def test_pow_precedence
    assert_parses(
      s(:send, s(:send, s(:int, 2), :**, s(:int, 10)), :-@),
      %q{-2 ** 10})

    assert_parses(
      s(:send, s(:send, s(:float, 2.0), :**, s(:int, 10)), :-@),
      %q{-2.0 ** 10})
  end

  def test_send_attr_asgn
    assert_parses(
      s(:send, s(:lvar, :foo), :a=, s(:int, 1)),
      %q{foo.a = 1},
      %q{    ~~~ selector
        |~~~~~~~~~ expression})

    assert_parses(
      s(:send, s(:lvar, :foo), :a=, s(:int, 1)),
      "foo::a = 1")

    assert_parses(
      s(:send, s(:lvar, :foo), :A=, s(:int, 1)),
      "foo.A = 1")

    assert_parses(
      s(:cdecl, s(:lvar, :foo), :A, s(:int, 1)),
      "foo::A = 1")
  end

  def test_send_index
    assert_parses(
      s(:send, s(:lvar, :foo), :[],
        s(:int, 1), s(:int, 2)),
      %q{foo[1, 2]},
      %q{   ~~~~~~ selector
        |   ^ begin
        |        ^ end
        |~~~~~~~~~ expression})
  end

  def test_send_index_cmd
    assert_parses(
      s(:send, s(:lvar, :foo), :[],
        s(:send, nil, :m, s(:lvar, :bar))),
      %q{foo[m bar]})
  end

  def test_send_index_asgn
    assert_parses(
      s(:send, s(:lvar, :foo), :[]=,
        s(:int, 1), s(:int, 2), s(:int, 3)),
      %q{foo[1, 2] = 3},
      %q{   ~~~~~~~~ selector
        |   ^ begin
        |        ^ end
        |~~~~~~~~~~~~~ expression})
  end

  def test_send_lambda
    assert_parses(
      s(:block, s(:send, nil, :lambda),
        s(:args), s(:nil)),
      %q{->{ }},
      %q{~~ selector (send)
        |  ^ begin
        |    ^ end
        |~~~~~ expression},
      ALL_VERSIONS - %w(1.8))

    assert_parses(
      s(:block, s(:send, nil, :lambda),
        s(:args), s(:nil)),
      %q{-> do end},
      %q{~~ selector (send)
        |   ^^ begin
        |      ^^^ end
        |~~~~~~~~~ expression},
      ALL_VERSIONS - %w(1.8))
  end

  def test_send_lambda_args
    assert_parses(
      s(:block, s(:send, nil, :lambda),
        s(:args,
          s(:arg, :a)),
        s(:nil)),
      %q{->(a) { }},
      %q{~~ selector (send)
        |  ^ begin (args)
        |    ^ end (args)
        |      ^ begin
        |        ^ end
        |~~~~~ expression},
      ALL_VERSIONS - %w(1.8))

    assert_parses(
      s(:block, s(:send, nil, :lambda),
        s(:args,
          s(:arg, :a)),
        s(:nil)),
      %q{-> (a) { }},
      %q{},
      ALL_VERSIONS - %w(1.8 1.9))
  end

  def test_send_lambda_args_shadow
    assert_parses(
      s(:block, s(:send, nil, :lambda),
        s(:args,
          s(:arg, :a),
          s(:shadowarg, :foo),
          s(:shadowarg, :bar)),
        s(:nil)),
      %q{->(a; foo, bar) { }},
      %q{      ~~~ expression (args.shadowarg)},
      ALL_VERSIONS - %w(1.8))
  end

  def test_send_call
    assert_parses(
      s(:send, s(:lvar, :foo), :call,
        s(:int, 1)),
      %q{foo.(1)},
      %q{    ^ begin
        |      ^ end
        |~~~~~~~ expression},
      ALL_VERSIONS - %w(1.8))

    assert_parses(
      s(:send, s(:lvar, :foo), :call,
        s(:int, 1)),
      %q{foo::(1)},
      %q{     ^ begin
        |       ^ end
        |~~~~~~~~ expression},
      ALL_VERSIONS - %w(1.8))
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
      s(:send, s(:lvar, :foo), :[],
        s(:lvar, :bar)),
      %q{foo[bar,]},
      %q{},
      ALL_VERSIONS - %w(1.8))
  end

  def test_args_assocs
    assert_parses(
      s(:send, nil, :fun,
        s(:hash, s(:pair, s(:sym, :foo), s(:int, 1)))),
      %q{fun(:foo => 1)})

    assert_parses(
      s(:send, nil, :fun,
        s(:hash, s(:pair, s(:sym, :foo), s(:int, 1))),
        s(:block_pass, s(:lvar, :baz))),
      %q{fun(:foo => 1, &baz)})
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
      s(:send, s(:lvar, :foo), :[],
        s(:hash, s(:pair, s(:sym, :baz), s(:int, 1)))),
      %q{foo[:baz => 1,]},
      %q{},
      ALL_VERSIONS - %w(1.8))
  end

  def test_args_args_assocs
    assert_parses(
      s(:send, nil, :fun,
        s(:lvar, :foo),
        s(:hash, s(:pair, s(:sym, :foo), s(:int, 1)))),
      %q{fun(foo, :foo => 1)})

    assert_parses(
      s(:send, nil, :fun,
        s(:lvar, :foo),
        s(:hash, s(:pair, s(:sym, :foo), s(:int, 1))),
        s(:block_pass, s(:lvar, :baz))),
      %q{fun(foo, :foo => 1, &baz)})
  end

  def test_args_args_assocs_comma
    assert_parses(
      s(:send, s(:lvar, :foo), :[],
        s(:lvar, :bar),
        s(:hash, s(:pair, s(:sym, :baz), s(:int, 1)))),
      %q{foo[bar, :baz => 1,]},
      %q{},
      ALL_VERSIONS - %w(1.8))
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
        s(:send, nil, :f, s(:lvar, :bar))),
      %q{fun (f bar)})
  end

  def test_space_args_arg
    assert_parses(
      s(:send, nil, :fun, s(:int, 1)),
      %q{fun (1)})
  end

  def test_space_args_arg_block
    assert_parses(
      s(:block,
        s(:send, nil, :fun, s(:int, 1)),
        s(:args), s(:nil)),
      %q{fun (1) {}})

    assert_parses(
      s(:block,
        s(:send, s(:lvar, :foo), :fun, s(:int, 1)),
        s(:args), s(:nil)),
      %q{foo.fun (1) {}})

    assert_parses(
      s(:block,
        s(:send, s(:lvar, :foo), :fun, s(:int, 1)),
        s(:args), s(:nil)),
      %q{foo::fun (1) {}})
  end

  def test_space_args_arg_call
    assert_parses(
      s(:send, nil, :fun,
        s(:send, s(:int, 1), :to_i)),
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
        s(:hash, s(:pair, s(:sym, :foo), s(:int, 1)))),
      %q{fun (:foo => 1)},
      %q{},
      %w(1.8))

    assert_parses(
      s(:send, nil, :fun,
        s(:hash, s(:pair, s(:sym, :foo), s(:int, 1))),
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
        s(:hash, s(:pair, s(:sym, :foo), s(:int, 1)))),
      %q{fun (foo, :foo => 1)},
      %q{},
      %w(1.8))

    assert_parses(
      s(:send, nil, :fun,
        s(:lvar, :foo),
        s(:hash, s(:pair, s(:sym, :foo), s(:int, 1))),
        s(:block_pass, s(:lvar, :baz))),
      %q{fun (foo, :foo => 1, &baz)},
      %q{},
      %w(1.8))

    assert_parses(
      s(:send, nil, :fun,
        s(:lvar, :foo), s(:int, 1),
        s(:hash, s(:pair, s(:sym, :foo), s(:int, 1)))),
      %q{fun (foo, 1, :foo => 1)},
      %q{},
      %w(1.8))

    assert_parses(
      s(:send, nil, :fun,
        s(:lvar, :foo), s(:int, 1),
        s(:hash, s(:pair, s(:sym, :foo), s(:int, 1))),
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

    assert_diagnoses(
      [:warning, :space_before_lparen],
      %q{fun (1, 2)},
      %q{    ^ location},
      %w(1.8))
  end

  def test_space_args_none
    assert_parses(
      s(:send, nil, :fun),
      %q{fun ()},
      %q{},
      %w(1.8))

    assert_diagnoses(
      [:warning, :space_before_lparen],
      %q{fun ()},
      %q{    ^ location},
      %w(1.8))
  end

  def test_space_args_block
    assert_parses(
      s(:block,
        s(:send, nil, :fun),
        s(:args), s(:nil)),
      %q{fun () {}},
      %q{    ^ begin (send)
        |     ^ end (send)},
      %w(1.8))

    assert_parses(
      s(:block,
        s(:send, s(:lvar, :foo), :fun),
        s(:args), s(:nil)),
      %q{foo.fun () {}},
      %q{        ^ begin (send)
        |         ^ end (send)},
      %w(1.8))

    assert_parses(
      s(:block,
        s(:send, s(:lvar, :foo), :fun),
        s(:args), s(:nil)),
      %q{foo::fun () {}},
      %q{         ^ begin (send)
        |          ^ end (send)},
      %w(1.8))

    assert_parses(
      s(:block,
        s(:send, nil, :fun,
          s(:nil)),
        s(:args), s(:nil)),
      %q{fun () {}},
      %q{    ~~ expression (send.nil)},
      ALL_VERSIONS - %w(1.8 1.9))
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

  def test_and_or_masgn_invalid
    assert_diagnoses(
      [:error, :masgn_as_condition],
      %q{foo && (a, b = bar)})

    assert_diagnoses(
      [:error, :masgn_as_condition],
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
        |                                   ~~~ end
        |                                   ~~~ end (if)
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

  def test_if_masgn
    assert_diagnoses(
      [:error, :masgn_as_condition],
      %q{if (a, b = foo); end},
      %q{   ~~~~~~~~~~~~ location})
  end

  def test_if_mod_masgn
    assert_diagnoses(
      [:error, :masgn_as_condition],
      %q{1 if (a, b = foo)},
      %q{     ~~~~~~~~~~~~ location})
  end

  def test_tern_masgn
    assert_diagnoses(
      [:error, :masgn_as_condition],
      %q{(a, b = foo) ? 1 : 2},
      %q{~~~~~~~~~~~~ location})
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
          s(:nil)),
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

  # TODO implement this
  # def test_while_post
  #   assert_parses(
  #     s(:while_post, s(:lvar, :foo), s(:send, nil, :meth)),
  #     %q{begin meth end while foo},
  #     %q{               ~~~~~ keyword})
  # end

  # TODO implement this
  # def test_until_post
  #   assert_parses(
  #     s(:until_post, s(:lvar, :foo), s(:send, nil, :meth)),
  #     %q{begin meth end until foo},
  #     %q{               ~~~~~ keyword})
  # end

  def test_while_masgn
    assert_diagnoses(
      [:error, :masgn_as_condition],
      %q{while (a, b = foo); end},
      %q{      ~~~~~~~~~~~~ location})
  end

  def test_while_mod_masgn
    assert_diagnoses(
      [:error, :masgn_as_condition],
      %q{foo while (a, b = foo)},
      %q{          ~~~~~~~~~~~~ location})
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
      s(:break, s(:lvar, :foo)),
      %q{break(foo)},
      %q{~~~~~ keyword
        |     ^ begin
        |         ^ end
        |~~~~~~~~~~ expression},
      ALL_VERSIONS - %w(1.8))

    assert_parses(
      s(:break, s(:lvar, :foo)),
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
        s(:break, s(:nil)),
      %q{break()},
      %q{~~~~~ keyword
        |~~~~~~~ expression},
      ALL_VERSIONS - %w(1.8))

    assert_parses(
      s(:break),
      %q{break},
      %q{~~~~~ keyword
        |~~~~~ expression})
  end

  def test_return
    assert_parses(
      s(:return, s(:lvar, :foo)),
      %q{return(foo)},
      %q{~~~~~~ keyword
        |      ^ begin
        |          ^ end
        |~~~~~~~~~~~ expression},
      ALL_VERSIONS - %w(1.8))

    assert_parses(
      s(:return, s(:lvar, :foo)),
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
      s(:return, s(:nil)),
      %q{return()},
      %q{~~~~~~ keyword
        |~~~~~~~~ expression},
      ALL_VERSIONS - %w(1.8))

    assert_parses(
      s(:return),
      %q{return},
      %q{~~~~~~ keyword
        |~~~~~~ expression})
  end

  def test_next
    assert_parses(
      s(:next, s(:lvar, :foo)),
      %q{next(foo)},
      %q{~~~~ keyword
        |    ^ begin
        |        ^ end
        |~~~~~~~~~ expression},
      ALL_VERSIONS - %w(1.8))

    assert_parses(
      s(:next, s(:lvar, :foo)),
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
        s(:next, s(:nil)),
      %q{next()},
      %q{~~~~ keyword
        |~~~~~~ expression},
      ALL_VERSIONS - %w(1.8))

    assert_parses(
      s(:next),
      %q{next},
      %q{~~~~ keyword
        |~~~~ expression})
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
      s(:rescue, s(:send, nil, :meth),
        s(:resbody, nil, nil, s(:lvar, :foo)),
        nil),
      %q{begin; meth; rescue; foo; end},
      %q{~~~~~ begin
        |                          ~~~ end
        |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression})
  end

  def test_rescue_else
    assert_parses(
      s(:rescue, s(:send, nil, :meth),
        s(:resbody, nil, nil, s(:lvar, :foo)),
        s(:lvar, :bar)),
      %q{begin; meth; rescue; foo; else; bar; end},
      %q{~~~~~ begin
        |                          ~~~~ else
        |                                     ~~~ end
        |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression})
  end

  def test_rescue_else_useless
    assert_diagnoses(
      [:warning, :useless_else],
      %q{begin; 1; else; 2; end},
      %q{          ~~~~ location})
  end

  def test_ensure
    assert_parses(
      s(:ensure, s(:send, nil, :meth),
        s(:lvar, :bar)),
      %q{begin; meth; ensure; bar; end},
      %q{~~~~~ begin
        |             ~~~~~~ keyword
        |                          ~~~ end
        |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression})
  end

  def test_rescue_ensure
    assert_parses(
      s(:ensure,
        s(:rescue,
          s(:send, nil, :meth),
          s(:resbody, nil, nil, s(:lvar, :baz)),
          nil),
        s(:lvar, :bar)),
      %q{begin; meth; rescue; baz; ensure; bar; end},
      %q{~~~~~ begin
        |~~~~~ begin (rescue)
        |                          ~~~~~~ keyword
        |             ~~~~~~ keyword (rescue)
        |                                       ~~~ end
        |                                       ~~~ end (rescue)
        |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression
        |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression (rescue)})
  end

  def test_rescue_else_ensure
    assert_parses(
      s(:ensure,
        s(:rescue,
          s(:send, nil, :meth),
          s(:resbody, nil, nil, s(:lvar, :baz)),
          s(:lvar, :foo)),
        s(:lvar, :bar)),
      %q{begin; meth; rescue; baz; else foo; ensure; bar end},
      %q{~~~~~ begin
        |~~~~~ begin (rescue)
        |                                    ~~~~~~ keyword
        |             ~~~~~~ keyword (rescue)
        |                          ~~~~ else (rescue)
        |                                                ~~~ end
        |                                                ~~~ end (rescue)
        |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression
        |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression (rescue)})
  end

  def test_rescue_mod
    assert_parses(
      s(:rescue,
        s(:send, nil, :meth),
        s(:resbody, nil, nil, s(:lvar, :bar)),
        nil),
      %q{meth rescue bar},
      %q{     ~~~~~~ keyword (resbody)
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
        |      ~~~~~~~~~~~~~~~ expression (rescue)
        |~~~~~~~~~~~~~~~~~~~~~ expression})
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
        |       ~~~~~~~~~~~~~~~ expression (rescue)
        |~~~~~~~~~~~~~~~~~~~~~~ expression},
      ALL_VERSIONS - %w(1.8))
  end

  def test_resbody_list
    assert_parses(
      s(:rescue,
        s(:send, nil, :meth),
        s(:resbody,
          s(:array, s(:const, nil, :Exception)),
          nil,
          s(:lvar, :bar)),
        nil),
      %q{begin; meth; rescue Exception; bar; end})
  end

  def test_resbody_list_mrhs
    assert_parses(
      s(:rescue,
        s(:send, nil, :meth),
        s(:resbody,
          s(:array,
            s(:const, nil, :Exception),
            s(:lvar, :foo)),
          nil,
          s(:lvar, :bar)),
        nil),
      %q{begin; meth; rescue Exception, foo; bar; end})
  end

  def test_resbody_var
    assert_parses(
      s(:rescue,
        s(:send, nil, :meth),
        s(:resbody, nil, s(:lvasgn, :ex), s(:lvar, :bar)),
        nil),
      %q{begin; meth; rescue => ex; bar; end})

    assert_parses(
      s(:rescue,
        s(:send, nil, :meth),
        s(:resbody, nil, s(:ivasgn, :@ex), s(:lvar, :bar)),
        nil),
      %q{begin; meth; rescue => @ex; bar; end})
  end

  def test_resbody_list_var
    assert_parses(
      s(:rescue,
        s(:send, nil, :meth),
        s(:resbody,
          s(:array, s(:lvar, :foo)),
          s(:lvasgn, :ex),
          s(:lvar, :bar)),
        nil),
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
        |          ^ end})
  end

  def test_preexe_invalid
    assert_diagnoses(
      [:error, :begin_in_method],
      %q{def f; BEGIN{}; end},
      %q{       ~~~~~ location},
      # Yes. *Exclude 1.9*. Sigh.
      ALL_VERSIONS - %w(1.9))
  end

  def test_postexe
    assert_parses(
      s(:postexe, s(:int, 1)),
      %q{END { 1 }},
      %q{~~~ keyword
        |    ^ begin
        |        ^ end})

    assert_diagnoses(
      [:warning, :end_in_method],
      %q{def f; END{ 1 }; end},
      %q{       ~~~ location})
  end

  #
  # Miscellanea
  #

  def test_begin_cmdarg
    assert_parses(
      s(:send, nil, :p,
        s(:block,
          s(:send, s(:int, 1), :times),
          s(:args),
          s(:int, 1))),
      %q{p begin 1.times do 1 end end},
      %{},
      ALL_VERSIONS - %w(1.8 1.9))
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

  def test_on_error
    assert_diagnoses(
      [:error, :unexpected_token, { :token => 'tIDENTIFIER' }],
      %q{def foo(bar baz); end},
      %q{            ~~~ location})
  end

  #
  # Bug-specific tests
  #

  def test_bug_cmd_string_lookahead
    assert_parses(
      s(:block,
        s(:send, nil, :desc,
          s(:str, "foo")),
        s(:args), s(:nil)),
      %q{desc "foo" do end})
  end

  def test_bug_interp_single
    assert_parses(
      s(:dstr, s(:int, 1)),
      %q{"#{1}"})

    assert_parses(
      s(:array, s(:dstr, s(:int, 1))),
      %q{%W"#{1}"})
  end
end
