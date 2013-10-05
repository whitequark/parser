module Parser
  module Source

    ##
    # @api public
    #
    # @!attribute [r] text
    #  @return String
    #
    # @!attribute [r] location
    #  @return Parser::Source::Map
    class Comment
      attr_reader  :text

      attr_reader  :location
      alias_method :loc, :location

      ##
      # @see Parser::Source::Comment::Associator
      def self.associate(ast, comments)
        associator = Associator.new(ast, comments)
        associator.associate
      end

      ##
      # @param [Parser::Source::Range] range
      def initialize(range)
        @location = Parser::Source::Map.new(range)
        @text     = range.source.freeze

        freeze
      end

      ##
      # Returns the type of this comment.
      #
      #   * Inline comments correspond to `:inline`:
      #
      #         # whatever
      #
      #   * Block comments correspond to `:document`:
      #
      #         =begin
      #         hi i am a document
      #         =end
      def type
        case text
        when /^#/
          :inline
        when /^=begin/
          :document
        end
      end

      ##
      # @see [#type]
      # @return [TrueClass|FalseClass]
      def inline?
        type == :inline
      end

      ##
      # @see [#type]
      # @return [TrueClass|FalseClass]
      def document?
        type == :document
      end

      ##
      # Compares comments. Two comments are identical if they
      # correspond to the same source range.
      # @param [Object] other
      # @return [TrueClass|FalseClass]
      def ==(other)
        other.is_a?(Source::Comment) &&
          @location == other.location
      end
    end

  end
end
