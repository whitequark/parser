#include <ruby.h>
#include <ruby/encoding.h>

#include <stdint.h>
#include <stdio.h>

#include "stack.h"
#include "stack_state.h"
#include "lexer.h"

%%machine lex;
%%write data;

static VALUE lexer_alloc(VALUE klass)
{
  lexer_state *state = xmalloc(sizeof(lexer_state));

  state->cs = state->p = state->pe = 0;
  state->paren_nest = 0;

  state->cs_stack      = xmalloc(4 * sizeof(int));
  state->cs_stack_top  = 0;
  state->cs_stack_size = 4;

  state->source_buffer = Qnil;
  state->source        = Qnil;
  state->source_pts    = Qnil;
  state->token_queue   = Qnil;
  state->static_env    = Qnil;
  state->lambda_stack  = Qnil;
  state->diagnostics   = Qnil;
  state->tokens        = Qnil;
  state->comments      = Qnil;
  state->encoding      = Qnil;
  state->escape        = Qnil;

  ss_stack_init(&state->cond_stack);
  ss_stack_init(&state->cmdarg_stack);
  lit_stack_init(&state->literal_stack);

  return Data_Wrap_Struct(klass, lexer_mark, lexer_dealloc, state);
}

static void lexer_mark(void *ptr)
{
  lexer_state *state = ptr;
  rb_gc_mark(state->source_buffer);
  rb_gc_mark(state->source);
  rb_gc_mark(state->source_pts);
  rb_gc_mark(state->token_queue);
  rb_gc_mark(state->static_env);
  rb_gc_mark(state->lambda_stack);
  rb_gc_mark(state->diagnostics);
  rb_gc_mark(state->tokens);
  rb_gc_mark(state->comments);
  rb_gc_mark(state->encoding);
  rb_gc_mark(state->escape);

  for (literal *lit = state->literal_stack.bottom; lit < state->literal_stack.top; lit++) {
    rb_gc_mark(lit->buffer);
    rb_gc_mark(lit->start_tok);
    rb_gc_mark(lit->start_delim);
    rb_gc_mark(lit->end_delim);
    rb_gc_mark(lit->delimiter);
  }
}

static void lexer_dealloc(void *ptr)
{
  lexer_state *state = ptr;
  ss_stack_dealloc(&state->cond_stack);
  ss_stack_dealloc(&state->cmdarg_stack);
  lit_stack_dealloc(&state->literal_stack);
  xfree(ptr);
}

static VALUE lexer_init(VALUE self, VALUE version)
{
  lexer_state *state;
  Data_Get_Struct(self, lexer_state, state);

  state->version = NUM2INT(version);

  return lexer_reset(0, NULL, self);
}

static VALUE lexer_reset(int argc, VALUE *argv, VALUE self)
{
  lexer_state *state;
  Data_Get_Struct(self, lexer_state, state);

  VALUE reset_state;
  rb_scan_args(argc, argv, "01", &reset_state);
  if (NIL_P(reset_state))
    reset_state = Qtrue;

  if (RTEST(reset_state)) {
    state->cs = lex_en_line_begin;
    ss_stack_clear(&state->cond_stack);
    ss_stack_clear(&state->cmdarg_stack);
    lit_stack_clear(&state->literal_stack);
    state->cond   = 0;
    state->cmdarg = 0;
  }

  state->force_utf32 = 0;

  state->source       = Qnil;
  state->source_pts   = Qnil;
  state->encoding     = Qnil;
  state->escape       = Qnil;

  state->p            = 0;

  state->token_queue  = rb_ary_new();
  state->lambda_stack = rb_ary_new();

  state->paren_nest   = 0;
  state->in_kwarg     = 0;

  state->newline_s    = 0;
  state->eq_begin_s   = 0;
  state->herebody_s   = 0;
  state->escape_s     = 0;

  state->dedent_level = -1;

  return self;
}

static VALUE lexer_set_source_buffer(VALUE self, VALUE buffer)
{
  lexer_state *state;
  Data_Get_Struct(self, lexer_state, state);

  state->source_buffer = buffer;

  if (RTEST(buffer)) {
    state->source = rb_funcall(buffer, rb_intern("source"), 0);
    state->encoding = rb_funcall(state->source, rb_intern("encoding"), 0);

    if (state->encoding == utf8_encoding) {
      state->source_pts = rb_funcall(state->source, rb_intern("unpack"), 1, rb_str_new2("U*"));
    } else {
      state->source_pts = rb_funcall(state->source, rb_intern("unpack"), 1, rb_str_new2("C*"));
    }

    state->pe = RARRAY_LEN(state->source_pts) + 2; /* pretend there is a null at the end */

    VALUE source_pt = rb_ary_entry(state->source_pts, 0);
    if (source_pt != Qnil && NUM2INT(source_pt) == 0xfeff) {
      state->p = 1;
    }
  } else {
    state->source = Qnil;
    state->source_pts = Qnil;
    state->encoding = Qnil;
    state->pe = 0;
  }

  return self;
}

static VALUE lexer_advance(VALUE self)
{
  int p, pe, eof, cs, ts = 0, te = 0, tm = 0, act = 0, top, command_state;
  int num_digits_s = 0, num_suffix_s = 0, num_base = 0, sharp_s = 0, heredoc_e = 0;
  void (*num_xfrm)(lexer_state*, VALUE, int, int); /* numeric suffix-induced transformation */
  lexer_state *state;
  int *stack;
  Data_Get_Struct(self, lexer_state, state);

  if (RARRAY_LEN(state->token_queue) > 0)
    return rb_ary_shift(state->token_queue);

  cs = state->cs;
  p = state->p;
  pe = eof = state->pe;
  stack = state->cs_stack;
  top = state->cs_stack_top;

  command_state = (cs == lex_en_expr_value || cs == lex_en_line_begin);

  %%{
    write exec;
  }%%

  state->p = p;
  state->cs = cs;
  state->cs_stack_top = top;

  if (RARRAY_LEN(state->token_queue) > 0) {
    return rb_ary_shift(state->token_queue);
  } else if (cs == lex_error) {
    VALUE token = rb_ary_new2(2);
    VALUE info  = rb_ary_new2(2);
    rb_ary_store(token, 0, Qfalse);
    rb_ary_store(token, 1, info);
    rb_ary_store(info,  0, rb_str_new2("$error"));
    rb_ary_store(info,  1, range(state, p - 1, p));
    return token;
  } else {
    VALUE token = rb_ary_new2(2);
    VALUE info  = rb_ary_new2(2);
    rb_ary_store(token, 0, Qfalse);
    rb_ary_store(token, 1, info);
    rb_ary_store(info,  0, rb_str_new2("$eof"));
    rb_ary_store(info,  1, range(state, eof, eof));
    return token;
  }
}

static VALUE lexer_push_cmdarg(VALUE self)
{
  lexer_state *state;
  Data_Get_Struct(self, lexer_state, state);

  ss_stack_push(&state->cmdarg_stack, state->cmdarg);
  state->cmdarg = 0;
  return Qnil;
}

static VALUE lexer_pop_cmdarg(VALUE self)
{
  lexer_state *state;
  Data_Get_Struct(self, lexer_state, state);

  state->cmdarg = ss_stack_pop(&state->cmdarg_stack);
  return Qnil;
}

static VALUE lexer_push_cond(VALUE self)
{
  lexer_state *state;
  Data_Get_Struct(self, lexer_state, state);

  ss_stack_push(&state->cond_stack, state->cond);
  state->cond = 0;
  return Qnil;
}

static VALUE lexer_pop_cond(VALUE self)
{
  lexer_state *state;
  Data_Get_Struct(self, lexer_state, state);

  state->cond = ss_stack_pop(&state->cond_stack);
  return Qnil;
}

static VALUE lexer_push_cmdarg_state(VALUE self, VALUE bit)
{
  lexer_state *state;
  Data_Get_Struct(self, lexer_state, state);

  int bitval;
  if (RTEST(bit))
    bitval = 1;
  else
    bitval = 0;

  stack_state_push(&state->cmdarg, bitval);
  return Qnil;
}

static VALUE lexer_pop_cmdarg_state(VALUE self)
{
  lexer_state *state;
  Data_Get_Struct(self, lexer_state, state);
  stack_state_pop(&state->cmdarg);
  return Qnil;
}

static VALUE lexer_lexpop_cmdarg_state(VALUE self)
{
  lexer_state *state;
  Data_Get_Struct(self, lexer_state, state);
  stack_state_lexpop(&state->cmdarg);
  return Qnil;
}

static VALUE lexer_push_cond_state(VALUE self, VALUE bit)
{
  lexer_state *state;
  Data_Get_Struct(self, lexer_state, state);

  int bitval;
  if (RTEST(bit))
    bitval = 1;
  else
    bitval = 0;

  stack_state_push(&state->cond, bitval);
  return Qnil;
}

static VALUE lexer_pop_cond_state(VALUE self)
{
  lexer_state *state;
  Data_Get_Struct(self, lexer_state, state);
  stack_state_pop(&state->cond);
  return Qnil;
}

static VALUE lexer_lexpop_cond_state(VALUE self)
{
  lexer_state *state;
  Data_Get_Struct(self, lexer_state, state);
  stack_state_lexpop(&state->cond);
  return Qnil;
}

static VALUE lexer_get_state(VALUE self)
{
  lexer_state *state;
  Data_Get_Struct(self, lexer_state, state);

  switch (state->cs) {
  case lex_en_line_begin:    return ID2SYM(rb_intern("line_begin"));
  case lex_en_expr_dot:      return ID2SYM(rb_intern("expr_dot"));
  case lex_en_expr_fname:    return ID2SYM(rb_intern("expr_fname"));
  case lex_en_expr_value:    return ID2SYM(rb_intern("expr_value"));
  case lex_en_expr_beg:      return ID2SYM(rb_intern("expr_beg"));
  case lex_en_expr_mid:      return ID2SYM(rb_intern("expr_mid"));
  case lex_en_expr_arg:      return ID2SYM(rb_intern("expr_arg"));
  case lex_en_expr_cmdarg:   return ID2SYM(rb_intern("expr_cmdarg"));
  case lex_en_expr_end:      return ID2SYM(rb_intern("expr_end"));
  case lex_en_expr_endarg:   return ID2SYM(rb_intern("expr_endarg"));
  case lex_en_expr_endfn:    return ID2SYM(rb_intern("expr_endfn"));
  case lex_en_expr_labelarg: return ID2SYM(rb_intern("expr_labelarg"));
  case lex_en_interp_string: return ID2SYM(rb_intern("interp_string"));
  case lex_en_interp_words:  return ID2SYM(rb_intern("interp_words"));
  case lex_en_plain_string:  return ID2SYM(rb_intern("plain_string"));
  case lex_en_plain_words:   return ID2SYM(rb_intern("plain_words"));
  default:
    rb_raise(rb_eRuntimeError, "Lexer state variable is borked");
  }
}

static VALUE lexer_set_state(VALUE self, VALUE state_sym)
{
  lexer_state *state;
  Data_Get_Struct(self, lexer_state, state);
  const char *state_name = rb_id2name(SYM2ID(state_sym));

  if (strcmp(state_name, "line_begin") == 0)
    state->cs = lex_en_line_begin;
  else if (strcmp(state_name, "expr_dot") == 0)
    state->cs = lex_en_expr_dot;
  else if (strcmp(state_name, "expr_fname") == 0)
    state->cs = lex_en_expr_fname;
  else if (strcmp(state_name, "expr_value") == 0)
    state->cs = lex_en_expr_value;
  else if (strcmp(state_name, "expr_beg") == 0)
    state->cs = lex_en_expr_beg;
  else if (strcmp(state_name, "expr_mid") == 0)
    state->cs = lex_en_expr_mid;
  else if (strcmp(state_name, "expr_arg") == 0)
    state->cs = lex_en_expr_arg;
  else if (strcmp(state_name, "expr_cmdarg") == 0)
    state->cs = lex_en_expr_cmdarg;
  else if (strcmp(state_name, "expr_end") == 0)
    state->cs = lex_en_expr_end;
  else if (strcmp(state_name, "expr_endarg") == 0)
    state->cs = lex_en_expr_endarg;
  else if (strcmp(state_name, "expr_endfn") == 0)
    state->cs = lex_en_expr_endfn;
  else if (strcmp(state_name, "expr_labelarg") == 0)
    state->cs = lex_en_expr_labelarg;
  else if (strcmp(state_name, "interp_string") == 0)
    state->cs = lex_en_interp_string;
  else if (strcmp(state_name, "interp_words") == 0)
    state->cs = lex_en_interp_words;
  else if (strcmp(state_name, "plain_string") == 0)
    state->cs = lex_en_plain_string;
  else if (strcmp(state_name, "plain_words") == 0)
    state->cs = lex_en_plain_words;
  else
    rb_raise(rb_eArgError, "Invalid state: %s", state_name);

  return state_sym;
}

