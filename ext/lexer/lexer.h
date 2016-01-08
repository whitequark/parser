typedef enum {
	SINGLE_QUOTE,      /* ' */
	DOUBLE_QUOTE,      /* " */
	PERCENT_Q,         /* %q */
	BIG_PERCENT_Q,     /* %Q */
	LSHFT_SINGLE_QUOT, /* <<' */
	LSHFT_DOUBLE_QUOT, /* <<" */
	BARE_PERCENT,      /* % */

	PERCENT_W,         /* %w */
	BIG_PERCENT_W,     /* %W */

	PERCENT_I,         /* %i */
	BIG_PERCENT_I,     /* %I */

	SYM_SINGLE_QUOT,   /* :' */
	SYM_DOUBLE_QUOT,   /* :" */
	PERCENT_S,         /* %s */

	SLASH,             /* / for regexp */
	PERCENT_R,         /* %r */

	PERCENT_X,         /* %x for xstr */
	BACKTICK,          /* ` */
	LSHFT_BACKTICK,    /* <<` */

	INVALID
} str_type;

struct lexer_state;

typedef struct literal {
	struct lexer_state *lexer;
	VALUE buffer;
	int buffer_s;
	int buffer_e;

	int nesting;

	str_type str_type;
	VALUE start_tok;
	int interpolate;

	VALUE start_delim;
	VALUE end_delim;
	VALUE delimiter;

	int heredoc_e;
	int str_s;
	int herebody_s;

	int indent;
	int label_allowed;
	int interp_braces;
	int space_emitted;
	int monolithic;

	int dedent_body;
	int dedent_level;
} literal;

define_stack_type(lit_stack, literal, {0});

typedef struct lexer_state {
  uint cs;               /* DFA state */
  uint p;                /* stream position */
  uint pe;               /* end-of-stream position */

  int *cs_stack;
  int cs_stack_top;
  int cs_stack_size;

  VALUE token_queue;
  VALUE static_env;

  VALUE source_buffer;
  VALUE source;          /* source code string */
  VALUE source_pts;      /* source as a codepoint array */
  VALUE encoding;

  VALUE tokens;
  VALUE comments;

  stack_state cond;
  stack_state cmdarg;
  ss_stack cond_stack;   /* for saving 'cond' */
  ss_stack cmdarg_stack; /* for saving 'cmdarg' */

  VALUE lambda_stack;
  int paren_nest;
  lit_stack literal_stack;

  int version;
  int in_kwarg;
  int force_utf32;

  VALUE diagnostics;

  int newline_s;         /* position of last newline encountered */
  int eq_begin_s;
  int herebody_s;
  int escape_s;

  int dedent_level;

  VALUE escape;
} lexer_state;

static void lexer_mark(void*);
static void lexer_dealloc(void*);
static VALUE lexer_reset(int, VALUE*, VALUE);

static void literal_init(literal*, lexer_state*, VALUE, VALUE, int, int, int, int, int);
static str_type literal_string_to_str_type(VALUE);
static VALUE literal_str_type_to_string(str_type);
static void literal_set_start_tok_and_interpolate(literal*, str_type);
static VALUE literal_get_start_delim(VALUE);
static VALUE literal_get_end_delim(VALUE);
static int  literal_munge_escape_p(literal*, VALUE);
static int  literal_nest_and_close(literal*, VALUE, int, int, VALUE);
static void literal_emit_start_tok(literal*);
static void literal_start_interp_brace(literal*);
static int  literal_end_interp_brace_and_close(literal*);
static void literal_extend_string(literal*, VALUE, int, int);
static void literal_flush_string(literal*);
static void literal_extend_content(literal*);
static void literal_extend_space(literal*, int, int);
static int  literal_words_p(literal*);
static void literal_infer_indent_level(literal*, VALUE);

static void emit_token(lexer_state*, VALUE, VALUE, int, int);
static void emit_comment(lexer_state*, int, int);
static void emit_do(lexer_state*, int, int, int);

static VALUE tok(lexer_state*, int, int);
static VALUE range(lexer_state*, int, int);
static void diagnostic(lexer_state*, VALUE, VALUE, VALUE, VALUE, VALUE);
static int get_codepoint(lexer_state*, int);
static int arg_or_cmdarg(int);
static int is_nthref(VALUE);
static int is_backref(VALUE);
static int is_capitalized(VALUE);
static int is_regexp_metachar(VALUE);
static int eof_codepoint(int);
static VALUE find_unknown_options(VALUE);
static int bad_cvar_name(VALUE);
static int bad_ivar_name(VALUE);
static int find_8_or_9(VALUE str);
static void emit_int(lexer_state*, VALUE, int, int);
static void emit_rational(lexer_state*, VALUE, int, int);
static void emit_complex(lexer_state*, VALUE, int, int);
static void emit_complex_rational(lexer_state*, VALUE, int, int);
static void emit_float(lexer_state*, VALUE, int, int);
static void emit_complex_float(lexer_state*, VALUE, int, int);
static int push_literal(lexer_state*, VALUE, VALUE, int, int, int, int, int);
static int pop_literal(lexer_state*);
static VALUE array_last(VALUE);
static VALUE unescape_char(char);
static VALUE escape_char(VALUE);
static void lex_unicode_points(lexer_state*, int);

#define emit(type) emit_token(state, type, tok(state, ts, te), ts, te)

#define def_lexer_attr_reader(name) \
  static VALUE lexer_get_ ## name(VALUE self) { \
    lexer_state *state; \
    Data_Get_Struct(self, lexer_state, state); \
    return state->name; }

#define def_lexer_attr_writer(name) \
  static VALUE lexer_set_ ## name(VALUE self, VALUE val) { \
    lexer_state *state; \
    Data_Get_Struct(self, lexer_state, state); \
    return state->name = val; } \

