require 'furnace/ast'

module Parser
  class Sexp < Furnace::AST::Node
    attr_reader :line, :first_column, :last_column
    alias :column :first_column
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

    def build_integer(token, negate=false)
      val = value(token)
      val = -val if negate

      t(token, :lit, val)
    end
    alias build_float build_integer

    def build_assignable(lhs)
      case lhs.type
      when :cvar
        if @parser.in_def?
          lhs.updated(:cvasgn)
        else
          lhs.updated(:cvdecl)
        end
      when :ivar
        lhs.updated(:iasgn)
      when :gvar
        lhs.updated(:gasgn)
      when :const
        lhs.updated(:cdecl)
      when :ident
        name, = *lhs
        @parser.static_env.declare(name)

        lhs.updated(:lasgn)
      when :nil, :self, :true, :false, :__FILE__, :__LINE__
        # TODO
        raise "cannot assign to #{lhs.type}"
      else
        raise NotImplementedError, "build_assignable #{lhs}"
      end
    end

    def build_assign(lhs, token, rhs)
      case lhs.type
      when :gasgn, :iasgn, :lasgn, :masgn, :cdecl, :cvdecl, :cvasgn
        lhs << rhs
      when :attrasgn, :call
        raise NotImplementedError
      when :const
        (lhs << rhs).updated(:cdecl)
      else
        raise NotImplementedError, "build_assign #{lhs}"
      end
    end

    def build_compstmt(statements)
      s(:begin, *statements)
    end

    protected

    def t(token, type, *args)
      line, first_col, last_col = *location(token)

      s(type, *args,
        line:         line,
        first_column: first_col,
        last_column:  last_col)
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
  end
end
