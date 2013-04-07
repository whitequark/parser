require 'set'
require 'racc/parser'

require 'ast'

# Library namespace
module Parser
  require 'parser/ast/node'
  require 'parser/ast/processor'

  require 'parser/source/buffer'
  require 'parser/source/range'

  require 'parser/source/map'
  require 'parser/source/map/operator'
  require 'parser/source/map/variable_assignment'

  require 'parser/syntax_error'
  require 'parser/diagnostic'
  require 'parser/diagnostic/engine'

  require 'parser/static_environment'

  require 'parser/lexer'
  require 'parser/lexer/literal'
  require 'parser/lexer/stack_state'

  module Builders
    require 'parser/builders/default'
  end

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
    ambiguous_literal:       "ambiguous first argument; parenthesize arguments or add whitespace to the right",
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
    argument_const:          "formal argument cannot be a constant",
    argument_ivar:           "formal argument cannot be an instance variable",
    argument_gvar:           "formal argument cannot be a global variable",
    argument_cvar:           "formal argument cannot be a class variable",
    empty_symbol:            "empty symbol literal",
    odd_hash:                "odd number of entries for a hash",
    singleton_literal:       "cannot define a singleton method for a literal",
    dynamic_const:           "dynamic constant assignment",
    module_in_def:           "module definition in method body",
    class_in_def:            "class definition in method body",
    grouped_expression:      "(...) interpreted as grouped expression",
    space_before_lparen:     "don't put space before argument parentheses",
    unexpected_percent_str:  "%%{type}: unknown type of percent-literal"
  }

  ERRORS.default_proc = ->(hash, key) do
    raise NotImplementedError, "Unknown error kind #{key.inspect}"
  end
end
