module Parser::Source

  class Range
    attr_reader :source_file, :begin, :end

    def initialize(source_file, begin_, end_)
      @source_file = source_file
      @begin, @end = begin_, end_

      freeze
    end

    def size
      @end - @begin + 1
    end

    def line
      line, _ = @source_file.decompose_position(@begin)

      line
    end

    def begin_column
      _, column = @source_file.decompose_position(@begin)

      column
    end

    def end_column
      _, column = @source_file.decompose_position(@end)

      column
    end

    def column_range
      begin_column..end_column
    end

    def source_line
      @source_file.source_line(line)
    end

    def to_s
      line, column = @source_file.decompose_position(@begin)
      [@source_file.name, line, column + 1].join(':')
    end

    def join(other)
      if other.source_file == @source_file
        Range.new(@source_file,
            [@begin, other.begin].min,
            [@end, other.end].max)
      else
        raise ArgumentError, "Cannot join SourceRanges for different SourceFiles"
      end
    end
  end

end
