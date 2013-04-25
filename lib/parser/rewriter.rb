module Parser
  class Rewriter < Parser::AST::Processor
    def rewrite(source_buffer, ast)
      @source_rewriter = Source::Rewriter.new(source_buffer)

      process(ast)

      @source_rewriter.process
    end

    private

    def assignment?(node)
      [:lvasgn, :ivasgn, :gvasgn,
       :cvasgn, :cvdecl, :cdecl].include?(node.type)
    end

    def remove(range)
      @source_rewriter.remove(range)
    end

    def insert_before(range, content)
      @source_rewriter.insert_before(range, content)
    end

    def insert_after(range, content)
      @source_rewriter.insert_after(range, content)
    end

    def replace(range, content)
      @source_rewriter.replace(range, content)
    end
  end
end
