module Parser
  class Node < AST::Node
    attr_reader :location

    alias loc location
  end
end
