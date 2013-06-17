require 'helper'

class TestDiagnostic < Minitest::Test
  def setup
    @buffer = Parser::Source::Buffer.new('(string)')
    @buffer.source = 'if (this is some bad code + bugs)'

    @range1 = Parser::Source::Range.new(@buffer, 0, 2) # if
    @range2 = Parser::Source::Range.new(@buffer, 4, 8) # this
  end

  def test_verifies_levels
    assert_raises ArgumentError, /level/ do
      Parser::Diagnostic.new(:foobar, 'foo', @range1)
    end
  end

  def test_freezes
    string     = 'foo'
    highlights = [@range2]

    diag = Parser::Diagnostic.new(:error, string, @range1, highlights)
    assert diag.frozen?
    assert diag.message.frozen?
    assert diag.highlights.frozen?

    refute string.frozen?
    refute highlights.frozen?
  end

  def test_render
    location = Parser::Source::Range.new(@buffer, 26, 27)

    highlights = [
      Parser::Source::Range.new(@buffer, 21, 25),
      Parser::Source::Range.new(@buffer, 28, 32)
    ]

    diag  = Parser::Diagnostic.new(:error, 'code far too bad',
                                   location, highlights)
    assert_equal([
      '(string):1:27: error: code far too bad',
      'if (this is some bad code + bugs)',
      '                     ~~~~ ^ ~~~~ '
    ], diag.render)
  end
end
