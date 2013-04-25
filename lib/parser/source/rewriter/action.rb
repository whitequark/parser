module Parser
  module Source

    class Rewriter::Action
      attr_reader :position, :length, :replacement

      def initialize(position, length, replacement="")
        @position, @length = position, length
        @replacement       = replacement.to_s

        freeze
      end

      def range
        @position...@position + length
      end

      def range_for(source_buffer)
        Source::Range.new(source_buffer, @position, @position + length)
      end

      def to_s
        if @length == 0 && @replacement.empty?
          "do nothing"
        elsif @length == 0
          "insert #{@replacement.inspect}"
        elsif @replacement.empty?
          "remove #{@length} character(s)"
        else
          "replace #{@length} character(s) with #{@replacement.inspect}"
        end
      end
    end

  end
end
