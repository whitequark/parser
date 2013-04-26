require 'helper'

class TestSourceRewriterAction < MiniTest::Unit::TestCase
  def test_accessors
    action = Parser::Source::Rewriter::Action.new(1, 10, "foo")

    assert action.frozen?
    assert_equal 1,      action.position
    assert_equal 10,     action.length
    assert_equal "foo",  action.replacement
    assert_equal 1...11, action.range
  end

  def test_range_for
    buf = Parser::Source::Buffer.new('(test_range_for)')
    buf.source = "foovar"

    action = Parser::Source::Rewriter::Action.new(3, 1, "b")

    range  = action.range_for(buf)

    assert_equal buf, range.source_buffer
    assert_equal 3, range.begin_pos
    assert_equal 1, range.length
  end

  def test_to_s
    action = Parser::Source::Rewriter::Action.new(3, 1, "foo")
    assert_equal "replace 1 character(s) with \"foo\"", action.to_s

    action = Parser::Source::Rewriter::Action.new(3, 0, "foo")
    assert_equal "insert \"foo\"", action.to_s

    action = Parser::Source::Rewriter::Action.new(3, 2, "")
    assert_equal "remove 2 character(s)", action.to_s

    action = Parser::Source::Rewriter::Action.new(3, 0, "")
    assert_equal "do nothing", action.to_s
  end
end
