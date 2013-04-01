module Parser
  # A particular ruby version
  class Version

    class << self
      private :new
    end

    # Initialize object
    #
    # @param [String] string
    #
    # @return [undefined]
    #
    # @api private
    #
    def initialize(string)
      @string = string
    end

    # Return inspection
    #
    # @return [String]
    #
    # @api private
    #
    def inspect
      "<#{self.class.name}::RUBY_#{@string}>".freeze
    end

    # Test for 1.8
    #
    # @return [true]
    #   if version is 1.8
    #
    # @return [false]
    #   otherwise
    #
    # @api private
    #
    def ruby18?
      equal?(RUBY_18)
    end

    # Test for 1.9
    #
    # @return [true]
    #   if version is 1.9
    #
    # @return [false]
    #   otherwise
    #
    # @api private
    #
    def ruby19?
      equal?(RUBY_19)
    end

    # Test for 2.0
    #
    # @return [true]
    #   if version is 2.0
    #
    # @return [false]
    #   otherwise
    #
    # @api private
    #
    def ruby20?
      equal?(RUBY_20)
    end

    RUBY_18 = new('18')
    RUBY_19 = new('19')
    RUBY_20 = new('20')

  end # Version
end # Parser
