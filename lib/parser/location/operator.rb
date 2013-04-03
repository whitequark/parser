module Parser

  class Location::Operator < Location
    attr_reader :operator

    def initialize(operator, expression)
      @operator = operator

      super(expression)
    end
  end

end
