# Usage in conjunction with the Prism Parser Translator

Because `parser` only parses Ruby <= 3.3 and `prism` only Ruby >= 3.3, if you want to continue parsing both old and new versions, you need to depend on both `parser` and `prism`.

## Using `prism` when parsing with an explicit Ruby verion

```rb
require 'parser'
require 'prism'

def parser_for_ruby_version(ruby_version)
  case ruby_version
  when 3.1
    require 'parser/ruby31'
    Parser::Ruby31
  when 3.2
    require 'parser/ruby32'
    Parser::Ruby32
  when 3.3
    Prism::Translation::Parser33
  when 3.4
    Prism::Translation::Parser34
  else
    raise 'Unknown Ruby version'
  end
end

parser_for_ruby_version(3.4).parse(<<~RUBY)
  puts 'Hello World!'
RUBY
```

## Using `prism` when parsing ruby for the currently running Ruby version

If you are using `Parser::CurrentRuby`, you need to do similar branching logic. Do note that `prism` has no concept of a parser for the currently executing ruby version. As an alternative, you can manually extract the necessary version from the `RUBY_VERSION` constant:

```rb
def parser_for_current_ruby
  code_version = RUBY_VERSION.to_f

  if code_version <= 3.3
    require 'parser/current'
    Parser::CurrentRuby
  else
    require 'prism'
    case code_version
    when 3.3
      Prism::Translation::Parser33
    when 3.4
      Prism::Translation::Parser34
    else
      warn "Unknown Ruby version #{code_version}, using 3.4 as a fallback"
      Prism::Translation::Parser34
    end
  end
end

parser_for_current_ruby.parse(<<~RUBY)
  puts 'Hello World!'
RUBY
```

## Using a custom builder

If you are providing a custom builder (see [Customization](./CUSTOMIZATION.md)), you must create a copy that behaves the same for `prism`, but inherits from a different base class. This is because the builder used internally by `prism` has more functionality for more modern node types, which is lacking in the builder from `parser`.

```rb
# Use a module to not duplicate the implementation
module BuilderExtensions
  def self.inherited(base)
    # Always emit the most modern format available
    base.modernize
  end
end

class BuilderParser < Parser::Builders::Default
  include BuilderExtensions
end

class BuilderPrism < Prism::Translation::Parser::Builder
  include BuilderExtensions
end
```

You can then conditionally use the proper builder class, branching on the version of ruby that will get analyzed.

## New node types

As new syntax gets added to Ruby, the `prism` gem may emit nodes that have no counterpart in the `parser` gem. These nodes will be documented [in the usual place](./AST_FORMAT.md) but are otherwise not supported or emitted by the `parser` gem.
