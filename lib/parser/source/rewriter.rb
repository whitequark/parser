module Parser
  module Source

    ##
    # @api public
    #
    class Rewriter
      attr_accessor :diagnostics

      def initialize(source_buffer)
        @diagnostics = Diagnostic::Engine.new
        @diagnostics.consumer = lambda do |diag|
          $stderr.puts diag.render
        end

        @source_buffer = source_buffer
        @queue         = []
        @clobber       = 0
      end

      def remove(range)
        append Rewriter::Action.new(range, '')
      end

      def insert_before(range, content)
        append Rewriter::Action.new(range.begin, content)
      end

      def insert_after(range, content)
        append Rewriter::Action.new(range.end, content)
      end

      def replace(range, content)
        append Rewriter::Action.new(range, content)
      end

      def process
        adjustment   = 0
        source       = @source_buffer.source.dup
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
                                      "cannot #{action}",
                                      action.range)
          @diagnostics.process(diagnostic)

          # clobbered by: remove 3 characters
          diagnostic = Diagnostic.new(:note,
                                      "clobbered by: #{clobber_action}",
                                      clobber_action.range)
          @diagnostics.process(diagnostic)
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
