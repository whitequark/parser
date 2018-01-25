# frozen_string_literal: true

module Parser
  module AST

    ##
    # {Parser::AST::Node} contains information about a single AST node and its
    # child nodes. It extends the basic [AST::Node](http://rdoc.info/gems/ast/AST/Node)
    # class provided by gem [ast](http://rdoc.info/gems/ast).
    #
    # @api public
    #
    # @!attribute [r] location
    #  Source map for this Node.
    #  @return [Parser::Source::Map]
    #
    class Node < ::AST::Node
      attr_reader :location

      alias loc location

      ##
      # Assigns various properties to this AST node. Currently only the
      # location can be set.
      #
      # @param [Hash] properties
      # @option properties [Parser::Source::Map] :location Location information
      #  of the node.
      #
      def assign_properties(properties)
        if (location = properties[:location])
          location = location.dup if location.frozen?
          location.node = self
          @location = location
        end
      end
      
      ##
      # Produces a machine-readable S-Expression.
      #
      def to_json
        children_json = children.map do |child|
          if child.is_a?(Node)
            child.to_json
          else
            child
          end
        end

        [type.to_s, *children_json]
      end
    end

  end
end
