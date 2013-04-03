# Parser

[![Build Status](https://travis-ci.org/whitequark/parser.png?branch=master)](https://travis-ci.org/whitequark/parser)
[![Code Climate](https://codeclimate.com/github/whitequark/parser.png)](https://codeclimate.com/github/whitequark/parser)

Parser is a Ruby parser written in pure Ruby.

## Installation

    $ gem install parser

## Usage

TODO: Write usage instructions here

## Features

 * Precise source location reporting.
 * [Documented](SEXP_FORMAT.md) Sexp format.
 * A simple interface (`Parser::Ruby19.parse("just parse this")`) and a powerful, tweakable one.
 * Parses 1.8, 1.9 and 2.0 syntax with backwards-compatible Sexp formats (WIP, no, not really yet).
 * Improved diagnostic messages.
 * Written in pure Ruby, runs on MRI >=1.9.2, JRuby and Rubinius in 1.9 mode.
 * Single runtime dependency: the [ast][] gem.
 * RubyParser compatibility (WIP, no, not really yet).
 * [Insane][insane-lexer] Ruby lexer rewritten from scratch in Ragel.

  [ast]: http://rubygems.org/gems/ast
  [insane-lexer]: http://whitequark.org/blog/2013/04/01/ruby-hacking-guide-ch-11-finite-state-lexer/

## Anti-features

 * Line number values are not slightly off.
 * No unreadable source code or comments. (And no swearing!)

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
