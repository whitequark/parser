module Parser
  ##
  # {Parser::SyntaxError} is raised whenever parser detects a syntax error
  # (what a surprise!) similar to the standard SyntaxError class.
  #
  class SyntaxError < StandardError
    attr_reader :diagnostic

    def initialize(diagnostic)
      @diagnostic = diagnostic
      super(diagnostic.message)
    end
  end
end
