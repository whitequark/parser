unless Range.method_defined? :size
  # A monkeypatch for 1.9.3.
  class Range
    def size
      max - min + 1
    end
  end
end

module Parser

  class Diagnostic
    LEVELS = [:note, :warning, :error, :fatal].freeze

    attr_reader :source_file
    attr_reader :level, :message, :ranges, :line

    def initialize(level, message, source_file, ranges)
      unless LEVELS.include?(level)
        raise ArgumentError,
              "Diagnostic#level must be one of #{LEVELS.join(', ')}; " \
              "#{level.inspect} provided."
      end

      @level       = level
      @message     = message.to_s.dup.freeze
      @source_file = source_file

      # Array(...) converts a range to an array of elements.
      # We probably need an #is_a?(Range) check here, but I dislike
      # type snooping in Ruby.
      unless ranges.respond_to?(:to_ary)
        ranges = [ranges]
      end

      if ranges.empty?
        raise ArgumentError,
              'Cannot create a Diagnostic without source locations.'
      end

      ranges       = ranges.sort_by(&:begin)

      # Refactor this?
      positions    = ranges.map { |r| [r.begin, r.end] }.reduce([], :+)
      unique_lines = positions.map { |pos| @source_file.position_to_line(pos) }.uniq

      if unique_lines.count > 1
        raise ArgumentError,
              'Cannot create a Diagnostic which spans over multiple source lines.'
      end

      @ranges      = ranges.dup.freeze
      @line        = unique_lines.first

      freeze
    end

    def render
      highlight_length   = ranges.map(&:end).max
      highlight_pointers = ' ' * highlight_length

      spans, points = ranges.partition { |r| r.size > 1 }

      spans.each do |span|
        highlight_pointers[span] = '~' * span.size
      end

      points.each do |point|
        highlight_pointers[point] = '^'
      end

      [
        "#{@source_file.name}:#{@line}:#{@ranges.first.begin + 1}: " \
          "#{@level}: #{@message}",
        @source_file.line(@line),
        highlight_pointers,
      ]
    end
  end

end
