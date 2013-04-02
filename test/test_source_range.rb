require 'minitest/autorun'
require 'parser'

class TestSourceRange < MiniTest::Unit::TestCase
  def setup
    @sfile = Parser::SourceFile.new('(string)')
    @sfile.source = "foobar\nbaz"
  end

  def test_initialize
    sr = Parser::SourceRange.new(@sfile, 1, 2)
    assert_equal 1, sr.begin
    assert_equal 2, sr.end
    assert sr.frozen?
  end

  def test_size
    sr = Parser::SourceRange.new(@sfile, 1, 2)
    assert_equal 2, sr.size
  end

  def test_join
    sr1 = Parser::SourceRange.new(@sfile, 1, 2)
    sr2 = Parser::SourceRange.new(@sfile, 5, 8)
    sr = sr1.join(sr2)

    assert_equal 1, sr.begin
    assert_equal 8, sr.end
  end

  def test_line
    sr = Parser::SourceRange.new(@sfile, 7, 8)
    assert_equal 2, sr.line
  end

  def test_source_line
    sr = Parser::SourceRange.new(@sfile, 7, 8)
    assert_equal "baz", sr.source_line
  end

  def test_columns
    sr = Parser::SourceRange.new(@sfile, 7, 8)
    assert_equal 0, sr.begin_column
    assert_equal 1, sr.end_column
    assert_equal 0..1, sr.column_range
  end

  def test_to_s
    sr = Parser::SourceRange.new(@sfile, 8, 9)
    assert_equal "(string):2:2", sr.to_s
  end
end
