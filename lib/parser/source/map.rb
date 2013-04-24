module Parser
  module Source

    # General idea for Map subclasses: only store what's
    # absolutely necessary; don't duplicate the info contained in
    # ASTs; if it can be extracted from source given only the other
    # stored information, don't store it.
    #
    class Map
      attr_reader :expression

      def initialize(expression)
        @expression = expression

        freeze
      end

      def with_expression(expression_l)
        with { |map| map.update_expression(expression_l) }
      end

      def with_begin_end(begin_l, end_l)
        with_expression(begin_l.join(end_l))
      end

      def with_operator(operator_l)
        Operator.new(operator_l, @expression)
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
