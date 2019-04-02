# frozen_string_literal: true

module Parser

  class Lexer::MaxNumparamStack
    def initialize
      @stack = []
    end

    def cant_have_numparams!
      set(-1)
    end

    def can_have_numparams?
      top >= 0
    end

    def register(numparam)
      set( [top, numparam].max )
    end

    def top
      @stack.last
    end

    def push
      @stack.push(0)
    end

    def pop
      @stack.pop
    end

    private

    def set(value)
      @stack.pop
      @stack.push(value)
    end
  end

end
