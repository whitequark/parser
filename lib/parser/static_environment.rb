require 'set'

module Parser

  class StaticEnvironment
    def initialize
      reset
    end

    def reset
      @variables = Set[]
      @stack     = []
    end

    def extend_static
      @stack.push @variables
      @variables = Set[]

      self
    end

    def extend_dynamic
      @stack.push @variables
      @variables = @variables.dup

      self
    end

    def unextend
      @variables = @stack.pop
    end

    def declare(name)
      @variables.add name
    end

    def declared?(name)
      @variables.include? name
    end
  end

end
