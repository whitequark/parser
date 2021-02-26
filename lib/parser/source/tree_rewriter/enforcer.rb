# frozen_string_literal: true

module Parser
  module Source
    class TreeRewriter
      ##
      # Base class for objects responsible to handle rewriting conflicts
      # At a minimum, `ignore?` must be defined.
      # Other methods may be overwritten.
      #
      class Enforcer
        #
        # @param [Symbol] one of :crossing_deletions, :different_replacements, :swallowed_insertions,
        # For future-proofing, `ignore?` must accept other events and return `true`.
        def ignore?(event)
          raise NotImplementedError
        end

        def on_crossing_insertions(range, conflict_range)
          on(:crossing_insertions, range, conflict: conflict_range)
        end

        def on_crossing_deletions(range, conflict_range)
          on(:crossing_deletions, range, conflict: conflict_range)
        end

        def on_swallowed_insertions(range, conflict_range)
          on(:swallowed_insertions, range, conflict: conflict_range)
        end

        def on_different_replacements(range, replacement, other_replacement)
          on(:different_replacements, range, replacement: replacement, other_replacement: other_replacement)
        end

        protected

        def on(_event, _range, **_args)
          reject
        end

        def reject
          raise Parser::ClobberingError, "Parser::Source::TreeRewriter detected clobbering"
        end

        class WithPolicy < Enforcer
          ACTIONS = %i[accept warn raise].freeze

          def initialize(
            crossing_deletions: :accept,
            different_replacements: :accept,
            swallowed_insertions: :accept
          )
            @crossing_deletions     = validate_policy(crossing_deletions    )
            @different_replacements = validate_policy(different_replacements)
            @swallowed_insertions   = validate_policy(swallowed_insertions  )
          end

          def ignore?(event)
            policy(event) == :accept
          end

          def diagnostics
            @diagnostics ||= Diagnostic::Engine.new(-> diag { $stderr.puts diag.render })
          end

          protected

          def validate_policy(action)
            raise ArgumentError, "Invalid policy value: #{action}" unless ACTIONS.include?(action)

            action
          end

          def policy(event)
            case event
            when :crossing_insertions    then :raise
            when :crossing_deletions     then @crossing_deletions
            when :different_replacements then @different_replacements
            when :swallowed_insertions   then @swallowed_insertions
            else :accept # Example of future proofing
            end
          end

          POLICY_TO_LEVEL = {warn: :warning, raise: :error}.freeze
          def on(event, range, conflict: nil, **arguments)
            action = policy(event)
            severity = POLICY_TO_LEVEL.fetch(action)
            diag = Parser::Diagnostic.new(severity, event, arguments, range)
            diagnostics.process(diag)
            if conflict
              range, *highlights = conflict
              diag = Parser::Diagnostic.new(severity, :"#{event}_conflict", arguments, range, highlights)
              diagnostics.process(diag)
            end
            raise Parser::ClobberingError, "Parser::Source::TreeRewriter detected clobbering" if action == :raise
          end
        end

        DEFAULT = WithPolicy.new.freeze
      end
    end
  end
end
