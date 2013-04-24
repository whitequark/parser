module Parser
  module Source

    class Map::Collection < Map
      attr_reader :begin
      attr_reader :end

      def initialize(begin_l, end_l, expression_l)
        @begin, @end = begin_l, end_l

        super(expression_l)
      end

      def with_begin_end(begin_l, end_l)
        with { |map| map.update_begin_end(begin_l, end_l) }
      end

      protected

      def update_begin_end(begin_l, end_l)
        @begin, @end = begin_l, end_l
        @expression  = begin_l.join(end_l)
      end
    end

  end
end