static VALUE lexer_get_in_kwarg(VALUE self)
{
  lexer_state *state;
  Data_Get_Struct(self, lexer_state, state);
  return state->in_kwarg ? Qtrue : Qfalse;
}

static VALUE lexer_set_in_kwarg(VALUE self, VALUE val)
{
  lexer_state *state;
  Data_Get_Struct(self, lexer_state, state);
  state->in_kwarg = RTEST(val) ? 1 : 0;
  return val;
}

static VALUE lexer_get_dedent_level(VALUE self)
{
  lexer_state *state;
  Data_Get_Struct(self, lexer_state, state);
  int result = state->dedent_level;
  state->dedent_level = -1;
  if (result == -1)
    return Qnil;
  else
    return INT2NUM(result);
}

static VALUE lexer_do_nothing(VALUE self, VALUE arg)
{
  return arg;
}

static void literal_init(literal *lit, lexer_state *lexer, VALUE str_type,
                         VALUE delimiter, int str_s, int heredoc_e, int indent,
                         int dedent_body, int label_allowed)
{
  lit->lexer = lexer;
  lit->nesting = 1;
  lit->str_type = literal_string_to_str_type(str_type);

  if (lit->str_type == INVALID) {
    VALUE hash = rb_hash_new();
    rb_hash_aset(hash, ID2SYM(rb_intern("type")), str_type);
    diagnostic(lexer, severity_error, unexpected_percent_str, hash,
               range(lexer, str_s, str_s + 2), empty_array);
  }

  literal_set_start_tok_and_interpolate(lit, lit->str_type);

  lit->str_s = str_s;

  lit->start_delim = literal_get_start_delim(delimiter);
  lit->end_delim   = literal_get_end_delim(delimiter);
  lit->delimiter   = delimiter;

  lit->herebody_s = 0;
  lit->heredoc_e = heredoc_e;
  lit->indent = indent;
  lit->label_allowed = label_allowed;
  lit->dedent_body = dedent_body;
  lit->dedent_level = -1;
  lit->interp_braces = 0;
  lit->space_emitted = 1;
  lit->monolithic = (lit->start_tok == tSTRING_BEG &&
                     (lit->str_type == SINGLE_QUOTE ||
                      lit->str_type == DOUBLE_QUOTE) &&
                     !heredoc_e);

  lit->buffer   = rb_str_new2("");
  rb_funcall(lit->buffer, rb_intern("force_encoding"), 1, lexer->encoding);

  lit->buffer_s = 0;
  lit->buffer_e = 0;

  if (!lit->monolithic) {
    literal_emit_start_tok(lit);
  }
}

static str_type literal_string_to_str_type(VALUE str)
{
  char *p = RSTRING_PTR(str);
  switch (*p) {
  case '%':
    switch (*++p) {
    case 'q':  return PERCENT_Q;
    case 'Q':  return BIG_PERCENT_Q;
    case '\0': return BARE_PERCENT;
    case 'w':  return PERCENT_W;
    case 'W':  return BIG_PERCENT_W;
    case 'i':  return PERCENT_I;
    case 'I':  return BIG_PERCENT_I;
    case 's':  return PERCENT_S;
    case 'r':  return PERCENT_R;
    case 'x':  return PERCENT_X;
    default:   return INVALID;
    }
    break;
  case '"':  return DOUBLE_QUOTE;
  case '\'': return SINGLE_QUOTE;
  case '/':  return SLASH;
  case ':':
    switch (*++p) {
    case '"':  return SYM_DOUBLE_QUOT;
    case '\'': return SYM_SINGLE_QUOT;
    default:   return INVALID;
    }
    break;
  case '`': return BACKTICK;
  case '<':
    if (*++p != '<')
      return INVALID;
    switch (*++p) {
    case '"':  return LSHFT_DOUBLE_QUOT;
    case '\'': return LSHFT_SINGLE_QUOT;
    case '`':  return LSHFT_BACKTICK;
    default:   return INVALID;
    }
  default: return INVALID;
  }
}

static VALUE literal_str_type_to_string(str_type stype)
{
  switch (stype) {
    case SINGLE_QUOTE:      return rb_str_new2("'");
    case DOUBLE_QUOTE:      return rb_str_new2("\"");
    case PERCENT_Q:         return rb_str_new2("%q");
    case BIG_PERCENT_Q:     return rb_str_new2("%Q");
    case LSHFT_SINGLE_QUOT: return rb_str_new2("<<'");
    case LSHFT_DOUBLE_QUOT: return rb_str_new2("<<\"");
    case BARE_PERCENT:      return rb_str_new2("%");
    case PERCENT_W:         return rb_str_new2("%w");
    case BIG_PERCENT_W:     return rb_str_new2("%W");
    case PERCENT_I:         return rb_str_new2("%i");
    case BIG_PERCENT_I:     return rb_str_new2("%I");
    case SYM_SINGLE_QUOT:   return rb_str_new2(":'");
    case SYM_DOUBLE_QUOT:   return rb_str_new2(":\"");
    case PERCENT_S:         return rb_str_new2("%s");
    case SLASH:             return rb_str_new2("/");
    case PERCENT_R:         return rb_str_new2("%r");
    case PERCENT_X:         return rb_str_new2("%x");
    case BACKTICK:          return rb_str_new2("`");
    case LSHFT_BACKTICK:    return rb_str_new2("<<`");
    default:                return Qnil;
  }
}

static void literal_set_start_tok_and_interpolate(literal *lit, str_type stype)
{
  switch(stype) {
  case SINGLE_QUOTE:
  case PERCENT_Q:
  case LSHFT_SINGLE_QUOT:
    lit->start_tok = tSTRING_BEG;
    lit->interpolate = 0;
    break;
  case DOUBLE_QUOTE:
  case BIG_PERCENT_Q:
  case BARE_PERCENT:
  case LSHFT_DOUBLE_QUOT:
    lit->start_tok = tSTRING_BEG;
    lit->interpolate = 1;
    break;
  case PERCENT_W:
    lit->start_tok = tQWORDS_BEG;
    lit->interpolate = 0;
    break;
  case BIG_PERCENT_W:
    lit->start_tok = tWORDS_BEG;
    lit->interpolate = 1;
    break;
  case PERCENT_I:
    lit->start_tok = tQSYMBOLS_BEG;
    lit->interpolate = 0;
    break;
  case BIG_PERCENT_I:
    lit->start_tok = tSYMBOLS_BEG;
    lit->interpolate = 1;
    break;
  case SYM_SINGLE_QUOT:
  case PERCENT_S:
    lit->start_tok = tSYMBEG;
    lit->interpolate = 0;
    break;
  case SYM_DOUBLE_QUOT:
    lit->start_tok = tSYMBEG;
    lit->interpolate = 1;
    break;
  case SLASH:
  case PERCENT_R:
    lit->start_tok = tREGEXP_BEG;
    lit->interpolate = 1;
    break;
  case PERCENT_X:
  case BACKTICK:
  case LSHFT_BACKTICK:
    lit->start_tok = tXSTRING_BEG;
    lit->interpolate = 1;
    break;
  default:
    lit->start_tok = Qnil;
    break;
  }
}

static VALUE literal_get_start_delim(VALUE str)
{
  VALUE end_delim = literal_get_end_delim(str);
  if (end_delim == str)
    return Qnil;
  else
    return str;
}

static VALUE literal_get_end_delim(VALUE str)
{
  char *p = RSTRING_PTR(str);

  switch (*p) {
  case '(': return rb_str_new2(")");
  case '[': return rb_str_new2("]");
  case '{': return rb_str_new2("}");
  case '<': return rb_str_new2(">");
  default:  return str;
  }
}

static int literal_munge_escape_p(literal *lit, VALUE character)
{
  char *p = RSTRING_PTR(character);

  if (literal_words_p(lit) && (*p == ' '  || *p == '\t' || *p == '\n' ||
                               *p == '\r' || *p == '\v' || *p == '\f')) {
    return 1;
  } else if (*p == '\\' ||
             rb_equal(character, lit->start_delim) ||
             rb_equal(character, lit->end_delim)) {
    return 1;
  } else {
    return 0;
  }
}

static int literal_nest_and_close(literal *lit, VALUE delimiter, int ts, int te,
                                  VALUE lookahead)
{
  if (lit->start_delim != Qnil && rb_equal(lit->start_delim, delimiter)) {
    lit->nesting += 1;
  } else if (lit->indent && rb_equal(lit->end_delim, rb_funcall(delimiter, rb_intern("lstrip"), 0))) {
    lit->nesting -= 1;
  } else if (!lit->indent && rb_equal(lit->end_delim, delimiter)) {
    lit->nesting -= 1;
  }

  if (lit->nesting == 0) {
    if (literal_words_p(lit)) {
      literal_extend_space(lit, ts, ts);
    }

    int quoted_label = 0;

    if (lookahead != Qnil) {
      char *p = RSTRING_PTR(lookahead);
      if (p[0] == ':' && p[1] != ':' && lit->label_allowed && lit->start_tok == tSTRING_BEG)
        quoted_label = 1;
    }

    if (quoted_label) {
      literal_flush_string(lit);
      emit_token(lit->lexer, tLABEL_END, lit->end_delim, ts, te + 1);
    } else if (lit->monolithic) {
      emit_token(lit->lexer, tSTRING, lit->buffer, lit->str_s, te);
    } else {
      if (!lit->heredoc_e) {
        literal_flush_string(lit);
      }
      emit_token(lit->lexer, tSTRING_END, lit->end_delim, ts, te);
    }
    return 1;
  } else {
    return 0;
  }
}

static void literal_emit_start_tok(literal *lit)
{
  VALUE str_type = literal_str_type_to_string(lit->str_type);

  if (*RSTRING_PTR(str_type) == '%')
    rb_str_concat(str_type, lit->delimiter);

  int str_e = lit->heredoc_e;
  if (str_e == 0)
    str_e = lit->str_s + NUM2INT(rb_str_length(str_type));

  emit_token(lit->lexer, lit->start_tok, str_type, lit->str_s, str_e);
}

static void literal_start_interp_brace(literal *lit)
{
  lit->interp_braces += 1;
}

static int literal_end_interp_brace_and_close(literal *lit)
{
  return --lit->interp_braces == 0;
}

static void literal_extend_string(literal *lit, VALUE str, int ts, int te)
{
  if (!lit->buffer_s)
    lit->buffer_s = ts;

  lit->buffer_e = te;
  rb_str_concat(lit->buffer, str);
}

static void literal_flush_string(literal *lit)
{
  if (lit->monolithic) {
    literal_emit_start_tok(lit);
    lit->monolithic = 0;
  }

  if (RSTRING_LEN(lit->buffer) > 0) {
    emit_token(lit->lexer, tSTRING_CONTENT, lit->buffer, lit->buffer_s, lit->buffer_e);
    lit->buffer = rb_str_new2("");
    lit->buffer_s = 0;
    lit->buffer_e = 0;
    lit->space_emitted = 0;
  }
}

static void literal_extend_content(literal *lit)
{
  lit->space_emitted = 0;
}

static void literal_extend_space(literal *lit, int ts, int te)
{
  literal_flush_string(lit);

  if (!lit->space_emitted) {
    emit_token(lit->lexer, tSPACE, Qnil, ts, te);
    lit->space_emitted = 1;
  }
}

static int literal_words_p(literal *lit)
{
  return lit->start_tok == tWORDS_BEG   || lit->start_tok == tQWORDS_BEG ||
         lit->start_tok == tSYMBOLS_BEG || lit->start_tok == tQSYMBOLS_BEG;
}

static void literal_infer_indent_level(literal *lit, VALUE line)
{
  if (!lit->dedent_body)
    return;

  char *p = RSTRING_PTR(line);
  int indent_level = 0;

  while (*p) {
    if (*p == ' ') {
      indent_level += 1;
    } else if (*p == '\t') {
      indent_level += (8 - (indent_level % 8));
    } else {
      if (lit->dedent_level == -1 || lit->dedent_level > indent_level)
        lit->dedent_level = indent_level;
      break;
    }
    p++;
  }
}

static void emit_token(lexer_state *state, VALUE type, VALUE val, int start, int end)
{
  VALUE token = rb_ary_new2(2);
  VALUE info  = rb_ary_new2(2);

  rb_ary_store(token, 0, type);
  rb_ary_store(token, 1, info);
  rb_ary_store(info,  0, val);
  rb_ary_store(info,  1, range(state, start, end));

  if (state->tokens != Qnil)
    rb_ary_push(state->tokens, token);

  rb_ary_push(state->token_queue, token);
}

static void emit_comment(lexer_state *state, int start, int end)
{
  VALUE rng = Qnil;

  if (state->tokens != Qnil) {
    VALUE token = rb_ary_new2(2);
    VALUE info  = rb_ary_new2(2);
    rb_ary_store(token, 0, tCOMMENT);
    rb_ary_store(token, 1, info);
    rb_ary_store(info,  0, tok(state, start, end));
    rng = range(state, start, end);
    rb_ary_store(info,  1, rng);
    rb_ary_push(state->tokens, token);
  }

  if (state->comments != Qnil) {
    if (rng == Qnil)
      rng = range(state, start, end);
    VALUE comment = rb_class_new_instance(1, &rng, comment_klass);
    rb_ary_push(state->comments, comment);
  }
}

