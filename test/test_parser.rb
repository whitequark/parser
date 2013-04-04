require 'minitest/autorun'
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
  # TODO:
  #  * Add assert_diagnostic.

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
  end

  def test_float
    assert_parses(
      s(:float, 1.33),
      %q{1.33},
      %q{~~~~ expression})
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

  # Execute-strings

  def test_xstring_plain
    assert_parses(
      s(:xstr, 'foobar'),
      %q{`foobar`},
      %q{^ begin
        |       ^ end
        |~~~~~~~~ expression})
  end

  def test_xstring_interp
    assert_parses(
      s(:dxstr,
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
      s(:regexp, s(:regopt, :i, :m), 'source'),
      %q{/source/im},
      %q{^ begin
        |       ^ end
        |        ~~ expression (regopt)
        |~~~~~~~~~~ expression})
  end

  def test_regex_interp
    assert_parses(
      s(:dregexp,
        s(:str, 'foo'),
        s(:lvar, :bar),
        s(:str, 'baz')),
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
        |~~~~~~~~~~~~ expression})
  end

  # Hashes

  def test_hash_hashrocket
    assert_parses(
      s(:hash, s(:pair, s(:int, 1), s(:int, 2))),
      %q[{ 1 => 2 }],
      %q{^ begin
        |         ^ end
        |    ^^ operator (pair)
        |  ~~~~~~ expression (pair)
        |~~~~~~~~~~ expression})
  end

  # def test_hash_label
  #   assert_parses(
  #     s(:hash, s(:pair, s(:symbol, :foo), s(:int, 2))),
  #     %q[{ foo: 2 }],
  #     %q{^ begin
  #       |         ^ end
  #       |     ^ operator (pair)
  #       |  ~~~ expression (pair.symbol)
  #       |  ~~~~~~ expression (pair)
  #       |~~~~~~~~~~ expression},
  #       %w(1.9 2.0))
  # end

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
        "@@foo",
      %q{~~~~~ expression},
        s(:cvar, :@@foo))
  end

  def test_gvar
    assert_parses(
      s(:gvar, :$foo),
      %q{$foo},
      %q{~~~~ expression})
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
      s(:const, s(:lvar, :bar), :Foo),
      %q{bar::Foo},
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
      s(:cdecl, s(:lvar, :foo), :Foo, s(:int, 10)),
      %q{foo::Foo = 10},
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
  end

  def test_masgn_splat
    assert_parses(
      s(:masgn,
        s(:mlhs, s(:ivasgn, :foo), s(:cvdecl, :bar)),
        s(:splat, s(:lvar, :foo))),
      %q{@foo, @@bar = *foo},
      %q{              ^ operator (splat)
        |              ~~~~ expression (splat)
        })

    assert_parses(
      s(:masgn,
        s(:mlhs, s(:lvasgn, :a), s(:lvasgn, :b)),
        s(:array, s(:splat, s(:lvar, :foo), s(:lvar, :bar)))),
      %q{a, b = *foo, bar})
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
  end

  # Variable binary operator-assignment

  def test_var_op_asgn
    assert_parses(
      s(:var_op_asgn, s(:lvar, :a), :+, s(:lit, 1)),
      %q{a += 1},
      %q{  ^^ operator
        |~~~~~~ expression})

    assert_parses(
      s(:var_op_asgn, s(:ivar, :a), :+, s(:lit, 1)),
      %q{@a += 1},
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
        s(:send, s(:lvar, :foo), :[],
          s(:int, 0), s(:int, 1)), :+,
        s(:int, 2)),
      %q{foo[0, 1] += 2},
      %q{          ^^ operator
        |   ~~~~~~ selector (send)
        |~~~~~~~~~ expression (send)
        |~~~~~~~~~~~~~~ expression})
  end

  # Variable logical operator-assignment

  def test_var_or_asgn
    assert_parses(
      s(:var_or_asgn, s(:lvar, :a), s(:lit, 1)),
      %q{a ||= 1},
      %q{  ^^^ operator
        |~~~~~~~ expression})
  end

  def test_var_and_asgn
    assert_parses(
      s(:var_and_asgn, s(:lvar, :a), s(:lit, 1)),
      %q{a &&= 1},
      %q{  ^^^ operator
        |~~~~~~~ expression})
  end

  # Method logical operator-assignment

  def test_or_asgn
    assert_parses(
      s(:or_asgn,
        s(:send, s(:lvar, :foo), :a),
        s(:lit, 1)),
      %q{foo.a ||= 1},
      %q{      ^^^ operator
        |    ~ selector (send)
        |~~~~~ expression (send)
        |~~~~~~~~~~~ expression})

    assert_parses(
      s(:or_asgn,
        s(:send, s(:lvar, :foo), :[],
          s(:int, 0), s(:int, 1)),
        s(:lit, 2)),
      %q{foo[0, 1] ||= 1},
      %q{          ^^^ operator
        |   ~~~~~~ selector (send)
        |~~~~~~~~~ expression (send)
        |~~~~~~~~~~~~~~~ expression})
  end

  def test_and_asgn
    assert_parses(
      s(:and_asgn,
        s(:send, s(:lvar, :foo), :a),
        s(:lit, 1)),
      %q{foo.a &&= 1},
      %q{      ^^^ operator
        |    ~ selector (send)
        |~~~~~ expression (send)
        |~~~~~~~~~~~ expression})

    assert_parses(
      s(:and_asgn,
        s(:send, s(:lvar, :foo), :[],
          s(:int, 0), s(:int, 1)),
        s(:lit, 2)),
      %q{foo[0, 1] &&= 1},
      %q{          ^^^ operator
        |   ~~~~~~ selector (send)
        |~~~~~~~~~ expression (send)
        |~~~~~~~~~~~~~~~ expression})
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
  end

  def test_undef
    assert_parses(
      s(:undef, s(:sym, :foo), s(:sym, :bar)),
      %q{undef foo :bar},
      %q{~~~~~ keyword
        |      ~~~ expression (sym/1)
        |          ~~~~ expression (sym/2)})
  end

  #
  # Aliasing
  #

  def test_alias
  end

  def test_alias_gvar
  end

  #
  # Formal arguments
  #

  def test_arg
  end

  def test_optarg
  end

  def test_splatarg_named
  end

  def test_splatarg_unnamed
  end

  def test_blockarg
  end

  def test_arg_mlhs
  end

  #
  # Sends
  #

  # To self

  def test_send_self
  end

  # To receiver

  def test_send_plain
  end

  def test_send_binary_op
  end

  def test_send_unary_op
  end

  def test_send_attr_asgn
  end

  def test_send_index
  end

  def test_send_index_asgn
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
