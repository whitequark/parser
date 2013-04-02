module Parser

  class Diagnostic
    LEVELS = [:note, :warning, :error, :fatal].freeze

    attr_reader :level, :message
    attr_reader :location, :highlights

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
