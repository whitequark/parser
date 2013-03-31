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

    def build_back_ref(token); t(token, :back_ref, value(token)); end
    def build_nth_ref(token);  t(token, :nth_ref,  value(token)); end

    def build_func_name(token)
      t(token, :lit, value(token).to_sym)
    end

    def build_integer(token, negate=false)
      val = value(token)
      val = -val if negate

      t(token, :lit, val)
    end
    alias build_float build_integer

    def build_readable(node)
      case node.type
      when :ident
        name, = *node

        if @parser.static_env.declared?(name)
          node.updated(:lvar)
        else
          raise NotImplementedError, "make this a call"
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
        node.updated(:iasgn)
      when :gvar
        node.updated(:gasgn)
      when :const
        node.updated(:cdecl)
      when :ident
        name, = *node
        @parser.static_env.declare(name)

        node.updated(:lasgn)
      when :nil, :self, :true, :false, :__FILE__, :__LINE__
        # TODO
        raise "cannot assign to #{node.type}"
      else
        raise NotImplementedError, "build_assignable #{node.inspect}"
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
