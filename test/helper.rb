require 'tempfile'

require 'simplecov'

if SimpleCov.usable?
  if defined?(TracePoint)
    require_relative 'racc_coverage_helper'

    RaccCoverage.start(%w(ruby18.y),
                       File.expand_path('../../lib/parser', __FILE__))
  end

  SimpleCov.start do
    add_filter "/test/"

    add_filter "/lib/parser/lexer.rb"
    add_filter "/lib/parser/ruby18.rb"
    add_filter "/lib/parser/ruby19.rb"
    add_filter "/lib/parser/ruby20.rb"
  end
end

# minitest/autorun must go after SimpleCov to preserve
# correct order of at_exit hooks.
require 'minitest/autorun'

$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))
require 'parser'
