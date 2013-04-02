require 'minitest/autorun'
require 'parser'

class TestSourceRange < MiniTest::Unit::TestCase
  def setup
    @sfile = Parser::SourceFile.new('(string)')
  end

  def test_initialize
    sr = Parser::SourceRange.new(@sfile, 1, 2)
    assert_equal 1, sr.begin
    assert_equal 2, sr.end
  end

  def test_join
    sr1 = Parser::SourceRange.new(@sfile, 1, 2)
    sr2 = Parser::SourceRange.new(@sfile, 5, 8)
    sr = sr1.join(sr2)

    assert_equal 1, sr.begin
    assert_equal 8, sr.end
  end
end
