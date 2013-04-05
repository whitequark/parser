module Parser

  class Builders::Default
    attr_accessor :parser

    #
    # Literals
    #

    # Singletons

    def nil(token);   t(token, :nil);   end
    def true(token);  t(token, :true);  end
    def false(token); t(token, :false); end

    # Numerics

    def integer(token, negate=false)
      val = value(token)
      val = -val if negate

      t(token, :int, val)
    end

    def float(token, negate=false)
      val = value(token)
      val = -val if negate

      t(token, :float, val)
    end

    # Strings

    def string(token)
      t(token, :str, value(token))
    end

    def string_compose(t_begin, parts, t_end)
      if parts.one?
        parts.first
      else
        s(:dstr, *parts)
      end
    end

    # Symbols

    def symbol(token)
      t(token, :sym, value(token).to_sym)
    end

    def symbol_compose(t_begin, parts, t_end)
      s(:dsym, *parts)
    end

    # Executable strings

    def xstring_compose(t_begin, parts, t_end)
      s(:xstr, *parts)
    end

    # Regular expressions

    def regexp_options(token)
      t(token, :regopt, *value(token).each_char.sort.uniq.map(&:to_sym))
    end

    def regexp_compose(t_begin, parts, t_end, options)
      s(:regexp, *parts, options)
    end

    # Arrays

    def words_compose(t_begin, parts, t_end)
      s(:array, *parts)
    end

    #
    # Access
    #

    def ident(token); t(token, :ident, value(token).to_sym); end
    def ivar(token);  t(token, :ivar,  value(token).to_sym); end
    def gvar(token);  t(token, :gvar,  value(token).to_sym); end
    def cvar(token);  t(token, :cvar,  value(token).to_sym); end
    def const(token); t(token, :const, value(token).to_sym); end

    def back_ref(token); t(token, :back_ref, value(token).to_sym); end
    def nth_ref(token);  t(token, :nth_ref,  value(token).to_sym); end

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

    #
    # Assignment
    #

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

    #
    # Class and module definition
    #

    #
    # Method (un)definition
    #

    def def_method(def_t, name, args, body, end_t, comments)
      s(:def, value(name).to_sym, args, body)
    end

    #
    # Aliasing
    #

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

    #
    # Formal arguments
    #

    def args(args, optargs, restarg, blockarg)
      s(:args, *(args + optargs + restarg + blockarg))
    end

    def arg(token)
      t(token, :arg, value(token).to_sym)
    end

    def optarg(token, eql_t, value)
      s(:optarg, value(token).to_sym, value)
    end

    def splatarg(star_t, token=nil)
      if token
        s(:splatarg, value(token).to_sym)
      else
        t(star_t, :splatarg)
      end
    end

    def blockarg(amper_t, token)
      s(:blockarg, value(token).to_sym)
    end

    #
    # Control flow
    #

    def begin(compound_stmt,
              rescue_, t_rescue,
              else_,   t_else,
              ensure_, t_ensure)
      # TODO
      compound_stmt
    end

    def compstmt(statements)
      case
      when statements.one?
        statements.first
      when statements.none?
        s(:nil)
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

      AST::Node.new(type, args, metadata)
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
