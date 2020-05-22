# frozen_string_literal: true

require 'helper'

class TestMeta < Minitest::Test
  def test_NODE_TYPES
    for_each_node do |node|
      assert Parser::Meta::NODE_TYPES.include?(node.type),
            "Type #{node.type} missing from Parser::Meta::NODE_TYPES"
    end
  end
end
