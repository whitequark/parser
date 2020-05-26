# frozen_string_literal: true

require 'helper'
require 'open3'

class TestRunnerParse < Minitest::Test
  PATH_TO_RUBY_PARSE = File.expand_path('../bin/ruby-parse', __dir__).freeze

  def assert_prints(argv, expected_output)
    stdout, _stderr, status = Open3.capture3(PATH_TO_RUBY_PARSE, *argv)

    assert_equal 0, status.to_i
    assert_includes(stdout, expected_output)
  end

  def test_emit_ruby
    assert_prints ['--emit-ruby', '-e 123'],
                  's(:int, 123)'
  end

  def test_emit_modern_ruby
    assert_prints ['-e', '->{}'],
                  '(lambda)'
    assert_prints ['-e', 'self[1] = 2'],
                  'indexasgn'
  end

  def test_emit_legacy
    assert_prints ['--legacy', '-e', '->{}'],
                  '(send nil :lambda)'
    assert_prints ['--legacy', '-e', 'self[1] = 2'],
                  ':[]='
  end

  def test_emit_legacy_lambda
    assert_prints ['--legacy-lambda', '-e', '->{}'],
                  '(send nil :lambda)'
    assert_prints ['--legacy-lambda', '-e', 'self[1] = 2'],
                  'indexasgn'
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
