require 'set'
require 'racc/parser'

require 'ast'

if RUBY_VERSION < '1.9'
  require 'parser/compatibility/ruby1_8'
end

if RUBY_VERSION < '2.0'
  require 'parser/compatibility/ruby1_9'
end

##
# @api public
#
module Parser
  require 'parser/version'

  module AST
    require 'parser/ast/node'
    require 'parser/ast/processor'
  end

  module Source
    require 'parser/source/buffer'
    require 'parser/source/range'

    require 'parser/source/comment'
    require 'parser/source/comment/associator'

    require 'parser/source/rewriter'
    require 'parser/source/rewriter/action'

    require 'parser/source/map'
    require 'parser/source/map/operator'
    require 'parser/source/map/collection'
    require 'parser/source/map/constant'
    require 'parser/source/map/variable'
    require 'parser/source/map/keyword'
    require 'parser/source/map/definition'
    require 'parser/source/map/send'
    require 'parser/source/map/condition'
    require 'parser/source/map/ternary'
    require 'parser/source/map/for'
    require 'parser/source/map/rescue_body'
  end

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

  require 'parser/rewriter'

  ERRORS = {
    # Lexer errors
    :unicode_point_too_large => 'invalid Unicode codepoint (too large)',
    :invalid_escape          => 'invalid escape character syntax',
    :incomplete_escape       => 'incomplete character syntax',
    :invalid_hex_escape      => 'invalid hex escape',
    :invalid_unicode_escape  => 'invalid Unicode escape',
    :unterminated_unicode    => 'unterminated Unicode escape',
    :escape_eof              => 'escape sequence meets end of file',
    :string_eof              => 'unterminated string meets end of file',
    :regexp_options          => 'unknown regexp options: %{options}',
    :cvar_name               => "`%{name}' is not allowed as a class variable name",
    :ivar_name               => "`%{name}' is not allowed as an instance variable name",
    :trailing_in_number      => "trailing `%{character}' in number",
    :empty_numeric           => 'numeric literal without digits',
    :invalid_octal           => 'invalid octal digit',
    :no_dot_digit_literal    => 'no .<digit> floating literal anymore; put 0 before dot',
    :bare_backslash          => 'bare backslash only allowed before newline',
    :unexpected              => "unexpected `%{character}'",
    :embedded_document       => 'embedded document meets end of file (and they embark on a romantic journey)',

    # Lexer warnings
    :invalid_escape_use      => 'invalid character syntax; use ?%{escape}',
    :ambiguous_literal       => 'ambiguous first argument; parenthesize arguments or add whitespace to the right',
    :ambiguous_prefix        => "`%{prefix}' interpreted as argument prefix",

    # Parser errors
    :nth_ref_alias           => 'cannot define an alias for a back-reference variable',
    :begin_in_method         => 'BEGIN in method',
    :backref_assignment      => 'cannot assign to a back-reference variable',
    :invalid_assignment      => 'cannot assign to a keyword',
    :module_name_const       => 'class or module name must be a constant literal',
    :unexpected_token        => 'unexpected token %{token}',
    :argument_const          => 'formal argument cannot be a constant',
    :argument_ivar           => 'formal argument cannot be an instance variable',
    :argument_gvar           => 'formal argument cannot be a global variable',
    :argument_cvar           => 'formal argument cannot be a class variable',
    :duplicate_argument      => 'duplicate argument name',
    :empty_symbol            => 'empty symbol literal',
    :odd_hash                => 'odd number of entries for a hash',
    :singleton_literal       => 'cannot define a singleton method for a literal',
    :dynamic_const           => 'dynamic constant assignment',
    :module_in_def           => 'module definition in method body',
    :class_in_def            => 'class definition in method body',
    :unexpected_percent_str  => '%{type}: unknown type of percent-literal',
    :block_and_blockarg      => 'both block argument and literal block are passed',
    :masgn_as_condition      => 'multiple assignment in conditional context',

    # Parser warnings
    :useless_else            => 'else without rescue is useless',

    # Rewriter diagnostics
    :invalid_action          => 'cannot %{action}',
    :clobbered               => 'clobbered by: %{action}',
  }.freeze

  ##
  # Verify that the current Ruby implementation supports Encoding.
  # @raise [RuntimeError]
  def self.check_for_encoding_support
    unless defined?(Encoding)
      raise RuntimeError, 'Parsing 1.9 and later versions of Ruby is not supported on 1.8 due to the lack of Encoding support'
    end
  end
end
