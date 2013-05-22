module Parser
  module Source

    class Comment
      attr_reader  :text

      attr_reader  :location
      alias_method :loc, :location

      def initialize(location)
        @location = location
        @text     = location.source.freeze

        freeze
      end

      def type
        case text
        when /^#/
          :inline
        when /^=begin/
          :document
        end
      end

      def inline?
        type == :inline
      end

      def document?
        type == :document
      end

      def ==(other)
        other.is_a?(Source::Comment) &&
          @location == other.location
      end
    end

  end
end
