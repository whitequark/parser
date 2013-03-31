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
end
