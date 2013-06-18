# encoding:ascii-8bit

module Parser
  module Source

    class Buffer
      attr_reader :name, :first_line

      def self.recognize_encoding(string)
        return if string.empty?

        # extract the first two lines in an efficient way
        string =~ /(.*)\n?(.*\n)?/
        first_line, second_line = $1, $2

        [first_line, second_line].each do |line|
          line.force_encoding(Encoding::ASCII_8BIT) if line
        end

        if first_line =~ /\A\xef\xbb\xbf/ # BOM
          return Encoding::UTF_8
        elsif first_line[0, 2] == '#!'
          encoding_line = second_line
        else
          encoding_line = first_line
        end

        if encoding_line =~ /^#.*coding\s*[:=]\s*([A-Za-z0-9_-]+)/
          Encoding.find($1)
        else
          nil
        end
      end

      # Lexer expects UTF-8 input. This method processes the input
      # in an arbitrary valid Ruby encoding and returns an UTF-8 encoded
      # string.
      #
      def self.reencode_string(string)
        encoding = recognize_encoding(string)

        if encoding.nil?
          string
        elsif encoding == Encoding::BINARY
          string.force_encoding(Encoding::BINARY)
        else
          string.
            force_encoding(encoding).
            encode(Encoding::UTF_8)
        end
      end

      def initialize(name, first_line = 1)
        @name        = name
        @source      = nil
        @first_line  = first_line

        @lines       = nil
        @line_begins = nil
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
        if @source
          raise ArgumentError, 'Source::Buffer is immutable'
        end

        if source.respond_to? :encoding
          source = source.dup if source.frozen?
          source = self.class.reencode_string(source)
        end

        @source = source.freeze
      end

      def decompose_position(position)
        line_no, line_begin = line_for(position)

        [ @first_line + line_no, position - line_begin ]
      end

      def source_line(line)
        unless @lines
          @lines = @source.lines.map(&:chomp)
        end

        @lines[line - @first_line].dup
      end

      private

      def line_begins
        unless @line_begins
          @line_begins, index = [ [ 0, 0 ] ], 1

          @source.each_char do |char|
            if char == "\n"
              @line_begins.unshift [ @line_begins.length, index ]
            end

            index += 1
          end
        end

        @line_begins
      end

      def line_for(position)
        if line_begins.respond_to? :bsearch
          # Fast O(log n) variant for Ruby >=2.0.
          line_begins.bsearch do |line, line_begin|
            line_begin <= position
          end
        else
          # Slower O(n) variant for Ruby <2.0.
          line_begins.find do |line, line_begin|
            line_begin <= position
          end
        end
      end
    end

  end
end
