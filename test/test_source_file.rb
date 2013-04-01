require 'minitest/autorun'
require 'parser'

class TestSourceFile < MiniTest::Unit::TestCase
  def setup
    @sfile = Parser::SourceFile.new('(string)')
  end

  def test_initialize
    sfile = Parser::SourceFile.new('(string)')
    assert_equal '(string)', sfile.name
    assert_equal 1, sfile.first_line

    sfile = Parser::SourceFile.new('(string)', 5)
    assert_equal 5, sfile.first_line
  end

  def test_source_setter
    @sfile.source = 'foo'
    assert_equal 'foo', @sfile.source
  end

  def test_read
    tempfile = Tempfile.new('parser')
    tempfile.write('foobar')
    tempfile.flush

    sfile = Parser::SourceFile.new(tempfile.path)
    sfile.read
    assert_equal 'foobar', sfile.source
  end

  def test_uninitialized
    assert_raises RuntimeError do
      @sfile.source
    end
  end

  def test_position_to_line
    @sfile.source = "1\nfoo\nbar"

    assert_equal 1, @sfile.position_to_line(0)
    assert_equal 1, @sfile.position_to_line(1)
    assert_equal 2, @sfile.position_to_line(2)
    assert_equal 3, @sfile.position_to_line(7)
  end

  def test_position_to_line_mapped
    @sfile = Parser::SourceFile.new('(string)', 5)
    @sfile.source = "1\nfoo\nbar"

    assert_equal 5, @sfile.position_to_line(0)
    assert_equal 6, @sfile.position_to_line(2)
  end

  def test_line
    @sfile.source = "1\nfoo\nbar"

    assert_equal "1", @sfile.line(1)
    assert_equal "foo", @sfile.line(2)
  end

  def test_line_mapped
    @sfile = Parser::SourceFile.new('(string)', 5)
    @sfile.source = "1\nfoo\nbar"

    assert_equal "1", @sfile.line(5)
    assert_equal "foo", @sfile.line(6)
  end
end
