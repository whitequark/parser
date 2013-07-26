module Parser
  module Source

    ##
    # @api public
    #
    class Range
      attr_reader :source_buffer
      attr_reader :begin_pos, :end_pos

      def initialize(source_buffer, begin_pos, end_pos)
        @source_buffer       = source_buffer
        @begin_pos, @end_pos = begin_pos, end_pos

        freeze
      end

      def begin
        Range.new(@source_buffer, @begin_pos, @begin_pos)
      end

      def end
        Range.new(@source_buffer, @end_pos, @end_pos)
      end

      def size
        @end_pos - @begin_pos
      end

      alias length size

      def line
        line, _ = @source_buffer.decompose_position(@begin_pos)

        line
      end

      def column
        _, column = @source_buffer.decompose_position(@begin_pos)

        column
      end

      def column_range
        self.begin.column...self.end.column
      end

      def source_line
        @source_buffer.source_line(line)
      end

      def source
        @source_buffer.source[self.begin_pos...self.end_pos]
      end

      def is?(*what)
        what.include?(source)
      end

      def to_a
        (@begin_pos...@end_pos).to_a
      end

      def to_s
        line, column = @source_buffer.decompose_position(@begin_pos)

        [@source_buffer.name, line, column + 1].join(':')
      end

      def resize(new_size)
        Range.new(@source_buffer, @begin_pos, @begin_pos + new_size)
      end

      def join(other)
        Range.new(@source_buffer,
            [@begin_pos, other.begin_pos].min,
            [@end_pos,   other.end_pos].max)
      end

      def ==(other)
        other.is_a?(Range) &&
          @source_buffer == other.source_buffer &&
          @begin_pos     == other.begin_pos     &&
          @end_pos       == other.end_pos
      end

      def inspect
        "#<Source::Range #{@source_buffer.name} #{@begin_pos}...#{@end_pos}>"
      end
    end

  end
end
