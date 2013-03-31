# Library namespace
module Parser
  require 'set'
  require 'racc/parser'

  require 'parser/syntax_error'
  require 'parser/source_file'
  require 'parser/static_environment'

  require 'parser/lexer'
  require 'parser/lexer/literal'

  require 'parser/builders/sexp'
  require 'parser/base'
end
