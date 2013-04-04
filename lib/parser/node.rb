module Parser

  class Node < AST::Node
    attr_reader :source_map

    alias src source_map
  end

end
