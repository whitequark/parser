module Parser
  module Source

    class Map::SendOperator < Map
      attr_reader :selector

      def initialize(selector, expression)
        @selector = selector

        super(expression)
      end
    end

  end
end
