module Parser

  module Lexer::Explanation

    # Like #advance, but also pretty-print the token and its position
    # in the stream to `stdout`.
    def advance_and_explain
      type, (val, range) = advance

      puts decorate(range,
                    "\e[0;32m#{type} #{val.inspect}\e[0m",
                    "#{state.to_s.ljust(10)} #{@cond} #{@cmdarg}\e[0m")

      [ type, [val, range] ]
    end

    private

    def decorate(range, token, info)
      from, to = range.begin.column, range.end.column

      line = range.source_line
      line[from...to] = "\e[4m#{line[from...to]}\e[0m"

      tail_len   = to - from - 1
      tail       = "~" * (tail_len >= 0 ? tail_len : 0)
      decoration =  "#{" " * from}\e[1;31m^#{tail}\e[0m #{token} ".
                        ljust(70) + info

      [ line, decoration ]
    end

  end

  Lexer.send :include, Lexer::Explanation

end