static void emit_do(lexer_state *state, int do_block, int ts, int te)
{
  if (stack_state_active(&state->cond))
    emit(kDO_COND);
  else if (do_block || stack_state_active(&state->cmdarg))
    emit(kDO_BLOCK);
  else
    emit(kDO);
}

static VALUE tok(lexer_state *state, int start, int end)
{
  return rb_str_substr(state->source, start, end - start);
}

static VALUE range(lexer_state *state, int start, int end)
{
  VALUE args[3];
  args[0] = state->source_buffer;
  args[1] = INT2NUM(start);
  args[2] = INT2NUM(end);
  return rb_class_new_instance(3, args, range_klass);
}

static void diagnostic(lexer_state *state, VALUE type, VALUE reason,
                       VALUE arguments, VALUE loc, VALUE hilights)
{
  VALUE args[5];
  args[0] = type;
  args[1] = reason;
  args[2] = arguments;
  args[3] = loc;
  args[4] = hilights;
  VALUE diagnostic = rb_class_new_instance(5, args, diagnostic_klass);
  rb_funcall(state->diagnostics, rb_intern("process"), 1, diagnostic);
}

static int get_codepoint(lexer_state *state, int p)
{
  if (p >= RARRAY_LEN(state->source_pts))
    return 0;
  else
    return NUM2INT(rb_ary_entry(state->source_pts, p));
}

static int arg_or_cmdarg(int command_state)
{
  if (command_state) {
    return lex_en_expr_cmdarg;
  } else {
    return lex_en_expr_arg;
  }
}

static int is_nthref(VALUE str)
{
  char c;
  char *p = RSTRING_PTR(str);

  if (*p++ != '$') return 0;

  c = *p++;
  if (c < '1' || c > '9') return 0;

  while (c = *p++) {
    if (c < '0' || c > '9') return 0;
  }

  return 1;
}

static int is_backref(VALUE str)
{
  char c;
  char *p = RSTRING_PTR(str);

  if (*p++ != '$') return 0;

  c = *p++;
  if (c != '&' && c != '`' && c != '\'' && c != '+') return 0;

  return *p == '\0'; /* are we at end of string? */
}

static int is_capitalized(VALUE str)
{
  char *p = RSTRING_PTR(str);
  return *p >= 'A' && *p <= 'Z';
}

static int is_regexp_metachar(VALUE str)
{
  char c = *RSTRING_PTR(str);
  return c == '\\' || c == '$' || c == '(' || c == ')' || c == '*' ||
         c == '+'  || c == '.' || c == '<' || c == '>' || c == '?' ||
         c == '['  || c == ']' || c == '^' || c == '{' || c == '|' ||
         c == '}';
}

static int eof_codepoint(int codepoint)
{
  return codepoint == 0x04 || codepoint == 0x1a || codepoint == 0x00;
}

static VALUE find_unknown_options(VALUE str)
{
  char c, *p = RSTRING_PTR(str);
  VALUE result = Qnil;

  while (c = *p++) {
    if (c != 'i' && c != 'm' && c != 'x' && c != 'o' && c != 'u' && c != 'e' &&
        c != 's' && c != 'n') {
      if (result == Qnil) {
        result = rb_str_new(&c, 1);
      } else {
        rb_str_concat(result, rb_str_new(&c, 1));
      }
    }
  }

  return result;
}

static int bad_cvar_name(VALUE str)
{
  char *p = RSTRING_PTR(str);

  if (*p++ != '@') return 0;
  if (*p++ != '@') return 0;
  return *p >= '0' && *p <= '9';
}

static int bad_ivar_name(VALUE str)
{
  char *p = RSTRING_PTR(str);

  if (*p++ != '@') return 0;
  return *p >= '0' && *p <= '9';
}

static int find_8_or_9(VALUE str)
{
  int idx = 0;
  char *p = RSTRING_PTR(str);

  while (*p) {
    if (*p == '8' || *p == '9')
      return idx;
    idx++;
    p++;
  }

  return -1;
}

static void emit_int(lexer_state *state, VALUE val, int start, int end)
{
  emit_token(state, tINTEGER, val, start, end);
}

static void emit_rational(lexer_state *state, VALUE val, int start, int end)
{
  emit_token(state, tRATIONAL, rb_funcall(Qnil, rb_intern("Rational"), 1, val),
             start, end);
}

static void emit_complex(lexer_state *state, VALUE val, int start, int end)
{
  emit_token(state, tIMAGINARY, rb_funcall(Qnil, rb_intern("Complex"), 2, Qzero, val),
             start, end);
}

static void emit_complex_rational(lexer_state *state, VALUE val, int start, int end)
{
  VALUE rational = rb_funcall(Qnil, rb_intern("Rational"), 1, val);
  emit_token(state, tIMAGINARY, rb_funcall(Qnil, rb_intern("Complex"), 2, Qzero, rational),
             start, end);
}

static void emit_float(lexer_state *state, VALUE val, int start, int end)
{
  emit_token(state, tFLOAT, rb_funcall(Qnil, rb_intern("Float"), 1, val),
             start, end);
}

static void emit_complex_float(lexer_state *state, VALUE val, int start, int end)
{
  VALUE fval = rb_funcall(Qnil, rb_intern("Float"), 1, val);
  emit_token(state, tIMAGINARY, rb_funcall(Qnil, rb_intern("Complex"), 2, Qzero, fval),
             start, end);
}

static int push_literal(lexer_state *state, VALUE str_type, VALUE delimiter,
                        int str_s, int heredoc_e, int indent, int dedent_body,
                        int label_allowed)
{
  literal lit;
  literal_init(&lit, state, str_type, delimiter, str_s, heredoc_e, indent,
               dedent_body, label_allowed);
  lit_stack_push(&state->literal_stack, lit);

  if (literal_words_p(&lit)) {
    if (lit.interpolate) {
      return lex_en_interp_words;
    } else {
      return lex_en_plain_words;
    }
  } else if (*RSTRING_PTR(lit.end_delim) == '\\') {
    if (lit.interpolate) {
      return lex_en_interp_backslash_delimited;
    } else {
      return lex_en_plain_backslash_delimited;
    }
  } else {
    if (lit.interpolate) {
      return lex_en_interp_string;
    } else {
      return lex_en_plain_string;
    }
  }
}

static int pop_literal(lexer_state *state)
{
  literal old_literal = lit_stack_pop(&state->literal_stack);

  state->dedent_level = old_literal.dedent_level;

  if (old_literal.start_tok == tREGEXP_BEG) {
    return lex_en_regexp_modifiers;
  } else {
    return lex_en_expr_end;
  }
}

static VALUE array_last(VALUE array)
{
  long len = RARRAY_LEN(array);
  if (len == 0)
    return Qnil;
  else
    return rb_ary_entry(array, len - 1);
}

static VALUE unescape_char(char c)
{
  switch (c) {
  case 'a': return rb_str_new("\a", 1);
  case 'b': return rb_str_new("\b", 1);
  case 'e': return rb_str_new("\e", 1);
  case 'f': return rb_str_new("\f", 1);
  case 'n': return rb_str_new("\n", 1);
  case 'r': return rb_str_new("\r", 1);
  case 's': return rb_str_new(" ", 1);
  case 't': return rb_str_new("\t", 1);
  case 'v': return rb_str_new("\v", 1);
  default:  return rb_str_new(&c, 1);
  }
}

static VALUE escape_char(VALUE str)
{
  char c = *RSTRING_PTR(str);

  switch (c) {
  case '\f': return rb_str_new("\\f", 2);
  case '\n': return rb_str_new("\\n", 2);
  case '\r': return rb_str_new("\\r", 2);
  case ' ':  return rb_str_new("\\s", 2);
  case '\t': return rb_str_new("\\t", 2);
  case '\v': return rb_str_new("\\v", 2);
  default:   return Qnil;
  }
}

static void lex_unicode_points(lexer_state *state, int p)
{
  state->escape = rb_str_new2("");

  int codepoint_s = state->escape_s + 2;
  int codepoint_e = codepoint_s;

  while (1) {
    VALUE src_pt = rb_ary_entry(state->source_pts, ++codepoint_e);
    int c = 0;
    if (src_pt != Qnil)
      c = NUM2INT(src_pt);

    if (codepoint_e == p || c == ' ' || c == '\t') {
      /* extract and decode codepoint */
      VALUE codepoint_str = tok(state, codepoint_s, codepoint_e);

      int codepoint = NUM2INT(rb_funcall(codepoint_str, rb_intern("to_i"), 1, INT2NUM(16)));

      if (codepoint >= 0x110000) {
        diagnostic(state, severity_error, unicode_point_too_large, Qnil,
                   range(state, codepoint_s, codepoint_e - 1), empty_array);
        return;
      }

      rb_str_concat(state->escape, rb_enc_uint_chr(codepoint, rb_to_encoding(utf8_encoding)));

      /* look for the beginning of the next codepoint */
      codepoint_s = codepoint_e;
      while (1) {
        if (++codepoint_s >= p)
          return;
        c = NUM2INT(rb_ary_entry(state->source_pts, codepoint_s));
        if (c != ' ' && c != '\t')
          break;
      }
      codepoint_e = codepoint_s;
    }
  }
}

def_lexer_attribute(diagnostics);
def_lexer_attribute(static_env);
def_lexer_attribute(tokens);
def_lexer_attribute(comments);
def_lexer_attribute(encoding);

def_lexer_attr_reader(source_buffer);

