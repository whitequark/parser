require 'helper'

class TestSourceRange < Minitest::Test
  def setup
    @buf = Parser::Source::Buffer.new('(string)')
    @buf.source = "foobar\nbaz"
    @sr1_3 = Parser::Source::Range.new(@buf, 1, 3)
    @sr2_2 = Parser::Source::Range.new(@buf, 2, 2)
    @sr2_6 = Parser::Source::Range.new(@buf, 2, 6)
    @sr5_8 = Parser::Source::Range.new(@buf, 5, 8)
  end

  def test_initialize
    assert_equal 1, @sr1_3.begin_pos
    assert_equal 3, @sr1_3.end_pos
    assert @sr1_3.frozen?
  end

  def test_size
    assert_equal 4, @sr2_6.size
  end

  def test_bad_size
    assert_raises ArgumentError do
      Parser::Source::Range.new(@buf, 2, 1)
    end
  end

  def test_join
    sr = @sr1_3.join(@sr5_8)

    assert_equal 1, sr.begin_pos
    assert_equal 8, sr.end_pos
  end

  def test_intersect
    assert_equal 2, @sr1_3.intersect(@sr2_6).begin_pos
    assert_equal 3, @sr1_3.intersect(@sr2_6).end_pos
    assert_equal 5, @sr2_6.intersect(@sr5_8).begin_pos
    assert_equal 6, @sr2_6.intersect(@sr5_8).end_pos
    assert @sr1_3.intersect(@sr5_8) == nil
    assert_equal 2, @sr1_3.intersect(@sr2_2).begin_pos
    assert_equal 2, @sr1_3.intersect(@sr2_2).end_pos
    assert_equal 2, @sr2_2.intersect(@sr2_2).begin_pos
    assert_equal 2, @sr2_2.intersect(@sr2_2).end_pos
  end

  def test_disjoint
    assert @sr1_3.disjoint?(@sr5_8)
    assert !@sr1_3.disjoint?(@sr2_6)
    assert !@sr2_6.disjoint?(@sr5_8)
    assert !@sr2_2.disjoint?(@sr2_2)
  end

  def test_overlaps
    assert !@sr1_3.overlaps?(@sr5_8)
    assert @sr1_3.overlaps?(@sr2_6)
    assert @sr2_6.overlaps?(@sr5_8)
    assert @sr1_3.overlaps?(@sr2_2)
    assert !@sr2_6.overlaps?(@sr2_2)
    assert @sr2_2.overlaps?(@sr2_2)
  end

  def test_empty
    assert !@sr1_3.empty?
    assert @sr2_2.empty?
  end

  def test_line
    sr = Parser::Source::Range.new(@buf, 7, 8)
    assert_equal 2, sr.line
  end

  def test_source_line
    sr = Parser::Source::Range.new(@buf, 7, 8)
    assert_equal 'baz', sr.source_line
  end

  def test_columns
    sr = Parser::Source::Range.new(@buf, 7, 8)
    assert_equal 0, sr.begin.column
    assert_equal 1, sr.end.column
    assert_equal 0...1, sr.column_range
  end

  def test_begin_end
    sr_beg = @sr2_6.begin
    assert_equal 2, sr_beg.begin_pos
    assert_equal 2, sr_beg.end_pos

    sr_end = @sr2_6.end
    assert_equal 6, sr_end.begin_pos
    assert_equal 6, sr_end.end_pos
  end

  def test_source
    sr = Parser::Source::Range.new(@buf, 0, 3)
    assert_equal 'foo', sr.source

    sr_multi = Parser::Source::Range.new(@buf, 0, 10)
    assert_equal "foobar\nbaz", sr_multi.source
  end

  def test_is?
    sr = Parser::Source::Range.new(@buf, 0, 3)
    assert sr.is?('foo')
    refute sr.is?('bar')
  end

  def test_to_s
    sr = Parser::Source::Range.new(@buf, 8, 9)
    assert_equal '(string):2:2', sr.to_s
  end

  def test_with
    sr2 = @sr1_3.with(begin_pos: 2)
    sr3 = @sr1_3.with(end_pos: 4)

    assert_equal 2, sr2.begin_pos
    assert_equal 3, sr2.end_pos
    assert_equal 1, sr3.begin_pos
    assert_equal 4, sr3.end_pos
  end
end
