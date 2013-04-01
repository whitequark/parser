module Parser

  class Diagnostic
    LEVELS = [:note, :warning, :error, :fatal].freeze

    attr_reader :source_file
    attr_reader :level, :message, :ranges

    def initialize(level, message, source_file, ranges)
      unless LEVELS.include?(level)
        raise ArgumentError, "Diagnostic#level must be one of #{LEVELS.join(', ')}; " <<
                             "#{level.inspect} provided."
      end

      @level       = level
      @message     = message.to_s.dup.freeze
      @source_file = source_file
      @ranges      = Array(ranges).dup.freeze

      freeze
    end
  end

end
