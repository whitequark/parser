module Parser
  module Helpers

    # @private
    #
    # Performs a check that optional argument is not used
    # in its own definition. Rejects code like
    #   def m(a = a)...
    #   def m(a = proc { 1 + a })...
    #
    class CircularArgumentReference < Parser::AST::Processor
      def initialize(arg_name, &on_error)
        @arg_name = arg_name
        @on_error = on_error
      end

      def on_lvar(node)
        name, = *node
        if name == @arg_name
          @on_error.call(node)
        end
      end

      def stop_traversing(_node); end

      alias on_class stop_traversing

      def on_sclass(node)
        of, _body = *node
        process(of)
      end

      alias on_def stop_traversing

      def on_defs(node)
        recv, _mid, _body = *node
        process(recv)
      end
    end

  end
end
