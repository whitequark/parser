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
        "nil",
      %q{~~~ expression},
        s(:nil))
  end

  def test_true
    assert_parses(
        "true",
      %q{~~~~ expression},
        s(:true))
  end

  def test_false
    assert_parses(
        "false",
      %q{~~~~~ expression},
        s(:false))
  end

  def test_int
    assert_parses(
        "42",
      %q{~~ expression},
        s(:int, 42))
  end

  def test_float
    assert_parses(
        "1.33",
      %q{~~~~ expression},
        s(:float, 1.33))
  end

  # Strings

  def test_string_plain
    assert_parses(
        "'foobar'",
      %q{^ begin
        |       ^ end
        |~~~~~~~~ expression},
        s(:str, 'foobar'))
  end

  def test_string_interp
    assert_parses(
      %q{"foo#{bar}baz"},
      %q{^ begin
        |             ^ end
        |~~~~~~~~~~~~~~ expression},
        s(:dstr,
          s(:str, 'foo'),
          s(:lvar, :bar),
          s(:str, 'baz')))
  end

  # Symbols

  def test_symbol_plain
    assert_parses(
        ":foo",
      %q{~~~~ expression},
        s(:sym, :foo))

    assert_parses(
        ":'foo'",
      %q{ ^ begin
        |     ^ end
        |~~~~~~ expression},
        s(:sym, :foo))
  end

  def test_symbol_interp
    assert_parses(
      %q{:"foo#{bar}baz"},
      %q{ ^ begin
        |              ^ end
        | ~~~~~~~~~~~~~~ expression},
        s(:dsym,
          s(:str, 'foo'),
          s(:lvar, :bar),
          s(:str, 'baz')))
  end

  # Execute-strings

  def test_xstring_plain
    assert_parses(
        "`foobar`",
      %q{^ begin
        |       ^ end
        |~~~~~~~~ expression},
        s(:xstr, 'foobar'))
  end

  def test_xstring_interp
    assert_parses(
      %q{`foo#{bar}baz`},
      %q{^ begin
        |             ^ end
        |~~~~~~~~~~~~~~ expression},
        s(:dxstr,
          s(:str, 'foo'),
          s(:lvar, :bar),
          s(:str, 'baz')))
  end

  # Regexp

  def test_regex_plain
    assert_parses(
        "/source/im",
      %q{^ begin
        |       ^ end
        |        ~~ expression (regopt)
        |~~~~~~~~~~ expression},
        s(:regexp, s(:regopt, :i, :m), 'source'))
  end

  def test_regex_interp
    assert_parses(
      %q{/foo#{bar}baz/},
      %q{^ begin
        |             ^ end
        |~~~~~~~~~~~~~~ expression},
        s(:dregexp,
          s(:str, 'foo'),
          s(:lvar, :bar),
          s(:str, 'baz')))
  end

  # Arrays

  def test_array_plain
    assert_parses(
        "[1, 2]",
      %q{^ begin
        |     ^ end
        |~~~~~~ expression},
        s(:array, s(:int, 1), s(:int, 2)))
  end

  def test_array_splat
    assert_parses(
        "[1, *foo, 2]",
      %q{^ begin
        |           ^ end
        |    ^ operator (splat)
        |    ~~~~ expression (splat)
        |~~~~~~~~~~~~ expression},
        s(:array,
          s(:int, 1),
          s(:splat, s(:lvar, :foo)),
          s(:int, 2)))
  end

  # Hashes

  def test_hash_hashrocket
    assert_parses(
        "{ 1 => 2 }",
      %q{^ begin
        |         ^ end
        |    ^^ operator (pair)
        |  ~~~~~~ expression (pair)
        |~~~~~~~~~~ expression},
        s(:hash, s(:pair, s(:int, 1), s(:int, 2))))
  end

  # def test_hash_label
  #   assert_parses(
  #       "{ foo: 2 }",
  #     %q{^ begin
  #       |         ^ end
  #       |     ^ operator (pair)
  #       |  ~~~ expression (pair.symbol)
  #       |  ~~~~~~ expression (pair)
  #       |~~~~~~~~~~ expression},
  #       s(:hash, s(:pair, s(:symbol, :foo), s(:int, 2))),
  #       %w(1.9 2.0))
  # end

  # def test_hash_kwsplat
  #   assert_parses(
  #       "{ foo: 2, **bar }",
  #     %q{          ^^ operator (kwsplat)
  #       |          ~~~~~ expression (kwsplat)},
  #       s(:hash,
  #         s(:pair, s(:symbol, :foo), s(:int, 2))
  #         s(:kwsplat, s(:lvar, :bar))),
  #       %w(2.0))
  # end

  # Range

  def test_range_inclusive
    assert_parses(
        "1..2",
      %q{ ~~ operator
        |~~~~ expression},
        s(:irange, s(:int, 1), s(:int, 2)))
  end

  def test_range_exclusive
    assert_parses(
        "1...2",
      %q{ ~~~ operator
        |~~~~~ expression},
        s(:erange, s(:int, 1), s(:int, 2)))
  end

  #
  # Access
  #

  # Variables and pseudovariables

  def test_self
    assert_parses(
        "self",
      %q{~~~~ expression},
        s(:self))
  end

  def test_lvar
    assert_parses(
        "foo",
      %q{~~~ expression},
        s(:lvar, :foo))
  end

  def test_ivar
    assert_parses(
        "@foo",
      %q{~~~~ expression},
        s(:ivar, :@foo))
  end

  def test_cvar
    assert_parses(
        "@@foo",
      %q{~~~~~ expression},
        s(:cvar, :@@foo))
  end

  def test_gvar
    assert_parses(
        "$foo",
      %q{~~~~ expression},
        s(:gvar, :$foo))
  end

  # Constants

  def test_const_toplevel
    assert_parses(
        "::Foo",
      %q{  ~~~ name
        |~~~~~ expression},
        s(:const, s(:cbase), :Foo))
  end

  def test_const_scoped
    assert_parses(
        "bar::Foo",
      %q{     ~~~ name
        |~~~~~~~~ expression},
        s(:const, s(:lvar, :bar), :Foo))
  end

  def test_const_unscoped
    assert_parses(
        "Foo",
      %q{~~~ name
        |~~~ expression},
        s(:const, nil, :Foo))
  end

  # defined?

  def test_defined
    assert_parses(
        "defined? foo",
      %q{~~~~~~~~ keyword
        |~~~~~~~~~~~~ expression},
        s(:defined?, s(:lvar, :foo)))

    assert_parses(
        "defined?(foo)",
      %q{~~~~~~~~ keyword
        |        ^ begin
        |            ^ end
        |~~~~~~~~~~~~~ expression},
        s(:defined?, s(:lvar, :foo)))
  end

  #
  # Assignment
  #

  # Variables

  def test_lvasgn
    assert_parses(
        "var = 10; var",
      %q{~~~ name (lvasgn)
        |    ^ operator (lvasgn)
        |~~~~~~~~ expression (lvasgn)
        },
        s(:begin,
          s(:lvasgn, :var, s(:int, 10)),
          s(:lvar, :var)))
  end

  def test_ivasgn
    assert_parses(
        "@var = 10",
      %q{~~~~ name
        |     ^ operator
        |~~~~~~~~~ expression
        },
        s(:ivasgn, :@var, s(:int, 10)))
  end

  def test_cvdecl
    assert_parses(
        "@@var = 10",
      %q{~~~~~ name
        |      ^ operator
        |~~~~~~~~~~ expression
        },
        s(:cvdecl, :@@var, s(:int, 10)))
  end

  def test_cvasgn
    assert_parses(
        "def a; @@var = 10; end",
      %q{       ~~~~~ name (cvasgn)
        |             ^ operator (cvasgn)
        |       ~~~~~~~~~~ expression (cvasgn)
        },
        s(:def, :a, s(:args),
          s(:cvasgn, :@@var, s(:int, 10))))
  end

  def test_gvasgn
    assert_parses(
        "$var = 10",
      %q{~~~~ name
        |     ^ operator
        |~~~~~~~~~ expression
        },
        s(:gvasgn, :$var, s(:int, 10)))
  end

  # Constants

  def test_cdecl_toplevel
    assert_parses(
        "::Foo = 10",
      %q{  ~~~ name
        |      ^ operator
        |~~~~~~~~~~ expression
        },
        s(:cdecl, s(:cbase), :Foo, s(:int, 10)))
  end

  def test_cdecl_scoped
    assert_parses(
        "foo::Foo = 10",
      %q{     ~~~ name
        |         ^ operator
        |~~~~~~~~~~~~~ expression
        },
        s(:cdecl, s(:lvar, :foo), :Foo, s(:int, 10)))
  end

  def test_cdecl_unscoped
    assert_parses(
        "Foo = 10",
      %q{~~~ name
        |    ^ operator
        |~~~~~~~~ expression
        },
        s(:cdecl, nil, :Foo, s(:int, 10)))
  end

  # Multiple assignment

  def test_masgn
    assert_parses(
        "foo, bar = 1, 2",
      %q{         ^ operator
        |~~~~~~~~ expression (mlhs)
        |           ~~~~ expression (array)
        |~~~~~~~~~~~~~~~ expression
        },
        s(:masgn,
          s(:mlhs, s(:lvasgn, :foo), s(:lvasgn, :bar)),
          s(:array, s(:int, 1), s(:int, 2))))
  end

  def test_masgn_splat
    assert_parses(
        "@foo, @@bar = *foo",
      %q{              ^ operator (splat)
        |              ~~~~ expression (splat)
        },
        s(:masgn,
          s(:mlhs, s(:ivasgn, :foo), s(:cvdecl, :bar)),
          s(:splat, s(:lvar, :foo))))

    assert_parses(
        "a, b = *foo, bar",
      %q{},
        s(:masgn,
          s(:mlhs, s(:lvasgn, :a), s(:lvasgn, :b)),
          s(:array, s(:splat, s(:lvar, :foo), s(:lvar, :bar)))))
  end

  def test_masgn_nested
    assert_parses(
        "a, (b, c) = foo",
      %q{   ^ begin (mlhs.mlhs)
        |        ^ end (mlhs.mlhs)
        |   ~~~~~~ expression (mlhs.mlhs)
        },
        s(:masgn,
          s(:mlhs,
            s(:lvasgn, :a),
            s(:mlhs,
              s(:lvasgn, :b),
              s(:lvasgn, :c))),
          s(:lvar, :foo)))
  end

  def test_masgn_attr
    assert_parses(
        "self.a, self[1, 2] = foo",
      %q{~~~~~~ expression (mlhs.send/1)
        |     ~ selector (mlhs.send/1)
        |            ~~~~~~ selector (mlhs.send/2)
        |        ~~~~~~~~~~ expression (mlhs.send/2)},
        s(:masgn,
          s(:mlhs,
            s(:send, s(:self), :a=),
            s(:send, s(:self), :[]=, s(:int, 1), s(:int, 2))),
          s(:lvar, :foo)))
  end

  # Variable binary operator-assignment

  def test_var_op_asgn
  end

  # Method binary operator-assignment

  def test_op_asgn
  end

  # Variable logical operator-assignment

  def test_var_or_asgn
  end

  def test_var_and_asgn
  end

  # Method logical operator-assignment

  def test_or_asgn
  end

  def test_and_asgn
  end

  #
  # Class and module definitions
  #

  def test_module
  end

  def test_class
  end

  def test_class_super
  end

  def test_sclass
  end

  #
  # Method (un)definition
  #

  def test_def
  end

  def test_defs
  end

  def test_undef
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
