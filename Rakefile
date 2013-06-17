# encoding:utf-8

require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rake/clean'

task :default => [:test]

Rake::TestTask.new do |t|
  t.libs       = %w(test/ lib/)
  t.test_files = FileList["test/**/test_*.rb"]
end

task :build => [:generate_release, :changelog]

GENERATED_FILES = %w(lib/parser/lexer.rb
                     lib/parser/ruby18.rb
                     lib/parser/ruby19.rb
                     lib/parser/ruby20.rb
                     lib/parser/ruby21.rb)

CLEAN.include(GENERATED_FILES)

desc 'Generate the Ragel lexer and Bison parser.'
task :generate => GENERATED_FILES do
  Rake::Task[:ragel_check].invoke
  GENERATED_FILES.each do |filename|
    content = File.read(filename)
    content = "# -*- encoding:utf-8; warn-indent:false -*-\n" + content

    File.open(filename, 'w') do |io|
      io.write content
    end
  end
end

task :regenerate => [:clean, :generate]

desc 'Generate the Ragel lexer and Bison parser in release mode.'
task :generate_release => [:clean_env, :regenerate]

task :clean_env do
  ENV.delete 'RACC_DEBUG'
end

task :ragel_check do
  major_req, minor_req = 6, 8

  ragel_check = `which ragel && ragel --version`
  ragel_version = ragel_check.match(/version (([0-9]+)\.([0-9]+))/)
  raise 'command-line dependency ragel not installed!' unless ragel_version

  _, version_str, major, minor = *ragel_version
  if (major.to_i != major_req || minor.to_i < minor_req) # ~> major.minor
    raise "command-line dependency ragel must be " +
          "~> #{major_req}.#{minor_req}; got #{version_str}"
  end
end

desc 'Generate YARD documentation'
task :yard => :generate do
  sh('yard doc')
end

desc 'Generate Changelog'
task :changelog do
  fs     = "\u{fffd}"
  format = "%d#{fs}%s#{fs}%an#{fs}%ai"

  # Format: version => { commit-class => changes }
  changelog = Hash.new do |hash, version|
    hash[version] = Hash.new do |hash, klass|
      hash[klass] = []
    end
  end

  IO.popen("git log --pretty='#{format}' HEAD", 'r') do |io|
    current_version = nil

    io.each_line do |line|
      version, message, author, date = line.
            match(/^(?: \((.*)\))?#{fs}(.*)#{fs}(.*)#{fs}(.*)$/o).captures
      date = Date.parse(date)

      current_version = "#{$1} (#{date})" if version =~ /(v[\d\w.]+)/
      current_version = "v#{Parser::VERSION} (#{date})" if version =~ /HEAD/

      next if current_version.nil? || message !~ /^[+*-]/

      changelog[current_version][message[0]] << "#{message[1..-1]} (#{author})"
    end
  end

  commit_classes = {
    '*' => 'API modifications:',
    '+' => 'Features implemented:',
    '-' => 'Bugs fixed:',
  }

  File.open('CHANGELOG.md', 'w') do |io|
    io.puts 'Changelog'
    io.puts '========='
    io.puts

    changelog.each do |version, commits|
      io.puts version
      io.puts '-' * version.length
      io.puts

      commit_classes.each do |sigil, description|
        next unless commits[sigil].any?

        io.puts description
        commits[sigil].each do |commit|
          io.puts " * #{commit.gsub('<', '\<').lstrip}"
        end
        io.puts
      end
    end
  end

  sh('git commit CHANGELOG.md -m "Update changelog."')
end

rule '.rb' => '.rl' do |t|
  sh "ragel -R #{t.source} -o #{t.name}"
end

rule '.rb' => '.y' do |t|
  opts = [ "--superclass=Parser::Base",
           t.source,
           "-o", t.name
         ]
  opts << "--debug" if ENV['RACC_DEBUG']

  sh "racc", *opts
end

task :test => [:generate]
