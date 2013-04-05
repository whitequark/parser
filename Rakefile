require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rake/clean'

task :default => [:generate, :test]

Rake::TestTask.new do |t|
  t.test_files = FileList["test/**/test_*.rb"]
end

GENERATED_FILES = %w(lib/parser/lexer.rb
                     lib/parser/ruby18.rb)
                    #lib/parser/ruby19.rb)

CLEAN.include(GENERATED_FILES)

desc 'Generate the Ragel lexer and Bison parser.'
task :generate => GENERATED_FILES

task :build => :generate

rule '.rb' => '.rl' do |t|
  sh "ragel -R #{t.source} -o #{t.name}"
end

rule '.rb' => '.y' do |t|
  sh "racc --superclass=Parser::Base #{t.source} -o #{t.name}"
end
