require 'helper'
require 'parser/ruby18'

class TestSourceCommentAssociator < MiniTest::Unit::TestCase
  def test_associate
    parser = Parser::Ruby18.new

    buffer = Parser::Source::Buffer.new('(comments)')
    buffer.source = <<-END
# Class comment
# another class comment
class Foo
  # attr_accessor comment
  attr_accessor :foo

  # method comment
  def bar
    # expr comment
    1 + # intermediate comment
      2
    # stray comment
  end
end
    END

    ast, comments = parser.parse_with_comments(buffer)
    associations  = Parser::Source::Comment.associate(ast, comments)

    klass_node         = ast
    attr_accessor_node = ast.children[2].children[0]
    method_node        = ast.children[2].children[1]
    expr_node          = method_node.children[2]
    intermediate_node  = expr_node.children[2]

    assert_equal 5, associations.size
    assert_equal ['# Class comment', '# another class comment'],
                 associations[klass_node].map(&:text)
    assert_equal ['# attr_accessor comment'],
                 associations[attr_accessor_node].map(&:text)
    assert_equal ['# method comment'],
                 associations[method_node].map(&:text)
    assert_equal ['# expr comment'],
                 associations[expr_node].map(&:text)
    assert_equal ['# intermediate comment'],
                 associations[intermediate_node].map(&:text)
  end

end
