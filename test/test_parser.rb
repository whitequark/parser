require_relative 'helper'
require_relative 'parse_helper'

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
        |~~~~~~~~~ expression},
      %w(1.8))

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
      s(:array, s(:str, "foo"), s(:lvar, :bar)),
      %q{%W[foo #{bar}]},
      %q{^^^ begin
        |             ^ end
        |   ~~~ expression (str)
        |         ~~~ expression (lvar)
        |~~~~~~~~~~~~~~ expression})
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
      s(:hash, s(:pair, s(:symbol, :foo), s(:int, 2))),
      %q[{ foo: 2 }],
      %q{^ begin
        |         ^ end
        |     ^ operator (pair)
        |  ~~~ expression (pair.symbol)
        |  ~~~~~~ expression (pair)
        |~~~~~~~~~~ expression},
        ALL_VERSIONS - %w(1.8))
  end

  # def test_hash_kwsplat
  #   assert_parses(
  #     s(:hash,
  #       s(:pair, s(:symbol, :foo), s(:int, 2))
  #       s(:kwsplat, s(:lvar, :bar))),
  #     %q[{ foo: 2, **bar }],
  #     %q{          ^^ operator (kwsplat)
  #       |          ~~~~~ expression (kwsplat)},
  #       %w(2.0))
  # end

  def test_hash_no_hashrocket
    assert_parses(
      s(:hash, s(:pair, s(:int, 1), s(:int, 2))),
      %q[{ 1, 2 }],
      %q{^ begin
        |       ^ end
        |   ^ operator (pair)
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
        s(:array, s(:splat, s(:lvar, :foo), s(:lvar, :bar)))),
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
        s(:mlhs, s(:lvasgn, :a), s(:splat)),
        s(:lvar, :bar)),
      %q{a, * = bar})

    assert_parses(
      s(:masgn,
        s(:mlhs, s(:splat, s(:lvasgn, :b))),
        s(:lvar, :bar)),
      %q{*b = bar})

    assert_parses(
      s(:masgn,
        s(:mlhs, s(:splat)),
        s(:lvar, :bar)),
      %q{* = bar})
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
      [:error, :dynamic_const],
      %q{Foo::Bar += 1; end},
      %q{     ~~~ location})

    assert_diagnoses(
      [:error, :dynamic_const],
      %q{::Bar += 1; end},
      %q{  ~~~ location})
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

  def test_splatarg_named
    assert_parses(
      s(:def, :f,
        s(:args, s(:splatarg, :foo)),
        s(:nil)),
      %q{def f(*foo); nil; end},
      %q{       ~~~ name (args.splatarg)
        |      ~~~~ expression (args.splatarg)})
  end

  def test_splatarg_unnamed
    assert_parses(
      s(:def, :f,
        s(:args, s(:splatarg)),
        s(:nil)),
      %q{def f(*); nil; end},
      %q{      ~ expression (args.splatarg)})
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

  def test_arg_mlhs
    assert_parses(
      s(:def, :f,
        s(:args,
          s(:mlhs,
            s(:arg, :a),
            s(:arg, :b),
            s(:splatarg)),
          s(:arg, :c)),
        s(:nil)),
      %q{def f((a, b, *f), c); nil; end},
      %q{      ^ begin (args.mlhs)
        |               ^ end (args.mlhs)
        |      ~~~~~~~~~~ expression (args.mlhs)
        |       ~ expression (args.mlhs.arg)
        |              ~ name (args.mlhs.splatarg)
        |             ~~ expression (args.mlhs.splatarg)},
      ALL_VERSIONS - %w(1.8))
  end

  def assert_parses_args(ast, code)
    assert_parses(
      s(:def, :f, ast, s(:nil)),
      %Q{def f #{code}; nil; end})
  end

  def test_arg_combinations
    # f_arg tCOMMA f_optarg tCOMMA f_rest_arg opt_f_block_arg
    assert_parses_args(
      s(:args,
        s(:arg, :a),
        s(:optarg, :o, s(:int, 1)),
        s(:splatarg, :r),
        s(:blockarg, :b)),
      %q{a, o=1, *r, &b})

    # f_arg tCOMMA f_optarg                   opt_f_block_arg
    assert_parses_args(
      s(:args,
        s(:arg, :a),
        s(:optarg, :o, s(:int, 1)),
        s(:blockarg, :b)),
      %q{a, o=1, &b})

    # f_arg tCOMMA                 f_rest_arg opt_f_block_arg
    assert_parses_args(
      s(:args,
        s(:arg, :a),
        s(:splatarg, :r),
        s(:blockarg, :b)),
      %q{a, *r, &b})

    # f_arg                                   opt_f_block_arg
    assert_parses_args(
      s(:args,
        s(:arg, :a),
        s(:blockarg, :b)),
      %q{a, &b})

    #              f_optarg tCOMMA f_rest_arg opt_f_block_arg
    assert_parses_args(
      s(:args,
        s(:optarg, :o, s(:int, 1)),
        s(:splatarg, :r),
        s(:blockarg, :b)),
      %q{o=1, *r, &b})

    #              f_optarg                   opt_f_block_arg
    assert_parses_args(
      s(:args,
        s(:optarg, :o, s(:int, 1)),
        s(:blockarg, :b)),
      %q{o=1, &b})

    #                              f_rest_arg opt_f_block_arg
    assert_parses_args(
      s(:args,
        s(:splatarg, :r),
        s(:blockarg, :b)),
      %q{*r, &b})

    #                                             f_block_arg
    assert_parses_args(
      s(:args,
        s(:blockarg, :b)),
      %q{&b})

    # (nothing)
    assert_parses_args(
      s(:args),
      %q{})
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

  # def test_kwoptarg
  #   flunk
  # end

  # def test_kwsplat_named
  #   flunk
  # end

  # def test_kwsplat_unnamed
  #   flunk
  # end

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
      s(:send, nil, :fun, s(:int, 1)),
      %q{fun(1)},
      %q{~~~ selector
        |   ^ begin
        |     ^ end
        |~~~~~~ expression})
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
      %q{foo::fun})

    assert_parses(
      s(:send, s(:lvar, :foo), :Fun),
      %q{foo::Fun()})
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
      s(:send, s(:lvar, :foo), :!=, s(:int, 1)),
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
      s(:send, s(:lvar, :foo), :!~, s(:int, 1)),
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

  def test_bang_lvar
    assert_parses(
      s(:not, s(:lvar, :foo)),
      %q{!foo},
      %{},
      %w(1.8))

    assert_parses(
      s(:send, s(:lvar, :foo), :!),
      %q{!foo},
      %{},
      ALL_VERSIONS - %w(1.8))
  end

  def test_not_lvar
    assert_parses(
      s(:not, s(:lvar, :foo)),
      %q{not foo},
      %{},
      %w(1.8))

    assert_parses(
      s(:send, s(:lvar, :foo), :!),
      %q{not foo},
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

  def test_send_index_asgn
    assert_parses(
      s(:send, s(:lvar, :foo), :[]=,
        s(:int, 1), s(:int, 2), s(:int, 3)),
      %q{foo[1, 2] = 3},
      %q{    ~~~~~~~ selector
        |   ^ begin
        |        ^ end
        |~~~~~~~~~~~~~ expression})
  end

  # To superclass

  def test_super
  end

  def test_zsuper
  end

  # To block argument

  def test_yield
  end

  # Send with a block

  def test_block
  end

  # Passing a block

  def test_block_pass
  end

  #
  # Control flow
  #

  # Operators

  def test_and
  end

  def test_or
  end

  def test_not
  end

  # Branching

  def test_if
  end

  def test_if_mod
  end

  def test_unless
  end

  def test_unless_mod
  end

  def test_if_else
  end

  def test_unless_else
  end

  def test_if_elsif
  end

  def test_ternary
  end

  # Case matching

  def test_case_expr
  end

  def test_case_expr_else
  end

  def test_case_cond
  end

  def test_case_cond_else
  end

  # Looping

  def test_while
  end

  def test_while_mod
  end

  def test_until
  end

  def test_until_mod
  end

  def test_while_post
  end

  def test_until_post
  end

  def test_for_in
  end

  # Loop-specific control flow

  def test_break
  end

  def test_next
  end

  def test_redo
  end

  # Returning

  def test_return
  end

  # Exception handling

  def test_rescue
  end

  def test_rescue_else
  end

  def test_ensure
  end

  def test_rescue_ensure
  end

  def test_rescue_ensure_else
  end

  def test_retry
  end

  # BEGIN and END

  def test_preexe
  end

  def test_postexe
  end
end
