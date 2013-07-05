module Parser
  module AST

    ##
    # {Parser::AST::Node} contains information about a single AST node and its
    # child nodes, it extends the basic `AST::Node` class provided by the "ast"
    # Gem.
    #
    # @!attribute [r] location
    #  @return [Parser::Source::Map]
    #
    class Node < ::AST::Node
      attr_reader :location

      alias loc location

      ##
      # Assigns various properties to the current AST node. Currently only the
      # location can be set.
      #
      # @param [Hash] properties
      #
      # @option properties [Parser::Source::Map] :location Location information
      #  of the node.
      #
      def assign_properties(properties)
        if (location = properties[:location])
          @location = location
        end
      end
    end

  end
end
