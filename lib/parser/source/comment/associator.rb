module Parser
  module Source

    ##
    # @api public
    #
    class Comment::Associator
      def initialize(comments, ast)
        @comments    = comments
        @ast         = ast
      end

      def associate
        @mapping     = Hash.new { |h, k| h[k] = [] }
        @comment_num = 0

        process(nil, @ast)

        @mapping
      end

      private

      def process(upper_node, node)
        if node.type == :begin
          prev_node, next_node = nil, upper_node
        else
          while current_comment_between?(prev_node, node)
            associate_and_advance_comment(node)
          end

          prev_node, next_node = nil, upper_node
        end

        node.children.each do |child|
          if child.is_a?(AST::Node) && child.location.expression
            prev_node, next_node = next_node, child

            process(prev_node, child)
          end
        end
      end

      def current_comment
        @comments[@comment_num]
      end

      def advance_comment
        @comment_num += 1
      end

      def current_comment_between?(prev_node, next_node)
        return false if current_comment.nil?

        comment_loc = current_comment.location
        next_loc    = next_node.location.expression

        if prev_node.nil?
          comment_loc.end_pos <= next_loc.begin_pos
        else
          prev_loc  = prev_node.location.expression

          comment_loc.begin_pos >= prev_loc.end_pos &&
                comment_loc.end_pos <= next_loc.begin_pos
        end
      end

      def associate_and_advance_comment(node)
        @mapping[node] << current_comment
        advance_comment
      end
    end

  end
end
