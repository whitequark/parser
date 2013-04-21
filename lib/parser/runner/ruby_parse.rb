module Parser

  class Runner::RubyParse < Parser::Runner
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