void Init_lexer()
{
  init_symbol(k__ENCODING__);
  init_symbol(k__FILE__);
  init_symbol(k__LINE__);
  init_symbol(kALIAS);
  init_symbol(kAND);
  init_symbol(kBEGIN);
  init_symbol(klBEGIN);
  init_symbol(kBREAK);
  init_symbol(kCASE);
  init_symbol(kCLASS);
  init_symbol(kDEF);
  init_symbol(kDEFINED);
  init_symbol(kDO);
  init_symbol(kDO_BLOCK);
  init_symbol(kDO_COND);
  init_symbol(kDO_LAMBDA);
  init_symbol(kELSE);
  init_symbol(kELSIF);
  init_symbol(kEND);
  init_symbol(klEND);
  init_symbol(kENSURE);
  init_symbol(kFALSE);
  init_symbol(kFOR);
  init_symbol(kIF);
  init_symbol(kIF_MOD);
  init_symbol(kIN);
  init_symbol(kMODULE);
  init_symbol(kNEXT);
  init_symbol(kNIL);
  init_symbol(kNOT);
  init_symbol(kOR);
  init_symbol(kREDO);
  init_symbol(kRESCUE);
  init_symbol(kRESCUE_MOD);
  init_symbol(kRETRY);
  init_symbol(kRETURN);
  init_symbol(kSELF);
  init_symbol(kSUPER);
  init_symbol(kTHEN);
  init_symbol(kTRUE);
  init_symbol(kUNDEF);
  init_symbol(kUNLESS);
  init_symbol(kUNLESS_MOD);
  init_symbol(kUNTIL);
  init_symbol(kUNTIL_MOD);
  init_symbol(kWHEN);
  init_symbol(kWHILE);
  init_symbol(kWHILE_MOD);
  init_symbol(kYIELD);

  init_symbol(tAMPER);
  init_symbol(tAMPER2);
  init_symbol(tANDDOT);
  init_symbol(tANDOP);
  init_symbol(tAREF);
  init_symbol(tASET);
  init_symbol(tASSOC);
  init_symbol(tBACK_REF);
  init_symbol(tBACK_REF2);
  init_symbol(tBANG);
  init_symbol(tCARET);
  init_symbol(tCHARACTER);
  init_symbol(tCMP);
  init_symbol(tCOLON);
  init_symbol(tCOLON2);
  init_symbol(tCOLON3);
  init_symbol(tCOMMA);
  init_symbol(tCOMMENT);
  init_symbol(tCONSTANT);
  init_symbol(tCVAR);
  init_symbol(tDIVIDE);
  init_symbol(tDOT);
  init_symbol(tDOT2);
  init_symbol(tDOT3);
  init_symbol(tDSTAR);
  init_symbol(tEH);
  init_symbol(tEQ);
  init_symbol(tEQL);
  init_symbol(tEQQ);
  init_symbol(tFID);
  init_symbol(tFLOAT);
  init_symbol(tGEQ);
  init_symbol(tGT);
  init_symbol(tGVAR);
  init_symbol(tIDENTIFIER);
  init_symbol(tIMAGINARY);
  init_symbol(tINTEGER);
  init_symbol(tIVAR);
  init_symbol(tLABEL);
  init_symbol(tLABEL_END);
  init_symbol(tLAMBDA);
  init_symbol(tLAMBEG);
  init_symbol(tLBRACE);
  init_symbol(tLBRACE_ARG);
  init_symbol(tLBRACK);
  init_symbol(tLBRACK2);
  init_symbol(tLCURLY);
  init_symbol(tLEQ);
  init_symbol(tLPAREN);
  init_symbol(tLPAREN_ARG);
  init_symbol(tLPAREN2);
  init_symbol(tLSHFT);
  init_symbol(tLT);
  init_symbol(tMATCH);
  init_symbol(tMINUS);
  init_symbol(tNEQ);
  init_symbol(tNL);
  init_symbol(tNMATCH);
  init_symbol(tNTH_REF);
  init_symbol(tOP_ASGN);
  init_symbol(tOROP);
  init_symbol(tPERCENT);
  init_symbol(tPIPE);
  init_symbol(tPLUS);
  init_symbol(tPOW);
  init_symbol(tQWORDS_BEG);
  init_symbol(tQSYMBOLS_BEG);
  init_symbol(tRATIONAL);
  init_symbol(tRBRACK);
  init_symbol(tRCURLY);
  init_symbol(tREGEXP_BEG);
  init_symbol(tREGEXP_OPT);
  init_symbol(tRPAREN);
  init_symbol(tRSHFT);
  init_symbol(tSEMI);
  init_symbol(tSPACE);
  init_symbol(tSTAR);
  init_symbol(tSTAR2);
  init_symbol(tSTRING);
  init_symbol(tSTRING_BEG);
  init_symbol(tSTRING_CONTENT);
  init_symbol(tSTRING_DBEG);
  init_symbol(tSTRING_DEND);
  init_symbol(tSTRING_DVAR);
  init_symbol(tSTRING_END);
  init_symbol(tSYMBEG);
  init_symbol(tSYMBOL);
  init_symbol(tSYMBOLS_BEG);
  init_symbol(tTILDE);
  init_symbol(tUMINUS);
  init_symbol(tUMINUS_NUM);
  init_symbol(tUPLUS);
  init_symbol(tWORDS_BEG);
  init_symbol(tXSTRING_BEG);

  severity_error = ID2SYM(rb_intern("error"));
  rb_gc_register_address(&severity_error);
  init_symbol(fatal);
  init_symbol(warning);

  init_symbol(ambiguous_literal);
  init_symbol(ambiguous_prefix);
  init_symbol(bare_backslash);
  init_symbol(character);
  init_symbol(cvar_name);
  init_symbol(embedded_document);
  init_symbol(empty_numeric);
  init_symbol(escape_eof);
  init_symbol(incomplete_escape);
  init_symbol(invalid_escape);
  init_symbol(invalid_escape_use);
  init_symbol(invalid_hex_escape);
  init_symbol(invalid_octal);
  init_symbol(invalid_unicode_escape);
  init_symbol(ivar_name);
  init_symbol(no_dot_digit_literal);
  init_symbol(prefix);
  init_symbol(regexp_options);
  init_symbol(string_eof);
  init_symbol(trailing_in_number);
  init_symbol(unexpected);
  init_symbol(unexpected_percent_str);
  init_symbol(unicode_point_too_large);
  init_symbol(unterminated_unicode);

  VALUE m_Parser = rb_define_module("Parser");
  VALUE c_Lexer  = rb_define_class_under(m_Parser, "Lexer", rb_cObject);

  rb_define_alloc_func(c_Lexer, lexer_alloc);

  rb_define_method(c_Lexer, "initialize", lexer_init,    1);
  rb_define_method(c_Lexer, "advance",    lexer_advance, 0);
  rb_define_method(c_Lexer, "reset",      lexer_reset,   -1);

  rb_define_method(c_Lexer, "push_cmdarg", lexer_push_cmdarg, 0);
  rb_define_method(c_Lexer, "pop_cmdarg",  lexer_pop_cmdarg,  0);
  rb_define_method(c_Lexer, "push_cond",   lexer_push_cond,   0);
  rb_define_method(c_Lexer, "pop_cond",    lexer_pop_cond,    0);

  rb_define_method(c_Lexer, "push_cmdarg_state",   lexer_push_cmdarg_state, 1);
  rb_define_method(c_Lexer, "pop_cmdarg_state",    lexer_pop_cmdarg_state, 0);
  rb_define_method(c_Lexer, "lexpop_cmdarg_state", lexer_lexpop_cmdarg_state, 0);

  rb_define_method(c_Lexer, "push_cond_state",   lexer_push_cond_state, 1);
  rb_define_method(c_Lexer, "pop_cond_state",    lexer_pop_cond_state, 0);
  rb_define_method(c_Lexer, "lexpop_cond_state", lexer_lexpop_cond_state, 0);

  rb_define_method(c_Lexer, "state",          lexer_get_state,       0);
  rb_define_method(c_Lexer, "state=",         lexer_set_state,       1);
  rb_define_method(c_Lexer, "in_kwarg",       lexer_get_in_kwarg,    0);
  rb_define_method(c_Lexer, "in_kwarg=",      lexer_set_in_kwarg,    1);
  rb_define_method(c_Lexer, "diagnostics",    lexer_get_diagnostics, 0);
  rb_define_method(c_Lexer, "diagnostics=",   lexer_set_diagnostics, 1);
  rb_define_method(c_Lexer, "static_env",     lexer_get_static_env,  0);
  rb_define_method(c_Lexer, "static_env=",    lexer_set_static_env,  1);
  rb_define_method(c_Lexer, "tokens",         lexer_get_tokens,      0);
  rb_define_method(c_Lexer, "tokens=",        lexer_set_tokens,      1);
  rb_define_method(c_Lexer, "comments",       lexer_get_comments,    0);
  rb_define_method(c_Lexer, "comments=",      lexer_set_comments,    1);
  rb_define_method(c_Lexer, "encoding",       lexer_get_encoding,    0);
  rb_define_method(c_Lexer, "encoding=",      lexer_set_encoding,    1);
  rb_define_method(c_Lexer, "dedent_level",   lexer_get_dedent_level,  0);
  rb_define_method(c_Lexer, "source_buffer",  lexer_get_source_buffer, 0);
  rb_define_method(c_Lexer, "source_buffer=", lexer_set_source_buffer, 1);
  rb_define_method(c_Lexer, "force_utf32=",   lexer_do_nothing,        1);

  VALUE m_Source   = rb_const_get(m_Parser, rb_intern("Source"));
  comment_klass    = rb_const_get(m_Source, rb_intern("Comment"));
  diagnostic_klass = rb_const_get(m_Parser, rb_intern("Diagnostic"));
  range_klass      = rb_const_get(m_Source, rb_intern("Range"));

  empty_array = rb_obj_freeze(rb_ary_new2(0));
  rb_gc_register_address(&empty_array);
  blank_string = rb_obj_freeze(rb_str_new2(""));
  rb_gc_register_address(&blank_string);
  escaped_next_line = rb_obj_freeze(rb_str_new2("\\\n"));
  rb_gc_register_address(&escaped_next_line);

  if (rb_const_defined(rb_cObject, rb_intern("Encoding"))) {
    VALUE encoding = rb_const_get(rb_cObject, rb_intern("Encoding"));
    utf8_encoding  = rb_const_get(encoding, rb_intern("UTF_8"));
    rb_gc_register_address(&utf8_encoding);
  } else {
    utf8_encoding = Qnil;
  }

  VALUE regex_str = rb_str_new2("\\r.*$");
  cr_then_anything_to_eol = rb_class_new_instance(1, &regex_str, rb_cRegexp);
  rb_gc_register_address(&cr_then_anything_to_eol);
  regex_str = rb_str_new2("\\r+$");
  crs_to_eol = rb_class_new_instance(1, &regex_str, rb_cRegexp);
  rb_gc_register_address(&crs_to_eol);
}

