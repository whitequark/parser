# encoding:ascii-8bit

module Parser
  module Source

    class Buffer
      attr_reader :name, :first_line

      def self.recognize_encoding(string)
        if string.empty?
          return Encoding::UTF_8
        end

        # TODO: Make this more efficient.
        first_line, second_line = string.lines.first(2)
        first_line.force_encoding(Encoding::ASCII_8BIT)

        if first_line =~ /\A\xef\xbb\xbf/ # BOM
          return Encoding::UTF_8
        elsif first_line[0, 2] == '#!'
          encoding_line = second_line
        else
          encoding_line = first_line
        end

        encoding_line.force_encoding(Encoding::ASCII_8BIT)

        if encoding_line =~ /coding[:=]?\s*([a-z0-9_-]+)/
          Encoding.find($1)
        else
          string.encoding
        end
      end

      # Lexer expects UTF-8 input. This method processes the input
      # in an arbitrary valid Ruby encoding and returns an UTF-8 encoded
      # string.
      #
      def self.reencode_string(string)
        encoding = recognize_encoding(string)

        unless encoding.ascii_compatible?
          raise RuntimeError, "Encoding #{encoding} is not ASCII-compatible"
        end

        string.
          force_encoding(encoding).
          encode(Encoding::UTF_8)
      end

      def initialize(name, first_line = 1)
        @name       = name
        @first_line = first_line
        @source     = nil
      end

      def read
        File.open(@name, 'rb') do |io|
          self.source = io.read
        end

        self
      end

      def source
        if @source.nil?
          raise RuntimeError, 'Cannot extract source from uninitialized Source::Buffer'
        end

        @source
      end

      def source=(source)
        if source.respond_to? :encoding
          source = self.class.reencode_string(source)
        end

        @source  = source.freeze

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
