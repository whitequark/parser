# encoding: ascii-8bit

require 'minitest/autorun'
require 'parser'

class TestVersion < MiniTest::Unit::TestCase

  def test_ruby18_predicate
    assert_predicate Parser::Version::RUBY_18, :ruby18?
    refute_predicate Parser::Version::RUBY_19, :ruby18?
    refute_predicate Parser::Version::RUBY_20, :ruby18?
  end

  def test_ruby19_predicate
    refute_predicate Parser::Version::RUBY_18, :ruby19?
    assert_predicate Parser::Version::RUBY_19, :ruby19?
    refute_predicate Parser::Version::RUBY_20, :ruby19?
  end

  def test_ruby20_predicate
    refute_predicate Parser::Version::RUBY_18, :ruby20?
    refute_predicate Parser::Version::RUBY_19, :ruby20?
    assert_predicate Parser::Version::RUBY_20, :ruby20?
  end

  def test_inspect
    assert_equal Parser::Version::RUBY_18.inspect, '<Parser::Version::RUBY_18>'
    assert_equal Parser::Version::RUBY_19.inspect, '<Parser::Version::RUBY_19>'
    assert_equal Parser::Version::RUBY_20.inspect, '<Parser::Version::RUBY_20>'
    assert_predicate Parser::Version::RUBY_18.inspect, :frozen?
    assert_same Parser::Version::RUBY_18.inspect, Parser::Version::RUBY_18.inspect
  end
end
