require 'set'
require 'racc/parser'

require 'ast'

# Library namespace
module Parser
  require 'parser/syntax_error'
  require 'parser/source_file'
  require 'parser/diagnostic'
  require 'parser/diagnostics_engine'

  require 'parser/static_environment'

  require 'parser/lexer'
  require 'parser/lexer/literal'

  require 'parser/builders/sexp'
  require 'parser/base'

  ERRORS = {
    nth_ref_alias:      "cannot define an alias for a back-reference variable",
    begin_in_method:    "BEGIN in method",
    end_in_method:      "END in method; use at_exit",
    backref_assignment: "cannot assign to a back-reference variable",
    invalid_assignment: "cannot assign to %{node}",
    module_name_const:  "class or module name must be a constant literal",
    unexpected_token:   "unexpected token %{token}"
  }

  ERRORS.default_proc = ->(hash, key) do
    raise NotImplementedError, "Unknown error kind #{key.inspect}"
  end
end
