module Parser
  module Source

    ##
    # {Rewriter} performs the heavy lifting in the source rewriting process.
    # It schedules code updates to be performed in the correct order and
    # verifies that no two updates _clobber_ each other, that is, attempt to
    # modify the same part of code.
    #
    # If it is detected that one update clobbers another one, an `:error` and
    # a `:note` diagnostics describing both updates are generated and passed to
    # the diagnostic engine. After that, an exception is raised.
    #
    # The default diagnostic engine consumer simply prints the diagnostics to `stderr`.
    #
    # @!attribute [r] source_buffer
    #  @return [Source::Buffer]
    #
    # @!attribute [r] diagnostics
    #  @return [Diagnostic::Engine]
    #
    # @api public
    #
    class Rewriter
      attr_reader :source_buffer
      attr_reader :diagnostics

      ##
      # @param [Source::Buffer] source_buffer
      #
      def initialize(source_buffer)
        @diagnostics = Diagnostic::Engine.new
        @diagnostics.consumer = lambda do |diag|
          $stderr.puts diag.render
        end

        @source_buffer = source_buffer
        @queue         = []
        @clobber       = 0
      end

      ##
      # Removes the source range.
      #
      # @param [Range] range
      # @return [Rewriter] self
      # @raise [RuntimeError] when clobbering is detected
      #
      def remove(range)
        append Rewriter::Action.new(range, '')
      end

      ##
      # Inserts new code before the given source range.
      #
      # @param [Range] range
      # @param [String] content
      # @return [Rewriter] self
      # @raise [RuntimeError] when clobbering is detected
      #
      def insert_before(range, content)
        append Rewriter::Action.new(range.begin, content)
      end

      ##
      # Inserts new code after the given source range.
      #
      # @param [Range] range
      # @param [String] content
      # @return [Rewriter] self
      # @raise [RuntimeError] when clobbering is detected
      #
      def insert_after(range, content)
        append Rewriter::Action.new(range.end, content)
      end

      ##
      # Replaces the code of the source range `range` with `content`.
      #
      # @param [Range] range
      # @param [String] content
      # @return [Rewriter] self
      # @raise [RuntimeError] when clobbering is detected
      #
      def replace(range, content)
        append Rewriter::Action.new(range, content)
      end

      ##
      # Applies all scheduled changes to the `source_buffer` and returns
      # modified source as a new string.
      #
      # @return [String]
      #
      def process
        adjustment = 0
        source     = @source_buffer.source.dup

        sorted_queue = @queue.sort_by.with_index do |action, index|
          [action.range.begin_pos, index]
        end

        sorted_queue.each do |action|
          begin_pos = action.range.begin_pos + adjustment
          end_pos   = begin_pos + action.range.length

          source[begin_pos...end_pos] = action.replacement

          adjustment += (action.replacement.length - action.range.length)
        end

        source
      end

      private

      def append(action)
        if (clobber_action = clobbered?(action.range))
          # cannot replace 3 characters with "foobar"
          diagnostic = Diagnostic.new(:error,
                                      :invalid_action,
                                      { :action => action },
                                      action.range)
          @diagnostics.process(diagnostic)

          # clobbered by: remove 3 characters
          diagnostic = Diagnostic.new(:note,
                                      :clobbered,
                                      { :action => clobber_action },
                                      clobber_action.range)
          @diagnostics.process(diagnostic)

          raise RuntimeError, "Parser::Source::Rewriter detected clobbering"
        else
          clobber(action.range)

          @queue << action
        end

        self
      end

      def clobber(range)
        @clobber |= (2 ** range.size - 1) << range.begin_pos
      end

      def clobbered?(range)
        if @clobber & ((2 ** range.size - 1) << range.begin_pos) != 0
          @queue.find do |action|
            action.range.to_a & range.to_a
          end
        end
      end
    end

  end
end
