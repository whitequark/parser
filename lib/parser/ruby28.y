class Parser::Ruby28

token kCLASS kMODULE kDEF kUNDEF kBEGIN kRESCUE kENSURE kEND kIF kUNLESS
      kTHEN kELSIF kELSE kCASE kWHEN kWHILE kUNTIL kFOR kBREAK kNEXT
      kREDO kRETRY kIN kDO kDO_COND kDO_BLOCK kDO_LAMBDA kRETURN kYIELD kSUPER
      kSELF kNIL kTRUE kFALSE kAND kOR kNOT kIF_MOD kUNLESS_MOD kWHILE_MOD
      kUNTIL_MOD kRESCUE_MOD kALIAS kDEFINED klBEGIN klEND k__LINE__
      k__FILE__ k__ENCODING__ tIDENTIFIER tFID tGVAR tIVAR tCONSTANT
      tLABEL tCVAR tNTH_REF tBACK_REF tSTRING_CONTENT tINTEGER tFLOAT
      tUPLUS tUMINUS tUNARY_NUM tPOW tCMP tEQ tEQQ tNEQ
      tGEQ tLEQ tANDOP tOROP tMATCH tNMATCH tDOT tDOT2 tDOT3 tAREF
      tASET tLSHFT tRSHFT tCOLON2 tCOLON3 tOP_ASGN tASSOC tLPAREN
      tLPAREN2 tRPAREN tLPAREN_ARG tLBRACK tLBRACK2 tRBRACK tLBRACE
      tLBRACE_ARG tSTAR tSTAR2 tAMPER tAMPER2 tTILDE tPERCENT tDIVIDE
      tDSTAR tPLUS tMINUS tLT tGT tPIPE tBANG tCARET tLCURLY tRCURLY
      tBACK_REF2 tSYMBEG tSTRING_BEG tXSTRING_BEG tREGEXP_BEG tREGEXP_OPT
      tWORDS_BEG tQWORDS_BEG tSYMBOLS_BEG tQSYMBOLS_BEG tSTRING_DBEG
      tSTRING_DVAR tSTRING_END tSTRING_DEND tSTRING tSYMBOL
      tNL tEH tCOLON tCOMMA tSPACE tSEMI tLAMBDA tLAMBEG tCHARACTER
      tRATIONAL tIMAGINARY tLABEL_END tANDDOT tBDOT2 tBDOT3

prechigh
  right    tBANG tTILDE tUPLUS
  right    tPOW
  right    tUNARY_NUM tUMINUS
  left     tSTAR2 tDIVIDE tPERCENT
  left     tPLUS tMINUS
  left     tLSHFT tRSHFT
  left     tAMPER2
  left     tPIPE tCARET
  left     tGT tGEQ tLT tLEQ
  nonassoc tCMP tEQ tEQQ tNEQ tMATCH tNMATCH
  left     tANDOP
  left     tOROP
  nonassoc tDOT2 tDOT3 tBDOT2 tBDOT3
  right    tEH tCOLON
  left     kRESCUE_MOD
  right    tEQL tOP_ASGN
  nonassoc kDEFINED
  right    kNOT
  left     kOR kAND
  nonassoc kIF_MOD kUNLESS_MOD kWHILE_MOD kUNTIL_MOD kIN
  nonassoc tLBRACE_ARG
  nonassoc tLOWEST
preclow

