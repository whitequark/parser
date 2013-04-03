module Parser
  class Sexp < AST::Node
    attr_reader :location

    alias loc location
  end
end

module Parser::Builders
  class Sexp
    attr_accessor :parser

    def build_nil(token);   t(token, :nil);   end
    def build_self(token);  t(token, :self);  end
    def build_true(token);  t(token, :true);  end
    def build_false(token); t(token, :false); end

    def build_ident(token); t(token, :ident, value(token).to_sym); end
    def build_ivar(token);  t(token, :ivar,  value(token).to_sym); end
    def build_gvar(token);  t(token, :gvar,  value(token).to_sym); end
    def build_cvar(token);  t(token, :cvar,  value(token).to_sym); end
    def build_const(token); t(token, :const, value(token).to_sym); end

    def build_back_ref(token); t(token, :back_ref, value(token).to_sym); end
    def build_nth_ref(token);  t(token, :nth_ref,  value(token).to_sym); end

    def build_func_name(token)
      t(token, :lit, value(token).to_sym)
    end

    def build_numeric(token, type, negate)
      val = value(token)
      val = -val if negate

      t(token, type, val)
    end

    def build_integer(token, negate=false)
      build_numeric(token, :int, negate)
    end

    def build_float(token, negate=false)
      build_numeric(token, :float, negate)
    end

    def build_readable(node)
      case node.type
      when :ident
        name, = *node

        if @parser.static_env.declared?(name)
          node.updated(:lvar)
        else
          name, = *node
          node.updated(:call, [ nil, name ])
        end
      else
        node
      end
    end

    def build_assignable(node)
      case node.type
      when :cvar
        if @parser.in_def?
          node.updated(:cvasgn)
        else
          node.updated(:cvdecl)
        end

      when :ivar
        node.updated(:ivasgn)

      when :gvar
        node.updated(:gvasgn)

      when :const
        node.updated(:cdecl)

      when :ident
        name, = *node
        @parser.static_env.declare(name)

        node.updated(:lvasgn)

      when :nil, :self, :true, :false, :__FILE__, :__LINE__
        message = Parser::ERRORS[:invalid_assignment] % { node: node.type }
        diagnostic :error, message, node.loc

      when :back_ref, :nth_ref
        message = Parser::ERRORS[:backref_assignment]
        diagnostic :error, message, node.loc

      else
        raise NotImplementedError, "build_assignable #{node.inspect}"
      end
    end

    def build_assign(lhs, token, rhs)
      case lhs.type
      when :gvasgn, :ivasgn, :lvasgn, :masgn, :cdecl, :cvdecl, :cvasgn
        (lhs << rhs).updated(nil, nil,
            location: Parser::Location::VariableAssignment.new(
                        lhs.loc.expression, location(token),
                        lhs.loc.expression.join(rhs.loc.expression)))

      when :attrasgn, :call
        raise NotImplementedError

      when :const
        (lhs << rhs).updated(:cdecl)

      else
        raise NotImplementedError, "build_assign #{lhs.inspect}"
      end
    end

    def build_alias(token, to, from)
      t(token, :alias, to, from)
    end

    def build_keyword_cmd(type, token, args=nil)
      case type
      when :return, :break, :next, :redo, :retry, :yield, :defined
        t(token, type, *args)

      else
        raise NotImplementedError, "build_keyword_cmd #{type} #{args.inspect}"
      end
    end

    def build_compstmt(statements)
      if statements.one?
        statements.first
      else
        s(:begin, *statements)
      end
    end

    protected

    def t(token, type, *args)
      s(type, *args, location: Parser::Location.new(location(token)))
    end

    def value(token)
      token[0]
    end

    def location(token)
      token[1]
    end

    def s(type, *args)
      if Hash === args.last
        metadata = args.pop
      else
        metadata = {}
      end

      Parser::Sexp.new(type, args, metadata)
    end

    def diagnostic(type, message, location, highlights=[])
      @parser.diagnostics.process(
          Parser::Diagnostic.new(type, message, location, highlights))

      if type == :error
        @parser.yyerror
      end
    end
  end
end
