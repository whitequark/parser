module Parser
  module Source

    ##
    #
    # @!attribute skip_directives
    #  Skip file processing directives disguised as comments,
    #  namely:
    #
    #    * Shebang line,
    #    * Magic encoding comment.
    #
    # @api public
    #
    class Comment::Associator
      attr_accessor :skip_directives

      def initialize(comments, ast)
        @comments    = comments
        @ast         = ast

        @skip_directives = true
      end

      def associate
        @mapping     = Hash.new { |h, k| h[k] = [] }
        @comment_num = 0

        advance_through_directives if @skip_directives

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

        comment_loc = current_comment.location.expression
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

      def advance_through_directives
        # Skip shebang.
        if current_comment && current_comment.text =~ /^#!/
          advance_comment
        end

        # Skip encoding line.
        if current_comment && current_comment.text =~ Buffer::ENCODING_RE
          advance_comment
        end
      end
    end

  end
end
