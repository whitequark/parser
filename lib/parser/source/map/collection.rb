module Parser
  module Source

    class Map::Collection < Map
      attr_reader :begin
      attr_reader :end

      def initialize(begin_l, end_l)
        @begin, @end = begin_l, end_l

        super(nil) #(@begin.join(@end))
      end
    end

  end
end
