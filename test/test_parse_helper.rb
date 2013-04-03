require 'minitest/autorun'
require_relative 'parse_helper'

class TestParseHelper < MiniTest::Unit::TestCase
  include ParseHelper

  def test_parser_for_ruby_version
    assert_equal Parser::Ruby18,
                 parser_for_ruby_version('1.8')

    # assert_equal Parser::Ruby19,
    #              parser_for_ruby_version('1.9')

    # assert_equal Parser::Ruby20,
    #              parser_for_ruby_version('2.0')
  end

  def parse_loc(what)
    parse_location_descriptions(what).to_a
  end

  def test_parse_location_description
    assert_equal [[0, 3, 'expr', []]],
                 parse_loc('~~~~ expr')

    assert_equal [[0, 3, 'expr', []]],
                 parse_loc('^~~~ expr')

    assert_equal [[0, 3, 'expr', []]],
                 parse_loc('^^^^ expr')

    assert_equal [[2, 2, 'op', []]],
                 parse_loc('  ^ op')

    assert_equal [[2, 2, 'op', ['foo'] ]],
                 parse_loc('  ~ op (foo)')

    assert_equal [[2, 3, 'op', ['foo', 'bar'] ]],
                 parse_loc('  ~~ op (foo.bar)')

    assert_equal [[2, 3, 'op', ['foo/2', 'bar'] ]],
                 parse_loc('  ~~ op (foo/2.bar)')

    assert_equal [[0, 3, 'expr', []],
                  [5, 6, 'op', ['str']]],
                 parse_loc(%{
                            |~~~~ expr
                            |     ~~ op (str)
                            })
  end

  def test_traverse_ast
    ast = s(:send,
            s(:int, 1), :+,
            s(:dstr,
              s(:str, "foo"),
              s(:int, 2),
              s(:int, 3)))

    assert_equal ast, traverse_ast(ast, %w())

    assert_equal s(:int, 1), traverse_ast(ast, %w(int))
    assert_equal nil, traverse_ast(ast, %w(str))

    assert_equal s(:str, "foo"), traverse_ast(ast, %w(dstr str))
    assert_equal s(:int, 2), traverse_ast(ast, %w(dstr int/1))
    assert_equal s(:int, 3), traverse_ast(ast, %w(dstr int/2))
    assert_equal nil, traverse_ast(ast, %w(dstr int/3))
  end

  def test_assert_parses
    # Someone more clever and/or motivated than me is going to test this.
  end
end
