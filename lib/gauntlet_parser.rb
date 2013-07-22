require 'gauntlet'
require 'parser/all'
require 'shellwords'

class ParserGauntlet < Gauntlet
  RUBY20 = 'ruby'
  RUBY19 = 'ruby1.9.1'
  RUBY18 = '/opt/rubies/ruby-1.8.7-p370/bin/ruby'

  def try(parser, ruby, file)
    begin
      parser.parse_file(file)
    rescue Parser::SyntaxError => e
      if e.diagnostic.location.resize(2).is?('<%')
        puts "ERb."
        return
      end

      Process.spawn(%{#{ruby} -c #{Shellwords.escape file}},
                    :err => '/dev/null', :out => '/dev/null')
      _, status = Process.wait2

      if status.success?
        # Bug in Parser.
        puts "Parser bug."
        @result[file] = { parser.to_s => "#{e.class}: #{e.to_s}" }
      else
        # No, this file is not Ruby.
        yield if block_given?
      end
    rescue Interrupt
      raise
    rescue Exception => e
      puts "Parser bug: #{e.to_s}"
      @result[file] = { parser.to_s => "#{e.class}: #{e.to_s}" }
    end
  end

  def parse(name)
    puts "GEM: #{name}"

    @result = {}

    Dir["**/*.rb"].each do |file|
      try(Parser::Ruby20, RUBY20, file) do
        puts "Trying 1.9:"
        try(Parser::Ruby19, RUBY19, file) do
          puts "Trying 1.8:"
          try(Parser::Ruby18, RUBY18, file) do
            puts "Invalid syntax."
          end
        end
      end
    end

    @result
  end

  def run(name)
    data[name] = parse(name)
    self.dirty = true
  end
end

filter = ARGV.shift
filter = Regexp.new filter if filter

gauntlet = ParserGauntlet.new

if ENV.include? 'UPDATE'
  gauntlet.source_index
  gauntlet.update_gem_tarballs
end

gauntlet.run_the_gauntlet filter
