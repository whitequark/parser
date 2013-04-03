require 'minitest/autorun'
require_relative 'parse_helper'

class TestParser < MiniTest::Unit::TestCase
  include ParseHelper

  def test_singletons
    assert_parses(
        "nil",
      %q{~~~ expression},
        s(:nil))

    assert_parses(
        "true",
      %q{~~~~ expression},
        s(:true))

    assert_parses(
        "false",
      %q{~~~~~ expression},
        s(:false))
  end

  def test_self
    assert_parses(
        "self",
      %q{~~~~ expression},
        s(:self))
  end

  def test_ivasgn
    assert_parses(
        "@a = 10",
      %q{~~ name
        |   ^ operator
        |~~~~~~~ expression
        |     ^~ expression (int)
        },
        s(:ivasgn, :@a, s(:int, 10)))
  end
end
