module Parser
  module AST

    class Node < ::AST::Node
      attr_reader :location

      alias loc location

      def assign_properties(properties)
        if (location = properties[:location])
          @location = location
        end
      end
    end

  end
end
