module Parser
  module Source

    class Buffer
      attr_reader :name, :first_line

      def initialize(name, first_line = 1)
        @name       = name
        @first_line = first_line
        @source     = nil
      end

      def read
        self.source = File.read(@name)

        self
      end

      def source
        if @source.nil?
          raise RuntimeError, 'Cannot extract source from uninitialized SourceFile'
        end

        @source
      end

      def source=(source)
        @source = source.freeze

        freeze
      end

      def decompose_position(position)
        line       = line_for(position)
        line_begin = line_begin_positions[line]

        [ @first_line + line, position - line_begin ]
      end

      def source_line(line)
        mapped_line = line - @first_line

        # Consider improving this naïve implementation.
        source_line = source.lines.drop(mapped_line).first

        # Line endings will be commonly present for all lines
        # except the last one. It does not make sense to keep them.
        if source_line.end_with? "\n"
          source_line.chomp
        else
          source_line
        end
      end

      private

      def line_begin_positions
        # TODO: Optimize this.
        [0] + source.
          each_char.
          with_index.
          select do |char, index|
            char == "\n"
          end.map do |char, index|
            index + 1
          end
      end

      def line_for(position)
        # TODO: Optimize this.
        line_begin_positions.rindex do |line_beg|
          line_beg <= position
        end
      end
    end

  end
end
