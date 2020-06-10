# frozen_string_literal: true

require 'tempfile'
require 'simplecov'

if ENV.include?('COVERAGE') && SimpleCov.usable?
  require_relative 'racc_coverage_helper'

  RaccCoverage.start(
    %w(
      ruby18.y
      ruby19.y
      ruby20.y
      ruby21.y
      ruby22.y
      ruby23.y
      ruby24.y
      ruby25.y
      ruby26.y
      ruby27.y
      ruby28.y
    ),
    File.expand_path('../../lib/parser', __FILE__))

  # Report results faster.
  at_exit { RaccCoverage.stop }

  SimpleCov.start do
    self.formatter = SimpleCov::Formatter::MultiFormatter.new(
      SimpleCov::Formatter::HTMLFormatter
    )

    add_group 'Grammars' do |source_file|
      source_file.filename =~ %r{\.y$}
    end

    # Exclude the testsuite itself.
    add_filter '/test/'

    # Exclude generated files.
    add_filter do |source_file|
      source_file.filename =~ %r{/lib/parser/(lexer|ruby\d+|macruby|rubymotion)\.rb$}
    end
  end
end

# minitest/autorun must go after SimpleCov to preserve
# correct order of at_exit hooks.
require 'minitest/autorun'

$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))
require 'parser'

module NodeCollector
  extend self
  attr_accessor :callbacks, :nodes
  self.callbacks = []
  self.nodes = []

  def check
    @callbacks.each do |callback|
      @nodes.each { |node| callback.call(node) }
    end
    puts "#{callbacks.size} additional tests on #{nodes.size} nodes ran successfully"
  end

  Minitest.after_run { check }
end

def for_each_node(&block)
  NodeCollector.callbacks << block
end

class Parser::AST::Node
  def initialize(type, *)
    NodeCollector.nodes << self
    super
  end
end

# Special test extension that records a context of the parser
# for any node that is created
module NodeContextExt
  module NodeExt
    attr_reader :context

    def assign_properties(properties)
      super

      if (context = properties[:context])
        @context = context
      end
    end
  end
  Parser::AST::Node.prepend(NodeExt)

  module BuilderExt
    def n(type, children, source_map)
      super.updated(nil, nil, context: @parser.context.stack.dup)
    end
  end
  Parser::Builders::Default.prepend(BuilderExt)
end
