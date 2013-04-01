module Parser
  # A particular ruby version
  class Version
    RUBY_18 = new
    RUBY_19 = new
    RUBY_20 = new

    class << self
      private :new
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

  end # Version
end # Parser