rule

         program: top_compstmt

    top_compstmt: top_stmts opt_terms
                    {
                      result = @builder.compstmt(val[0])
                    }

       top_stmts: # nothing
                    {
                      result = []
                    }
                | top_stmt
                    {
                      result = [ val[0] ]
                    }
                | top_stmts terms top_stmt
                    {
                      result = val[0] << val[2]
                    }
                | error top_stmt
                    {
                      result = [ val[1] ]
                    }

        top_stmt: stmt
                | klBEGIN begin_block
                    {
                      result = @builder.preexe(val[0], *val[1])
                    }

     begin_block: tLCURLY top_compstmt tRCURLY
                    {
                      result = val
                    }

        bodystmt: compstmt opt_rescue opt_else opt_ensure
                    {
                      rescue_bodies     = val[1]
                      else_t,   else_   = val[2]
                      ensure_t, ensure_ = val[3]

                      if rescue_bodies.empty? && !else_t.nil?
                        diagnostic :error, :useless_else, nil, else_t
                      end

                      result = @builder.begin_body(val[0],
                                  rescue_bodies,
                                  else_t,   else_,
                                  ensure_t, ensure_)
                    }

        compstmt: stmts opt_terms
                    {
                      result = @builder.compstmt(val[0])
                    }

           stmts: # nothing
                    {
                      result = []
                    }
                | stmt_or_begin
                    {
                      result = [ val[0] ]
                    }
                | stmts terms stmt_or_begin
                    {
                      result = val[0] << val[2]
                    }
                | error stmt
                    {
                      result = [ val[1] ]
                    }

   stmt_or_begin: stmt
                | klBEGIN begin_block
                    {
                      diagnostic :error, :begin_in_method, nil, val[0]
                    }

            stmt: kALIAS fitem
                    {
                      @lexer.state = :expr_fname
                    }
                    fitem
                    {
                      result = @builder.alias(val[0], val[1], val[3])
                    }
                | kALIAS tGVAR tGVAR
                    {
                      result = @builder.alias(val[0],
                                  @builder.gvar(val[1]),
                                  @builder.gvar(val[2]))
                    }
                | kALIAS tGVAR tBACK_REF
                    {
                      result = @builder.alias(val[0],
                                  @builder.gvar(val[1]),
                                  @builder.back_ref(val[2]))
                    }
                | kALIAS tGVAR tNTH_REF
                    {
                      diagnostic :error, :nth_ref_alias, nil, val[2]
                    }
                | kUNDEF undef_list
                    {
                      result = @builder.undef_method(val[0], val[1])
                    }
                | stmt kIF_MOD expr_value
                    {
                      result = @builder.condition_mod(val[0], nil,
                                                      val[1], val[2])
                    }
                | stmt kUNLESS_MOD expr_value
                    {
                      result = @builder.condition_mod(nil, val[0],
                                                      val[1], val[2])
                    }
                | stmt kWHILE_MOD expr_value
                    {
                      result = @builder.loop_mod(:while, val[0], val[1], val[2])
                    }
                | stmt kUNTIL_MOD expr_value
                    {
                      result = @builder.loop_mod(:until, val[0], val[1], val[2])
                    }
                | stmt kRESCUE_MOD stmt
                    {
                      rescue_body = @builder.rescue_body(val[1],
                                        nil, nil, nil,
                                        nil, val[2])

                      result = @builder.begin_body(val[0], [ rescue_body ])
                    }
                | klEND tLCURLY compstmt tRCURLY
                    {
                      result = @builder.postexe(val[0], val[1], val[2], val[3])
                    }
                | command_asgn
                | mlhs tEQL command_call
                    {
                      result = @builder.multi_assign(val[0], val[1], val[2])
                    }
                | lhs tEQL mrhs
                    {
                      result = @builder.assign(val[0], val[1],
                                  @builder.array(nil, val[2], nil))
                    }
                | mlhs tEQL mrhs_arg kRESCUE_MOD stmt
                    {
                      rescue_body = @builder.rescue_body(val[3],
                                                         nil, nil, nil,
                                                         nil, val[4])
                      begin_body = @builder.begin_body(val[2], [ rescue_body ])

                      result = @builder.multi_assign(val[0], val[1], begin_body)
                    }
                | mlhs tEQL mrhs_arg
                    {
                      result = @builder.multi_assign(val[0], val[1], val[2])
                    }
                | rassign
                | expr

        rassign: arg_value tASSOC lhs
                    {
                      result = @builder.rassign(val[0], val[1], val[2])
                    }
                | arg_value tASSOC mlhs
                    {
                      result = @builder.multi_rassign(val[0], val[1], val[2])
                    }
                | rassign tASSOC lhs
                    {
                      result = @builder.rassign(val[0], val[1], val[2])
                    }
                | rassign tASSOC mlhs
                    {
                      result = @builder.multi_rassign(val[0], val[1], val[2])
                    }

    command_asgn: lhs tEQL command_rhs
                    {
                      result = @builder.assign(val[0], val[1], val[2])
                    }
                | var_lhs tOP_ASGN command_rhs
                    {
                      result = @builder.op_assign(val[0], val[1], val[2])
                    }
                | primary_value tLBRACK2 opt_call_args rbracket tOP_ASGN command_rhs
                    {
                      result = @builder.op_assign(
                                  @builder.index(
                                    val[0], val[1], val[2], val[3]),
                                  val[4], val[5])
                    }
                | primary_value call_op tIDENTIFIER tOP_ASGN command_rhs
                    {
                      result = @builder.op_assign(
                                  @builder.call_method(
                                    val[0], val[1], val[2]),
                                  val[3], val[4])
                    }
                | primary_value call_op tCONSTANT tOP_ASGN command_rhs
                    {
                      result = @builder.op_assign(
                                  @builder.call_method(
                                    val[0], val[1], val[2]),
                                  val[3], val[4])
                    }
                | primary_value tCOLON2 tCONSTANT tOP_ASGN command_rhs
                    {
                      const  = @builder.const_op_assignable(
                                  @builder.const_fetch(val[0], val[1], val[2]))
                      result = @builder.op_assign(const, val[3], val[4])
                    }
                | primary_value tCOLON2 tIDENTIFIER tOP_ASGN command_rhs
                    {
                      result = @builder.op_assign(
                                  @builder.call_method(
                                    val[0], val[1], val[2]),
                                  val[3], val[4])
                    }
                | backref tOP_ASGN command_rhs
                    {
                      @builder.op_assign(val[0], val[1], val[2])
                    }

     command_rhs: command_call =tOP_ASGN
                | command_call kRESCUE_MOD stmt
                    {
                      rescue_body = @builder.rescue_body(val[1],
                                        nil, nil, nil,
                                        nil, val[2])

                      result = @builder.begin_body(val[0], [ rescue_body ])
                    }
                | command_asgn

            expr: command_call
                | expr kAND expr
                    {
                      result = @builder.logical_op(:and, val[0], val[1], val[2])
                    }
                | expr kOR expr
                    {
                      result = @builder.logical_op(:or, val[0], val[1], val[2])
                    }
                | kNOT opt_nl expr
                    {
                      result = @builder.not_op(val[0], nil, val[2], nil)
                    }
                | tBANG command_call
                    {
                      result = @builder.not_op(val[0], nil, val[1], nil)
                    }
                | arg kIN
                    {
                      @lexer.state = :expr_beg
                      @lexer.command_start = false
                      pattern_variables.push

                      result = @lexer.in_kwarg
                      @lexer.in_kwarg = true
                    }
                  p_expr
                    {
                      @lexer.in_kwarg = val[2]
                      result = @builder.in_match(val[0], val[1], val[3])
                    }
                | arg =tLBRACE_ARG

      expr_value: expr

   expr_value_do:   {
                      @lexer.cond.push(true)
                    }
                  expr_value do
                    {
                      @lexer.cond.pop
                      result = [ val[1], val[2] ]
                    }

        def_name:  fname
                    {
                      @static_env.extend_static
                      @lexer.cmdarg.push(false)
                      @lexer.cond.push(false)
                      @current_arg_stack.push(nil)

                      result = val[0]
                    }

       defn_head: kDEF def_name
                    {
                      @context.push(:def)

                      result = [ val[0], val[1] ]
                    }

       defs_head: kDEF singleton dot_or_colon
                    {
                      @lexer.state = :expr_fname
                    }
                  def_name
                    {
                      @context.push(:defs)

                      result = [ val[0], val[1], val[2], val[4] ]
                    }


    command_call: command
                | block_command

   block_command: block_call
                | block_call dot_or_colon operation2 command_args
                    {
                      result = @builder.call_method(val[0], val[1], val[2],
                                  nil, val[3], nil)
                    }

 cmd_brace_block: tLBRACE_ARG
                    {
                      @context.push(:block)
                    }
                  brace_body tRCURLY
                    {
                      result = [ val[0], *val[2], val[3] ]
                      @context.pop
                    }

           fcall: operation

         command: fcall command_args =tLOWEST
                    {
                      result = @builder.call_method(nil, nil, val[0],
                                  nil, val[1], nil)
                    }
                | fcall command_args cmd_brace_block
                    {
                      method_call = @builder.call_method(nil, nil, val[0],
                                        nil, val[1], nil)

                      begin_t, args, body, end_t = val[2]
                      result      = @builder.block(method_call,
                                      begin_t, args, body, end_t)
                    }
                | primary_value call_op operation2 command_args =tLOWEST
                    {
                      result = @builder.call_method(val[0], val[1], val[2],
                                  nil, val[3], nil)
                    }
                | primary_value call_op operation2 command_args cmd_brace_block
                    {
                      method_call = @builder.call_method(val[0], val[1], val[2],
                                        nil, val[3], nil)

                      begin_t, args, body, end_t = val[4]
                      result      = @builder.block(method_call,
                                      begin_t, args, body, end_t)
                    }
                | primary_value tCOLON2 operation2 command_args =tLOWEST
                    {
                      result = @builder.call_method(val[0], val[1], val[2],
                                  nil, val[3], nil)
                    }
                | primary_value tCOLON2 operation2 command_args cmd_brace_block
                    {
                      method_call = @builder.call_method(val[0], val[1], val[2],
                                        nil, val[3], nil)

                      begin_t, args, body, end_t = val[4]
                      result      = @builder.block(method_call,
                                      begin_t, args, body, end_t)
                    }
                | kSUPER command_args
                    {
                      result = @builder.keyword_cmd(:super, val[0],
                                  nil, val[1], nil)
                    }
                | kYIELD command_args
                    {
                      result = @builder.keyword_cmd(:yield, val[0],
                                  nil, val[1], nil)
                    }
                | k_return call_args
                    {
                      result = @builder.keyword_cmd(:return, val[0],
                                  nil, val[1], nil)
                    }
                | kBREAK call_args
                    {
                      result = @builder.keyword_cmd(:break, val[0],
                                  nil, val[1], nil)
                    }
                | kNEXT call_args
                    {
                      result = @builder.keyword_cmd(:next, val[0],
                                  nil, val[1], nil)
                    }

            mlhs: mlhs_basic
                    {
                      result = @builder.multi_lhs(nil, val[0], nil)
                    }
                | tLPAREN mlhs_inner rparen
                    {
                      result = @builder.begin(val[0], val[1], val[2])
                    }

      mlhs_inner: mlhs_basic
                    {
                      result = @builder.multi_lhs(nil, val[0], nil)
                    }
                | tLPAREN mlhs_inner rparen
                    {
                      result = @builder.multi_lhs(val[0], val[1], val[2])
                    }

      mlhs_basic: mlhs_head
                | mlhs_head mlhs_item
                    {
                      result = val[0].
                                  push(val[1])
                    }
                | mlhs_head tSTAR mlhs_node
                    {
                      result = val[0].
                                  push(@builder.splat(val[1], val[2]))
                    }
                | mlhs_head tSTAR mlhs_node tCOMMA mlhs_post
                    {
                      result = val[0].
                                  push(@builder.splat(val[1], val[2])).
                                  concat(val[4])
                    }
                | mlhs_head tSTAR
                    {
                      result = val[0].
                                  push(@builder.splat(val[1]))
                    }
                | mlhs_head tSTAR tCOMMA mlhs_post
                    {
                      result = val[0].
                                  push(@builder.splat(val[1])).
                                  concat(val[3])
                    }
                | tSTAR mlhs_node
                    {
                      result = [ @builder.splat(val[0], val[1]) ]
                    }
                | tSTAR mlhs_node tCOMMA mlhs_post
                    {
                      result = [ @builder.splat(val[0], val[1]),
                                 *val[3] ]
                    }
                | tSTAR
                    {
                      result = [ @builder.splat(val[0]) ]
                    }
                | tSTAR tCOMMA mlhs_post
                    {
                      result = [ @builder.splat(val[0]),
                                 *val[2] ]
                    }

       mlhs_item: mlhs_node
                | tLPAREN mlhs_inner rparen
                    {
                      result = @builder.begin(val[0], val[1], val[2])
                    }

       mlhs_head: mlhs_item tCOMMA
                    {
                      result = [ val[0] ]
                    }
                | mlhs_head mlhs_item tCOMMA
                    {
                      result = val[0] << val[1]
                    }

       mlhs_post: mlhs_item
                    {
                      result = [ val[0] ]
                    }
                | mlhs_post tCOMMA mlhs_item
                    {
                      result = val[0] << val[2]
                    }

       mlhs_node: user_variable
                    {
                      result = @builder.assignable(val[0])
                    }
                | keyword_variable
                    {
                      result = @builder.assignable(val[0])
                    }
                | primary_value tLBRACK2 opt_call_args rbracket
                    {
                      result = @builder.index_asgn(val[0], val[1], val[2], val[3])
                    }
                | primary_value call_op tIDENTIFIER
                    {
                      if (val[1][0] == :anddot)
                        diagnostic :error, :csend_in_lhs_of_masgn, nil, val[1]
                      end

                      result = @builder.attr_asgn(val[0], val[1], val[2])
                    }
                | primary_value tCOLON2 tIDENTIFIER
                    {
                      result = @builder.attr_asgn(val[0], val[1], val[2])
                    }
                | primary_value call_op tCONSTANT
                    {
                      if (val[1][0] == :anddot)
                        diagnostic :error, :csend_in_lhs_of_masgn, nil, val[1]
                      end

                      result = @builder.attr_asgn(val[0], val[1], val[2])
                    }
                | primary_value tCOLON2 tCONSTANT
                    {
                      result = @builder.assignable(
                                  @builder.const_fetch(val[0], val[1], val[2]))
                    }
                | tCOLON3 tCONSTANT
                    {
                      result = @builder.assignable(
                                  @builder.const_global(val[0], val[1]))
                    }
                | backref
                    {
                      result = @builder.assignable(val[0])
                    }

             lhs: user_variable
                    {
                      result = @builder.assignable(val[0])
                    }
                | keyword_variable
                    {
                      result = @builder.assignable(val[0])
                    }
                | primary_value tLBRACK2 opt_call_args rbracket
                    {
                      result = @builder.index_asgn(val[0], val[1], val[2], val[3])
                    }
                | primary_value call_op tIDENTIFIER
                    {
                      result = @builder.attr_asgn(val[0], val[1], val[2])
                    }
                | primary_value tCOLON2 tIDENTIFIER
                    {
                      result = @builder.attr_asgn(val[0], val[1], val[2])
                    }
                | primary_value call_op tCONSTANT
                    {
                      result = @builder.attr_asgn(val[0], val[1], val[2])
                    }
                | primary_value tCOLON2 tCONSTANT
                    {
                      result = @builder.assignable(
                                  @builder.const_fetch(val[0], val[1], val[2]))
                    }
                | tCOLON3 tCONSTANT
                    {
                      result = @builder.assignable(
                                  @builder.const_global(val[0], val[1]))
                    }
                | backref
                    {
                      result = @builder.assignable(val[0])
                    }

           cname: tIDENTIFIER
                    {
                      diagnostic :error, :module_name_const, nil, val[0]
                    }
                | tCONSTANT

           cpath: tCOLON3 cname
                    {
                      result = @builder.const_global(val[0], val[1])
                    }
                | cname
                    {
                      result = @builder.const(val[0])
                    }
                | primary_value tCOLON2 cname
                    {
                      result = @builder.const_fetch(val[0], val[1], val[2])
                    }

           fname: tIDENTIFIER | tCONSTANT | tFID
                | op
                | reswords

           fitem: fname
                    {
                      result = @builder.symbol(val[0])
                    }
                | symbol

      undef_list: fitem
                    {
                      result = [ val[0] ]
                    }
                | undef_list tCOMMA
                    {
                      @lexer.state = :expr_fname
                    }
                    fitem
                    {
                      result = val[0] << val[3]
                    }

              op:   tPIPE    | tCARET  | tAMPER2  | tCMP  | tEQ     | tEQQ
                |   tMATCH   | tNMATCH | tGT      | tGEQ  | tLT     | tLEQ
                |   tNEQ     | tLSHFT  | tRSHFT   | tPLUS | tMINUS  | tSTAR2
                |   tSTAR    | tDIVIDE | tPERCENT | tPOW  | tBANG   | tTILDE
                |   tUPLUS   | tUMINUS | tAREF    | tASET | tDSTAR  | tBACK_REF2

        reswords: k__LINE__ | k__FILE__ | k__ENCODING__ | klBEGIN | klEND
                | kALIAS    | kAND      | kBEGIN        | kBREAK  | kCASE
                | kCLASS    | kDEF      | kDEFINED      | kDO     | kELSE
                | kELSIF    | kEND      | kENSURE       | kFALSE  | kFOR
                | kIN       | kMODULE   | kNEXT         | kNIL    | kNOT
                | kOR       | kREDO     | kRESCUE       | kRETRY  | kRETURN
                | kSELF     | kSUPER    | kTHEN         | kTRUE   | kUNDEF
                | kWHEN     | kYIELD    | kIF           | kUNLESS | kWHILE
                | kUNTIL

             arg: lhs tEQL arg_rhs
                    {
                      result = @builder.assign(val[0], val[1], val[2])
                    }
                | var_lhs tOP_ASGN arg_rhs
                    {
                      result = @builder.op_assign(val[0], val[1], val[2])
                    }
                | primary_value tLBRACK2 opt_call_args rbracket tOP_ASGN arg_rhs
                    {
                      result = @builder.op_assign(
                                  @builder.index(
                                    val[0], val[1], val[2], val[3]),
                                  val[4], val[5])
                    }
                | primary_value call_op tIDENTIFIER tOP_ASGN arg_rhs
                    {
                      result = @builder.op_assign(
                                  @builder.call_method(
                                    val[0], val[1], val[2]),
                                  val[3], val[4])
                    }
                | primary_value call_op tCONSTANT tOP_ASGN arg_rhs
                    {
                      result = @builder.op_assign(
                                  @builder.call_method(
                                    val[0], val[1], val[2]),
                                  val[3], val[4])
                    }
                | primary_value tCOLON2 tIDENTIFIER tOP_ASGN arg_rhs
                    {
                      result = @builder.op_assign(
                                  @builder.call_method(
                                    val[0], val[1], val[2]),
                                  val[3], val[4])
                    }
                | primary_value tCOLON2 tCONSTANT tOP_ASGN arg_rhs
                    {
                      const  = @builder.const_op_assignable(
                                  @builder.const_fetch(val[0], val[1], val[2]))
                      result = @builder.op_assign(const, val[3], val[4])
                    }
                | tCOLON3 tCONSTANT tOP_ASGN arg_rhs
                    {
                      const  = @builder.const_op_assignable(
                                  @builder.const_global(val[0], val[1]))
                      result = @builder.op_assign(const, val[2], val[3])
                    }
                | backref tOP_ASGN arg_rhs
                    {
                      result = @builder.op_assign(val[0], val[1], val[2])
                    }
                | arg tDOT2 arg
                    {
                      result = @builder.range_inclusive(val[0], val[1], val[2])
                    }
                | arg tDOT3 arg
                    {
                      result = @builder.range_exclusive(val[0], val[1], val[2])
                    }
                | arg tDOT2
                    {
                      result = @builder.range_inclusive(val[0], val[1], nil)
                    }
                | arg tDOT3
                    {
                      result = @builder.range_exclusive(val[0], val[1], nil)
                    }
                | tBDOT2 arg
                    {
                      result = @builder.range_inclusive(nil, val[0], val[1])
                    }
                | tBDOT3 arg
                    {
                      result = @builder.range_exclusive(nil, val[0], val[1])
                    }
                | arg tPLUS arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tMINUS arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tSTAR2 arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tDIVIDE arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tPERCENT arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tPOW arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | tUNARY_NUM simple_numeric tPOW arg
                    {
                      result = @builder.unary_op(val[0],
                                  @builder.binary_op(
                                    val[1], val[2], val[3]))
                    }
                | tUPLUS arg
                    {
                      result = @builder.unary_op(val[0], val[1])
                    }
                | tUMINUS arg
                    {
                      result = @builder.unary_op(val[0], val[1])
                    }
                | arg tPIPE arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tCARET arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tAMPER2 arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tCMP arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | rel_expr =tCMP
                | arg tEQ arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tEQQ arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tNEQ arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tMATCH arg
                    {
                      result = @builder.match_op(val[0], val[1], val[2])
                    }
                | arg tNMATCH arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | tBANG arg
                    {
                      result = @builder.not_op(val[0], nil, val[1], nil)
                    }
                | tTILDE arg
                    {
                      result = @builder.unary_op(val[0], val[1])
                    }
                | arg tLSHFT arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tRSHFT arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tANDOP arg
                    {
                      result = @builder.logical_op(:and, val[0], val[1], val[2])
                    }
                | arg tOROP arg
                    {
                      result = @builder.logical_op(:or, val[0], val[1], val[2])
                    }
                | kDEFINED opt_nl arg
                    {
                      result = @builder.keyword_cmd(:defined?, val[0], nil, [ val[2] ], nil)
                    }
                | arg tEH arg opt_nl tCOLON arg
                    {
                      result = @builder.ternary(val[0], val[1],
                                                val[2], val[4], val[5])
                    }
                | defn_head f_paren_args tEQL arg
                    {
                      result = @builder.def_endless_method(*val[0],
                                 val[1], val[2], val[3])

                      @lexer.cmdarg.pop
                      @lexer.cond.pop
                      @static_env.unextend
                      @context.pop
                      @current_arg_stack.pop
                    }
                | defn_head f_paren_args tEQL arg kRESCUE_MOD arg
                    {
                      rescue_body = @builder.rescue_body(val[4],
                                        nil, nil, nil,
                                        nil, val[5])

                      method_body = @builder.begin_body(val[3], [ rescue_body ])

                      result = @builder.def_endless_method(*val[0],
                                 val[1], val[2], method_body)

                      @lexer.cmdarg.pop
                      @lexer.cond.pop
                      @static_env.unextend
                      @context.pop
                      @current_arg_stack.pop
                    }
                | defs_head f_paren_args tEQL arg
                    {
                      result = @builder.def_endless_singleton(*val[0],
                                 val[1], val[2], val[3])

                      @lexer.cmdarg.pop
                      @lexer.cond.pop
                      @static_env.unextend
                      @context.pop
                      @current_arg_stack.pop
                    }
                | defs_head f_paren_args tEQL arg kRESCUE_MOD arg
                    {
                      rescue_body = @builder.rescue_body(val[4],
                                        nil, nil, nil,
                                        nil, val[5])

                      method_body = @builder.begin_body(val[3], [ rescue_body ])

                      result = @builder.def_endless_singleton(*val[0],
                                 val[1], val[2], method_body)

                      @lexer.cmdarg.pop
                      @lexer.cond.pop
                      @static_env.unextend
                      @context.pop
                      @current_arg_stack.pop
                    }
                | primary

           relop: tGT | tLT | tGEQ | tLEQ

        rel_expr: arg relop arg =tGT
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | rel_expr relop arg =tGT
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }

       arg_value: arg

       aref_args: none
                | args trailer
                | args tCOMMA assocs trailer
                    {
                      result = val[0] << @builder.associate(nil, val[2], nil)
                    }
                | assocs trailer
                    {
                      result = [ @builder.associate(nil, val[0], nil) ]
                    }

         arg_rhs: arg =tOP_ASGN
                | arg kRESCUE_MOD arg
                    {
                      rescue_body = @builder.rescue_body(val[1],
                                        nil, nil, nil,
                                        nil, val[2])

                      result = @builder.begin_body(val[0], [ rescue_body ])
                    }

      paren_args: tLPAREN2 opt_call_args rparen
                    {
                      result = val
                    }
                | tLPAREN2 args tCOMMA args_forward rparen
                    {
                      unless @static_env.declared_forward_args?
                        diagnostic :error, :unexpected_token, { :token => 'tBDOT3' } , val[3]
                      end

                      result = [val[0], [*val[1], @builder.forwarded_args(val[3])], val[4]]
                    }
                | tLPAREN2 args_forward rparen
                    {
                      unless @static_env.declared_forward_args?
                        diagnostic :error, :unexpected_token, { :token => 'tBDOT3' } , val[1]
                      end

                      result = [val[0], [@builder.forwarded_args(val[1])], val[2]]
                    }

  opt_paren_args: # nothing
                    {
                      result = [ nil, [], nil ]
                    }
                | paren_args

   opt_call_args: # nothing
                    {
                      result = []
                    }
                | call_args
                | args tCOMMA
                | args tCOMMA assocs tCOMMA
                    {
                      result = val[0] << @builder.associate(nil, val[2], nil)
                    }
                | assocs tCOMMA
                    {
                      result = [ @builder.associate(nil, val[0], nil) ]
                    }

       call_args: command
                    {
                      result = [ val[0] ]
                    }
                | args opt_block_arg
                    {
                      result = val[0].concat(val[1])
                    }
                | assocs opt_block_arg
                    {
                      result = [ @builder.associate(nil, val[0], nil) ]
                      result.concat(val[1])
                    }
                | args tCOMMA assocs opt_block_arg
                    {
                      assocs = @builder.associate(nil, val[2], nil)
                      result = val[0] << assocs
                      result.concat(val[3])
                    }
                | block_arg
                    {
                      result =  [ val[0] ]
                    }

    command_args:   {
                      # When branch gets invoked by RACC's lookahead
                      # and command args start with '[' or '('
                      # we need to put `true` to the cmdarg stack
                      # **before** `false` pushed by lexer
                      #   m [], n
                      #     ^
                      # Right here we have cmdarg [...0] because
                      # lexer pushed it on '['
                      # We need to modify cmdarg stack to [...10]
                      #
                      # For all other cases (like `m n` or `m n, []`) we simply put 1 to the stack
                      # and later lexer pushes corresponding bits on top of it.
                      last_token = @last_token[0]
                      lookahead = last_token == :tLBRACK || last_token == :tLPAREN_ARG

                      if lookahead
                        top = @lexer.cmdarg.pop
                        @lexer.cmdarg.push(true)
                        @lexer.cmdarg.push(top)
                      else
                        @lexer.cmdarg.push(true)
                      end
                    }
                  call_args
                    {
                      # call_args can be followed by tLBRACE_ARG (that does cmdarg.push(0) in the lexer)
                      # but the push must be done after cmdarg.pop() in the parser.
                      # So this code does cmdarg.pop() to pop 0 pushed by tLBRACE_ARG,
                      # cmdarg.pop() to pop 1 pushed by command_args,
                      # and cmdarg.push(0) to restore back the flag set by tLBRACE_ARG.
                      last_token = @last_token[0]
                      lookahead = last_token == :tLBRACE_ARG
                      if lookahead
                        top = @lexer.cmdarg.pop
                        @lexer.cmdarg.pop
                        @lexer.cmdarg.push(top)
                      else
                        @lexer.cmdarg.pop
                      end

                      result = val[1]
                    }

       block_arg: tAMPER arg_value
                    {
                      result = @builder.block_pass(val[0], val[1])
                    }

   opt_block_arg: tCOMMA block_arg
                    {
                      result = [ val[1] ]
                    }
                | # nothing
                    {
                      result = []
                    }

            args: arg_value
                    {
                      result = [ val[0] ]
                    }
                | tSTAR arg_value
                    {
                      result = [ @builder.splat(val[0], val[1]) ]
                    }
                | args tCOMMA arg_value
                    {
                      result = val[0] << val[2]
                    }
                | args tCOMMA tSTAR arg_value
                    {
                      result = val[0] << @builder.splat(val[2], val[3])
                    }

        mrhs_arg: mrhs
                    {
                      result = @builder.array(nil, val[0], nil)
                    }
                | arg_value

            mrhs: args tCOMMA arg_value
                    {
                      result = val[0] << val[2]
                    }
                | args tCOMMA tSTAR arg_value
                    {
                      result = val[0] << @builder.splat(val[2], val[3])
                    }
                | tSTAR arg_value
                    {
                      result = [ @builder.splat(val[0], val[1]) ]
                    }

         primary: literal
                | strings
                | xstring
                | regexp
                | words
                | qwords
                | symbols
                | qsymbols
                | var_ref
                | backref
                | tFID
                    {
                      result = @builder.call_method(nil, nil, val[0])
                    }
                | kBEGIN
                    {
                      @lexer.cmdarg.push(false)
                    }
                    bodystmt kEND
                    {
                      @lexer.cmdarg.pop

                      result = @builder.begin_keyword(val[0], val[2], val[3])
                    }
                | tLPAREN_ARG stmt
                    {
                      @lexer.state = :expr_endarg
                    }
                    rparen
                    {
                      result = @builder.begin(val[0], val[1], val[3])
                    }
                | tLPAREN_ARG
                    {
                      @lexer.state = :expr_endarg
                    }
                    opt_nl tRPAREN
                    {
                      result = @builder.begin(val[0], nil, val[3])
                    }
                | tLPAREN compstmt tRPAREN
                    {
                      result = @builder.begin(val[0], val[1], val[2])
                    }
                | primary_value tCOLON2 tCONSTANT
                    {
                      result = @builder.const_fetch(val[0], val[1], val[2])
                    }
                | tCOLON3 tCONSTANT
                    {
                      result = @builder.const_global(val[0], val[1])
                    }
                | tLBRACK aref_args tRBRACK
                    {
                      result = @builder.array(val[0], val[1], val[2])
                    }
                | tLBRACE assoc_list tRCURLY
                    {
                      result = @builder.associate(val[0], val[1], val[2])
                    }
                | k_return
                    {
                      result = @builder.keyword_cmd(:return, val[0])
                    }
                | kYIELD tLPAREN2 call_args rparen
                    {
                      result = @builder.keyword_cmd(:yield, val[0], val[1], val[2], val[3])
                    }
                | kYIELD tLPAREN2 rparen
                    {
                      result = @builder.keyword_cmd(:yield, val[0], val[1], [], val[2])
                    }
                | kYIELD
                    {
                      result = @builder.keyword_cmd(:yield, val[0])
                    }
                | kDEFINED opt_nl tLPAREN2 expr rparen
                    {
                      result = @builder.keyword_cmd(:defined?, val[0],
                                                    val[2], [ val[3] ], val[4])
                    }
                | kNOT tLPAREN2 expr rparen
                    {
                      result = @builder.not_op(val[0], val[1], val[2], val[3])
                    }
                | kNOT tLPAREN2 rparen
                    {
                      result = @builder.not_op(val[0], val[1], nil, val[2])
                    }
                | fcall brace_block
                    {
                      method_call = @builder.call_method(nil, nil, val[0])

                      begin_t, args, body, end_t = val[1]
                      result      = @builder.block(method_call,
                                      begin_t, args, body, end_t)
                    }
                | method_call
                | method_call brace_block
                    {
                      begin_t, args, body, end_t = val[1]
                      result      = @builder.block(val[0],
                                      begin_t, args, body, end_t)
                    }
                | lambda
                | kIF expr_value then compstmt if_tail kEND
                    {
                      else_t, else_ = val[4]
                      result = @builder.condition(val[0], val[1], val[2],
                                                  val[3], else_t,
                                                  else_,  val[5])
                    }
                | kUNLESS expr_value then compstmt opt_else kEND
                    {
                      else_t, else_ = val[4]
                      result = @builder.condition(val[0], val[1], val[2],
                                                  else_,  else_t,
                                                  val[3], val[5])
                    }
                | kWHILE expr_value_do compstmt kEND
                    {
                      result = @builder.loop(:while, val[0], *val[1], val[2], val[3])
                    }
                | kUNTIL expr_value_do compstmt kEND
                    {
                      result = @builder.loop(:until, val[0], *val[1], val[2], val[3])
                    }
                | kCASE expr_value opt_terms case_body kEND
                    {
                      *when_bodies, (else_t, else_body) = *val[3]

                      result = @builder.case(val[0], val[1],
                                             when_bodies, else_t, else_body,
                                             val[4])
                    }
                | kCASE            opt_terms case_body kEND
                    {
                      *when_bodies, (else_t, else_body) = *val[2]

                      result = @builder.case(val[0], nil,
                                             when_bodies, else_t, else_body,
                                             val[3])
                    }
                | kCASE expr_value opt_terms p_case_body kEND
                    {
                      *in_bodies, (else_t, else_body) = *val[3]

                      result = @builder.case_match(val[0], val[1],
                                             in_bodies, else_t, else_body,
                                             val[4])
                    }
                | kFOR for_var kIN expr_value_do compstmt kEND
                    {
                      result = @builder.for(val[0], val[1], val[2], *val[3], val[4], val[5])
                    }
                | kCLASS cpath superclass
                    {
                      @static_env.extend_static
                      @lexer.cmdarg.push(false)
                      @lexer.cond.push(false)
                      @context.push(:class)
                    }
                    bodystmt kEND
                    {
                      unless @context.class_definition_allowed?
                        diagnostic :error, :class_in_def, nil, val[0]
                      end

                      lt_t, superclass = val[2]
                      result = @builder.def_class(val[0], val[1],
                                                  lt_t, superclass,
                                                  val[4], val[5])

                      @lexer.cmdarg.pop
                      @lexer.cond.pop
                      @static_env.unextend
                      @context.pop
                    }
                | kCLASS tLSHFT expr term
                    {
                      @static_env.extend_static
                      @lexer.cmdarg.push(false)
                      @lexer.cond.push(false)
                      @context.push(:sclass)
                    }
                    bodystmt kEND
                    {
                      result = @builder.def_sclass(val[0], val[1], val[2],
                                                   val[5], val[6])

                      @lexer.cmdarg.pop
                      @lexer.cond.pop
                      @static_env.unextend
                      @context.pop
                    }
                | kMODULE cpath
                    {
                      @static_env.extend_static
                      @lexer.cmdarg.push(false)
                      @context.push(:module)
                    }
                    bodystmt kEND
                    {
                      unless @context.module_definition_allowed?
                        diagnostic :error, :module_in_def, nil, val[0]
                      end

                      result = @builder.def_module(val[0], val[1],
                                                   val[3], val[4])

                      @lexer.cmdarg.pop
                      @static_env.unextend
                      @context.pop
                    }
                | defn_head f_arglist bodystmt kEND
                    {
                      result = @builder.def_method(*val[0], val[1],
                                  val[2], val[3])

                      @lexer.cmdarg.pop
                      @lexer.cond.pop
                      @static_env.unextend
                      @context.pop
                      @current_arg_stack.pop
                    }
                | defs_head f_arglist bodystmt kEND
                    {
                      result = @builder.def_singleton(*val[0], val[1],
                                  val[2], val[3])

                      @lexer.cmdarg.pop
                      @lexer.cond.pop
                      @static_env.unextend
                      @context.pop
                      @current_arg_stack.pop
                    }
                | kBREAK
                    {
                      result = @builder.keyword_cmd(:break, val[0])
                    }
                | kNEXT
                    {
                      result = @builder.keyword_cmd(:next, val[0])
                    }
                | kREDO
                    {
                      result = @builder.keyword_cmd(:redo, val[0])
                    }
                | kRETRY
                    {
                      result = @builder.keyword_cmd(:retry, val[0])
                    }

   primary_value: primary

        k_return: kRETURN
                    {
                      if @context.in_class?
                        diagnostic :error, :invalid_return, nil, val[0]
                      end
                    }

            then: term
                | kTHEN
                | term kTHEN
                    {
                      result = val[1]
                    }

              do: term
                | kDO_COND

         if_tail: opt_else
                | kELSIF expr_value then compstmt if_tail
                    {
                      else_t, else_ = val[4]
                      result = [ val[0],
                                 @builder.condition(val[0], val[1], val[2],
                                                    val[3], else_t,
                                                    else_,  nil),
                               ]
                    }

        opt_else: none
                | kELSE compstmt
                    {
                      result = val
                    }

         for_var: lhs
                | mlhs

          f_marg: f_norm_arg
                    {
                      result = @builder.arg(val[0])
                    }
                | tLPAREN f_margs rparen
                    {
                      result = @builder.multi_lhs(val[0], val[1], val[2])
                    }

     f_marg_list: f_marg
                    {
                      result = [ val[0] ]
                    }
                | f_marg_list tCOMMA f_marg
                    {
                      result = val[0] << val[2]
                    }

         f_margs: f_marg_list
                | f_marg_list tCOMMA f_rest_marg
                    {
                      result = val[0].
                                  push(val[2])
                    }
                | f_marg_list tCOMMA f_rest_marg tCOMMA f_marg_list
                    {
                      result = val[0].
                                  push(val[2]).
                                  concat(val[4])
                    }
                |                    f_rest_marg
                    {
                      result = [ val[0] ]
                    }
                |                    f_rest_marg tCOMMA f_marg_list
                    {
                      result = [ val[0], *val[2] ]
                    }

     f_rest_marg: tSTAR f_norm_arg
                    {
                      result = @builder.restarg(val[0], val[1])
                    }
                | tSTAR
                    {
                      result = @builder.restarg(val[0])
                    }

    f_any_kwrest: f_kwrest
                | f_no_kwarg

 block_args_tail: f_block_kwarg tCOMMA f_kwrest opt_f_block_arg
                    {
                      result = val[0].concat(val[2]).concat(val[3])
                    }
                | f_block_kwarg opt_f_block_arg
                    {
                      result = val[0].concat(val[1])
                    }
                | f_any_kwrest opt_f_block_arg
                    {
                      result = val[0].concat(val[1])
                    }
                | f_block_arg
                    {
                      result = [ val[0] ]
                    }

