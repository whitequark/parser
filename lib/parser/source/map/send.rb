module Parser
  module Source

    class Map::Send < Map
      attr_reader :selector
      attr_reader :begin
      attr_reader :end

      def initialize(selector, expression)
        @selector = selector

        super(expression)
      end
    end

  end
end
