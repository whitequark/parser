# Library namespace
module Parser
  require 'set'
  require 'racc/parser'

  require 'parser/syntax_error'

  require 'parser/lexer'
  require 'parser/lexer/literal'

  require 'parser/static_environment'
  require 'parser/base'
end
