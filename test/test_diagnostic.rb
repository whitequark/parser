require 'minitest/autorun'
require 'parser'

class TestDiagnostic < MiniTest::Unit::TestCase
  def test_verifies_levels
    assert_raises ArgumentError do
      Parser::Diagnostic.new(:foobar, "foo", nil, [])
    end
  end

  def test_freezes
    string = "foo"
    ranges = [1..2]

    diag = Parser::Diagnostic.new(:error, string, nil, ranges)
    assert diag.frozen?
    assert diag.message.frozen?
    assert diag.ranges.frozen?

    refute string.frozen?
    refute ranges.frozen?
  end

  def test_range_array
    diag = Parser::Diagnostic.new(:error, "foo", nil, 1..2)
    assert_equal [1..2], diag.ranges
  end
end
