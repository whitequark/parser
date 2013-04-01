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
        raise RuntimeError, "Cannot extract source from uninitialized SourceFile"
      end

      @source
    end

    def source=(source)
      @source     = source
    end
  end

end
