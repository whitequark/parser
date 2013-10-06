require 'helper'
require 'parser/current'

class TestCurrent < Minitest::Test
  def test_current
    case RUBY_VERSION
    when '1.8.7'
      assert_equal Parser::Ruby18, Parser::CurrentRuby
    when '1.9.2', '1.9.3'
      assert_equal Parser::Ruby19, Parser::CurrentRuby
    when '2.0.0'
      assert_equal Parser::Ruby20, Parser::CurrentRuby
    when '2.1.0'
      assert_equal Parser::Ruby21, Parser::CurrentRuby
    else
      flunk "Update test_parser_current for #{RUBY_VERSION}"
    end
  end
end
