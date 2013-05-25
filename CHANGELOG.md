Changelog
=========

2.0.0.beta1 (2013-05-25)
------------------------

API modifications:
 * Completely rewrite whitespace handling in lexer (fixes #36). (Peter Zotov)
 * Rename Parser::AST::Node#source_map to #location, #src to #loc (closes #40). (Peter Zotov)
 * Rename Parser::Source::Range#to_source to #source (refs #40). (Peter Zotov)
 * Rename (cdecl) node to (casgn), remove (cvdecl) nodes (fixes #26). (Peter Zotov)

Features implemented:
 * Add Source::Comment.associate for mapping comments back to nodes (fixes #31). (Peter Zotov)
 * Return AST and comments from Parser::Base#parse_with_comments. (Peter Zotov)
 * Return comments from Parser::Base#tokenize (fixes #46). (Peter Zotov)
 * Add tokenizer, Parser::Base#tokenize (refs #46). (Peter Zotov)
 * lexer.rl: better location reporting for invalid unicode codepoints (fixes #38). (Peter Zotov)
 * lexer.rl: better location reporting for unterminated =begin (fixes #37). (Peter Zotov)
 * Better location reporting for hashes with labels. (Peter Zotov)
 * Add `dot' source map to (send) nodes (fixes #34). (Peter Zotov)
 * Significantly improve performance of Source::Buffer (fixes #28). (Peter Zotov)

Bugs fixed:
 * lexer.rl: fix lexing label at line_begin "foo:bar" (fixes #48). (Peter Zotov)
 * lexer.rl: "Option /^I/" is a method call (fixes #32). (Peter Zotov)
 * Don't allow destructive mutation of line cache in Source::Buffer. (Peter Zotov)
 * Fix quantifier in magic encoding parser (refs #33). (Peter Zotov)
 * Better handling of magic encoding comment edge cases (fixes #33). (Peter Zotov)

v1.3.2 (2013-05-13)
-------------------

Features implemented:
 * lexer.rl: disallow "$-" (dollar, dash, no character) special. (Peter Zotov)

Bugs fixed:
 * Source::Range: fix #to_source for multiline ranges. (Peter Zotov)
 * builders/default: source map for class/module name (fixes #24). (Peter Zotov)

v1.3.1 (2013-05-09)
-------------------

Bugs fixed:
 * ruby{19,20,21}.y: "def foo\n=begin\n=end\nend" (fixes #22). (Peter Zotov)
 * lexer.rl: "rescue::Exception" (fixes #23). (Peter Zotov)

v1.3.0 (2013-04-26)
-------------------

Bugs fixed:
 * lexer.rl: "alias foo bar \n alias bar baz". (Peter Zotov)

v1.2.0 (2013-04-25)
-------------------

Bugs fixed:
 * lexer.rl: lex "def String.foo; end" correctly (fixes #16). (Peter Zotov)
 * lexer.rl: reject "1end", "1.1end". (Peter Zotov)

v1.1.0 (2013-04-18)
-------------------

API modifications:
 * ruby19.y, ruby20.y, ruby21.y: check for Encoding support (fixes #9). (Peter Zotov)

Features implemented:
 * builders/default: ignore duplicate _ args (>=1.9), _.* args (>1.9) (fixes #5). (Peter Zotov)
 * builders/default: detect duplicate argument names (refs #5). (Peter Zotov)
 * lexer.rl: "def foo bar: 1; end" (for ruby 2.1) (fixes #15). (Peter Zotov)
 * ruby21.y: required keyword arguments. (Peter Zotov)

Bugs fixed:
 * ruby20.y, ruby21.y: "foo::A += 1" and friends (scoped constant op-asgn). (Peter Zotov)

v1.0.1 (2013-04-18)
-------------------

Bugs fixed:
 * builders/default: %Q{#{1}} and friends (fixes #14). (Peter Zotov)

v1.0.0 (2013-04-17)
-------------------

Features implemented:
 * ruby20.y: "meth 1 do end.fun(bar) {}" and friends. (Peter Zotov)
 * ruby20.y: keyword arguments. (Peter Zotov)
 * ruby20.y: { **kwsplat }. (Peter Zotov)

v0.9.2 (2013-04-16)
-------------------

Features implemented:
 * lexer.rl: "-> (a) {}". (Peter Zotov)
 * builders/default: treat &&/|| lhs/rhs as conditional context. (Peter Zotov)
 * ruby20.y: "class Foo \< a:b; end". (Peter Zotov)
 * lexer.rl: "class \<\< a:b". (Peter Zotov)
 * ruby19.y, ruby20.y: "f { || a:b }". (Peter Zotov)
 * ruby19.y, ruby20.y: "def foo() a:b end", "def foo\n a:b end". (Peter Zotov)
 * lexer.rl: %i/%I. (Peter Zotov)
 * lexer.rl: warn at "foo **bar". (Peter Zotov)
 * lexer.rl: ** at expr_beg is tDSTAR. (Peter Zotov)
 * ruby20.y: "f {|;\nvar\n|}". (Peter Zotov)
 * ruby20.y: "p () {}". (Peter Zotov)
 * ruby20.y: "p begin 1.times do 1 end end". (Peter Zotov)
 * ruby20.y: better error message for BEGIN{} in a method body. (Peter Zotov)

Bugs fixed:
 * lexer.rl, ruby18.y, ruby19.y, ruby20.y: "%W[#{a}#@b foo #{c}]". (Peter Zotov)
 * lexer.rl: parse "foo=1; foo / bar #/" as method call on 1.8, division on 1.9. (Peter Zotov)
 * ruby18.y, ruby19.y: BEGIN{} does not introduce a scope. (Peter Zotov)
 * lexer.rl: improve whitespace handling. (Peter Zotov)

v0.9.0 (2013-04-15)
-------------------

API modifications:
 * runtime compatibility with 1.8.7. (Peter Zotov)

Features implemented:
 * builders/default: check for multiple assignment in conditions (fixes #4). (Peter Zotov)
 * builders/default: check if actual block and blockarg are passed (fixes #6). (Peter Zotov)
 * ruby19.y: "foo::A += m foo". (Peter Zotov)
 * ruby18.y, ruby19.y: "rescue without else is useless" warning. (Peter Zotov)
 * ruby19.y: 99.16% coverage, 100% sans error recovery. (Peter Zotov)
 * ruby19.y: mlhs arguments "def foo((a, *, p)) end". (Peter Zotov)
 * ruby19.y: "fun (1) {}" and friends. (Peter Zotov)
 * ruby19.y: mlhs post variables "a, *b, c = ...". (Peter Zotov)
 * builders/default: @@a |= 1; def f; @@a |= 1; end. (Peter Zotov)
 * ruby18.y: fun (&foo). (Peter Zotov)
 * ruby18.y: block formal arguments. 99.33% coverage. (Peter Zotov)
 * ruby18.y: fun(meth 1 do end); fun(1, meth 1 do end). (Peter Zotov)
 * ruby18.y: "meth 1 do end.fun(bar)" and friends. (Peter Zotov)
 * ruby18.y: foo () {}; a.foo () {}; a::foo () {}. (Peter Zotov)
 * ruby18.y: various call argument combinations. (Peter Zotov)
 * ruby18.y: foo (1, 2); foo (). (Peter Zotov)
 * ruby18.y: foo (1).to_i. (Peter Zotov)
 * ruby18.y: fun{}; fun(){}; fun(1){}; fun do end. (Peter Zotov)
 * ruby18.y: foo.fun bar. (Peter Zotov)
 * lexer.rl, ruby18.y: add support for cond/cmdarg stack states. (Peter Zotov)
 * ruby18.y: rescue. (Peter Zotov)
 * ruby18.y: begin end while|until (tests only). (Peter Zotov)
 * ruby18.y: case. (Peter Zotov)
 * ruby18.y: foo[m bar]. (Peter Zotov)
 * ruby18.y: for..in. (Peter Zotov)

Bugs fixed:
 * lexer.rl: handle : at expr_beg as a symbol, at expr_end as tCOLON. (Peter Zotov)
 * lexer.rl: handle "rescue #foo\nbar". (Peter Zotov)
 * lexer.rl: handle "foo.#bar\nbaz". (Peter Zotov)
 * lexer.rl: fix location info for symbols. (Peter Zotov)
 * lexer.rl: handle \<backslash>\<nl> at expr_beg. (Peter Zotov)
 * lexer.rl: emit tCONSTANT/tIDENTIFIER/tFID in expr_dot. (Peter Zotov)
 * lexer.rl: correctly disambiguate "x ::Foo" as tIDENT, tCOLON3, ... (Peter Zotov)
 * lexer.rl: correctly disambiguate ident!= as tIDENTIFIER, tNEQ. (Peter Zotov)
 * lexer.rl: correctly report the %r%% tREGEXP_BEG value as %r%. (Peter Zotov)
 * ruby19.y: emit correct error on "nil = 1" and friends. (Peter Zotov)
 * ruby19.y: 1.9 permits empty symbol literals. (Peter Zotov)
 * ruby18.y: foo(&bar). (Peter Zotov)
 * lexer.rl: don't lookahead two tokens on "func %{str} do". (Peter Zotov)
 * lexer.rl: fix lexing of non-interp heredoc with trailing backslash. (Peter Zotov)
 * lexer.rl: fix erroneous number and =begin lookahead in expr_beg. (Peter Zotov)
 * lexer.rl: fix stack corruption. (Peter Zotov)
 * lexer.rl: /= at expr_beg. (Peter Zotov)
 * lexer.rl: class\<\<self. (Peter Zotov)
 * fix lexing comments at expr_beg "{#1\n}". (Peter Zotov)

