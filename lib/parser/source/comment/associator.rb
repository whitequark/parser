module Parser
  module Source

    ##
    # A processor which associates AST nodes with comments based on their
    # location in source code. It may be used, for example, to implement
    # rdoc-style processing.
    #
    # @example
    #   require 'parser/current'
    #
    #   ast, comments = Parser::CurrentRuby.parse_with_comments(<<-CODE)
    #   # Class stuff
    #   class Foo
    #     # Attr stuff
    #     # @see bar
    #     attr_accessor :foo
    #   end
    #   CODE
    #
    #   p Parser::Source::Comment.associate(ast, comments)
    #   # => {
    #   #   (class (const nil :Foo) ...) =>
    #   #     [#<Parser::Source::Comment (string):1:1 "# Class stuff">],
    #   #   (send nil :attr_accessor (sym :foo)) =>
    #   #     [#<Parser::Source::Comment (string):3:3 "# Attr stuff">,
    #   #      #<Parser::Source::Comment (string):4:3 "# @see bar">]
    #   # }
    #
    # @see #associate
    #
    # @!attribute skip_directives
    #  Skip file processing directives disguised as comments.
    #  Namely:
    #
    #    * Shebang line,
    #    * Magic encoding comment.
    #
    #  @return [Boolean]
    #
    # @api public
    #
    class Comment::Associator
      attr_accessor :skip_directives

      ##
      # @param [Parser::AST::Node] ast
      # @param [Array(Parser::Source::Comment)] comments
      def initialize(ast, comments)
        @ast         = ast
        @comments    = comments

        @skip_directives = true
      end

      ##
      # Compute a mapping between AST nodes and comments.
      #
      # A comment belongs to a certain node if it begins after end
      # of the previous node (if one exists) and ends before beginning of
      # the current node.
      #
      # This rule is unambiguous and produces the result
      # one could reasonably expect; for example, this code
      #
      #     # foo
      #     hoge # bar
      #       + fuga
      #
      # will result in the following association:
      #
      #     {
      #       (send (lvar :hoge) :+ (lvar :fuga)) =>
      #         [#<Parser::Source::Comment (string):2:1 "# foo">],
      #       (lvar :fuga) =>
      #         [#<Parser::Source::Comment (string):3:8 "# bar">]
      #     }
      #
      # @return [Hash(Parser::AST::Node, Array(Parser::Source::Comment))]
      #
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
          if child.is_a?(AST::Node) && child.loc && child.loc.expression
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