opt_block_args_tail:
                  tCOMMA block_args_tail
                    {
                      result = val[1]
                    }
                | # nothing
                    {
                      result = []
                    }

  excessed_comma: tCOMMA

     block_param: f_arg tCOMMA f_block_optarg tCOMMA f_rest_arg              opt_block_args_tail
                    {
                      result = val[0].
                                  concat(val[2]).
                                  concat(val[4]).
                                  concat(val[5])
                    }
                | f_arg tCOMMA f_block_optarg tCOMMA f_rest_arg tCOMMA f_arg opt_block_args_tail
                    {
                      result = val[0].
                                  concat(val[2]).
                                  concat(val[4]).
                                  concat(val[6]).
                                  concat(val[7])
                    }
                | f_arg tCOMMA f_block_optarg                                opt_block_args_tail
                    {
                      result = val[0].
                                  concat(val[2]).
                                  concat(val[3])
                    }
                | f_arg tCOMMA f_block_optarg tCOMMA                   f_arg opt_block_args_tail
                    {
                      result = val[0].
                                  concat(val[2]).
                                  concat(val[4]).
                                  concat(val[5])
                    }
                | f_arg tCOMMA                       f_rest_arg              opt_block_args_tail
                    {
                      result = val[0].
                                  concat(val[2]).
                                  concat(val[3])
                    }
                | f_arg excessed_comma
                | f_arg tCOMMA                       f_rest_arg tCOMMA f_arg opt_block_args_tail
                    {
                      result = val[0].
                                  concat(val[2]).
                                  concat(val[4]).
                                  concat(val[5])
                    }
                | f_arg                                                      opt_block_args_tail
                    {
                      if val[1].empty? && val[0].size == 1
                        result = [@builder.procarg0(val[0][0])]
                      else
                        result = val[0].concat(val[1])
                      end
                    }
                | f_block_optarg tCOMMA              f_rest_arg              opt_block_args_tail
                    {
                      result = val[0].
                                  concat(val[2]).
                                  concat(val[3])
                    }
                | f_block_optarg tCOMMA              f_rest_arg tCOMMA f_arg opt_block_args_tail
                    {
                      result = val[0].
                                  concat(val[2]).
                                  concat(val[4]).
                                  concat(val[5])
                    }
                | f_block_optarg                                             opt_block_args_tail
                    {
                      result = val[0].
                                  concat(val[1])
                    }
                | f_block_optarg tCOMMA                                f_arg opt_block_args_tail
                    {
                      result = val[0].
                                  concat(val[2]).
                                  concat(val[3])
                    }
                |                                    f_rest_arg              opt_block_args_tail
                    {
                      result = val[0].
                                  concat(val[1])
                    }
                |                                    f_rest_arg tCOMMA f_arg opt_block_args_tail
                    {
                      result = val[0].
                                  concat(val[2]).
                                  concat(val[3])
                    }
                |                                                                block_args_tail

 opt_block_param: # nothing
                    {
                      result = @builder.args(nil, [], nil)
                    }
                | block_param_def
                    {
                      @lexer.state = :expr_value
                    }

 block_param_def: tPIPE opt_bv_decl tPIPE
                    {
                      @max_numparam_stack.has_ordinary_params!
                      @current_arg_stack.set(nil)
                      result = @builder.args(val[0], val[1], val[2])
                    }
                | tPIPE block_param opt_bv_decl tPIPE
                    {
                      @max_numparam_stack.has_ordinary_params!
                      @current_arg_stack.set(nil)
                      result = @builder.args(val[0], val[1].concat(val[2]), val[3])
                    }

     opt_bv_decl: opt_nl
                    {
                      result = []
                    }
                | opt_nl tSEMI bv_decls opt_nl
                    {
                      result = val[2]
                    }

        bv_decls: bvar
                    {
                      result = [ val[0] ]
                    }
                | bv_decls tCOMMA bvar
                    {
                      result = val[0] << val[2]
                    }

            bvar: tIDENTIFIER
                    {
                      @static_env.declare val[0][0]
                      result = @builder.shadowarg(val[0])
                    }
                | f_bad_arg

          lambda: tLAMBDA
                    {
                      @static_env.extend_dynamic
                      @max_numparam_stack.push
                      @context.push(:lambda)
                    }
                  f_larglist
                    {
                      @context.pop
                      @lexer.cmdarg.push(false)
                    }
                  lambda_body
                    {
                      lambda_call = @builder.call_lambda(val[0])
                      args = @max_numparam_stack.has_numparams? ? @builder.numargs(@max_numparam_stack.top) : val[2]
                      begin_t, body, end_t = val[4]

                      @max_numparam_stack.pop
                      @static_env.unextend
                      @lexer.cmdarg.pop

                      result      = @builder.block(lambda_call,
                                      begin_t, args, body, end_t)
                    }

     f_larglist: tLPAREN2 f_args opt_bv_decl tRPAREN
                    {
                      @max_numparam_stack.has_ordinary_params!
                      result = @builder.args(val[0], val[1].concat(val[2]), val[3])
                    }
                | f_args
                    {
                      if val[0].any?
                        @max_numparam_stack.has_ordinary_params!
                      end
                      result = @builder.args(nil, val[0], nil)
                    }

     lambda_body: tLAMBEG
                    {
                      @context.push(:lambda)
                    }
                  compstmt tRCURLY
                    {
                      result = [ val[0], val[2], val[3] ]
                      @context.pop
                    }
                | kDO_LAMBDA
                    {
                      @context.push(:lambda)
                    }
                  bodystmt kEND
                    {
                      result = [ val[0], val[2], val[3] ]
                      @context.pop
                    }

        do_block: kDO_BLOCK
                    {
                      @context.push(:block)
                    }
                  do_body kEND
                    {
                      result = [ val[0], *val[2], val[3] ]
                      @context.pop
                    }

      block_call: command do_block
                    {
                      begin_t, block_args, body, end_t = val[1]
                      result      = @builder.block(val[0],
                                      begin_t, block_args, body, end_t)
                    }
                | block_call dot_or_colon operation2 opt_paren_args
                    {
                      lparen_t, args, rparen_t = val[3]
                      result = @builder.call_method(val[0], val[1], val[2],
                                  lparen_t, args, rparen_t)
                    }
                | block_call dot_or_colon operation2 opt_paren_args brace_block
                    {
                      lparen_t, args, rparen_t = val[3]
                      method_call = @builder.call_method(val[0], val[1], val[2],
                                      lparen_t, args, rparen_t)

                      begin_t, args, body, end_t = val[4]
                      result      = @builder.block(method_call,
                                      begin_t, args, body, end_t)
                    }
                | block_call dot_or_colon operation2 command_args do_block
                    {
                      method_call = @builder.call_method(val[0], val[1], val[2],
                                      nil, val[3], nil)

                      begin_t, args, body, end_t = val[4]
                      result      = @builder.block(method_call,
                                      begin_t, args, body, end_t)
                    }

     method_call: fcall paren_args
                    {
                      lparen_t, args, rparen_t = val[1]
                      result = @builder.call_method(nil, nil, val[0],
                                  lparen_t, args, rparen_t)
                    }
                | primary_value call_op operation2 opt_paren_args
                    {
                      lparen_t, args, rparen_t = val[3]
                      result = @builder.call_method(val[0], val[1], val[2],
                                  lparen_t, args, rparen_t)
                    }
                | primary_value tCOLON2 operation2 paren_args
                    {
                      lparen_t, args, rparen_t = val[3]
                      result = @builder.call_method(val[0], val[1], val[2],
                                  lparen_t, args, rparen_t)
                    }
                | primary_value tCOLON2 operation3
                    {
                      result = @builder.call_method(val[0], val[1], val[2])
                    }
                | primary_value call_op paren_args
                    {
                      lparen_t, args, rparen_t = val[2]
                      result = @builder.call_method(val[0], val[1], nil,
                                  lparen_t, args, rparen_t)
                    }
                | primary_value tCOLON2 paren_args
                    {
                      lparen_t, args, rparen_t = val[2]
                      result = @builder.call_method(val[0], val[1], nil,
                                  lparen_t, args, rparen_t)
                    }
                | kSUPER paren_args
                    {
                      lparen_t, args, rparen_t = val[1]
                      result = @builder.keyword_cmd(:super, val[0],
                                  lparen_t, args, rparen_t)
                    }
                | kSUPER
                    {
                      result = @builder.keyword_cmd(:zsuper, val[0])
                    }
                | primary_value tLBRACK2 opt_call_args rbracket
                    {
                      result = @builder.index(val[0], val[1], val[2], val[3])
                    }

     brace_block: tLCURLY
                    {
                      @context.push(:block)
                    }
                  brace_body tRCURLY
                    {
                      result = [ val[0], *val[2], val[3] ]
                      @context.pop
                    }
                | kDO
                    {
                      @context.push(:block)
                    }
                  do_body kEND
                    {
                      result = [ val[0], *val[2], val[3] ]
                      @context.pop
                    }

      brace_body:   {
                      @static_env.extend_dynamic
                      @max_numparam_stack.push
                    }
                    opt_block_param compstmt
                    {
                      args = @max_numparam_stack.has_numparams? ? @builder.numargs(@max_numparam_stack.top) : val[1]
                      result = [ args, val[2] ]

                      @max_numparam_stack.pop
                      @static_env.unextend
                    }

         do_body:   {
                      @static_env.extend_dynamic
                      @max_numparam_stack.push
                    }
                    {
                      @lexer.cmdarg.push(false)
                    }
                    opt_block_param bodystmt
                    {
                      args = @max_numparam_stack.has_numparams? ? @builder.numargs(@max_numparam_stack.top) : val[2]
                      result = [ args, val[3] ]

                      @max_numparam_stack.pop
                      @static_env.unextend
                      @lexer.cmdarg.pop
                    }

       case_body: kWHEN args then compstmt cases
                    {
                      result = [ @builder.when(val[0], val[1], val[2], val[3]),
                                 *val[4] ]
                    }

           cases: opt_else
                    {
                      result = [ val[0] ]
                    }
                | case_body

     p_case_body: kIN
                    {
                      @lexer.state = :expr_beg
                      @lexer.command_start = false
                      @pattern_variables.push
                      @pattern_hash_keys.push

                      result = @lexer.in_kwarg
                      @lexer.in_kwarg = true
                    }
                  p_top_expr then
                    {
                      @lexer.in_kwarg = val[1]
                    }
                  compstmt p_cases
                    {
                      result = [ @builder.in_pattern(val[0], *val[2], val[3], val[5]),
                                 *val[6] ]
                    }

         p_cases: opt_else
                    {
                      result = [ val[0] ]
                    }
                | p_case_body

      p_top_expr: p_top_expr_body
                    {
                      result = [ val[0], nil ]
                    }
                | p_top_expr_body kIF_MOD expr_value
                    {
                      result = [ val[0], @builder.if_guard(val[1], val[2]) ]
                    }
                | p_top_expr_body kUNLESS_MOD expr_value
                    {
                      result = [ val[0], @builder.unless_guard(val[1], val[2]) ]
                    }

 p_top_expr_body: p_expr
                | p_expr tCOMMA
                    {
                      # array patterns that end with comma
                      # like 1, 2,
                      # must be emitted as `array_pattern_with_tail`
                      item = @builder.match_with_trailing_comma(val[0], val[1])
                      result = @builder.array_pattern(nil, [ item ], nil)
                    }
                | p_expr tCOMMA p_args
                    {
                      result = @builder.array_pattern(nil, [val[0]].concat(val[2]), nil)
                    }
                | p_find
                    {
                      result = @builder.find_pattern(nil, val[0], nil)
                    }
                | p_args_tail
                    {
                      result = @builder.array_pattern(nil, val[0], nil)
                    }
                | p_kwargs
                    {
                      result = @builder.hash_pattern(nil, val[0], nil)
                    }

          p_expr: p_as

            p_as: p_expr tASSOC p_variable
                    {
                      result = @builder.match_as(val[0], val[1], val[2])
                    }
                | p_alt

           p_alt: p_alt tPIPE p_expr_basic
                    {
                      result = @builder.match_alt(val[0], val[1], val[2])
                    }
                | p_expr_basic

        p_lparen: tLPAREN2
                    {
                      result = val[0]
                      @pattern_hash_keys.push
                    }

      p_lbracket: tLBRACK2
                    {
                      result = val[0]
                      @pattern_hash_keys.push
                    }

    p_expr_basic: p_value
                | p_const p_lparen p_args rparen
                    {
                      @pattern_hash_keys.pop
                      pattern = @builder.array_pattern(nil, val[2], nil)
                      result = @builder.const_pattern(val[0], val[1], pattern, val[3])
                    }
                | p_const p_lparen p_find rparen
                    {
                      @pattern_hash_keys.pop
                      pattern = @builder.find_pattern(nil, val[2], nil)
                      result = @builder.const_pattern(val[0], val[1], pattern, val[3])
                    }
                | p_const p_lparen p_kwargs rparen
                    {
                      @pattern_hash_keys.pop
                      pattern = @builder.hash_pattern(nil, val[2], nil)
                      result = @builder.const_pattern(val[0], val[1], pattern, val[3])
                    }
                | p_const tLPAREN2 rparen
                    {
                      pattern = @builder.array_pattern(val[1], nil, val[2])
                      result = @builder.const_pattern(val[0], val[1], pattern, val[2])
                    }
                | p_const p_lbracket p_args rbracket
                    {
                      @pattern_hash_keys.pop
                      pattern = @builder.array_pattern(nil, val[2], nil)
                      result = @builder.const_pattern(val[0], val[1], pattern, val[3])
                    }
                | p_const p_lbracket p_find rbracket
                    {
                      @pattern_hash_keys.pop
                      pattern = @builder.find_pattern(nil, val[2], nil)
                      result = @builder.const_pattern(val[0], val[1], pattern, val[3])
                    }
                | p_const p_lbracket p_kwargs rbracket
                    {
                      @pattern_hash_keys.pop
                      pattern = @builder.hash_pattern(nil, val[2], nil)
                      result = @builder.const_pattern(val[0], val[1], pattern, val[3])
                    }
                | p_const tLBRACK2 rbracket
                    {
                      pattern = @builder.array_pattern(val[1], nil, val[2])
                      result = @builder.const_pattern(val[0], val[1], pattern, val[2])
                    }
                | tLBRACK p_args rbracket
                    {
                      result = @builder.array_pattern(val[0], val[1], val[2])
                    }
                | tLBRACK p_find rbracket
                    {
                      result = @builder.find_pattern(val[0], val[1], val[2])
                    }
                | tLBRACK rbracket
                    {
                      result = @builder.array_pattern(val[0], [], val[1])
                    }
                | tLBRACE
                    {
                      @pattern_hash_keys.push
                      result = @lexer.in_kwarg
                      @lexer.in_kwarg = false
                    }
                  p_kwargs rbrace
                    {
                      @pattern_hash_keys.pop
                      @lexer.in_kwarg = val[1]
                      result = @builder.hash_pattern(val[0], val[2], val[3])
                    }
                | tLBRACE rbrace
                    {
                      result = @builder.hash_pattern(val[0], [], val[1])
                    }
                | tLPAREN
                    {
                      @pattern_hash_keys.push
                    }
                  p_expr rparen
                    {
                      @pattern_hash_keys.pop
                      result = @builder.begin(val[0], val[2], val[3])
                    }

          p_args: p_expr
                    {
                      result = [ val[0] ]
                    }
                | p_args_head
                    {
                      result = val[0]
                    }
                | p_args_head p_arg
                    {
                      result = [ *val[0], val[1] ]
                    }
                | p_args_head tSTAR tIDENTIFIER
                    {
                      match_rest = @builder.match_rest(val[1], val[2])
                      result = [ *val[0], match_rest ]
                    }
                | p_args_head tSTAR tIDENTIFIER tCOMMA p_args_post
                    {
                      match_rest = @builder.match_rest(val[1], val[2])
                      result = [ *val[0], match_rest, *val[4] ]
                    }
                | p_args_head tSTAR
                    {
                      result = [ *val[0], @builder.match_rest(val[1]) ]
                    }
                | p_args_head tSTAR tCOMMA p_args_post
                    {
                      result = [ *val[0], @builder.match_rest(val[1]), *val[3] ]
                    }
                | p_args_tail

     p_args_head: p_arg tCOMMA
                    {
                      # array patterns that end with comma
                      # like [1, 2,]
                      # must be emitted as `array_pattern_with_tail`
                      item = @builder.match_with_trailing_comma(val[0], val[1])
                      result = [ item ]
                    }
                | p_args_head p_arg tCOMMA
                    {
                      # array patterns that end with comma
                      # like [1, 2,]
                      # must be emitted as `array_pattern_with_tail`
                      last_item = @builder.match_with_trailing_comma(val[1], val[2])
                      result = [ *val[0], last_item ]
                    }

     p_args_tail: p_rest
                    {
                      result = [ val[0] ]
                    }
                | p_rest tCOMMA p_args_post
                    {
                      result = [ val[0], *val[2] ]
                    }

          p_find: p_rest tCOMMA p_args_post tCOMMA p_rest
                    {
                      result = [ val[0], *val[2], val[4] ]
                    }

          p_rest: tSTAR tIDENTIFIER
                    {
                      result = @builder.match_rest(val[0], val[1])
                    }
                | tSTAR
                    {
                      result = @builder.match_rest(val[0])
                    }

     p_args_post: p_arg
                    {
                      result = [ val[0] ]
                    }
                | p_args_post tCOMMA p_arg
                    {
                      result = [ *val[0], val[2] ]
                    }

           p_arg: p_expr

        p_kwargs: p_kwarg tCOMMA p_any_kwrest
                    {
                      result = [ *val[0], *val[2] ]
                    }
                | p_kwarg
                    {
                      result = val[0]
                    }
                | p_kwarg tCOMMA
                    {
                      result = val[0]
                    }
                | p_any_kwrest
                    {
                      result = val[0]
                    }

         p_kwarg: p_kw
                    {
                      result = [ val[0] ]
                    }
                | p_kwarg tCOMMA p_kw
                    {
                      result = [ *val[0], val[2] ]
                    }

            p_kw: p_kw_label p_expr
                    {
                      result = @builder.match_pair(*val[0], val[1])
                    }
                | p_kw_label
                    {
                      result = @builder.match_label(*val[0])
                    }

      p_kw_label: tLABEL
                  {
                    check_kwarg_name(val[0])
                    result = [:label, val[0]]
                  }
                | tSTRING_BEG string_contents tLABEL_END
                  {
                    result = [:quoted, [val[0], val[1], val[2]]]
                  }

        p_kwrest: kwrest_mark tIDENTIFIER
                    {
                      result = [ @builder.match_rest(val[0], val[1]) ]
                    }
                | kwrest_mark
                    {
                      result = [ @builder.match_rest(val[0], nil) ]
                    }

      p_kwnorest: kwrest_mark kNIL
                    {
                      result = [ @builder.match_nil_pattern(val[0], val[1]) ]
                    }

    p_any_kwrest: p_kwrest
                | p_kwnorest

         p_value: p_primitive
                | p_primitive tDOT2 p_primitive
                    {
                      result = @builder.range_inclusive(val[0], val[1], val[2])
                    }
                | p_primitive tDOT3 p_primitive
                    {
                      result = @builder.range_exclusive(val[0], val[1], val[2])
                    }
                | p_primitive tDOT2
                    {
                      result = @builder.range_inclusive(val[0], val[1], nil)
                    }
                | p_primitive tDOT3
                    {
                      result = @builder.range_exclusive(val[0], val[1], nil)
                    }
                | p_variable
                | p_var_ref
                | p_const
                | tBDOT2 p_primitive
                    {
                      result = @builder.range_inclusive(nil, val[0], val[1])
                    }
                | tBDOT3 p_primitive
                    {
                      result = @builder.range_exclusive(nil, val[0], val[1])
                    }

     p_primitive: literal
                | strings
                | xstring
                | regexp
                | words
                | qwords
                | symbols
                | qsymbols
                | keyword_variable
                    {
                      result = @builder.accessible(val[0])
                    }
                | lambda

      p_variable: tIDENTIFIER
                    {
                      result = @builder.match_var(val[0])
                    }

       p_var_ref: tCARET tIDENTIFIER
                    {
                      name = val[1][0]
                      unless static_env.declared?(name)
                        diagnostic :error, :undefined_lvar, { :name => name }, val[1]
                      end

                      lvar = @builder.accessible(@builder.ident(val[1]))
                      result = @builder.pin(val[0], lvar)
                    }

         p_const: tCOLON3 cname
                    {
                      result = @builder.const_global(val[0], val[1])
                    }
                | p_const tCOLON2 cname
                    {
                      result = @builder.const_fetch(val[0], val[1], val[2])
                    }
                | tCONSTANT
                   {
                      result = @builder.const(val[0])
                   }

      opt_rescue: kRESCUE exc_list exc_var then compstmt opt_rescue
                    {
                      assoc_t, exc_var = val[2]

                      if val[1]
                        exc_list = @builder.array(nil, val[1], nil)
                      end

                      result = [ @builder.rescue_body(val[0],
                                      exc_list, assoc_t, exc_var,
                                      val[3], val[4]),
                                 *val[5] ]
                    }
                |
                    {
                      result = []
                    }

        exc_list: arg_value
                    {
                      result = [ val[0] ]
                    }
                | mrhs
                | none

         exc_var: tASSOC lhs
                    {
                      result = [ val[0], val[1] ]
                    }
                | none

      opt_ensure: kENSURE compstmt
                    {
                      result = [ val[0], val[1] ]
                    }
                | none

         literal: numeric
                | symbol

         strings: string
                    {
                      result = @builder.string_compose(nil, val[0], nil)
                    }

          string: string1
                    {
                      result = [ val[0] ]
                    }
                | string string1
                    {
                      result = val[0] << val[1]
                    }

         string1: tSTRING_BEG string_contents tSTRING_END
                    {
                      string = @builder.string_compose(val[0], val[1], val[2])
                      result = @builder.dedent_string(string, @lexer.dedent_level)
                    }
                | tSTRING
                    {
                      string = @builder.string(val[0])
                      result = @builder.dedent_string(string, @lexer.dedent_level)
                    }
                | tCHARACTER
                    {
                      result = @builder.character(val[0])
                    }

         xstring: tXSTRING_BEG xstring_contents tSTRING_END
                    {
                      string = @builder.xstring_compose(val[0], val[1], val[2])
                      result = @builder.dedent_string(string, @lexer.dedent_level)
                    }

          regexp: tREGEXP_BEG regexp_contents tSTRING_END tREGEXP_OPT
                    {
                      opts   = @builder.regexp_options(val[3])
                      result = @builder.regexp_compose(val[0], val[1], val[2], opts)
                    }

           words: tWORDS_BEG word_list tSTRING_END
                    {
                      result = @builder.words_compose(val[0], val[1], val[2])
                    }

       word_list: # nothing
                    {
                      result = []
                    }
                | word_list word tSPACE
                    {
                      result = val[0] << @builder.word(val[1])
                    }

            word: string_content
                    {
                      result = [ val[0] ]
                    }
                | word string_content
                    {
                      result = val[0] << val[1]
                    }

         symbols: tSYMBOLS_BEG symbol_list tSTRING_END
                    {
                      result = @builder.symbols_compose(val[0], val[1], val[2])
                    }

     symbol_list: # nothing
                    {
                      result = []
                    }
                | symbol_list word tSPACE
                    {
                      result = val[0] << @builder.word(val[1])
                    }

          qwords: tQWORDS_BEG qword_list tSTRING_END
                    {
                      result = @builder.words_compose(val[0], val[1], val[2])
                    }

        qsymbols: tQSYMBOLS_BEG qsym_list tSTRING_END
                    {
                      result = @builder.symbols_compose(val[0], val[1], val[2])
                    }

      qword_list: # nothing
                    {
                      result = []
                    }
                | qword_list tSTRING_CONTENT tSPACE
                    {
                      result = val[0] << @builder.string_internal(val[1])
                    }

       qsym_list: # nothing
                    {
                      result = []
                    }
                | qsym_list tSTRING_CONTENT tSPACE
                    {
                      result = val[0] << @builder.symbol_internal(val[1])
                    }

 string_contents: # nothing
                    {
                      result = []
                    }
                | string_contents string_content
                    {
                      result = val[0] << val[1]
                    }

