module Parser
  module AST

    class Processor < ::AST::Processor
      def process_regular_node(node)
        node.updated(nil, process_all(node))
      end

      alias on_dstr     process_regular_node
      alias on_dsym     process_regular_node
      alias on_regexp   process_regular_node
      alias on_xstr     process_regular_node
      alias on_splat    process_regular_node
      alias on_array    process_regular_node
      alias on_pair     process_regular_node
      alias on_hash     process_regular_node
      alias on_irange   process_regular_node
      alias on_erange   process_regular_node

      def on_var(node)
        name, = *node

        node.updated
      end

      def process_variable_node(node)
        on_var(node)
      end

      alias on_lvar     process_variable_node
      alias on_ivar     process_variable_node
      alias on_gvar     process_variable_node
      alias on_cvar     process_variable_node
      alias on_back_ref process_variable_node
      alias on_nth_ref  process_variable_node

      def on_vasgn(node)
        name, value_node = *node

        value_node = process(value_node) if value_node
        node.updated(nil, [ name, value_node ])
      end

      def process_var_asgn_node(node)
        on_vasgn(node)
      end

      alias on_lvasgn   process_var_asgn_node
      alias on_ivasgn   process_var_asgn_node
      alias on_gvasgn   process_var_asgn_node
      alias on_cvdecl   process_var_asgn_node
      alias on_cvasgn   process_var_asgn_node

      alias on_and_asgn process_regular_node
      alias on_or_asgn  process_regular_node

      def on_op_asgn(node)
        var_node, method_name, value_node = *node

        node.updated(nil, [
          process(var_node), method_name, process(value_node)
        ])
      end

      alias on_mlhs     process_regular_node
      alias on_masgn    process_regular_node

      def on_const(node)
        scope_node, name = *node

        scope_node = process(scope_node) if scope_node
        node.updated(nil, [ scope_node, name ])
      end

      def on_cdecl(node)
        scope_node, name, value_node = *node

        scope_node = process(scope_node) if scope_node
        value_node = process(value_node)
        node.updated(nil, [ scope_node, name, value_node ])
      end

      alias on_args     process_regular_node

      def on_argument(node)
        arg_name, value_node = *node

        value_node = process(value_node) if value_node
        node.updated(nil, [ arg_name, value_node ])
      end

      def process_argument_node(node)
        on_argument(node)
      end

      alias on_arg            process_argument_node
      alias on_optarg         process_argument_node
      alias on_splatarg       process_argument_node
      alias on_blockarg       process_argument_node
      alias on_kwarg          process_argument_node
      alias on_kwoptarg       process_argument_node
      alias on_kwsplatarg     process_argument_node

      alias on_arg_expr       process_regular_node
      alias on_restarg_expr   process_regular_node
      alias on_blockarg_expr  process_regular_node

      def on_def(node)
        method_name, args_node, body_node = *node

        node.updated(nil, [
          method_name,
          process(args_node), process(body_node)
        ])
      end

      def on_defs(node)
        target_node, method_name, args_node, body_node = *node

        node.updated(nil, [
          process(target_node), method_name,
          process(args_node), process(body_node)
        ])
      end

      alias on_undef    process_regular_node
      alias on_alias    process_regular_node

      def on_send(node)
        receiver_node, method_name, *arg_nodes = *node

        receiver_node = process(receiver_node) if receiver_node
        node.updated(nil, [
          receiver_node, method_name, *process_all(arg_nodes)
        ])
      end

      alias on_block    process_regular_node

      alias on_and      process_regular_node
      alias on_or       process_regular_node
      alias on_if       process_regular_node

      alias on_begin    process_regular_node
    end

  end
end
