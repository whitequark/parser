module Parser
  module AST

    class Processor < ::AST::Processor
      def process_regular_node(node)
        node.updated(nil, process_all(node))
      end

      alias on_begin    process_regular_node
      alias on_if       process_regular_node
      alias on_array    process_regular_node

      def on_send(node)
        receiver, method, *args = *node
        node.updated(nil, [
          process(receiver), method,
          *process_all(args)
        ])
      end
    end

  end
end
