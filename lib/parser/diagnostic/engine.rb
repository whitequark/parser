module Parser

  ##
  # {Parser::Diagnostic::Engine} provides a basic API for dealing with
  # diagnostics by delegating them to registered consumers.
  #
  # @example
  #  buffer      = Parser::Source::Buffer.new(__FILE__)
  #  buffer.code = 'foobar'
  #
  #  consumer = lambda do |diagnostic|
  #    puts diagnostic.message
  #  end
  #
  #  engine     = Parser::Diagnostic::Engine.new(consumer)
  #  diagnostic = Parser::Diagnostic.new(:warning, 'warning!', buffer, 1..2)
  #
  #  engine.process(diagnostic) # => "warning!"
  #
  # @api public
  #
  # @!attribute [rw] consumer
  #  @return [#call(Diagnostic)]
  #
  # @!attribute [rw] all_errors_are_fatal
  #  When set to `true` any error that is encountered will result in
  #  {Parser::SyntaxError} being raised.
  #  @return [TrueClass|FalseClass]
  #
  # @!attribute [rw] ignore_warnings
  #  When set to `true` warnings will be ignored.
  #  @return [TrueClass|FalseClass]
  #
  class Diagnostic::Engine
    attr_accessor :consumer

    attr_accessor :all_errors_are_fatal
    attr_accessor :ignore_warnings

    ##
    # @param [#call(Diagnostic)] consumer
    #
    def initialize(consumer=nil)
      @consumer             = consumer

      @all_errors_are_fatal = false
      @ignore_warnings      = false
    end

    ##
    # Processes a diagnostic and optionally raises {Parser::SyntaxError} when
    # `all_errors_are_fatal` is set to true.
    #
    # @param [Parser::Diagnostic] diagnostic
    # @return [Parser::Diagnostic::Engine]
    #
    def process(diagnostic)
      if ignore?(diagnostic)
        # do nothing
      elsif @consumer
        @consumer.call(diagnostic)
      end

      if raise?(diagnostic)
        raise Parser::SyntaxError, diagnostic
      end

      self
    end

    protected

    ##
    # @param [Parser::Diagnostic] diagnostic
    # @return [TrueClass|FalseClass]
    #
    def ignore?(diagnostic)
      @ignore_warnings &&
            diagnostic.level == :warning
    end

    ##
    # @param [Parser::Diagnostic] diagnostic
    # @return [TrueClass|FalseClass]
    #
    def raise?(diagnostic)
      (@all_errors_are_fatal &&
          diagnostic.level == :error) ||
        diagnostic.level == :fatal
    end
  end

end
