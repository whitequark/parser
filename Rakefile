require "bundler/gem_tasks"

task :default => [:generate, :test]

task :test do
  $LOAD_PATH << File.expand_path('../lib/', __FILE__)
  Dir['test/test_*.rb'].each do |file|
    load file
  end
end

desc 'Generate the Ragel lexer and Bison parser.'
task :generate => %w(lib/parser/lexer.rb
                     lib/parser/ruby18.rb)
                    #lib/parser/ruby19.rb)

task :build => :generate

rule '.rb' => '.rl' do |t|
  sh "ragel -R #{t.source} -o #{t.name}"
end

rule '.rb' => '.y' do |t|
  # `bundle exec` to use the racc from git (specified in Gemfile),
  # to avoid installation error on JRuby. See also the issue
  # https://github.com/tenderlove/racc/issues/22.
  sh "bundle exec racc --superclass=Parser::Base #{t.source} -o #{t.name}"
end
