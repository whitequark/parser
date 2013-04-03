module Parser

  class Location
    attr_reader :expression

    def initialize(expression)
      @expression = expression

      freeze
    end
  end

end
