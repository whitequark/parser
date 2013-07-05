module Parser
  ##
  # {Parser::SyntaxError} is raised whenever parser detects a syntax error
  # (what a surprise!) similar to the standard SyntaxError class.
  #
  class SyntaxError < StandardError; end
end
