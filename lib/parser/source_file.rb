module Parser

  class SourceFile
    attr_reader   :name, :first_line

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
      @source = source
    end

    # TODO: add a variant of this function which handles tabulation.
    # Replicating VT-52 features in 2013 :/
    def position_to_line(position)
      # Consider improving this naïve implementation.
      line = source[0..position].lines.count - 1

      mapped_line = line + @first_line

      mapped_line
    end

    def line(line)
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
  end

end
