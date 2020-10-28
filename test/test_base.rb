# frozen_string_literal: true

require 'helper'
require 'parser/current'

class TestBase < Minitest::Test
  include AST::Sexp

  def test_parse
    ast = Parser::CurrentRuby.parse('1')
    assert_equal s(:int, 1), ast
  end

  def test_parse_with_comments
    ast, comments = Parser::CurrentRuby.parse_with_comments('1 # foo')
    assert_equal s(:int, 1), ast
    assert_equal 1, comments.size
    assert_equal '# foo', comments.first.text
  end

  def test_loc_to_node
    ast = Parser::CurrentRuby.parse('1')
    assert_equal ast.loc.node, ast
  end

  def test_loc_dup
    ast = Parser::CurrentRuby.parse('1')
    assert_nil ast.loc.dup.node
    Parser::AST::Node.new(:zsuper, [], :location => ast.loc)
  end

  def test_node_ractor
    ast = Parser::CurrentRuby.parse('1')
    ::Ractor.make_shareable(ast)
    assert ::Ractor.shareable?(ast)
    assert_equal '1', ast.loc.expression.source
  end if defined?(::Ractor)
end
