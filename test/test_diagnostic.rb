require 'minitest/autorun'
require 'parser'

class TestDiagnostic < MiniTest::Unit::TestCase
  def setup
    @sfile = Parser::SourceFile.new('(string)')
    @sfile.source = "if (this is some bad code + bugs)"

    @range1 = Parser::SourceRange.new(@sfile, 0, 1) # if
    @range2 = Parser::SourceRange.new(@sfile, 4, 7) # this
  end

  def test_verifies_levels
    assert_raises ArgumentError, /level/ do
      Parser::Diagnostic.new(:foobar, "foo", @range1)
    end
  end

  def test_freezes
    string     = "foo"
    highlights = [@range2]

    diag = Parser::Diagnostic.new(:error, string, @range1, highlights)
    assert diag.frozen?
    assert diag.message.frozen?
    assert diag.highlights.frozen?

    refute string.frozen?
    refute highlights.frozen?
  end

  def test_render
    location = Parser::SourceRange.new(@sfile, 26, 26)

    highlights = [
      Parser::SourceRange.new(@sfile, 21, 24),
      Parser::SourceRange.new(@sfile, 28, 31)
    ]

    diag  = Parser::Diagnostic.new(:error, "code far too bad",
                                   location, highlights)
    assert_equal([
      "(string):1:27: error: code far too bad",
      "if (this is some bad code + bugs)",
      "                     ~~~~ ^ ~~~~ "
    ], diag.render)
  end
end
