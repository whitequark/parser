# Parser

[![Build Status](https://travis-ci.org/whitequark/parser.png?branch=master)](https://travis-ci.org/whitequark/parser)
[![Code Climate](https://codeclimate.com/github/whitequark/parser.png)](https://codeclimate.com/github/whitequark/parser)
[![Coverage Status](https://coveralls.io/repos/whitequark/parser/badge.png?branch=master)](https://coveralls.io/r/whitequark/parser)

_Parser_ is a Ruby parser written in pure Ruby.

## Installation

    $ gem install parser

## Usage

Parse a chunk of code:
```
require 'parser/ruby18'

p Parser::Ruby18.parse("2 + 2")
# (send
#   (int 2) :+
#   (int 2))
```

Parse a chunk of code and display all diagnostics:
```
parser = Parser::Ruby18.new
parser.diagnostics.consumer = lambda do |diag|
  puts diag.render
end

buffer = Parser::Source::Buffer.new('(string)')
buffer.source = "foo *bar"

p parser.parse(buffer)
# (string):1:5: warning: `*' interpreted as argument prefix
# foo *bar
#     ^
# (send nil :foo
#   (splat
#     (send nil :bar)))

```

## Features

 * Precise source location reporting.
 * [Documented](AST_FORMAT.md) AST format which is convenient to work with.
 * A simple interface and a powerful, tweakable one.
 * Parses 1.8, 1.9 and 2.0 syntax with backwards-compatible AST formats (WIP, only 1.8 yet).
 * Parsing error recovery.
 * Improved [clang-like][] diagnostic messages with location information.
 * Written in pure Ruby, runs on MRI >=1.9.2, JRuby and Rubinius in 1.9 mode.
 * Single runtime dependency: the [ast][] gem.
 * RubyParser compatibility (WIP, no, not really yet).
 * [Insane][insane-lexer] Ruby lexer rewritten from scratch in Ragel.
 * 100% test coverage for Bison grammars (except error recovery).
 * Readable commented source code.

  [clang-like]: clang.llvm.org/diagnostics.html
  [ast]: http://rubygems.org/gems/ast
  [insane-lexer]: http://whitequark.org/blog/2013/04/01/ruby-hacking-guide-ch-11-finite-state-lexer/

## Acknowledgements

The lexer testsuite and ruby_parser compatibility testsuite are derived from [ruby_parser](http://github.com/seattlerb/ruby_parser).

The Bison parser rules are derived from [Ruby MRI](http://github.com/ruby/ruby) parse.y.

## Contributing

1. Make sure you have [Ragel 6.8](http://www.complang.org/ragel/) installed
2. Fork it
3. Create your feature branch (`git checkout -b my-new-feature`)
4. Commit your changes (`git commit -am 'Add some feature'`)
5. Push to the branch (`git push origin my-new-feature`)
6. Create new Pull Request
