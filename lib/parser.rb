require 'set'
require 'racc/parser'

require 'furnace/ast'

# Library namespace
module Parser
  require 'parser/version'
  require 'parser/syntax_error'
  require 'parser/source_file'
  require 'parser/diagnostic'
  require 'parser/diagnostics_engine'

  require 'parser/static_environment'

  require 'parser/lexer'
  require 'parser/lexer/literal'

  require 'parser/builders/sexp'
  require 'parser/base'
end
