require 'parser/runner'
require 'parser/lexer/explanation'

module Parser

  class Runner::RubyParse < Parser::Runner

    class LocationProcessor < Parser::AST::Processor
      def process(node)
        p node

        if node.src.nil?
          puts "\e[31m[no location info]\e[0m"
        elsif node.src.expression.nil?
          puts "\e[31m[location info present but empty]\e[0m"
        else
          puts "\e[32m#{node.src.expression.source_line}\e[0m"

          hilight_line = ""

          print_line = lambda do |line|
            puts line.
              gsub(/[a-z_]+/) { |m| "\e[1;33m#{m}\e[0m" }.
              gsub(/~+/)      { |m| "\e[1;35m#{m}\e[0m" }
          end

          node.src.to_hash.each do |name, range|
            next if range.nil?

            length    = range.length + 1 + name.length
            end_col   = range.begin.column + length
            col_range = range.begin.column...end_col

            if hilight_line.length < end_col
              hilight_line = hilight_line.ljust(end_col)
            end

            if hilight_line[col_range] =~ /^\s*$/
              hilight_line[col_range] = '~' * range.length + " #{name}"
            else
              print_line.(hilight_line)
              hilight_line = ""
              redo
            end
          end

          print_line.(hilight_line) unless hilight_line.empty?
        end

        super
      end
    end

    private

    def runner_name
      'ruby-parse'
    end

    def setup_option_parsing
      super

      @slop.on 'L', 'locate',  'Explain how source maps for AST nodes are laid out'

      @slop.on 'E', 'explain', 'Explain how the source is tokenized' do
        ENV['RACC_DEBUG'] = '1'

        Parser::Base.class_eval do
          def next_token
            @lexer.advance_and_explain
          end
        end
      end
    end

    def process(buffer)
      ast = @parser.parse(buffer)

      if @slop.locate?
        LocationProcessor.new.process(ast)
      elsif !@slop.benchmark?
        p ast
      end
    end
  end

end
