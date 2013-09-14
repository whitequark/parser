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
          @location = location
        end
      end

      ##
      # Compares `self` to `other` for runtime equivalence. An AST for Ruby
      # source that has superfluous parentheses, for instance, is equivalent to
      # the AST for the source without them.
      #
      # @param [#to_ast] other
      #
      # @return [Boolean]
      #
      def equivalent?(other)
        if equal?(other)
          true
        elsif other.respond_to? :to_ast
          other = other.to_ast
          if equivalent_type? other
            equivalent_children? other
          elsif begin_type? && self.children.size == 1
            self.children.first.equivalent? other
          elsif other.begin_type? && other.children.size == 1
            other.children.first.equivalent? self
          else
            false
          end
        else
          false
        end
      end

      protected

      # @return [Boolean] is the node a begin type?
      def begin_type?
        [:begin, :kwbegin].include? self.type
      end

      private

      # @param [Parser::AST::Node] other
      #
      # @return [Boolean] is the node's type equivalent to other's?
      def equivalent_type?(other)
        other.type == self.type || (other.begin_type? && begin_type?)
      end

      # @param [Parser::AST::Node] other
      #
      # @return [Boolean] are the node's children equivalent to other's?
      def equivalent_children?(other)
        return false if other.children.size != self.children.size
        self.children.each_with_index do |child, index|
          other_child = other.children[index]
          if child.respond_to? :equivalent?
            return false unless child.equivalent?(other_child)
          else
            return false unless child == other_child
          end
        end
        true
      end
    end

  end
end
