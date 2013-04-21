module Parser
  module AST

    class Node < ::AST::Node
      attr_reader :source_map

      alias src source_map

      def assign_properties(properties)
        if (source_map = properties[:source_map])
          @source_map = source_map
        end
      end
    end

  end
end
