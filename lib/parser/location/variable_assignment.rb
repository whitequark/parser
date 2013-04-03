module Parser

  class Location::VariableAssignment < Location::Operator
    attr_reader :name

    def initialize(name, operator, expression)
      @name = name

      super(operator, expression)
    end
  end

end
