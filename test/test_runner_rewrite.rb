require 'pathname'
require 'fileutils'
require 'shellwords'

BASE_DIR = Pathname.new(__FILE__) + '..'
require (BASE_DIR + 'helper').expand_path

class TestRunnerRewrite < Minitest::Test
  def assert_rewriter_output(path, args, input: 'input.rb', output: 'output.rb')
    @ruby_rewrite = BASE_DIR.expand_path + '../bin/ruby-rewrite'
    @test_dir     = BASE_DIR + path
    @fixtures_dir = @test_dir + 'fixtures'

    Dir.mktmpdir("parser", BASE_DIR.expand_path.to_s) do |tmp_dir|
      tmp_dir = Pathname.new(tmp_dir)
      sample_file = tmp_dir + "#{path}.rb"
      sample_file_expanded = sample_file.expand_path
      expected_file = @fixtures_dir + output

      FileUtils.cp(@fixtures_dir + input, sample_file_expanded)
      FileUtils.cd @test_dir do
        exit_code = system %Q{
          #{Shellwords.escape(@ruby_rewrite.to_s)} #{args} \
          #{Shellwords.escape(sample_file_expanded.to_s)}
        }
      end

      assert File.read(expected_file.expand_path) == File.read(sample_file),
        "#{sample_file} should be identical to #{expected_file}"
    end
  end

  def test_rewriter_bug_163
    assert_rewriter_output('bug_163', '--modify  -l rewriter.rb')
  end
end
