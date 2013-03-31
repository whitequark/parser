module Parser

  class SourceFile
    attr_reader   :name, :first_line
    attr_accessor :source

    def initialize(name, first_line = 1)
      @name       = name
      @first_line = first_line
      @source     = nil
    end

    def read
      self.source = File.read(@name)

      self
    end

    def source=(source)
      @source     = source
    end
  end

end
