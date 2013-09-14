require 'helper'

class TestNode < Minitest::Test

  def setup
  end

  def test_equivalent
    ast = s(:begin,
            s(:send,
              s(:int, 1), :==,
              s(:int, 2)))

    equivalent = [
      ast,
      s(:send,
        s(:int, 1), :==,
        s(:int, 2)),
      s(:begin,
        s(:send,
          s(:int, 1), :==,
          s(:int, 2))),
      s(:kwbegin,
        s(:send,
          s(:int, 1), :==,
          s(:int, 2))),
      s(:send,
        s(:begin, s(:int, 1)), :==,
        s(:begin, s(:int, 2))),
      s(:begin,
        s(:send,
          s(:begin, s(:int, 1)), :==,
          s(:begin, s(:int, 2)))),
      s(:begin,
        s(:begin,
          s(:send,
            s(:begin, s(:int, 1)), :==,
            s(:begin, s(:int, 2)))))
    ]

    equivalent.each do |other_ast|
      assert ast.equivalent?(other_ast)
      assert other_ast.equivalent?(ast)
    end

    not_equivalent = [
      s(:send,
        s(:int, 1), :==,
        s(:int, 3)),
      s(:begin,
        s(:begin,
          s(:send,
            s(:begin, s(:int, 1)), :==,
            s(:begin, s(:int, 3)))))
    ]

    not_equivalent.each do |other_ast|
      refute ast.equivalent?(other_ast)
      refute other_ast.equivalent?(ast)
    end
  end

  private

  def s(type, *children)
    Parser::AST::Node.new(type, children)
  end
end
