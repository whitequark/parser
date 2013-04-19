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

      # TODO This is naive and slow
      def to_hash
        Hash[instance_variables.map do |ivar|
          [ ivar[1..-1].to_sym, instance_variable_get(ivar) ]
        end]
      end
    end

  end
end
