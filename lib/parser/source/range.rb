module Parser
  module Source

    class Range
      attr_reader :source_buffer
      attr_reader :begin, :end

      def initialize(source_buffer, begin_, end_)
        @source_buffer = source_buffer
        @begin, @end   = begin_, end_

        freeze
      end

      def size
        @end - @begin + 1
      end

      alias length size

      def line
        line, _ = @source_buffer.decompose_position(@begin)

        line
      end

      def begin_column
        _, column = @source_buffer.decompose_position(@begin)

        column
      end

      def end_column
        _, column = @source_buffer.decompose_position(@end)

        column
      end

      def column_range
        begin_column..end_column
      end

      def source_line
        @source_buffer.source_line(line)
      end

      def to_s
        line, column = @source_buffer.decompose_position(@begin)
        [@source_buffer.name, line, column + 1].join(':')
      end

      def join(other)
        if other.source_buffer == @source_buffer
          Range.new(@source_buffer,
              [@begin, other.begin].min,
              [@end, other.end].max)
        else
          raise ArgumentError, "Cannot join SourceRanges for different SourceFiles"
        end
      end

      def inspect
        "#<Source::Range #{@source_buffer.name} #{@begin}..#{@end}>"
      end
    end

  end
end
