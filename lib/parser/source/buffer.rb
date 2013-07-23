# encoding:ascii-8bit

module Parser
  module Source

    class Buffer
      attr_reader :name, :first_line

      def self.recognize_encoding(string)
        return if string.empty?

        # extract the first two lines in an efficient way
        string =~ /\A(.*)\n?(.*\n)?/
        first_line, second_line = $1, $2

        if first_line =~ /\A\xef\xbb\xbf/ # BOM
          return Encoding::UTF_8
        elsif first_line[0, 2] == '#!'
          encoding_line = second_line
        else
          encoding_line = first_line
        end

        if encoding_line =~ /\A#.*coding\s*[:=]\s*([A-Za-z0-9_-]+)/
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
        original_encoding = string.encoding
        detected_encoding = recognize_encoding(string.force_encoding(Encoding::BINARY))

        if detected_encoding.nil?
          string.force_encoding(original_encoding)
        elsif detected_encoding == Encoding::BINARY
          string
        else
          string.
            force_encoding(detected_encoding).
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
        if defined?(Encoding)
          source = source.dup if source.frozen?
          source = self.class.reencode_string(source)
        end

        self.raw_source = source
      end

      def raw_source=(source)
        if @source
          raise ArgumentError, 'Source::Buffer is immutable'
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