xstring_contents: # nothing
                    {
                      result = []
                    }
                | xstring_contents string_content
                    {
                      result = val[0] << val[1]
                    }

regexp_contents: # nothing
                    {
                      result = []
                    }
                | regexp_contents string_content
                    {
                      result = val[0] << val[1]
                    }

  string_content: tSTRING_CONTENT
                    {
                      result = @builder.string_internal(val[0])
                    }
                | tSTRING_DVAR string_dvar
                    {
                      result = val[1]
                    }
                | tSTRING_DBEG
                    {
                      @lexer.cmdarg.push(false)
                      @lexer.cond.push(false)
                    }
                    compstmt tSTRING_DEND
                    {
                      @lexer.cmdarg.pop
                      @lexer.cond.pop

                      result = @builder.begin(val[0], val[2], val[3])
                    }

     string_dvar: tGVAR
                    {
                      result = @builder.gvar(val[0])
                    }
                | tIVAR
                    {
                      result = @builder.ivar(val[0])
                    }
                | tCVAR
                    {
                      result = @builder.cvar(val[0])
                    }
                | backref

          symbol: ssym
                | dsym

            ssym: tSYMBOL
                    {
                      @lexer.state = :expr_end
                      result = @builder.symbol(val[0])
                    }

            dsym: tSYMBEG string_contents tSTRING_END
                    {
                      @lexer.state = :expr_end
                      result = @builder.symbol_compose(val[0], val[1], val[2])
                    }

         numeric: simple_numeric
                    {
                      result = val[0]
                    }
                | tUNARY_NUM simple_numeric =tLOWEST
                    {
                      if @builder.respond_to? :negate
                        # AST builder interface compatibility
                        result = @builder.negate(val[0], val[1])
                      else
                        result = @builder.unary_num(val[0], val[1])
                      end
                    }

  simple_numeric: tINTEGER
                    {
                      @lexer.state = :expr_end
                      result = @builder.integer(val[0])
                    }
                | tFLOAT
                    {
                      @lexer.state = :expr_end
                      result = @builder.float(val[0])
                    }
                | tRATIONAL
                    {
                      @lexer.state = :expr_end
                      result = @builder.rational(val[0])
                    }
                | tIMAGINARY
                    {
                      @lexer.state = :expr_end
                      result = @builder.complex(val[0])
                    }

   user_variable: tIDENTIFIER
                    {
                      result = @builder.ident(val[0])
                    }
                | tIVAR
                    {
                      result = @builder.ivar(val[0])
                    }
                | tGVAR
                    {
                      result = @builder.gvar(val[0])
                    }
                | tCONSTANT
                    {
                      result = @builder.const(val[0])
                    }
                | tCVAR
                    {
                      result = @builder.cvar(val[0])
                    }

