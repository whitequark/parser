module Parser
  module Source

    class Map::KeywordWithBlock < Map
      attr_reader :keyword
      attr_reader :begin
      attr_reader :end

      def initialize(keyword_l, begin_l, end_l)
        @keyword     = keyword_l
        @begin, @end = begin_l, end_l

        super(@keyword.join(@end))
      end
    end

  end
end
