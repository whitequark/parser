# encoding: binary

require 'helper'

class TestEncoding < Minitest::Test
  def recognize(string)
    Parser::Source::Buffer.recognize_encoding(string)
  end

  if defined?(Encoding)
    def test_default
      assert_equal Encoding::UTF_8, recognize("foobar")
    end

    def test_bom
      assert_equal Encoding::UTF_8, recognize("\xef\xbb\xbf\nfoobar")
      assert_equal Encoding::UTF_8, recognize("\xef\xbb\xbf# coding:koi8-r\nfoobar")
    end

    def test_magic_comment
      assert_equal Encoding::KOI8_R, recognize("# coding:koi8-r\nfoobar")
    end

    def test_shebang
      assert_equal Encoding::KOI8_R, recognize("#!/bin/foo\n# coding:koi8-r\nfoobar")
    end

    def test_case
      assert_equal Encoding::KOI8_R, recognize("#!/bin/foo\n# coding:KoI8-r\nfoobar")
    end

    def test_space
      assert_equal Encoding::KOI8_R, recognize("#!/bin/foo\n# coding : koi8-r\nfoobar")
    end

    def test_empty
      assert_equal Encoding::UTF_8, recognize("")
    end

    def test_no_comment
      assert_equal Encoding::UTF_8, recognize(%{require 'cane/encoding_aware_iterator'})
    end

    def test_adjacent
      assert_equal Encoding::UTF_8, recognize("# codingkoi8-r")
      assert_equal Encoding::UTF_8, recognize("# coding koi8-r")
    end
  end
end
