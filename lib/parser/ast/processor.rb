module Parser
  module AST

    class Processor < ::AST::Processor
      def process_regular_node(node)
        node.updated(nil, process_all(node))
      end

      alias on_array    process_regular_node
      alias on_dstr     process_regular_node
      alias on_dsym     process_regular_node
      alias on_regexp   process_regular_node
      alias on_xstr     process_regular_node
      alias on_begin    process_regular_node
      alias on_if       process_regular_node

      def on_send(node)
        receiver, method, *args = *node

        receiver = process(receiver) if receiver
        node.updated(nil, [
          receiver, method, *process_all(args)
        ])
      end
    end

  end
end