%%{
  alphtype int;
  getkey (get_codepoint(state, p));

  prepush {
    /* grow the state stack as needed */
    if (state->cs_stack_top == state->cs_stack_size) {
      int *new_stack = xmalloc(state->cs_stack_size * 2 * sizeof(int));
      memcpy(new_stack, state->cs_stack, state->cs_stack_size * sizeof(int));
      xfree(state->cs_stack);
      stack = state->cs_stack = new_stack;
      state->cs_stack_size = state->cs_stack_size * 2;
    }
  }

  action do_nl { state->newline_s = p; }

  c_nl       = '\n' $ do_nl;
  c_space    = [ \t\r\f\v];
  c_space_nl = c_space | c_nl;

  c_eof      = 0x04 | 0x1a | 0 | zlen; # ^D, ^Z, \0, EOF
  c_eol      = c_nl | c_eof;
  c_any      = any - c_eof;

  c_nl_zlen  = c_nl | zlen;
  c_line     = any - c_nl_zlen;

  c_unicode  = c_any - 0x00..0x7f;
  c_upper    = [A-Z];
  c_lower    = [a-z_]  | c_unicode;
  c_alpha    = c_lower | c_upper;
  c_alnum    = c_alpha | [0-9];

  action do_eof { fhold; fbreak; }

  operator_fname      = '[]' | '[]=' | '`'  | '-@' | '+@' | '~@'  | '!@' ;
  operator_arithmetic = '&'  | '|'   | '&&' | '||' | '^'  | '+'   | '-'  |
                        '*'  | '/'   | '**' | '~'  | '<<' | '>>'  | '%'  ;
  operator_rest       = '=~' | '!~' | '==' | '!=' | '!'   | '===' |
                        '<'  | '<=' | '>'  | '>=' | '<=>' | '=>'  ;

  punctuation_begin   = '-'  | '+'  | '::' | '('  | '['  |
                        '*'  | '**' | '&'  ;
  punctuation_end     = ','  | '='  | '->' | '('  | '['  | ']'   |
                        '::' | '?'  | ':'  | '.'  | '..' | '...' ;

  keyword_modifier    = 'if'     | 'unless' | 'while'  | 'until' | 'rescue' ;
  keyword_with_arg    = 'yield'  | 'super'  | 'not'    | 'defined?' ;
  keyword_with_fname  = 'def'    | 'undef'  | 'alias'  ;
  keyword_with_value  = 'else'   | 'case'   | 'ensure' | 'module' | 'elsif' | 'then'  |
                        'for'    | 'in'     | 'do'     | 'when'   | 'begin' | 'class' |
                        'and'    | 'or'     ;
  keyword_with_mid    = 'rescue' | 'return' | 'break'  | 'next'   ;
  keyword_with_end    = 'end'    | 'self'   | 'true'   | 'false'  | 'retry'    |
                        'redo'   | 'nil'    | 'BEGIN'  | 'END'    | '__FILE__' |
                        '__LINE__' | '__ENCODING__';

  keyword             = keyword_with_value | keyword_with_mid |
                        keyword_with_end   | keyword_with_arg |
                        keyword_with_fname | keyword_modifier ;

  constant       = c_upper c_alnum*;
  bareword       = c_alpha c_alnum*;

  call_or_var    = c_lower c_alnum*;
  class_var      = '@@' bareword;
  instance_var   = '@' bareword;
  global_var     = '$'
      ( bareword | digit+
      | [`'+~*$&?!@/\\;,.=:<>"] # '
      | '-' c_alnum
      )
  ;

  class_var_v    = '@@' c_alnum+;
  instance_var_v = '@' c_alnum+;

  label          = bareword [?!]? ':';

  int_hex  = ( xdigit+ '_' )* xdigit* '_'? ;
  int_dec  = ( digit+ '_' )* digit* '_'? ;
  int_bin  = ( [01]+ '_' )* [01]* '_'? ;

  flo_int  = [1-9] [0-9]* ( '_' digit+ )* | '0';
  flo_frac = '.' ( digit+ '_' )* digit+;
  flo_pow  = [eE] [+\-]? ( digit+ '_' )* digit+;

  int_suffix =
    ''   % { num_xfrm = emit_int; }
  | 'r'  % { num_xfrm = emit_rational; }
  | 'i'  % { num_xfrm = emit_complex; }
  | 'ri' % { num_xfrm = emit_complex_rational; };

  flo_pow_suffix =
    ''   % { num_xfrm = emit_float; }
  | 'i'  % { num_xfrm = emit_complex_float; };

  flo_suffix =
    flo_pow_suffix
  | 'r'  % { num_xfrm = emit_rational; }
  | 'ri' % { num_xfrm = emit_complex_rational; };

  escaped_nl = "\\" c_nl;

  action unescape_char {
    char c = NUM2INT(rb_ary_entry(state->source_pts, p - 1));
    state->escape = unescape_char(c);
  }

  action invalid_complex_escape {
    diagnostic(state, fatal, invalid_escape, Qnil, range(state, ts, te),
               empty_array);
  }

  action slash_c_char {
    char c = *RSTRING_PTR(state->escape) & 0x9f;
    state->escape = rb_str_new(&c, 1);
    rb_funcall(state->escape, rb_intern("force_encoding"), 1, state->encoding);
  }

  action slash_m_char {
    char c = *RSTRING_PTR(state->escape) | 0x80;
    state->escape = rb_str_new(&c, 1);
    rb_funcall(state->escape, rb_intern("force_encoding"), 1, state->encoding);
  }

  maybe_escaped_char = (
        '\\' c_any      %unescape_char
    | ( c_any - [\\] )  % { state->escape = rb_str_substr(state->source, p - 1, 1); }
  );

  maybe_escaped_ctrl_char = (
        '\\' c_any      %unescape_char %slash_c_char
    |   '?'             % { state->escape = rb_str_new2("\x7f"); }
    | ( c_any - [\\?] ) % { state->escape = rb_str_substr(state->source, p - 1, 1); } %slash_c_char
  );

  escape = (
      [0-7]{1,3} % {
        VALUE token = tok(state, state->escape_s, p);
        char c = NUM2INT(rb_funcall(token, rb_intern("to_i"), 1, INT2NUM(8)));
        c = c % 0x100;
        state->escape = rb_str_new(&c, 1);
        rb_funcall(state->escape, rb_intern("force_encoding"), 1, state->encoding);
      }

    | 'x' xdigit{1,2} % {
        VALUE token = tok(state, state->escape_s + 1, p);
        char c = NUM2INT(rb_funcall(token, rb_intern("to_i"), 1, INT2NUM(16)));
        state->escape = rb_str_new(&c, 1);
        rb_funcall(state->escape, rb_intern("force_encoding"), 1, state->encoding);
      }

    | 'u' xdigit{4} % {
        VALUE token = tok(state, state->escape_s + 1, p);
        int i = NUM2INT(rb_funcall(token, rb_intern("to_i"), 1, INT2NUM(16)));
        state->escape = rb_enc_uint_chr(i, rb_to_encoding(utf8_encoding));
      }

    | 'x' ( c_any - xdigit )
      % {
        diagnostic(state, fatal, invalid_hex_escape, Qnil,
                   range(state, state->escape_s - 1, p + 2), empty_array);
      }

    | 'u' ( c_any{0,4}  -
            xdigit{4}   -
            ( '{' xdigit{1,3}
            | '{' xdigit [ \t}] any?
            | '{' xdigit{2} [ \t}]
            )
          )
      % {
        diagnostic(state, fatal, invalid_unicode_escape, Qnil,
                   range(state, state->escape_s - 1, p), empty_array);
      }

    | 'u{' ( xdigit{1,6} [ \t] )*
      ( xdigit{1,6} '}' % { lex_unicode_points(state, p); }
      | ( xdigit* ( c_any - xdigit - '}' )+ '}'
        | ( c_any - '}' )* c_eof
        | xdigit{7,}
        ) % {
          diagnostic(state, fatal, unterminated_unicode, Qnil,
                     range(state, p - 1, p), empty_array);
        }
      )

    | ( 'C-' | 'c' ) escaped_nl?
      maybe_escaped_ctrl_char

    | 'M-' escaped_nl?
      maybe_escaped_char
      %slash_m_char

    | ( ( 'C-'   | 'c' ) escaped_nl?   '\\M-'
      |   'M-\\'         escaped_nl? ( 'C-'   | 'c' ) ) escaped_nl?
      maybe_escaped_ctrl_char
      %slash_m_char

    | 'C' c_any %invalid_complex_escape
    | 'M' c_any %invalid_complex_escape
    | ( 'M-\\C' | 'C-\\M' ) c_any %invalid_complex_escape

    | ( c_any - [0-7xuCMc] ) %unescape_char

    | c_eof % {
        diagnostic(state, fatal, escape_eof, Qnil, range(state, p - 1, p),
                   empty_array);
      }
  );

  e_bs = '\\' % {
    state->escape_s = p;
    state->escape = Qnil;
  };

  e_heredoc_nl = c_nl % {
    if (state->herebody_s) {
      p = state->herebody_s;
      state->herebody_s = 0;
    }
  };

  action extend_string {
    VALUE string = tok(state, ts, te);
    VALUE lookahead = Qnil;

    if (state->version >= 22 && !stack_state_active(&state->cond)) {
      lookahead = tok(state, te, te + 2);
    }

    literal *current_literal = lit_stack_top(&state->literal_stack);

    if (!current_literal->heredoc_e &&
         literal_nest_and_close(current_literal, string, ts, te, lookahead)) {
      VALUE token = array_last(state->token_queue);
      if (rb_ary_entry(token, 0) == tLABEL_END) {
        p += 1;
        pop_literal(state);
        fnext expr_labelarg;
      } else {
        fnext *pop_literal(state);
      }

      fbreak;
    } else {
      literal_extend_string(current_literal, string, ts, te);
    }
  }

  action extend_string_escaped {
    literal *current_literal = lit_stack_top(&state->literal_stack);
    VALUE escaped_char = rb_str_substr(state->source, state->escape_s, 1);

    if (literal_munge_escape_p(current_literal, escaped_char)) {
      if (current_literal->start_tok == tREGEXP_BEG && is_regexp_metachar(escaped_char)) {
        literal_extend_string(current_literal, tok(state, ts, te), ts, te);
      } else {
        literal_extend_string(current_literal, escaped_char, ts, te);
      }
    } else if (current_literal->start_tok == tREGEXP_BEG) {
        VALUE token = tok(state, ts, te);
        rb_funcall(token, rb_intern("gsub!"), 2, escaped_next_line, blank_string);
        literal_extend_string(current_literal, token, ts, te);
    } else if (state->escape == Qnil) {
      literal_extend_string(current_literal, tok(state, ts, te), ts, te);
    } else {
      literal_extend_string(current_literal, state->escape, ts, te);
    }
  }

  action extend_string_eol {
    literal *current_literal = lit_stack_top(&state->literal_stack);
    int str_s = current_literal->str_s;

    if (te == pe) {
      diagnostic(state, fatal, string_eof, Qnil,
                 range(state, str_s, str_s + 1), empty_array);
    }

    if (current_literal->heredoc_e) {
      VALUE line = tok(state, state->herebody_s, ts);
      rb_funcall(line, rb_intern("gsub!"), 2, crs_to_eol, blank_string);

      if (state->version >= 18 && state->version <= 20) {
        rb_funcall(line, rb_intern("gsub!"), 2, cr_then_anything_to_eol, blank_string);
      }

      if (literal_nest_and_close(current_literal, line, state->herebody_s, ts, Qnil)) {
        state->herebody_s = te;
        p = current_literal->heredoc_e - 1;
        fnext *pop_literal(state); fbreak;
      } else {
        literal_infer_indent_level(current_literal, line);
        state->herebody_s = te;
      }
    } else {
      if (literal_nest_and_close(current_literal, tok(state, ts, te), ts, te, Qnil)) {
        fnext *pop_literal(state); fbreak;
      }

      if (state->herebody_s) {
        p = state->herebody_s - 1;
        state->herebody_s = 0;
      }
    }

    if (literal_words_p(current_literal) && !eof_codepoint(get_codepoint(state, p))) {
      literal_extend_space(current_literal, ts, te);
    } else {
      literal_extend_string(current_literal, tok(state, ts, te), ts, te);
      literal_flush_string(current_literal);
    }
  }

  action extend_string_space {
    literal *current_literal = lit_stack_top(&state->literal_stack);
    literal_extend_space(current_literal, ts, te);
  }

  interp_var = '#' ( global_var | class_var_v | instance_var_v );

  action extend_interp_var {
    literal *current_literal = lit_stack_top(&state->literal_stack);
    literal_flush_string(current_literal);
    literal_extend_content(current_literal);

    emit_token(state, tSTRING_DVAR, Qnil, ts, ts + 1);

    p = ts;
    fcall expr_variable;
  }

  interp_code = '#{';

  e_lbrace = '{' % {
    stack_state_push(&state->cond, 0);
    stack_state_push(&state->cmdarg, 0);

    literal *current_literal = lit_stack_top(&state->literal_stack);
    if (current_literal != NULL) {
      literal_start_interp_brace(current_literal);
    }
  };

  e_rbrace = '}' % {
    literal *current_literal = lit_stack_top(&state->literal_stack);
    if (current_literal != NULL) {
      if (literal_end_interp_brace_and_close(current_literal)) {
        if (state->version == 18 || state->version == 19) {
          emit_token(state, tRCURLY, rb_str_new2("}"), p - 1, p);
        } else {
          emit_token(state, tSTRING_DEND, rb_str_new2("}"), p - 1, p);
        }

        if (current_literal->herebody_s) {
          state->herebody_s = current_literal->herebody_s;
        }

        fhold; fret; fbreak;
      }
    }
  };

  action extend_interp_code {
    literal *current_literal = lit_stack_top(&state->literal_stack);
    literal_flush_string(current_literal);
    literal_extend_content(current_literal);

    emit_token(state, tSTRING_DBEG, rb_str_new2("#{"), ts, te);

    if (current_literal->heredoc_e) {
      current_literal->herebody_s = state->herebody_s;
      state->herebody_s = 0;
    }

    literal_start_interp_brace(current_literal);
    fcall expr_value;
  }

  interp_words := |*
      interp_code => extend_interp_code;
      interp_var  => extend_interp_var;
      e_bs escape => extend_string_escaped;
      c_space+    => extend_string_space;
      c_eol       => extend_string_eol;
      c_any       => extend_string;
  *|;

  interp_string := |*
      interp_code => extend_interp_code;
      interp_var  => extend_interp_var;
      e_bs escape => extend_string_escaped;
      c_eol       => extend_string_eol;
      c_any       => extend_string;
  *|;

  plain_words := |*
      e_bs c_any  => extend_string_escaped;
      c_space+    => extend_string_space;
      c_eol       => extend_string_eol;
      c_any       => extend_string;
  *|;

  plain_string := |*
      '\\' c_nl   => extend_string_eol;
      e_bs c_any  => extend_string_escaped;
      c_eol       => extend_string_eol;
      c_any       => extend_string;
  *|;

  interp_backslash_delimited := |*
      interp_code => extend_interp_code;
      interp_var  => extend_interp_var;
      c_eol       => extend_string_eol;
      c_any       => extend_string;
  *|;

  plain_backslash_delimited := |*
      c_eol       => extend_string_eol;
      c_any       => extend_string;
  *|;

  regexp_modifiers := |*
      [A-Za-z]+
      => {
        VALUE unknown_options = find_unknown_options(tok(state, ts, te));

        if (unknown_options != Qnil) {
          VALUE hash = rb_hash_new();
          rb_hash_aset(hash, ID2SYM(rb_intern("options")), unknown_options);
          diagnostic(state, severity_error, regexp_options, hash,
                     range(state, ts, te), empty_array);
        }

        emit(tREGEXP_OPT);
        fnext expr_end; fbreak;
      };

      any
      => {
        emit_token(state, tREGEXP_OPT, tok(state, ts, te - 1), ts, te - 1);
        fhold; fgoto expr_end;
      };
  *|;

  w_space =
      c_space+
    | '\\' e_heredoc_nl
    ;

  w_comment =
      '#'     %{ sharp_s = p - 1; }
      c_line* %{ emit_comment(state, sharp_s, p == pe ? p - 2 : p); }
    ;

  w_space_comment =
      w_space
    | w_comment
    ;

  w_newline =
      e_heredoc_nl;

  w_any =
      w_space
    | w_comment
    | w_newline
    ;

  ambiguous_fid_suffix =
    [?!]  %{ tm = p; }      |
    '!='  %{ tm = p - 2; }
  ;

  ambiguous_ident_suffix =
    ambiguous_fid_suffix    |
    '='   %{ tm = p; }      |
    '=='  %{ tm = p - 2; }  |
    '=~'  %{ tm = p - 2; }  |
    '=>'  %{ tm = p - 2; }  |
    '===' %{ tm = p - 3; }
  ;

  ambiguous_symbol_suffix =
    ambiguous_ident_suffix |
    '==>' %{ tm = p - 2; }
  ;

  ambiguous_const_suffix =
    '::'  %{ tm = p - 2; }
  ;

  e_lbrack = '[' % {
    stack_state_push(&state->cond, 0);
    stack_state_push(&state->cmdarg, 0);
  };

  e_lparen = '(' % {
    stack_state_push(&state->cond, 0);
    stack_state_push(&state->cmdarg, 0);
    state->paren_nest += 1;
  };

  e_rparen = ')' % {
    state->paren_nest -= 1;
  };

  action local_ident {
    VALUE str = tok(state, ts, te);
    emit(tIDENTIFIER);

    if (state->static_env != Qnil &&
        RTEST(rb_funcall(state->static_env, rb_intern("declared?"), 1, str))) {
      fnext expr_end; fbreak;
    } else {
      fnext *arg_or_cmdarg(command_state); fbreak;
    }
  }

  expr_beg := |*
      [+\-][0-9] => {
        fhold;
        if (get_codepoint(state, ts) == '-') {
          emit_token(state, tUMINUS_NUM, rb_str_new2("-"), ts, ts + 1);
          fnext expr_end; fbreak;
        }
      };

      '*' => { emit(tSTAR); fbreak; };

      '/' c_any => {
        VALUE delimiter = rb_str_substr(state->source, ts, 1);
        fhold; fgoto *push_literal(state, delimiter, delimiter, ts, 0, 0, 0, 0);
      };

      '%' ( any - [A-Za-z] ) => {
        VALUE type = rb_str_substr(state->source, ts, 1);
        VALUE delimiter = rb_str_substr(state->source, te - 1, 1);
        if (delimiter == Qnil)
          delimiter = blank_string;

        fgoto *push_literal(state, type, delimiter, ts, 0, 0, 0, 0);
      };

      '%' [A-Za-z]+ c_any => {
        VALUE type = rb_str_substr(state->source, ts, te - ts - 1);
        VALUE delimiter = rb_str_substr(state->source, te - 1, 1);
        if (delimiter == Qnil)
          delimiter = blank_string;

        fgoto *push_literal(state, type, delimiter, ts, 0, 0, 0, 0);
      };

      '%' c_eof => {
        diagnostic(state, fatal, string_eof, Qnil,
                   range(state, ts, ts + 1), empty_array);
      };

      '<<' [~\-]?
        ( '"' ( c_line - '"' )* '"'
        | "'" ( c_line - "'" )* "'"
        | "`" ( c_line - "`" )* "`"
        | bareword ) % { heredoc_e = p; }
        c_line* c_nl % { if (!state->herebody_s) state->herebody_s = p; } => {

        VALUE heredoc = tok(state, ts, heredoc_e);
        VALUE type;
        char *cp = RSTRING_PTR(heredoc);
        int indent = 0, dedent_body = 0, rng_s = ts, rng_e = heredoc_e;

        if (cp[2] == '-') {
          indent = 1;
          cp += 3;
          rng_s += 3;
        } else if (cp[2] == '~') {
          dedent_body = indent = 1;
          cp += 3;
          rng_s += 3;
        } else {
          cp += 2;
          rng_s += 2;
        }

        if (dedent_body && state->version >= 18 && state->version <= 22) {
          emit_token(state, tLSHFT, rb_str_new2("<<"), ts, ts + 2);
          p = ts + 1;
          fnext expr_beg; fbreak;
        } else {
          if (*cp == '"' || *cp == '\'' || *cp == '`') {
            char type_str[3];
            type_str[0] = '<';
            type_str[1] = '<';
            type_str[2] = *cp;

            cp += 1;
            rng_s += 1;
            rng_e -= 1;

            type = rb_str_new(type_str, 3);
          } else {
            type = rb_str_new2("<<\"");
          }

          VALUE delimiter = tok(state, rng_s, rng_e);

          fnext *push_literal(state, type, delimiter, ts, heredoc_e, indent,
                              dedent_body, 0);
          p = state->herebody_s - 1;
        }
      };

      ':' ['"] => { /* ' */
        VALUE type = tok(state, ts, te);
        VALUE delimiter = tok(state, te - 1, te);
        fgoto *push_literal(state, type, delimiter, ts, 0, 0, 0, 0);
      };

      ':' bareword ambiguous_symbol_suffix => {
        emit_token(state, tSYMBOL, tok(state, ts + 1, tm), ts, tm);
        p = tm - 1;
        fnext expr_end; fbreak;
      };

      ':' ( bareword | global_var | class_var | instance_var |
            operator_fname | operator_arithmetic | operator_rest ) => {
        emit_token(state, tSYMBOL, tok(state, ts + 1, te), ts, te);
        fnext expr_end; fbreak;
      };

      '?' ( e_bs ( escape - ( '\u{' (xdigit+ [ \t]+)+ xdigit+ '}' ))
          | (c_any - c_space_nl - e_bs) % { state->escape = Qnil; }
          ) => {
        VALUE value = state->escape;
        if (value == Qnil)
          value = tok(state, ts + 1, te);

        if (state->version == 18)
          emit_token(state, tINTEGER, rb_funcall(rb_str_substr(value, 0, 1), rb_intern("ord"), 0), ts, te);
        else
          emit_token(state, tCHARACTER, value, ts, te);

        fnext expr_end; fbreak;
      };

      '?' c_space_nl => {
        VALUE escape = escape_char(rb_str_subseq(state->source, ts + 1, 1));
        VALUE hash = rb_hash_new();
        rb_hash_aset(hash, ID2SYM(rb_intern("escape")), escape);
        diagnostic(state, warning, invalid_escape_use, hash,
                   range(state, ts, te), empty_array);

        p = ts - 1;
        fgoto expr_end;
      };

      '?' c_eof => {
        diagnostic(state, fatal, incomplete_escape, Qnil,
                   range(state, ts, ts + 1), empty_array);
      };

      '?' [A-Za-z_] bareword => { p = ts - 1; fgoto expr_end; };

      e_lbrace => {
        VALUE val = array_last(state->lambda_stack);
        if (val != Qnil && NUM2INT(val) == state->paren_nest) {
          rb_ary_pop(state->lambda_stack);
          emit(tLAMBEG);
        } else {
          emit(tLBRACE);
        }
        fbreak;
      };

      e_lbrack => {
        emit_token(state, tLBRACK, tok(state, ts, te), ts, te);
        fbreak;
      };

      e_lparen => {
        emit_token(state, tLPAREN, tok(state, ts, te), ts, te);
        fbreak;
      };

      '-'  => { emit(tUMINUS); fbreak; };
      '+'  => { emit(tUPLUS); fbreak; };
      '::' => { emit(tCOLON3); fbreak; };
      '**' => { emit(tDSTAR); fbreak; };
      '&'  => { emit(tAMPER); fbreak; };

      'rescue' %{ tm = p; } '=>'? => {
        emit_token(state, kRESCUE, tok(state, ts, tm), ts, tm);
        p = tm - 1;
        fnext expr_mid; fbreak;
      };

      'if'     => { emit(kIF);     fnext expr_value; fbreak; };
      'unless' => { emit(kUNLESS); fnext expr_value; fbreak; };
      'while'  => { emit(kWHILE);  fnext expr_value; fbreak; };
      'until'  => { emit(kUNTIL);  fnext expr_value; fbreak; };
      'rescue' => { emit(kRESCUE); fnext expr_value; fbreak; };

      label ( any - ':' )
      => {
        fhold;

        if (state->version == 18) {
          VALUE ident = tok(state, ts, te - 2);

          emit_token(state, is_capitalized(ident) ? tCONSTANT : tIDENTIFIER,
               ident, ts, te - 2);
          fhold;

          if (state->static_env != Qnil &&
              RTEST(rb_funcall(state->static_env, rb_intern("declared?"), 1, ident))) {
            fnext expr_end;
          } else {
            fnext *arg_or_cmdarg(command_state);
          }
        } else {
          emit_token(state, tLABEL, tok(state, ts, te - 2), ts, te - 1);
          fnext expr_labelarg;
        }

        fbreak;
      };

      bareword ambiguous_ident_suffix | keyword => { p = ts - 1; fgoto expr_end; };

      call_or_var => local_ident;

      w_any;

      e_heredoc_nl '=begin' ( c_space | c_nl_zlen ) => {
        p = ts - 1;
        fgoto line_begin;
      };

      operator_arithmetic '='    |
      operator_rest              |
      punctuation_end            |
      c_any
      => { p = ts - 1; fgoto expr_end; };

      c_eof => do_eof;
  *|;

  expr_end := |*
      '->' => {
        emit_token(state, tLAMBDA, tok(state, ts, ts + 2), ts, ts + 2);
        rb_ary_push(state->lambda_stack, INT2NUM(state->paren_nest));
        fnext expr_endfn; fbreak;
      };

      e_lbrace => {
        VALUE val = array_last(state->lambda_stack);
        if (val != Qnil && NUM2INT(val) == state->paren_nest) {
          rb_ary_pop(state->lambda_stack);
          emit(tLAMBEG);
        } else {
          emit(tLCURLY);
        }
        fnext expr_value; fbreak;
      };

      'do' => {
        VALUE val = array_last(state->lambda_stack);
        if (val != Qnil && NUM2INT(val) == state->paren_nest) {
          rb_ary_pop(state->lambda_stack);
          emit(kDO_LAMBDA);
        } else {
          emit_do(state, 0, ts, te);
        }
        fnext expr_value; fbreak;
      };

      'def'   => { emit(kDEF);   fnext expr_fname; fbreak; };
      'undef' => { emit(kUNDEF); fnext expr_fname; fbreak; };
      'alias' => { emit(kALIAS); fnext expr_fname; fbreak; };

      'class' w_any* '<<'
      => { emit_token(state, kCLASS, rb_str_new2("class"), ts, ts + 5);
           emit_token(state, tLSHFT, rb_str_new2("<<"),    te - 2, te);
           fnext expr_value; fbreak; };

      'if'     => { emit(kIF_MOD);     fnext expr_beg; fbreak; };
      'unless' => { emit(kUNLESS_MOD); fnext expr_beg; fbreak; };
      'while'  => { emit(kWHILE_MOD);  fnext expr_beg; fbreak; };
      'until'  => { emit(kUNTIL_MOD);  fnext expr_beg; fbreak; };
      'rescue' => { emit(kRESCUE_MOD); fnext expr_beg; fbreak; };

      'else'   => { emit(kELSE);   fnext expr_value; fbreak; };
      'case'   => { emit(kCASE);   fnext expr_value; fbreak; };
      'ensure' => { emit(kENSURE); fnext expr_value; fbreak; };
      'module' => { emit(kMODULE); fnext expr_value; fbreak; };
      'elsif'  => { emit(kELSIF);  fnext expr_value; fbreak; };
      'then'   => { emit(kTHEN);   fnext expr_value; fbreak; };
      'for'    => { emit(kFOR);    fnext expr_value; fbreak; };
      'in'     => { emit(kIN);     fnext expr_value; fbreak; };
      'do'     => { emit(kDO);     fnext expr_value; fbreak; };
      'when'   => { emit(kWHEN);   fnext expr_value; fbreak; };
      'begin'  => { emit(kBEGIN);  fnext expr_value; fbreak; };
      'class'  => { emit(kCLASS);  fnext expr_value; fbreak; };
      'and'    => { emit(kAND);    fnext expr_value; fbreak; };
      'or'     => { emit(kOR);     fnext expr_value; fbreak; };

      'return' => { emit(kRETURN); fnext expr_mid; fbreak; };
      'break'  => { emit(kBREAK);  fnext expr_mid; fbreak; };
      'next'   => { emit(kNEXT);   fnext expr_mid; fbreak; };

      'yield'    => { emit(kYIELD);   fnext expr_arg; fbreak; };
      'super'    => { emit(kSUPER);   fnext expr_arg; fbreak; };
      'defined?' => { emit(kDEFINED); fnext expr_arg; fbreak; };

      'not'      => {
        emit(kNOT);
        if (state->version == 18) {
          fnext expr_beg; fbreak;
        } else {
          fnext expr_arg; fbreak;
        }
      };

      '__ENCODING__' => {
        if (state->version == 18) {
          VALUE str = tok(state, ts, te);
          emit(tIDENTIFIER);

          if (state->static_env != Qnil &&
              RTEST(rb_funcall(state->static_env, rb_intern("declared?"), 1, str))) {
            fnext expr_end;
          } else {
            fnext *arg_or_cmdarg(command_state);
          }
        } else {
          emit(k__ENCODING__);
        }
        fbreak;
      };

      'end'      => { emit(kEND);      fbreak; };
      'self'     => { emit(kSELF);     fbreak; };
      'true'     => { emit(kTRUE);     fbreak; };
      'false'    => { emit(kFALSE);    fbreak; };
      'retry'    => { emit(kRETRY);    fbreak; };
      'redo'     => { emit(kREDO);     fbreak; };
      'nil'      => { emit(kNIL);      fbreak; };
      'BEGIN'    => { emit(klBEGIN);   fbreak; };
      'END'      => { emit(klEND);     fbreak; };
      '__FILE__' => { emit(k__FILE__); fbreak; };
      '__LINE__' => { emit(k__LINE__); fbreak; };

      ( '0' [Xx] %{ num_base = 16; num_digits_s = p; } int_hex
      | '0' [Dd] %{ num_base = 10; num_digits_s = p; } int_dec
      | '0' [Oo] %{ num_base = 8;  num_digits_s = p; } int_dec
      | '0' [Bb] %{ num_base = 2;  num_digits_s = p; } int_bin
      | [1-9] digit* '_'? %{ num_base = 10; num_digits_s = ts; } int_dec
      | '0'   digit* '_'? %{ num_base = 8;  num_digits_s = ts; } int_dec
      ) %{ num_suffix_s = p; } int_suffix
      => {
        int invalid_idx;
        VALUE digits = tok(state, num_digits_s, num_suffix_s);

        if (NUM2INT(rb_ary_entry(state->source_pts, num_suffix_s - 1)) == '_') {
          VALUE hash = rb_hash_new();
          rb_hash_aset(hash, character, rb_str_new2("_"));
          diagnostic(state, severity_error, trailing_in_number, hash,
                     range(state, te - 1, te), empty_array);
        } else if (RSTRING_LEN(digits) == 0 && num_base == 8 && state->version == 18) {
          digits = rb_str_new2("0");
        } else if (RSTRING_LEN(digits) == 0) {
          diagnostic(state, severity_error, empty_numeric, Qnil,
                     range(state, ts, te), empty_array);
        } else if (num_base == 8 && (invalid_idx = find_8_or_9(digits)) != -1) {
          int invalid_s = num_digits_s + invalid_idx;
          diagnostic(state, severity_error, invalid_octal, Qnil,
                     range(state, invalid_s, invalid_s + 1), empty_array);
        }

        VALUE integer = rb_funcall(digits, rb_intern("to_i"), 1, INT2NUM(num_base));
        if (state->version >= 18 && state->version <= 20) {
          emit_token(state, tINTEGER, integer, num_digits_s, num_suffix_s);
          p = num_suffix_s - 1;
        } else {
          num_xfrm(state, integer, num_digits_s, te);
        }

        fbreak;
      };

      flo_frac flo_pow?
      => {
        diagnostic(state, severity_error, no_dot_digit_literal, Qnil,
                   range(state, ts, te), empty_array);
      };

      flo_int [eE]
      => {
        if (state->version >= 18 && state->version <= 20) {
          VALUE hash = rb_hash_new();
          rb_hash_aset(hash, character, tok(state, te - 1, te));
          diagnostic(state, severity_error, trailing_in_number, hash,
                     range(state, te - 1, te), empty_array);
        } else {
          VALUE integer = rb_funcall(tok(state, ts, te - 1), rb_intern("to_i"), 0);
          emit_token(state, tINTEGER, integer, ts, te - 1);
          fhold; fbreak;
        }
      };

      flo_int flo_frac [eE]
      => {
        if (state->version >= 18 && state->version <= 20) {
          VALUE hash = rb_hash_new();
          rb_hash_aset(hash, character, tok(state, te - 1, te));
          diagnostic(state, severity_error, trailing_in_number, hash,
                     range(state, te - 1, te), empty_array);
        } else {
          VALUE fval = rb_funcall(tok(state, ts, te - 1), rb_intern("to_f"), 0);
          emit_token(state, tFLOAT, fval, ts, te - 1);
          fhold; fbreak;
        }
      };

      flo_int
      ( flo_frac? flo_pow %{ num_suffix_s = p; } flo_pow_suffix
      | flo_frac          %{ num_suffix_s = p; } flo_suffix
      )
      => {
        VALUE digits = tok(state, ts, num_suffix_s);

        if (state->version >= 18 && state->version <= 20) {
          VALUE fval = rb_funcall(Qnil, rb_intern("Float"), 1, digits);
          emit_token(state, tFLOAT, fval, ts, num_suffix_s);
          p = num_suffix_s - 1;
        } else {
          num_xfrm(state, digits, ts, te);
        }
        fbreak;
      };

      '`' | ['"] => { /* ' */
        VALUE type = tok(state, ts, te);
        VALUE delimiter = tok(state, te - 1, te);
        fgoto *push_literal(state, type, delimiter, ts, 0, 0, 0, 1);
      };

      constant => { emit(tCONSTANT); fnext *arg_or_cmdarg(command_state); fbreak; };

      constant ambiguous_const_suffix => {
        emit_token(state, tCONSTANT, tok(state, ts, tm), ts, tm);
        p = tm - 1;
        fbreak;
      };

      global_var | class_var_v | instance_var_v
      => { p = ts - 1; fcall expr_variable; };

      '.'  => { emit(tDOT);    fnext expr_dot; fbreak; };
      '&.' => { emit(tANDDOT); fnext expr_dot; fbreak; };
      '::' => { emit(tCOLON2); fnext expr_dot; fbreak; };

      call_or_var => local_ident;

      bareword ambiguous_fid_suffix => {
        if (tm == te) {
          emit(tFID);
        } else {
          emit_token(state, tIDENTIFIER, tok(state, ts, tm), ts, tm);
          p = tm - 1;
        }
        fnext expr_arg; fbreak;
      };

      e_lparen => { emit(tLPAREN2); fnext expr_beg; fbreak; };
      '&'   => { emit(tAMPER2);  fnext expr_beg; fbreak; };
      '|'   => { emit(tPIPE);    fnext expr_beg; fbreak; };
      '&&'  => { emit(tANDOP);   fnext expr_beg; fbreak; };
      '||'  => { emit(tOROP);    fnext expr_beg; fbreak; };
      '^'   => { emit(tCARET);   fnext expr_beg; fbreak; };
      '+'   => { emit(tPLUS);    fnext expr_beg; fbreak; };
      '-'   => { emit(tMINUS);   fnext expr_beg; fbreak; };
      '*'   => { emit(tSTAR2);   fnext expr_beg; fbreak; };
      '/'   => { emit(tDIVIDE);  fnext expr_beg; fbreak; };
      '**'  => { emit(tPOW);     fnext expr_beg; fbreak; };
      '~'   => { emit(tTILDE);   fnext expr_beg; fbreak; };
      '<<'  => { emit(tLSHFT);   fnext expr_beg; fbreak; };
      '>>'  => { emit(tRSHFT);   fnext expr_beg; fbreak; };
      '%'   => { emit(tPERCENT); fnext expr_beg; fbreak; };
      '=~'  => { emit(tMATCH);   fnext expr_beg; fbreak; };
      '!~'  => { emit(tNMATCH);  fnext expr_beg; fbreak; };
      '=='  => { emit(tEQ);      fnext expr_beg; fbreak; };
      '!='  => { emit(tNEQ);     fnext expr_beg; fbreak; };
      '!'   => { emit(tBANG);    fnext expr_beg; fbreak; };
      '===' => { emit(tEQQ);     fnext expr_beg; fbreak; };
      '<'   => { emit(tLT);      fnext expr_beg; fbreak; };
      '<='  => { emit(tLEQ);     fnext expr_beg; fbreak; };
      '>'   => { emit(tGT);      fnext expr_beg; fbreak; };
      '>='  => { emit(tGEQ);     fnext expr_beg; fbreak; };
      '<=>' => { emit(tCMP);     fnext expr_beg; fbreak; };
      '=>'  => { emit(tASSOC);   fnext expr_beg; fbreak; };

      e_rbrace => {
        emit(tRCURLY);
        stack_state_lexpop(&state->cond);
        stack_state_lexpop(&state->cmdarg);
        fnext expr_endarg; fbreak;
      };

      e_rparen => {
        emit(tRPAREN);
        stack_state_lexpop(&state->cond);
        stack_state_lexpop(&state->cmdarg);
        fbreak;
      };

      ']' => {
        emit(tRBRACK);
        stack_state_lexpop(&state->cond);
        stack_state_lexpop(&state->cmdarg);
        fnext expr_endarg; fbreak;
      };

      operator_arithmetic '='
      => { emit_token(state, tOP_ASGN, tok(state, ts, te - 1), ts, te);
           fnext expr_beg; fbreak; };

      '?' => { emit(tEH); fnext expr_value; fbreak; };

      e_lbrack => { emit(tLBRACK2); fnext expr_beg; fbreak; };

      ','   => { emit(tCOMMA); fnext expr_beg; fbreak; };
      '='   => { emit(tEQL);   fnext expr_beg; fbreak; };
      ':'   => { emit(tCOLON); fnext expr_beg; fbreak; };
      '..'  => { emit(tDOT2);  fnext expr_beg; fbreak; };
      '...' => { emit(tDOT3);  fnext expr_beg; fbreak; };

      w_space_comment;

      w_newline => { fgoto leading_dot; };

      ';' => { emit(tSEMI); fnext expr_value; fbreak; };

      '\\' c_line {
        diagnostic(state, severity_error, bare_backslash, Qnil,
                   range(state, ts, ts + 1), empty_array);
        fhold;
      };

      c_any
      => {
        VALUE hash = rb_hash_new();
        VALUE str  = rb_str_inspect(tok(state, ts, te));
        rb_hash_aset(hash, character, rb_str_substr(str, 1, NUM2INT(rb_str_length(str)) - 2));
        diagnostic(state, fatal, unexpected, hash, range(state, ts, te), empty_array);
      };

      c_eof => do_eof;
  *|;

  leading_dot := |*
      c_space* %{ tm = p; } ('.' | '&.') => { p = tm - 1; fgoto expr_end; };

      any => {
        emit_token(state, tNL, Qnil, state->newline_s, state->newline_s + 1);
        fhold; fnext line_begin; fbreak;
      };
  *|;

  expr_fname := |*
      'if'           => { emit(kIF);           fnext expr_endfn; fbreak; };
      'unless'       => { emit(kUNLESS);       fnext expr_endfn; fbreak; };
      'while'        => { emit(kWHILE);        fnext expr_endfn; fbreak; };
      'until'        => { emit(kUNTIL);        fnext expr_endfn; fbreak; };
      'rescue'       => { emit(kRESCUE);       fnext expr_endfn; fbreak; };
      'yield'        => { emit(kYIELD);        fnext expr_endfn; fbreak; };
      'super'        => { emit(kSUPER);        fnext expr_endfn; fbreak; };
      'not'          => { emit(kNOT);          fnext expr_endfn; fbreak; };
      'defined?'     => { emit(kDEFINED);      fnext expr_endfn; fbreak; };
      'def'          => { emit(kDEF);          fnext expr_endfn; fbreak; };
      'undef'        => { emit(kUNDEF);        fnext expr_endfn; fbreak; };
      'alias'        => { emit(kALIAS);        fnext expr_endfn; fbreak; };
      'else'         => { emit(kELSE);         fnext expr_endfn; fbreak; };
      'case'         => { emit(kCASE);         fnext expr_endfn; fbreak; };
      'ensure'       => { emit(kENSURE);       fnext expr_endfn; fbreak; };
      'module'       => { emit(kMODULE);       fnext expr_endfn; fbreak; };
      'elsif'        => { emit(kELSIF);        fnext expr_endfn; fbreak; };
      'then'         => { emit(kTHEN);         fnext expr_endfn; fbreak; };
      'for'          => { emit(kFOR);          fnext expr_endfn; fbreak; };
      'in'           => { emit(kIN);           fnext expr_endfn; fbreak; };
      'do'           => { emit(kDO);           fnext expr_endfn; fbreak; };
      'when'         => { emit(kWHEN);         fnext expr_endfn; fbreak; };
      'begin'        => { emit(kBEGIN);        fnext expr_endfn; fbreak; };
      'class'        => { emit(kCLASS);        fnext expr_endfn; fbreak; };
      'and'          => { emit(kAND);          fnext expr_endfn; fbreak; };
      'or'           => { emit(kOR);           fnext expr_endfn; fbreak; };
      'return'       => { emit(kRETURN);       fnext expr_endfn; fbreak; };
      'break'        => { emit(kBREAK);        fnext expr_endfn; fbreak; };
      'next'         => { emit(kNEXT);         fnext expr_endfn; fbreak; };
      'end'          => { emit(kEND);          fnext expr_endfn; fbreak; };
      'self'         => { emit(kSELF);         fnext expr_endfn; fbreak; };
      'true'         => { emit(kTRUE);         fnext expr_endfn; fbreak; };
      'false'        => { emit(kFALSE);        fnext expr_endfn; fbreak; };
      'retry'        => { emit(kRETRY);        fnext expr_endfn; fbreak; };
      'redo'         => { emit(kREDO);         fnext expr_endfn; fbreak; };
      'nil'          => { emit(kNIL);          fnext expr_endfn; fbreak; };
      'BEGIN'        => { emit(klBEGIN);       fnext expr_endfn; fbreak; };
      'END'          => { emit(klEND);         fnext expr_endfn; fbreak; };
      '__FILE__'     => { emit(k__FILE__);     fnext expr_endfn; fbreak; };
      '__LINE__'     => { emit(k__LINE__);     fnext expr_endfn; fbreak; };
      '__ENCODING__' => { emit(k__ENCODING__); fnext expr_endfn; fbreak; };

      constant        => { emit(tCONSTANT); fnext expr_endfn; fbreak; };

      bareword [?=!]? => { emit(tIDENTIFIER); fnext expr_endfn; fbreak; };

      global_var => { p = ts - 1; fnext expr_end; fcall expr_variable; };

      '[]'  => { emit(tAREF);      fnext expr_endfn; fbreak; };
      '[]=' => { emit(tASET);      fnext expr_endfn; fbreak; };
      '`'   => { emit(tBACK_REF2); fnext expr_endfn; fbreak; };
      '-@'  => { emit(tUMINUS);    fnext expr_endfn; fbreak; };
      '+@'  => { emit(tUPLUS);     fnext expr_endfn; fbreak; };
      '~@'  => { emit(tTILDE);     fnext expr_endfn; fbreak; };
      '!@'  => { emit(tBANG);      fnext expr_endfn; fbreak; };
      '&'   => { emit(tAMPER2);    fnext expr_endfn; fbreak; };
      '|'   => { emit(tPIPE);      fnext expr_endfn; fbreak; };
      '&&'  => { emit(tANDOP);     fnext expr_endfn; fbreak; };
      '||'  => { emit(tOROP);      fnext expr_endfn; fbreak; };
      '^'   => { emit(tCARET);     fnext expr_endfn; fbreak; };
      '+'   => { emit(tPLUS);      fnext expr_endfn; fbreak; };
      '-'   => { emit(tMINUS);     fnext expr_endfn; fbreak; };
      '*'   => { emit(tSTAR2);     fnext expr_endfn; fbreak; };
      '/'   => { emit(tDIVIDE);    fnext expr_endfn; fbreak; };
      '**'  => { emit(tPOW);       fnext expr_endfn; fbreak; };
      '~'   => { emit(tTILDE);     fnext expr_endfn; fbreak; };
      '<<'  => { emit(tLSHFT);     fnext expr_endfn; fbreak; };
      '>>'  => { emit(tRSHFT);     fnext expr_endfn; fbreak; };
      '%'   => { emit(tPERCENT);   fnext expr_endfn; fbreak; };
      '=~'  => { emit(tMATCH);     fnext expr_endfn; fbreak; };
      '!~'  => { emit(tNMATCH);    fnext expr_endfn; fbreak; };
      '=='  => { emit(tEQ);        fnext expr_endfn; fbreak; };
      '!='  => { emit(tNEQ);       fnext expr_endfn; fbreak; };
      '!'   => { emit(tBANG);      fnext expr_endfn; fbreak; };
      '===' => { emit(tEQQ);       fnext expr_endfn; fbreak; };
      '<'   => { emit(tLT);        fnext expr_endfn; fbreak; };
      '<='  => { emit(tLEQ);       fnext expr_endfn; fbreak; };
      '>'   => { emit(tGT);        fnext expr_endfn; fbreak; };
      '>='  => { emit(tGEQ);       fnext expr_endfn; fbreak; };
      '<=>' => { emit(tCMP);       fnext expr_endfn; fbreak; };
      '=>'  => { emit(tASSOC);     fnext expr_endfn; fbreak; };

      '::' => { fhold; fhold; fgoto expr_end; };

      ':' => { fhold; fgoto expr_beg; };

      w_any;

      c_any => { fhold; fgoto expr_end; };

      c_eof => do_eof;
  *|;

  expr_endfn := |*
      label => {
        emit_token(state, tLABEL, tok(state, ts, te - 1), ts, te);
        fnext expr_labelarg; fbreak;
      };

      w_space_comment;

      c_any => { fhold; fgoto expr_end; };

      c_eof => do_eof;
  *|;

  expr_dot := |*
      constant => { emit(tCONSTANT); fnext *arg_or_cmdarg(command_state); fbreak; };

      call_or_var => { emit(tIDENTIFIER); fnext *arg_or_cmdarg(command_state); fbreak; };

      bareword ambiguous_fid_suffix
      => { emit_token(state, tFID, tok(state, ts, tm), ts, tm);
           fnext *arg_or_cmdarg(command_state); p = tm - 1; fbreak; };

      '[]'  => { emit(tAREF);      fnext expr_arg; fbreak; };
      '[]=' => { emit(tASET);      fnext expr_arg; fbreak; };
      '`'   => { emit(tBACK_REF2); fnext expr_arg; fbreak; };
      '-@'  => { emit(tUMINUS);    fnext expr_arg; fbreak; };
      '+@'  => { emit(tUPLUS);     fnext expr_arg; fbreak; };
      '~@'  => { emit(tTILDE);     fnext expr_arg; fbreak; };
      '!@'  => { emit(tBANG);      fnext expr_arg; fbreak; };
      '&'   => { emit(tAMPER2);    fnext expr_arg; fbreak; };
      '|'   => { emit(tPIPE);      fnext expr_arg; fbreak; };
      '&&'  => { emit(tANDOP);     fnext expr_arg; fbreak; };
      '||'  => { emit(tOROP);      fnext expr_arg; fbreak; };
      '^'   => { emit(tCARET);     fnext expr_arg; fbreak; };
      '+'   => { emit(tPLUS);      fnext expr_arg; fbreak; };
      '-'   => { emit(tMINUS);     fnext expr_arg; fbreak; };
      '*'   => { emit(tSTAR2);     fnext expr_arg; fbreak; };
      '/'   => { emit(tDIVIDE);    fnext expr_arg; fbreak; };
      '**'  => { emit(tPOW);       fnext expr_arg; fbreak; };
      '~'   => { emit(tTILDE);     fnext expr_arg; fbreak; };
      '<<'  => { emit(tLSHFT);     fnext expr_arg; fbreak; };
      '>>'  => { emit(tRSHFT);     fnext expr_arg; fbreak; };
      '%'   => { emit(tPERCENT);   fnext expr_arg; fbreak; };
      '=~'  => { emit(tMATCH);     fnext expr_arg; fbreak; };
      '!~'  => { emit(tNMATCH);    fnext expr_arg; fbreak; };
      '=='  => { emit(tEQ);        fnext expr_arg; fbreak; };
      '!='  => { emit(tNEQ);       fnext expr_arg; fbreak; };
      '!'   => { emit(tBANG);      fnext expr_arg; fbreak; };
      '===' => { emit(tEQQ);       fnext expr_arg; fbreak; };
      '<'   => { emit(tLT);        fnext expr_arg; fbreak; };
      '<='  => { emit(tLEQ);       fnext expr_arg; fbreak; };
      '>'   => { emit(tGT);        fnext expr_arg; fbreak; };
      '>='  => { emit(tGEQ);       fnext expr_arg; fbreak; };
      '<=>' => { emit(tCMP);       fnext expr_arg; fbreak; };
      '=>'  => { emit(tASSOC);     fnext expr_arg; fbreak; };

      w_any;

      c_any
      => { fhold; fgoto expr_end; };

      c_eof => do_eof;
  *|;

  expr_arg := |*
      w_space+ e_lparen => {
        if (state->version == 18) {
          emit_token(state, tLPAREN2, rb_str_new2("("), te - 1, te);
          fnext expr_value; fbreak;
        } else {
          emit_token(state, tLPAREN_ARG, rb_str_new2("("), te - 1, te);
          fnext expr_beg; fbreak;
        }
      };

      e_lparen => { emit(tLPAREN2); fnext expr_beg; fbreak; };

      w_space+ e_lbrack => {
        emit_token(state, tLBRACK, rb_str_new2("["), te - 1, te);
        fnext expr_beg; fbreak;
      };

      w_space* e_lbrace => {
        VALUE val = array_last(state->lambda_stack);
        if (val != Qnil && NUM2INT(val) == state->paren_nest) {
          p = ts - 1;
          fgoto expr_end;
        } else {
          emit_token(state, tLCURLY, rb_str_new2("{"), te - 1, te);
          fnext expr_value; fbreak;
        }
      };

      '?' c_space_nl => { p = ts - 1; fgoto expr_end; };

      w_space* '?' => { fhold; fgoto expr_beg; };

      w_space+ %{ tm = p; } ( [%/] ( c_any - c_space_nl - '=' ) | '<<' ) => {
        if (NUM2INT(rb_ary_entry(state->source_pts, tm)) == '/') {
          diagnostic(state, warning, ambiguous_literal, Qnil,
                     range(state, tm, tm + 1), empty_array);
        }

        p = tm - 1;
        fgoto expr_beg;
      };

      w_space+ %{ tm = p; } ( '+' | '-' | '*' | '&' | '**' ) => {
        VALUE hash = rb_hash_new();
        VALUE str  = tok(state, tm, te);
        rb_hash_aset(hash, prefix, str);
        diagnostic(state, warning, ambiguous_prefix, hash, range(state, tm, te),
                   empty_array);

        p = tm - 1;
        fgoto expr_beg;
      };

      w_space+ '::' => { fhold; fhold; fgoto expr_beg; };

      w_space* ':' => { fhold; fgoto expr_beg; };

      w_space+ label => { p = ts - 1; fgoto expr_beg; };

      w_space+ %{ tm = p; } '?' c_space_nl => { p = tm - 1; fgoto expr_end; };

      w_space* operator_arithmetic
                  ( '=' | c_space_nl )?    |
      w_space* keyword_modifier            |
      w_space* punctuation_end
      => {
        p = ts - 1;
        fgoto expr_end;
      };

      w_space;

      w_comment => { fgoto expr_end; };

      w_newline => { fhold; fgoto expr_end; };

      c_any => { fhold; fgoto expr_beg; };

      c_eof => do_eof;
  *|;

  expr_cmdarg := |*
      w_space+ e_lparen
      => {
        emit_token(state, tLPAREN_ARG, rb_str_new2("("), te - 1, te);
        if (state->version == 18) {
          fnext expr_value; fbreak;
        } else {
          fnext expr_beg; fbreak;
        }
      };

      w_space* 'do'
      => {
        if (stack_state_active(&state->cond)) {
          emit_token(state, kDO_COND, rb_str_new2("do"), te - 2, te);
        } else {
          emit_token(state, kDO, rb_str_new2("do"), te - 2, te);
        }
        fnext expr_value; fbreak;
      };

      c_any             |
      w_space* bareword |
      w_space* label
      => { p = ts - 1;
           fgoto expr_arg; };

      c_eof => do_eof;
  *|;

  expr_endarg := |*
      e_lbrace => { emit(tLBRACE_ARG); fnext expr_value; };

      'do' => { emit_do(state, 1, ts, te); fnext expr_value; fbreak; };

      w_space_comment;

      c_any
      => { fhold; fgoto expr_end; };

      c_eof => do_eof;
  *|;

  expr_mid := |*
      'if'     => { emit(kIF_MOD);     fnext expr_beg; fbreak; };
      'unless' => { emit(kUNLESS_MOD); fnext expr_beg; fbreak; };
      'while'  => { emit(kWHILE_MOD);  fnext expr_beg; fbreak; };
      'until'  => { emit(kUNTIL_MOD);  fnext expr_beg; fbreak; };
      'rescue' => { emit(kRESCUE_MOD); fnext expr_beg; fbreak; };

      bareword => { p = ts - 1; fgoto expr_beg; };

      w_space_comment;

      w_newline => { fhold; fgoto expr_end; };

      c_any => { fhold; fgoto expr_beg; };

      c_eof => do_eof;
  *|;

  expr_labelarg := |*
      w_space_comment;

      w_newline => {
        if (state->in_kwarg) {
          fhold; fgoto expr_end;
        } else {
          fgoto line_begin;
        }
      };

      c_any => { fhold; fgoto expr_beg; };

      c_eof => do_eof;
  *|;

  expr_value := |*
      label (any - ':') => { p = ts - 1; fgoto expr_end; };

      ['"] => { /* ' */
        VALUE type = tok(state, ts, te);
        fgoto *push_literal(state, type, type, ts, 0, 0, 0, 0);
      };

      w_space_comment;

      w_newline => { fgoto line_begin; };

      c_any => { fhold; fgoto expr_beg; };

      c_eof => do_eof;
  *|;

  expr_variable := |*
      global_var => {
        VALUE str = tok(state, ts, te);

        if (is_nthref(str)) {
          VALUE integer = rb_funcall(tok(state, ts + 1, te), rb_intern("to_i"), 0);
          emit_token(state, tNTH_REF, integer, ts, te);
        } else if (is_backref(str)) {
          emit(tBACK_REF);
        } else {
          emit(tGVAR);
        }

        fret; fbreak;
      };

      class_var_v => {
        VALUE str = tok(state, ts, te);

        if (bad_cvar_name(str)) {
          VALUE hash = rb_hash_new();
          rb_hash_aset(hash, ID2SYM(rb_intern("name")), str);
          diagnostic(state, severity_error, cvar_name, hash, range(state, ts, te), empty_array);
        }

        emit(tCVAR);
        fret; fbreak;
      };

      instance_var_v => {
        VALUE str = tok(state, ts, te);

        if (bad_ivar_name(str)) {
          VALUE hash = rb_hash_new();
          rb_hash_aset(hash, ID2SYM(rb_intern("name")), str);
          diagnostic(state, severity_error, ivar_name, hash, range(state, ts, te), empty_array);
        }

        emit(tIVAR);
        fret; fbreak;
      };
  *|;

  line_comment := |*
      '=end' c_line* c_nl_zlen => {
        emit_comment(state, state->eq_begin_s, te);
        fgoto line_begin;
      };

      c_line* c_nl;

      c_line* zlen => {
        diagnostic(state, fatal, embedded_document, Qnil,
                   range(state, state->eq_begin_s, state->eq_begin_s + 6),
                   empty_array);
      };
  *|;

  line_begin := |*
      w_any;

      '=begin' ( c_space | c_nl_zlen ) => {
        state->eq_begin_s = ts;
        fgoto line_comment;
      };

      '__END__' ( c_eol - zlen ) => { p = pe - 3; };

      c_any => { fhold; fgoto expr_value; };

      c_eof => do_eof;
  *|;
}%%
