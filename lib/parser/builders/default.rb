module Parser

  class Builders::Default
    attr_accessor :parser

    def nil(token);   t(token, :nil);   end
    def self(token);  t(token, :self);  end
    def true(token);  t(token, :true);  end
    def false(token); t(token, :false); end

    def ident(token); t(token, :ident, value(token).to_sym); end
    def ivar(token);  t(token, :ivar,  value(token).to_sym); end
    def gvar(token);  t(token, :gvar,  value(token).to_sym); end
    def cvar(token);  t(token, :cvar,  value(token).to_sym); end
    def const(token); t(token, :const, value(token).to_sym); end

    def back_ref(token); t(token, :back_ref, value(token).to_sym); end
    def nth_ref(token);  t(token, :nth_ref,  value(token).to_sym); end

    def function_name(token)
      t(token, :lit, value(token).to_sym)
    end

    def numeric(token, type, negate)
      val = value(token)
      val = -val if negate

      t(token, type, val)
    end
    private :numeric

    def integer(token, negate=false)
      numeric(token, :int, negate)
    end

    def float(token, negate=false)
      numeric(token, :float, negate)
    end

    def accessible(node)
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

    def assignable(node)
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
        message = ERRORS[:invalid_assignment] % { node: node.type }
        diagnostic :error, message, node.loc

      when :back_ref, :nth_ref
        message = ERRORS[:backref_assignment]
        diagnostic :error, message, node.loc

      else
        raise NotImplementedError, "build_assignable #{node.inspect}"
      end
    end

    def assign(lhs, token, rhs)
      case lhs.type
      when :gvasgn, :ivasgn, :lvasgn, :masgn, :cdecl, :cvdecl, :cvasgn
        (lhs << rhs).updated(nil, nil,
            source_map: Source::Map::VariableAssignment.new(
                        lhs.src.expression, location(token),
                        lhs.src.expression.join(rhs.src.expression)))

      when :attrasgn, :call
        raise NotImplementedError

      when :const
        (lhs << rhs).updated(:cdecl)

      else
        raise NotImplementedError, "build_assign #{lhs.inspect}"
      end
    end

    def alias(token, to, from)
      t(token, :alias, to, from)
    end

    def keyword_cmd(type, token, args=nil)
      case type
      when :return, :break, :next, :redo, :retry, :yield, :defined
        t(token, type, *args)

      else
        raise NotImplementedError, "build_keyword_cmd #{type} #{args.inspect}"
      end
    end

    def compstmt(statements)
      if statements.one?
        statements.first
      else
        s(:begin, *statements)
      end
    end

    protected

    def t(token, type, *args)
      s(type, *args, source_map: Source::Map.new(location(token)))
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

      Node.new(type, args, metadata)
    end

    def diagnostic(type, message, location, highlights=[])
      @parser.diagnostics.process(
          Diagnostic.new(type, message, location, highlights))

      if type == :error
        @parser.yyerror
      end
    end
  end

end
