# frozen_string_literal: true

require 'helper'
require 'open3'

class TestRunnerParse < Minitest::Test
  PATH_TO_RUBY_PARSE = File.expand_path('../bin/ruby-parse', __dir__).freeze

  def assert_prints(argv, expected_output)
    stdout, stderr, status = Open3.capture3(PATH_TO_RUBY_PARSE, *argv)

    assert_equal 0, status.to_i
    assert_includes(stdout, expected_output)
  end

  def test_emit_ruby
    assert_prints ['--emit-ruby', '-e 123'],
                  's(:int, 123)'
  end

  def test_emit_json
    assert_prints ['--emit-json', '-e', '123'],
                  '["int",123]'
  end

  def test_emit_ruby_empty
    assert_prints ['--emit-ruby', '-e', ''],
                  "\n"
  end

  def test_emit_json_empty
    assert_prints ['--emit-json', '-e', ''],
                  "\n"
  end
end
