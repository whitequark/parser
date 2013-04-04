module Parser

  # General idea for Location subclasses: only store what's
  # absolutely necessary; don't duplicate the info contained in
  # ASTs; if it can be extracted from source given only the other
  # stored information, don't store it.
  #
  class Location
    attr_reader :expression

    def initialize(expression)
      @expression = expression

      freeze
    end
  end

end
