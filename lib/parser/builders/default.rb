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

    def __LINE__(token)
      t(token, :int, location(token).line)
    end

    # Strings

    def string(token)
      t(token, :str, value(token))
    end

    def string_compose(begin_t, parts, end_t)
      if parts.one?
        parts.first
      else
        s(:dstr, *parts)
      end
    end

    def __FILE__(token)
      t(token, :str, location(token).source_buffer.name)
    end

    # Symbols

    def symbol(token)
      t(token, :sym, value(token).to_sym)
    end

    def symbol_compose(begin_t, parts, end_t)
      s(:dsym, *parts)
    end

    # Executable strings

    def xstring_compose(begin_t, parts, end_t)
      s(:xstr, *parts)
    end

    # Regular expressions

    def regexp_options(token)
      t(token, :regopt, *value(token).each_char.sort.uniq.map(&:to_sym))
    end

    def regexp_compose(begin_t, parts, end_t, options)
      s(:regexp, *(parts << options))
    end

    # Arrays

    def array(begin_t, elements, end_t)
      s(:array, *elements)
    end

    def splat(star_t, arg=nil)
      if arg.nil?
        s(:splat)
      else
        s(:splat, arg)
      end
    end

    def words_compose(begin_t, parts, end_t)
      s(:array, *parts)
    end

    # Hashes

    def pair(key, assoc_t, value)
      s(:pair, key, value)
    end

    def pair_list_18(list)
      if list.size % 2 != 0
        # TODO better location info here
        message = ERRORS[:odd_hash]
        diagnostic :error, message, list.last.src.expression
      else
        list.
          each_slice(2).map do |key, value|
            s(:pair, key, value)
          end
      end
    end

    def associate(begin_t, pairs, end_t)
      s(:hash, *pairs)
    end

    # Ranges

    def range_inclusive(lhs, token, rhs)
      s(:irange, lhs, rhs)
    end

    def range_exclusive(lhs, token, rhs)
      s(:erange, lhs, rhs)
    end

    #
    # Expression grouping
    #

    def parenthesize(begin_t, expr, end_t)
      expr
    end

    #
    # Access
    #

    def self(token);  t(token, :self); end

    def ident(token); t(token, :ident, value(token).to_sym); end
    def ivar(token);  t(token, :ivar,  value(token).to_sym); end
    def gvar(token);  t(token, :gvar,  value(token).to_sym); end
    def cvar(token);  t(token, :cvar,  value(token).to_sym); end

    def back_ref(token); t(token, :back_ref, value(token).to_sym); end
    def nth_ref(token);  t(token, :nth_ref,  value(token));        end

    def accessible(node)
      case node.type
      when :ident
        name, = *node

        if @parser.static_env.declared?(name)
          node.updated(:lvar)
        else
          name, = *node
          node.updated(:send, [ nil, name ])
        end
      else
        node
      end
    end

    def const(token)
      t(token, :const, nil, value(token).to_sym)
    end

    def const_global(t_colon3, token)
      s(:const, s(:cbase), value(token).to_sym)
    end

    def const_fetch(scope, t_colon2, token)
      s(:const, scope, value(token).to_sym)
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
        if @parser.in_def?
          message = ERRORS[:dynamic_const]
          diagnostic :error, message, node.src.expression
        end

        node.updated(:cdecl)

      when :ident
        name, = *node
        @parser.static_env.declare(name)

        node.updated(:lvasgn)

      when :nil, :self, :true, :false, :__FILE__, :__LINE__
        message = ERRORS[:invalid_assignment] % { :node => node.type }
        diagnostic :error, message, node.loc

      when :back_ref, :nth_ref
        message = ERRORS[:backref_assignment]
        diagnostic :error, message, node.src.expression

      else
        raise NotImplementedError, "build_assignable #{node.inspect}"
      end
    end

    def assign(lhs, token, rhs)
      case lhs.type
      when :lvasgn, :masgn, :gvasgn, :ivasgn, :cvdecl,
           :cvasgn, :cdecl,
           :send
        lhs << rhs

      when :const
        (lhs << rhs).updated(:cdecl)

      else
        raise NotImplementedError, "build assign #{lhs.inspect}"
      end
    end

    def op_assign(lhs, operator_t, rhs)
      case lhs.type
      when :gvasgn, :ivasgn, :lvasgn, :cvasgn, :cvdecl, :send
        operator = value(operator_t)[0..-1].to_sym

        case operator
        when :'&&'
          s(:and_asgn, lhs, rhs)
        when :'||'
          s(:or_asgn, lhs, rhs)
        else
          s(:op_asgn, lhs, operator, rhs)
        end

      when :back_ref, :nth_ref
        message = ERRORS[:backref_assignment]
        diagnostic :error, message, lhs.src.expression

      else
        raise NotImplementedError, "build op_assign #{lhs.inspect}"
      end
    end

    def multi_lhs(begin_t, items, end_t)
      s(:mlhs, *items)
    end

    def multi_assign(lhs, eql_t, rhs)
      s(:masgn, lhs, rhs)
    end

    #
    # Class and module definition
    #

    def def_class(class_t, name,
                  lt_t, superclass,
                  body, end_t)
      s(:class, name, superclass, body)
    end

    def def_sclass(class_t, lshft_t, expr,
                   body, end_t)
      s(:sclass, expr, body)
    end

    def def_module(module_t, name,
                   body, end_t)
      s(:module, name, body)
    end

    #
    # Method (un)definition
    #

    def def_method(def_t, name, args,
                   body, end_t, comments)
      s(:def, value(name).to_sym, args, body)
    end

    def def_singleton(def_t, definee, dot_t,
                      name, args,
                      body, end_t, comments)
      case definee.type
      when :int, :str, :dstr, :sym, :dsym,
           :regexp, :array, :hash

        message = ERRORS[:singleton_literal]
        diagnostic :error, message, nil # TODO definee.src.expression

      else
        s(:defs, definee, value(name).to_sym, args, body)
      end
    end

    def undef_method(token, names)
      s(:undef, *names)
    end

    #
    # Aliasing
    #

    def alias(token, to, from)
      t(token, :alias, to, from)
    end

    def keyword_cmd(type, token, lparen_t=nil, args=[], rparen_t=nil)
      case type
      when :return,
           :break, :next, :redo,
           :retry,
           :super, :zsuper, :yield,
           :defined?

        t(token, type, *args)

      else
        raise NotImplementedError, "build_keyword_cmd #{type} #{args.inspect}"
      end
    end

    #
    # Formal arguments
    #

    def args(begin_t, args, end_t)
      s(:args, *args)
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

    def shadowarg(token)
      s(:shadowarg, value(token).to_sym)
    end

    def blockarg(amper_t, token)
      s(:blockarg, value(token).to_sym)
    end

    # Ruby 1.8 block arguments

    def arg_expr(expr)
      if expr.type == :lvasgn
        expr.updated(:arg)
      else
        s(:arg_expr, expr)
      end
    end

    def splatarg_expr(star_t, expr=nil)
      if expr.nil?
        t(star_t, :splatarg)
      elsif expr.type == :lvasgn
        expr.updated(:splatarg)
      else
        s(:splatarg_expr, expr)
      end
    end

    def blockarg_expr(amper_t, expr)
      if expr.type == :lvasgn
        expr.updated(:blockarg)
      else
        s(:blockarg_expr, expr)
      end
    end

    #
    # Method calls
    #

    def call_method(receiver, dot_t, selector_t,
                    begin_t=nil, args=[], end_t=nil)
      if selector_t.nil?
        s(:send, receiver, :call, *args)
      else
        s(:send, receiver, value(selector_t).to_sym, *args)
      end
    end

    def call_lambda(lambda_t)
      s(:send, nil, :lambda)
    end

    def block(method_call, begin_t, args, body, end_t)
      s(:block, method_call, args, body)
    end

    def block_pass(amper_t, arg)
      s(:block_pass, arg)
    end

    def attr_asgn(receiver, dot_t, selector_t)
      method_name = (value(selector_t) + '=').to_sym

      # Incomplete method call.
      s(:send, receiver, method_name)
    end

    def index(receiver, lbrack_t, indexes, rbrack_t)
      s(:send, receiver, :[], *indexes)
    end

    def index_asgn(receiver, lbrack_t, indexes, rbrack_t)
      # Incomplete method call.
      s(:send, receiver, :[]=, *indexes)
    end

    def binary_op(receiver, token, arg)
      if @parser.version == 18
        if value(token) == '!='
          return s(:not, s(:send, receiver, :==, arg))
        elsif value(token) == '!~'
          return s(:not, s(:send, receiver, :=~, arg))
        end
      end

      s(:send, receiver, value(token).to_sym, arg)
    end

    def unary_op(token, receiver)
      case value(token)
      when '+', '-'
        method = value(token) + '@'
      else
        method = value(token)
      end

      s(:send, receiver, method.to_sym)
    end

    def not_op(token, receiver=nil)
      if @parser.version == 18
        s(:not, receiver)
      else
        if receiver.nil?
          s(:send, s(:nil), :'!')
        else
          s(:send, receiver, :'!')
        end
      end
    end

    #
    # Control flow
    #

    # Logical operations: and, or

    def logical_op(type, lhs, token, rhs)
      s(type, lhs, rhs)
    end

    # Conditionals

    def condition(cond_t, cond, then_t,
                  if_true, else_t, if_false, end_t)
      s(:if, cond, if_true, if_false)
    end

    def condition_mod(if_true, if_false, cond_t, cond)
      s(:if, cond, if_true, if_false)
    end

    def ternary(cond, question_t, if_true, colon_t, if_false)
      s(:if, cond, if_true, if_false)
    end

    # Case matching

    def when(when_t, patterns, then_t, body)
      s(:when, *(patterns << body))
    end

    def case(case_t, expr, body, end_t)
      s(:case, expr, *body)
    end

    # Loops

    def loop(loop_t, cond, do_t, body, end_t)
      s(value(loop_t).to_sym, cond, body)
    end

    def loop_mod(body, loop_t, cond)
      s(value(loop_t).to_sym, cond, body)
    end

    def for(for_t, iterator, in_t, iteratee,
            do_t, body, end_t)
      s(:for, iterator, iteratee, body)
    end

    # Exception handling

    def begin(begin_t, body, end_t)
      body
    end

    def rescue_body(rescue_t,
                    exc_list, assoc_t, exc_var,
                    then_t, compound_stmt)
      s(:resbody, exc_list, exc_var, compound_stmt)
    end

    def begin_body(compound_stmt, rescue_bodies=[],
                   else_t=nil,    else_=nil,
                   ensure_t=nil,  ensure_=nil)
      if rescue_bodies.any?
        if else_t
          compound_stmt = s(:rescue, compound_stmt,
                            *(rescue_bodies << else_))
        else
          compound_stmt = s(:rescue, compound_stmt,
                            *(rescue_bodies << nil))
        end
      end

      if ensure_t
        compound_stmt = s(:ensure, compound_stmt, ensure_)
      end

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

    # BEGIN, END

    def preexe(preexe_t, lbrace_t, compstmt, rbrace_t)
      s(:preexe, compstmt)
    end

    def postexe(postexe_t, lbrace_t, compstmt, rbrace_t)
      s(:postexe, compstmt)
    end

    protected

    def t(token, type, *args)
      s(type, *(args << { :source_map => Source::Map.new(location(token)) }))
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
        @parser.send :yyerror
      end
    end
  end

end
