require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rake/clean'

task :default => [:generate, :test]

Rake::TestTask.new do |t|
  t.libs       = %w(test/ lib/)
  t.test_files = FileList["test/**/test_*.rb"]
end

task :build => :generate_release

GENERATED_FILES = %w(lib/parser/lexer.rb
                     lib/parser/ruby18.rb
                     lib/parser/ruby19.rb
                     lib/parser/ruby20.rb
                     lib/parser/ruby21.rb)

CLEAN.include(GENERATED_FILES)

desc 'Generate the Ragel lexer and Bison parser.'
task :generate => GENERATED_FILES do
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

desc 'Generates YARD documentation'
task :yard => :generate do
  sh('yard doc')
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

