require 'mkmf'

if RUBY_VERSION < '1.9'
  raise "Parser's smokin' hot native-code lexer can only be built on Ruby " \
        "1.9+. Sorry!"
end

$CFLAGS << ' -Wall -Werror -Wno-declaration-after-statement '
$CFLAGS << ' --std=c99 -march=native -mtune=native -O2 '
create_makefile 'lexer'