keyword_variable: kNIL
                    {
                      result = @builder.nil(val[0])
                    }
                | kSELF
                    {
                      result = @builder.self(val[0])
                    }
                | kTRUE
                    {
                      result = @builder.true(val[0])
                    }
                | kFALSE
                    {
                      result = @builder.false(val[0])
                    }
                | k__FILE__
                    {
                      result = @builder.__FILE__(val[0])
                    }
                | k__LINE__
                    {
                      result = @builder.__LINE__(val[0])
                    }
                | k__ENCODING__
                    {
                      result = @builder.__ENCODING__(val[0])
                    }

         var_ref: user_variable
                    {
                      if (node = val[0]) && node.type == :ident
                        name = node.children[0]

                        if name =~ /\A_[1-9]\z/ && !static_env.declared?(name) && context.in_dynamic_block?
                          # definitely an implicit param
                          location = node.loc.expression

                          if max_numparam_stack.has_ordinary_params?
                            diagnostic :error, :ordinary_param_defined, nil, [nil, location]
                          end

                          raw_context = context.stack.dup
                          raw_max_numparam_stack = max_numparam_stack.stack.dup

                          # ignore current block scope
                          raw_context.pop
                          raw_max_numparam_stack.pop

                          raw_context.reverse_each do |outer_scope|
                            if outer_scope == :block || outer_scope == :lambda
                              outer_scope_has_numparams = raw_max_numparam_stack.pop > 0

                              if outer_scope_has_numparams
                                diagnostic :error, :numparam_used_in_outer_scope, nil, [nil, location]
                              else
                                # for now it's ok, but an outer scope can also be a block
                                # with numparams, so we need to continue
                              end
                            else
                              # found an outer scope that can't have numparams
                              # like def/class/etc
                              break
                            end
                          end

                          static_env.declare(name)
                          max_numparam_stack.register(name[1].to_i)
                        end
                      end

                      result = @builder.accessible(val[0])
                    }
                | keyword_variable
                    {
                      result = @builder.accessible(val[0])
                    }

         var_lhs: user_variable
                    {
                      result = @builder.assignable(val[0])
                    }
                | keyword_variable
                    {
                      result = @builder.assignable(val[0])
                    }

         backref: tNTH_REF
                    {
                      result = @builder.nth_ref(val[0])
                    }
                | tBACK_REF
                    {
                      result = @builder.back_ref(val[0])
                    }

      superclass: tLT
                    {
                      @lexer.state = :expr_value
                    }
                    expr_value term
                    {
                      result = [ val[0], val[2] ]
                    }
                | # nothing
                    {
                      result = nil
                    }

   f_paren_args: tLPAREN2 f_args rparen
                    {
                      result = @builder.args(val[0], val[1], val[2])

                      @lexer.state = :expr_value
                    }
                | tLPAREN2 f_arg tCOMMA args_forward rparen
                    {
                      args = [ *val[1], @builder.forward_arg(val[3]) ]
                      result = @builder.args(val[0], args, val[4])

                      @static_env.declare_forward_args
                    }
                | tLPAREN2 args_forward rparen
                    {
                      result = @builder.forward_only_args(val[0], val[1], val[2])
                      @static_env.declare_forward_args

                      @lexer.state = :expr_value
                    }

       f_arglist: f_paren_args
                |   {
                      result = @lexer.in_kwarg
                      @lexer.in_kwarg = true
                    }
                  f_args term
                    {
                      @lexer.in_kwarg = val[0]
                      result = @builder.args(nil, val[1], nil)
                    }

       args_tail: f_kwarg tCOMMA f_kwrest opt_f_block_arg
                    {
                      result = val[0].concat(val[2]).concat(val[3])
                    }
                | f_kwarg opt_f_block_arg
                    {
                      result = val[0].concat(val[1])
                    }
                | f_any_kwrest opt_f_block_arg
                    {
                      result = val[0].concat(val[1])
                    }
                | f_block_arg
                    {
                      result = [ val[0] ]
                    }

   opt_args_tail: tCOMMA args_tail
                    {
                      result = val[1]
                    }
                | # nothing
                    {
                      result = []
                    }

          f_args: f_arg tCOMMA f_optarg tCOMMA f_rest_arg              opt_args_tail
                    {
                      result = val[0].
                                  concat(val[2]).
                                  concat(val[4]).
                                  concat(val[5])
                    }
                | f_arg tCOMMA f_optarg tCOMMA f_rest_arg tCOMMA f_arg opt_args_tail
                    {
                      result = val[0].
                                  concat(val[2]).
                                  concat(val[4]).
                                  concat(val[6]).
                                  concat(val[7])
                    }
                | f_arg tCOMMA f_optarg                                opt_args_tail
                    {
                      result = val[0].
                                  concat(val[2]).
                                  concat(val[3])
                    }
                | f_arg tCOMMA f_optarg tCOMMA                   f_arg opt_args_tail
                    {
                      result = val[0].
                                  concat(val[2]).
                                  concat(val[4]).
                                  concat(val[5])
                    }
                | f_arg tCOMMA                 f_rest_arg              opt_args_tail
                    {
                      result = val[0].
                                  concat(val[2]).
                                  concat(val[3])
                    }
                | f_arg tCOMMA                 f_rest_arg tCOMMA f_arg opt_args_tail
                    {
                      result = val[0].
                                  concat(val[2]).
                                  concat(val[4]).
                                  concat(val[5])
                    }
                | f_arg                                                opt_args_tail
                    {
                      result = val[0].
                                  concat(val[1])
                    }
                |              f_optarg tCOMMA f_rest_arg              opt_args_tail
                    {
                      result = val[0].
                                  concat(val[2]).
                                  concat(val[3])
                    }
                |              f_optarg tCOMMA f_rest_arg tCOMMA f_arg opt_args_tail
                    {
                      result = val[0].
                                  concat(val[2]).
                                  concat(val[4]).
                                  concat(val[5])
                    }
                |              f_optarg                                opt_args_tail
                    {
                      result = val[0].
                                  concat(val[1])
                    }
                |              f_optarg tCOMMA                   f_arg opt_args_tail
                    {
                      result = val[0].
                                  concat(val[2]).
                                  concat(val[3])
                    }
                |                              f_rest_arg              opt_args_tail
                    {
                      result = val[0].
                                  concat(val[1])
                    }
                |                              f_rest_arg tCOMMA f_arg opt_args_tail
                    {
                      result = val[0].
                                  concat(val[2]).
                                  concat(val[3])
                    }
                |                                                          args_tail
                    {
                      result = val[0]
                    }
                | # nothing
                    {
                      result = []
                    }

    args_forward: tBDOT3
                    {
                      result = val[0]
                    }

       f_bad_arg: tCONSTANT
                    {
                      diagnostic :error, :argument_const, nil, val[0]
                    }
                | tIVAR
                    {
                      diagnostic :error, :argument_ivar, nil, val[0]
                    }
                | tGVAR
                    {
                      diagnostic :error, :argument_gvar, nil, val[0]
                    }
                | tCVAR
                    {
                      diagnostic :error, :argument_cvar, nil, val[0]
                    }

      f_norm_arg: f_bad_arg
                | tIDENTIFIER
                    {
                      @static_env.declare val[0][0]

                      @max_numparam_stack.has_ordinary_params!

                      result = val[0]
                    }

      f_arg_asgn: f_norm_arg
                    {
                      @current_arg_stack.set(val[0][0])
                      result = val[0]
                    }

      f_arg_item: f_arg_asgn
                    {
                      @current_arg_stack.set(0)
                      result = @builder.arg(val[0])
                    }
                | tLPAREN f_margs rparen
                    {
                      result = @builder.multi_lhs(val[0], val[1], val[2])
                    }

           f_arg: f_arg_item
                    {
                      result = [ val[0] ]
                    }
                | f_arg tCOMMA f_arg_item
                    {
                      result = val[0] << val[2]
                    }

         f_label: tLABEL
                    {
                      check_kwarg_name(val[0])

                      @static_env.declare val[0][0]

                      @max_numparam_stack.has_ordinary_params!

                      @current_arg_stack.set(val[0][0])

                      result = val[0]
                    }

            f_kw: f_label arg_value
                    {
                      @current_arg_stack.set(nil)
                      result = @builder.kwoptarg(val[0], val[1])
                    }
                | f_label
                    {
                      @current_arg_stack.set(nil)
                      result = @builder.kwarg(val[0])
                    }

      f_block_kw: f_label primary_value
                    {
                      result = @builder.kwoptarg(val[0], val[1])
                    }
                | f_label
                    {
                      result = @builder.kwarg(val[0])
                    }

   f_block_kwarg: f_block_kw
                    {
                      result = [ val[0] ]
                    }
                | f_block_kwarg tCOMMA f_block_kw
                    {
                      result = val[0] << val[2]
                    }

         f_kwarg: f_kw
                    {
                      result = [ val[0] ]
                    }
                | f_kwarg tCOMMA f_kw
                    {
                      result = val[0] << val[2]
                    }

     kwrest_mark: tPOW | tDSTAR

      f_no_kwarg: kwrest_mark kNIL
                    {
                      result = [ @builder.kwnilarg(val[0], val[1]) ]
                    }

        f_kwrest: kwrest_mark tIDENTIFIER
                    {
                      @static_env.declare val[1][0]

                      result = [ @builder.kwrestarg(val[0], val[1]) ]
                    }
                | kwrest_mark
                    {
                      result = [ @builder.kwrestarg(val[0]) ]
                    }

           f_opt: f_arg_asgn tEQL arg_value
                    {
                      @current_arg_stack.set(0)
                      result = @builder.optarg(val[0], val[1], val[2])
                    }

     f_block_opt: f_arg_asgn tEQL primary_value
                    {
                      @current_arg_stack.set(0)
                      result = @builder.optarg(val[0], val[1], val[2])
                    }

  f_block_optarg: f_block_opt
                    {
                      result = [ val[0] ]
                    }
                | f_block_optarg tCOMMA f_block_opt
                    {
                      result = val[0] << val[2]
                    }

        f_optarg: f_opt
                    {
                      result = [ val[0] ]
                    }
                | f_optarg tCOMMA f_opt
                    {
                      result = val[0] << val[2]
                    }

    restarg_mark: tSTAR2 | tSTAR

      f_rest_arg: restarg_mark tIDENTIFIER
                    {
                      @static_env.declare val[1][0]

                      result = [ @builder.restarg(val[0], val[1]) ]
                    }
                | restarg_mark
                    {
                      result = [ @builder.restarg(val[0]) ]
                    }

     blkarg_mark: tAMPER2 | tAMPER

     f_block_arg: blkarg_mark tIDENTIFIER
                    {
                      @static_env.declare val[1][0]

                      result = @builder.blockarg(val[0], val[1])
                    }

 opt_f_block_arg: tCOMMA f_block_arg
                    {
                      result = [ val[1] ]
                    }
                |
                    {
                      result = []
                    }

       singleton: var_ref
                | tLPAREN2 expr rparen
                    {
                      result = val[1]
                    }

      assoc_list: # nothing
                    {
                      result = []
                    }
                | assocs trailer

          assocs: assoc
                    {
                      result = [ val[0] ]
                    }
                | assocs tCOMMA assoc
                    {
                      result = val[0] << val[2]
                    }

           assoc: arg_value tASSOC arg_value
                    {
                      result = @builder.pair(val[0], val[1], val[2])
                    }
                | tLABEL arg_value
                    {
                      result = @builder.pair_keyword(val[0], val[1])
                    }
                | tSTRING_BEG string_contents tLABEL_END arg_value
                    {
                      result = @builder.pair_quoted(val[0], val[1], val[2], val[3])
                    }
                | tDSTAR arg_value
                    {
                      result = @builder.kwsplat(val[0], val[1])
                    }

       operation: tIDENTIFIER | tCONSTANT | tFID
      operation2: tIDENTIFIER | tCONSTANT | tFID | op
      operation3: tIDENTIFIER | tFID | op
    dot_or_colon: call_op | tCOLON2
         call_op: tDOT
                    {
                      result = [:dot, val[0][1]]
                    }
                | tANDDOT
                    {
                      result = [:anddot, val[0][1]]
                    }
       opt_terms:  | terms
          opt_nl:  | tNL
          rparen: opt_nl tRPAREN
                    {
                      result = val[1]
                    }
        rbracket: opt_nl tRBRACK
                    {
                      result = val[1]
                    }
          rbrace: opt_nl tRCURLY
                    {
                      result = val[1]
                    }
         trailer:  | tNL | tCOMMA

            term: tSEMI
                  {
                    yyerrok
                  }
                | tNL

           terms: term
                | terms tSEMI

            none: # nothing
                  {
                    result = nil
                  }
end

---- header

require 'parser'

---- inner

  def version
    28
  end

  def default_encoding
    Encoding::UTF_8
  end