#define def_lexer_attribute(name) \
    def_lexer_attr_reader(name) \
    def_lexer_attr_writer(name)

#define Qzero INT2NUM(0)

#define init_symbol(name) \
    name = ID2SYM(rb_intern(#name)); \
    rb_gc_register_address(&name)

VALUE k__ENCODING__;
VALUE k__FILE__;
VALUE k__LINE__;
VALUE kALIAS;
VALUE kAND;
VALUE kBEGIN;
VALUE klBEGIN;
VALUE kBREAK;
VALUE kCASE;
VALUE kCLASS;
VALUE kDEF;
VALUE kDEFINED;
VALUE kDO;
VALUE kDO_BLOCK;
VALUE kDO_COND;
VALUE kDO_LAMBDA;
VALUE kELSE;
VALUE kELSIF;
VALUE kEND;
VALUE klEND;
VALUE kENSURE;
VALUE kFALSE;
VALUE kFOR;
VALUE kIF;
VALUE kIF_MOD;
VALUE kIN;
VALUE kMODULE;
VALUE kNEXT;
VALUE kNIL;
VALUE kNOT;
VALUE kOR;
VALUE kREDO;
VALUE kRESCUE;
VALUE kRESCUE_MOD;
VALUE kRETRY;
VALUE kRETURN;
VALUE kSELF;
VALUE kSUPER;
VALUE kTHEN;
VALUE kTRUE;
VALUE kUNDEF;
VALUE kUNLESS;
VALUE kUNLESS_MOD;
VALUE kUNTIL;
VALUE kUNTIL_MOD;
VALUE kWHEN;
VALUE kWHILE;
VALUE kWHILE_MOD;
VALUE kYIELD;

VALUE tAMPER;
VALUE tAMPER2;
VALUE tANDDOT;
VALUE tANDOP;
VALUE tAREF;
VALUE tASET;
VALUE tASSOC;
VALUE tBACK_REF;
VALUE tBACK_REF2;
VALUE tBANG;
VALUE tCARET;
VALUE tCHARACTER;
VALUE tCMP;
VALUE tCOLON;
VALUE tCOLON2;
VALUE tCOLON3;
VALUE tCOMMA;
VALUE tCOMMENT;
VALUE tCONSTANT;
VALUE tCVAR;
VALUE tDIVIDE;
VALUE tDOT;
VALUE tDOT2;
VALUE tDOT3;
VALUE tDSTAR;
VALUE tEH;
VALUE tEQ;
VALUE tEQL;
VALUE tEQQ;
VALUE tFID;
VALUE tFLOAT;
VALUE tGEQ;
VALUE tGT;
VALUE tGVAR;
VALUE tIDENTIFIER;
VALUE tIMAGINARY;
VALUE tINTEGER;
VALUE tIVAR;
VALUE tLABEL;
VALUE tLABEL_END;
VALUE tLAMBDA;
VALUE tLAMBEG;
VALUE tLBRACE;
VALUE tLBRACE_ARG;
VALUE tLBRACK;
VALUE tLBRACK2;
VALUE tLCURLY;
VALUE tLEQ;
VALUE tLPAREN;
VALUE tLPAREN_ARG;
VALUE tLPAREN2;
VALUE tLSHFT;
VALUE tLT;
VALUE tMATCH;
VALUE tMINUS;
VALUE tNEQ;
VALUE tNL;
VALUE tNMATCH;
VALUE tNTH_REF;
VALUE tOP_ASGN;
VALUE tOROP;
VALUE tPERCENT;
VALUE tPIPE;
VALUE tPLUS;
VALUE tPOW;
VALUE tQWORDS_BEG;
VALUE tQSYMBOLS_BEG;
VALUE tRATIONAL;
VALUE tRBRACK;
VALUE tRCURLY;
VALUE tREGEXP_BEG;
VALUE tREGEXP_OPT;
VALUE tRPAREN;
VALUE tRSHFT;
VALUE tSEMI;
VALUE tSPACE;
VALUE tSTAR;
VALUE tSTAR2;
VALUE tSTRING;
VALUE tSTRING_BEG;
VALUE tSTRING_CONTENT;
VALUE tSTRING_DBEG;
VALUE tSTRING_DEND;
VALUE tSTRING_DVAR;
VALUE tSTRING_END;
VALUE tSYMBEG;
VALUE tSYMBOL;
VALUE tSYMBOLS_BEG;
VALUE tTILDE;
VALUE tUMINUS;
VALUE tUMINUS_NUM;
VALUE tUPLUS;
VALUE tWORDS_BEG;
VALUE tXSTRING_BEG;

VALUE comment_klass;
VALUE diagnostic_klass;
VALUE range_klass;

VALUE severity_error;
VALUE fatal;
VALUE warning;

VALUE ambiguous_literal;
VALUE ambiguous_prefix;
VALUE bare_backslash;
VALUE character;
VALUE cvar_name;
VALUE embedded_document;
VALUE empty_numeric;
VALUE escape_eof;
VALUE incomplete_escape;
VALUE invalid_escape;
VALUE invalid_escape_use;
VALUE invalid_hex_escape;
VALUE invalid_octal;
VALUE invalid_unicode_escape;
VALUE ivar_name;
VALUE no_dot_digit_literal;
VALUE prefix;
VALUE regexp_options;
VALUE string_eof;
VALUE trailing_in_number;
VALUE unexpected;
VALUE unexpected_percent_str;
VALUE unicode_point_too_large;
VALUE unterminated_unicode;

VALUE empty_array;
VALUE blank_string;
VALUE escaped_next_line;
VALUE utf8_encoding;
VALUE cr_then_anything_to_eol;
VALUE crs_to_eol;