module Parser
  module Source

    class Map::VariableAssignment < Map::Operator
      attr_reader :name

      def initialize(name, operator, expression)
        @name = name

        super(operator, expression)
      end
    end

  end
end
