module Parser
  module Source

    ##
    # @api public
    #
    class Map
      attr_reader :expression

      def initialize(expression)
        @expression = expression

        freeze
      end

      def line
        @expression.line
      end

      def column
        @expression.column
      end

      def with_expression(expression_l)
        with { |map| map.update_expression(expression_l) }
      end

      def ==(other)
        other.class == self.class &&
          instance_variables.map do |ivar|
            instance_variable_get(ivar) ==
              other.send(:instance_variable_get, ivar)
          end.reduce(:&)
      end

      def to_hash
        Hash[instance_variables.map do |ivar|
          [ ivar[1..-1].to_sym, instance_variable_get(ivar) ]
        end]
      end

      protected

      def with(&block)
        dup.tap(&block).freeze
      end

      def update_expression(expression_l)
        @expression = expression_l
      end
    end

  end
end
