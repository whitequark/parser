require 'set'
require 'racc/parser'

require 'ast'

# Library namespace
module Parser
  require 'parser/syntax_error'
  require 'parser/source_range'
  require 'parser/source_file'
  require 'parser/diagnostic'
  require 'parser/diagnostics_engine'

  require 'parser/static_environment'

  require 'parser/lexer'
  require 'parser/lexer/literal'

  require 'parser/builders/sexp'
  require 'parser/base'

  ERRORS = {
    # Lexer errors
    unicode_point_too_large: "invalid Unicode codepoint (too large)",
    invalid_escape:          "invalid escape character syntax",
    invalid_escape_use:      "invalid character syntax; use ?%{escape}",
    incomplete_escape:       "incomplete character syntax",
    invalid_hex_escape:      "invalid hex escape",
    invalid_unicode_escape:  "invalid Unicode escape",
    unterminated_unicode:    "unterminated Unicode escape",
    escape_eof:              "escape sequence meets end of file",
    string_eof:              "unterminated string meets end of file",
    regexp_options:          "unknown regexp options: %{options}",
    cvar_name:               "`%{name}' is not allowed as a class variable name",
    ivar_name:               "`%{name}' is not allowed as an instance variable name",
    ambiguous_literal:       "ambiguous first argument; put parentheses or even spaces",
    ambiguous_prefix:        "`%{prefix}' interpreted as argument prefix",
    trailing_underscore:     "trailing `_' in number",
    empty_numeric:           "numeric literal without digits",
    invalid_octal:           "invalid octal digit",
    no_dot_digit_literal:    "no .<digit> floating literal anymore; put 0 before dot",
    bare_backslash:          "bare backslash only allowed before newline",
    unexpected:              "unexpected %{character}",
    embedded_document:       "embedded document meats end of file (and they embark on a romantic journey)",

    # Parser errors
    nth_ref_alias:           "cannot define an alias for a back-reference variable",
    begin_in_method:         "BEGIN in method",
    end_in_method:           "END in method; use at_exit",
    backref_assignment:      "cannot assign to a back-reference variable",
    invalid_assignment:      "cannot assign to %{node}",
    module_name_const:       "class or module name must be a constant literal",
    unexpected_token:        "unexpected token %{token}",
  }

  ERRORS.default_proc = ->(hash, key) do
    raise NotImplementedError, "Unknown error kind #{key.inspect}"
  end
end
