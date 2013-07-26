module Parser

  ##
  # @api public
  #
  # @!attribute [r] level
  #  @see LEVELS
  #  @return [Symbol] diagnostic level
  #
  # @!attribute [r] message
  #  @return [String] error message
  #
  # @!attribute [r] location
  #  Main error-related source range.
  #  @return [Parser::Source::Range]
  #
  # @!attribute [r] highlights
  #  Supplementary error-related source ranges.
  #  @return [Array<Parser::Source::Range>]
  #
  class Diagnostic
    ##
    # Collection of the available diagnostic levels.
    #
    # @return [Array]
    #
    LEVELS = [:note, :warning, :error, :fatal].freeze

    attr_reader :level, :message
    attr_reader :location, :highlights

    ##
    # @param [Symbol] level
    # @param [String] message
    # @param [Parser::Source::Range] location
    # @param [Array<Parser::Source::Range>] highlights
    #
    def initialize(level, message, location, highlights=[])
      unless LEVELS.include?(level)
        raise ArgumentError,
              "Diagnostic#level must be one of #{LEVELS.join(', ')}; " \
              "#{level.inspect} provided."
      end

      @level       = level
      @message     = message.to_s.dup.freeze
      @location    = location
      @highlights  = highlights.dup.freeze

      freeze
    end

    ##
    # Renders the diagnostic message as a clang-like diagnostic.
    #
    # @example
    #  diagnostic.render # =>
    #  # [
    #  #   "(fragment:0):1:5: error: unexpected token $end",
    #  #   "foo +",
    #  #   "    ^"
    #  # ]
    #
    # @return [Array<String>]
    #
    def render
      source_line    = @location.source_line
      highlight_line = ' ' * source_line.length

      @highlights.each do |hilight|
        range = hilight.column_range
        highlight_line[range] = '~' * hilight.size
      end

      range = @location.column_range
      highlight_line[range] = '^' * @location.size

      [
        "#{@location.to_s}: #{@level}: #{@message}",
        source_line,
        highlight_line,
      ]
    end
  end

end
