require 'minitest/autorun'
require 'parser'

class TestDiagnostic < MiniTest::Unit::TestCase
  def setup
    @sfile = Parser::SourceFile.new('(string)')
    @sfile.source = "if (this is some bad code + bugs)"
  end

  def test_verifies_levels
    assert_raises ArgumentError do
      Parser::Diagnostic.new(:foobar, "foo", @sfile, [])
    end
  end

  def test_freezes
    string = "foo"
    ranges = [1..2]

    diag = Parser::Diagnostic.new(:error, string, @sfile, ranges)
    assert diag.frozen?
    assert diag.message.frozen?
    assert diag.ranges.frozen?

    refute string.frozen?
    refute ranges.frozen?
  end

  def test_range_array
    diag = Parser::Diagnostic.new(:error, "foo", @sfile, 1..2)
    assert_equal [1..2], diag.ranges
  end

  def test_render
    diag  = Parser::Diagnostic.new(:error, "code far too bad",
                                   @sfile, [21..24, 26...27, 28..31])
    assert_equal([
      "(string):1:21: error: code far too bad",
      "if (this is some bad code + bugs)",
      "                     ~~~~ ^ ~~~~"
    ], diag.render)
  end
end
