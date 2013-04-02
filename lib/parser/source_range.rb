module Parser

  class SourceRange
    attr_reader :source_file, :begin, :end

    def initialize(source_file, begin_, end_)
      @source_file = source_file
      @begin, @end = begin_, end_

      freeze
    end

    def join(other)
      if other.source_file == @source_file
        SourceRange.new(@source_file,
            [@begin, other.begin].min,
            [@end, other.end].max)
      else
        raise ArgumentError, "Cannot join SourceRanges for different SourceFiles"
      end
    end
  end

end
