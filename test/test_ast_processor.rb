# frozen_string_literal: true

require 'helper'

class TestASTProcessor < Minitest::Test
  LEAF_NODES = %i[
    sym str int float complex rational
    true false nil self
    __FILE__ __LINE__ __ENCODING__
    cbase regopt zsuper
    match_with_trailing_comma match_nil_pattern
    forward_args forwarded_args numargs kwnilarg
    objc_varargs objc_restarg objc_kwarg
    ident
  ].freeze

  def setup
    @traversible = Parser::AST::Processor
      .instance_methods(false)
      .map { |mid| mid.to_s.scan(/\Aon_(.*)/) }
      .flatten
      .map(&:to_sym)

    @traversible += LEAF_NODES
  end

  def test_nodes_are_traversible
    for_each_node do |node|
      assert_includes @traversible, node.type
    end
  end
end
