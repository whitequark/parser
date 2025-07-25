Changelog
=========

v3.3.9.0 (2025-07-25)
---------------------

API modifications:
 * Bump maintenance branches to 3.3.9 (#1080) (Koichi ITO)
 * Bump maintenance branches to 3.2.9 (#1079) (Koichi ITO)

v3.3.7.5 (2025-04-14)
---------------------

API modifications:
 * Bump maintenance branches to 3.3.8 (#1077) (Koichi ITO)
 * YARD docs for Parser::CurrentRuby and Parser::Base#version (#1076) (Vince Broz)

v3.3.7.4 (2025-03-31)
---------------------

Bugs fixed:
 * lexer-strings.rb: Avoid an exception on utf8 surrogate pair codepoints (#1051) (Earlopain)
 * builder.rb: emit `kwargs` node for `indexasgn` when opted in (#1053) (Earlopain)
 * builder.rb: correctly handle `...` forwarding to super with explicit block (#1049) (Earlopain)
 * numbered parameters are valid for pattern matching pinning (#1060) (Earlopain)

v3.3.7.3 (2025-03-26)
---------------------

API modifications:
 * Bump maintenance branches to 3.2.8 and 3.1.7 (#1074) (Koichi ITO)

v3.3.7.2 (2025-03-20)
---------------------

Features implemented:
 * add prism-specific node types (#1071) (Earlopain)

Bugs fixed:
 * builder.rb: fix hash value omission considering some local vars as constants (#1064) (Earlopain)

v3.3.7.1 (2025-02-05)
---------------------

API modifications:
 * parser/current: add -dev prefix to 3.4 branch (#1067) (Ilya Bylich)
 * parser/current: bump 3.2 branch to 3.2.7 (#1066) (Ilya Bylich)

v3.3.7.0 (2025-01-16)
---------------------

API modifications:
 * Bump maintenance branches to 3.3.7 (#1061) (Koichi ITO)
 * bump 3.4 branch, remove 3.0 from CI (EOL) (#1057) (Ilya Bylich)
 * assert that version-specific checks actually run against at least one version (#1050) (Earlopain)

Features implemented:
 * ruby34.y: reject `return` in singleton class (#1048) (Earlopain)

Bugs fixed:
 * Fix `ruby-parse` with a folder ending in `.rb` (#1047) (Earlopain)

v3.3.6.0 (2024-11-05)
---------------------

API modifications:
 * Bump maintenance branches to 3.3.6 (#1045) (Koichi ITO)

v3.3.5.1 (2024-10-31)
---------------------

API modifications:
 * Bump maintenance branches to 3.2.6 (#1044) (Koichi ITO)

v3.3.5.0 (2024-09-04)
---------------------

API modifications:
 * Bump maintenance branches to 3.3.5 (#1039) (Koichi ITO)

v3.3.4.2 (2024-08-08)
---------------------

Bugs fixed:
 * Fix errros in the ascii specs of RuboCop (#1037) (Koichi ITO)

v3.3.4.1 (2024-08-07)
---------------------

API modifications:
 * Bump 3.2 branch to 3.2.5. (#1036) (Ilya Bylich)
 * Bump Racc to 1.8.1 (#1031) (Koichi ITO)

Bugs fixed:
 * builder.rb: catch encoding errors when parsing invalid encoding regexp (#1033) (Earlopain)

v3.3.4.0 (2024-07-10)
---------------------

API modifications:
 * Bump maintenance branches to 3.3.4 (#1027) (Koichi ITO)

v3.3.3.0 (2024-06-12)
---------------------

API modifications:
 * Bump maintenance branches to 3.3.3 (#1023) (Koichi ITO)
 * Bump Racc to 1.8.0 (#1018) (Koichi ITO)

v3.3.2.0 (2024-05-30)
---------------------

API modifications:
 * Bump 3.3 branch to 3.3.2 (Ilya Bylich)
 * Bump 3.1 branch to 3.1.6 (#1014) (Koichi ITO)

v3.3.1.0 (2024-04-26)
---------------------

API modifications:
 * Bump parser branches to 3.0.7, 3.1.5, 3.2.4, 3.3.1 (#1011) (Ilya Bylich)

Features implemented:
 * ruby{33,34}.y: allow blocks inherit anonymous args. (#1010) (Ilya Bylich)

ve (2024-03-18)
---------------

API modifications:
 * Use `require_relative` in the Parser codebase (#1003) (Koichi ITO)

Features implemented:
 * Raise a more specific error when encountering an unknown magic comment encoding (#999) (Earlopain)

v3.3.0.5 (2024-01-21)
---------------------

API modifications:
 * Bump 3.2 branch to 3.2.3 (#993) (Koichi ITO)

v3.3.0.4 (2024-01-15)
---------------------

Features implemented:
 * Register a Ruby 3.4 parser (#991) (Jean byroot Boussier)

v3.3.0.3 (2024-01-12)
---------------------

Bugs fixed:
 * lexer.rl: accept tabs before closing heredoc delimiter (#990) (Ilya Bylich)

v3.3.0.2 (2024-01-07)
---------------------

Bugs fixed:
 * Fix an error when using heredoc with non-word delimiters (#987) (Koichi ITO)

v3.3.0.1 (2024-01-06)
---------------------

Bugs fixed:
 * Supports Ruby 2.0+ runtime (#986) (Koichi ITO)

v3.3.0.0 (2024-01-05)
---------------------

API modifications:
 * current.rb: mark 3.3 branch as stable (#984) (Ilya Bylich)
 * ruby33.y: extract string_dend (#969) (Ilya Bylich)
 * lexer.rl: treat numparams as locals (#968) (Ilya Bylich)
 * ruby33.y: extract words_sep (#967) (Ilya Bylich)
 * literal.rb: match heredoc identifier from end of line (#965) (Ilya Bylich)
 * ruby33.y: extract {endless_command,endless_arg} rules (#964) (Ilya Bylich)
 * Bump Racc to 1.7.3 (#954) (Koichi ITO)

Features implemented:
 * ruby33.y: reject ambiguous anonymous arguments (#983) (Ilya Bylich)
 * ruby33.y: extract arg_splat rule. (#981) (Ilya Bylich)
 * builder.rb: warn `it` in a block with no ordinary params. (#980) (Ilya Bylich)
 * builder.rb: extract named captures only from static regexes. (#979) (Ilya Bylich)
 * ruby33.y: accept expr_value in sclass definition. (#978) (Ilya Bylich)
 * ruby33.y: extract p_in_kwarg (#977) (Ilya Bylich)
 * ruby33.y: extract p_assoc and p_in rules (#976) (Ilya Bylich)
 * ruby33.y: reject invalid gvar as symbol (#974) (Ilya Bylich)
 * ruby33.y: properly restore in_defined flag, extract begin_defined rule (#973) (Ilya Bylich)
 * builder.rb: reject multi-char gvar names starting with 0 (#972) (Ilya Bylich)
 * ruby33.y: allow semicolon in parenthesis at the first argument of command call (#971) (Ilya Bylich)
 * ruby33.y: parse qualified const with brace block as a method call (#970) (Ilya Bylich)

v3.2.2.4 (2023-10-04)
---------------------

API modifications:
 * bump Racc to 1.7.1 (#930) (Koichi ITO)

Bugs fixed:
 * Fix an error for flip-flop with beginless or endless ranges (#946) (Koichi ITO)

v3.2.2.3 (2023-06-08)
---------------------

API modifications:
 * Add Racc to runtime dependencies (#929) (Koichi ITO)

v3.2.2.2 (2023-06-08)
---------------------

API modifications:
 * bump racc to 1.7.0 (#928) (Ilya Bylich)

v3.2.2.0 (2023-04-01)
---------------------

API modifications:
 * Bump maintenance branches to 3.2.2, 3.1.4, 3.0.6, and 2.7.8 (#920) (Koichi ITO)

v3.2.1.1 (2023-03-08)
---------------------

API modifications:
 * bump racc to 1.6.2 (#916) (Ilya Bylich)
 * backport tests for mixed usage of anonymous kwarg/kwrestarg and forwarded-arguments (#915) (Ilya Bylich)
 * add tests for kwopt+kwrest arguments and forwarded_kwrestarg. (#913) (Ilya Bylich)

Bugs fixed:
 * builders/default: allow forwarded_kwrestarg with additional kwargs (#912) (Owen Stephens)

v3.2.1.0 (2023-02-09)
---------------------

API modifications:
 * Bump maintenance branches to 3.2.1 (#908) (Koichi ITO)
 * lexer.rl: extract strings lexing to lexer-strings.rl (#905) (Ilya Bylich)

Features implemented:
 * Ruby 3.3 support (#904) (Ole Friis Østergaard)

v3.2.0.0 (2023-01-03)
---------------------

API modifications:
 * lexer.rl: extract `extend_string_escaped` to a separate method (#893) (Ilya Bylich)
 * bump Racc to 1.6.1 (#890) (Koichi ITO)

Features implemented:
 * lexer.rl: use Ragel -F0 on non-CRuby (#894) (Benoit Daloze)
 * ruby32.y: Allow optional newlines before closing parenthesis (#892) (Koichi ITO)

Bugs fixed:
 * ruby32.y: fix a parse error when using forwarded argument with restarg (#889) (Koichi ITO)

v3.1.3.0 (2022-11-25)
---------------------

API modifications:
 * Bump maintenance branches to 3.1.3, 3.0.5, 2.7.7 (#886) (Koichi ITO)
 * ruby32.y: reuse nonlocal_var rule. (#879) (Ilya Bylich)
 * ruby32.y: reuse opt_nl rule. (#878) (Ilya Bylich)

Features implemented:
 * ruby32.y: implement forwarded restarg and kwrestarg. (#874) (Ilya Bylich)

v3.1.2.1 (2022-08-08)
---------------------

Bugs fixed:
 * ruby31.y: fix preparing the state for one-line patterns without braces (#864) (Vladimir Dementyev)

v3.1.2.0 (2022-04-12)
---------------------

API modifications:
 * Bump maintenance branches to 3.1.2, 3.0.4, 2.7.6, and 2.6.10 (#850) (Koichi ITO)

Bugs fixed:
 * ruby32.y: fix using p_kwnorest in f_no_kwarg (#848) (Vladimir Dementyev)

v3.1.1.0 (2022-02-21)
---------------------

API modifications:
 * Bump 3.1 branch to 3.1.1 (Koichi ITO)

Features implemented:
 * ruby32.y: Reuse operation rule for operation2 (Koichi ITO)
 * ruby32.y: Reuse p_kwnorest rule for f_no_kwarg (Koichi ITO)
 * ruby-parse: add ability to read fragment from stdin (#844) (Jeremy Stanley)
 * ruby32.y: reduce p_args with p_rest (#843) (Vladimir Dementyev)
 * ruby32.y: branch parser (#841) (Ilya Bylich)

v3.1.0.0 (2022-01-03)
---------------------

API modifications:
 * parser/current: update for 3.1.0 release. (#840) (Ilya Bylich)

Features implemented:
 * ruby31.y: accept forward arg without parentheses. (#839) (Ilya Bylich)

v3.0.3.2 (2021-12-08)
---------------------

Bugs fixed:
 * dedenter.rb: fix an encoding/squiggly heredoc regression (#836) (hmdne)

v3.0.3.1 (2021-11-29)
---------------------

Features implemented:
 * ruby31.y: parse anonymous block argument. (#833) (Ilya Bylich)
 * ruby31.y: parse forward argument without parentheses (#832) (Ilya Bylich)

v3.0.3.0 (2021-11-25)
---------------------

API modifications:
 * Bump maintenance branches to 3.0.3, 2.7.5, and 2.6.9 (#829) (Koichi ITO)

Features implemented:
 * lexer.rl: parse meta-control-hex chars in regexes starting from 3.1 (#828) (Ilya Bylich)
 * builder.rb: warn on duplicate hash key literals. (#827) (Ilya Bylich)
 * ruby31.y: Allow value omission in Hash literals (#818) (Svyatoslav Kryukov)
 * ruby31.y: Allow omission of parentheses in one line pattern matching (#816) (Koichi ITO)
 * ruby31.y: Add pattern matching pin support for instance/class/global variables (#813) (Koichi ITO)

Bugs fixed:
 * ruby31.y: handle local variables as hash labels with omitted values (#820) (Ilya Bylich)
 * lexer.rl: Fix handling of beginless ranges at start of line (#822) (Matijs van Zuijlen)
 * dedenter.rb: Fix squiggly heredoc line continuation handling (#819) (Matijs van Zuijlen)
 * lexer.rl: fix incompatible delimiters on percent literal (#808) (Masataka Pocke Kuwabara)

v3.0.2.0 (2021-07-08)
---------------------

API modifications:
 * Bump maintenance branches to 3.0.2, 2.7.4, and 2.6.8 (#805) (Koichi ITO)

Features implemented:
 * lexer.rl: reject `\u` after control/meta escape chars. (#807) (Ilya Bylich)
 * ruby31.y: allow "command" syntax in endless method definition (#801) (Koichi ITO)

v3.0.1.1 (2021-05-02)
---------------------

Features implemented:
 * Add `associate_by_identity` as an alternate to `associate` (#798) (Marc-André Lafortune)
 * ruby31.y: pin operator with expression (#797) (Ilya Bylich)
 * ruby31.y: branch parser (#792) (Koichi ITO)

Bugs fixed:
 * fix a false positive for endless method definition (#796) (Koichi ITO)

v3.0.1.0 (2021-04-06)
---------------------

API modifications:
 * Bump maintenance branches to 3.0.1, 2.7.3, 2.6.7, and 2.5.9 (#791) (Koichi ITO)

Features implemented:
 * `Source::TreeRewriter#inspect` [#728] (#788) (Marc-André Lafortune)
 * `Source::Buffer#inspect` [#728] (#787) (Marc-André Lafortune)

v3.0.0.0 (2020-12-25)
---------------------

API modifications:
 * current.rb: bump default branch to parser/ruby30. (#782) (Ilya Bylich)
 * do not emit truncated parts of squiggly heredoc (#774) (Ilya Bylich)
 * Optimize `SourceBuffer` line and column handling (#755) (Marc-André Lafortune)

Features implemented:
 * ruby30.y: reintroduce `expr in pat` (#777) (Ilya Bylich)
 * builder: emit implicit hash passed to a method call as kwargs (#769) (Ilya Bylich)
 * lexer.rl: use more specific warning for ambiguous slash. (#768) (Ilya Bylich)
 * ruby30.y: allow endless method without arglist. (#765) (Ilya Bylich)
 * ruby30.y: use `=>` for one-line pattern matching. (#760) (Ilya Bylich)
 * ruby30.y: reject setters in all endless method defs. (#758) (Ilya Bylich)

Bugs fixed:
 * lexer.rl: don't perform lookahead after tASSOC. (#764) (Ilya Bylich)

v2.7.2.0 (2020-10-06)
---------------------

API modifications:
 * Bump 2.7 branch to 2.7.2 (#748) (Koichi ITO)

v2.7.1.5 (2020-09-24)
---------------------

API modifications:
 * right assignment: use existing AST node types (#738) (#739) (Marc-André Lafortune)
 * ruby28.y -> ruby30.y (#729) (Vladimir Dementyev)

Features implemented:
 * Optimize Range#column_range (#741) (Marc-André Lafortune)
 * ruby30.y: reject endless setter. (#736) (Ilya Bylich)
 * ruby28.y: reject assignment to numparam. (#725) (Ilya Bylich)
 * emit "endless method def" as `:def` node. (#716) (Ilya Bylich)

Bugs fixed:
 * rename 2.8 to 3.0 everywhere (#732) (Ilya Bylich)
 * test_current.rb: 2.8 -> 3.0 (#731) (Vladimir Dementyev)
 * Parser#parse returns nil instead of false if error is thrown (#722) (Marc-André Lafortune)
 * unify locations for normal and endless method definition (#718) (Marc-André Lafortune)
 * ruby27.y: accept const names as hash keys for pattern matching (#717) (Koichi ITO)
 * Fix locations for alias / undef nodes with internal symbols (#715) (Marc-André Lafortune)

v2.7.1.4 (2020-06-19)
---------------------

Features implemented:
 * ruby28.y: add find pattern. (#714) (Ilya Bylich)
 * lexer.rl: reject `->...` and `->(...)` with the same error. (#713) (Ilya Bylich)
 * ruby28.y: accept leading args before forward arg. (#712) (Ilya Bylich)
 * Added `emit_forward_arg` compatibility flag. (#710) (Ilya Bylich)
 * ruby28.y: include entire lambda expr in lambda rule. (#708) (Ilya Bylich)
 * ruby28.y: extracted excessed_comma rule. (#706) (Ilya Bylich)
 * Source::TreeRewriter: Improved merging and representations (#703) (Marc-André Lafortune)

Bugs fixed:
 * ruby*.y: fixed context inside lambda args and module. (#709) (Ilya Bylich)

v2.7.1.3 (2020-05-26)
---------------------

API modifications:
 * fixed all warnings. tests are running in verbose mode now. (#685) (Ilya Bylich)

Features implemented:
 * ruby-[parse, rewrite]: add legacy switches (#699) (Marc-André Lafortune)
 * Added Parser::Source::Range#to_range. (#697) (Ilya Bylich)
 * ruby28.y: support rescue modifier in endless method definition. (#696) (Ilya Bylich)
 * ruby28.y: unify kwrest and no-kwrest rules. (#694) (Ilya Bylich)
 * ruby28.y: add right hand assignment (#682) (Vladimir Dementyev)

Bugs fixed:
 * fix Comment.associate for postfix conditions/loops (#688) (Marc-André Lafortune)

v2.7.1.2 (2020-04-30)
---------------------

Features implemented:
 * ruby28.y: endless method definition (#676) (Vladimir Dementyev)
 * ruby28.y: branch parser (#677) (Vladimir Dementyev)

Bugs fixed:
 * ruby27.y: reject invalid lvar in pattern matching (#680) (Vladimir Dementyev)

v2.7.1.1 (2020-04-15)
---------------------

Features implemented:
 * Add Source::Range#eql? and hash (#675) (Marc-André Lafortune)
 * Source::TreeRewriter: Add #merge, #merge! and #empty? (#674) (Marc-André Lafortune)

v2.7.1.0 (2020-04-03)
---------------------

API modifications:
 * Bump ruby versions to 2.4.10, 2.5.8, 2.6.6, 2.7.1. (#665) (Ilya Bylich)

Features implemented:
 * ruby27.y: allow newlines inside braced pattern. (#664) (Ilya Bylich)
 * ruby27.y: Allow trailing comma in hash pattern (#661) (Koichi ITO)

v2.7.0.5 (2020-03-20)
---------------------

Features implemented:
 * ruby27.y: fix array pattern with tail source map (#659) (Vladimir Dementyev)

Bugs fixed:
 * builder.rb: fix constant_pattern source map (#660) (Vladimir Dementyev)

v2.7.0.4 (2020-03-02)
---------------------

Bugs fixed:
 * lexer.rl: allow spaces before comments-before-leading-dot. (#654) (Ilya Bylich)

v2.7.0.2 (2020-01-08)
---------------------

Bugs fixed:
 * lexer.rl: fix paren_nest for curly braces (#646) (Ilya Bylich)

v2.7.0.1 (2019-12-30)
---------------------

Bugs fixed:
 * dedenter.rb: prevent `ArgumentError` when processing binary en… (#642) (Koichi ITO)

v2.7.0.0 (2019-12-26)
---------------------

API modifications:
 * README.md: documented compatibility issue with EOF chars after… (#637) (Ilya Bylich)
 * ruby27.y: refactor logic around 'circular argument reference'(#628) (Ilya Bylich)

Features implemented:
 * ruby27.y: added pattern matching (#574) (Ilya Bylich)
 * lexer.rl: parse embedded ivars/cvars starting with digit as str (#639) (Ilya Bylich)
 * lexer.rl: warn on `...` at EOL. (#636) (Ilya Bylich)
 * ruby27.y: removed opt_block_args_tail: tOROP rule. (#635) (Ilya Bylich)
 * ruby27.y: reverted method reference operator (added in #634) (Ilya Bylich)
 * ruby27.y: treat numparams as locals outside numblock. (#633) (Ilya Bylich)

Bugs fixed:
 * dedenter.rb: fixed over-dedenting of squiggly heredocs (#641) (Ilya Bylich)
 * ruby27.y: added "arguments forwarding" (#625) (Ilya Bylich)
 * ruby27.y: reject circular argument reference. (#622) (Ilya Bylich)
 * ruby27.y: changed prefix of numparams to "_" (#620) (Ilya Bylich)

v2.6.5.0 (2019-10-03)
---------------------

API modifications:
 * Bump ruby versions to 2.4.9, 2.5.7 and 2.6.5. (#619) (Ilya Bylich)

Features implemented:
 * lexer.rl: changed max numparam to `@9` (#617) (Ilya Bylich)
 * lexer.rl: support comments before leading dot in 27 mode. (#613) (Ilya Bylich)

Bugs fixed:
 * lexer.rl: emit tMETHREF as tDOT+tCOLON for rubies \< 27. (#614) (Ilya Bylich)

v2.6.4.1 (2019-09-12)
---------------------

Bugs fixed:
 * lexer.rl: fix parsing of 'm a + b do end' (#605) (Ilya Bylich)

v2.6.4.0 (2019-08-30)
---------------------

API modifications:
 * Added specs for heredocs with mixed encoding. (#581) (Ilya Bylich)

Features implemented:
 * ruby27.y: Revert "pipeline operator" (#601) (Koichi ITO)
 * ruby27.y: Fix parsing of mutiple assignment with rescue modifier (#600) (Koichi ITO)
 * ruby27.y: hoisted out f_rest_marg. (#594) (Ilya Bylich)
 * ruby27.y: added pipeline operator. (#592) (Ilya Bylich)
 * ruby27.y: reject safe navigator in LHS of mass-assignment. (#586) (Ilya Bylich)
 * lexer.rl: reject whitespaces in meta and control chars. (#585) (Ilya Bylich)
 * lexer.rl: Reject numparams as symbol literals. (#582) (Ilya Bylich)
 * ruby27.y: Added numbered parameters support. (#565) (Ilya Bylich)
 * lexer.rl: Reject \n and \r in heredoc identifiers starting from 2.7. (#575) (Ilya Bylich)

Bugs fixed:
 * ruby-parse: print empty string when --emit-json and empty input are given. (#590) (Ilya Bylich)
 * AST_FORMAT: fixed documentation of the string with interpolation. (#589) (Ilya Bylich)
 * builder.rb, processor.rb: Changed format of the procarg0 node. (#587) (Ilya Bylich)

v2.6.3.0 (2019-04-28)
---------------------

Features implemented:
 * ruby27.y: Added beginless ranges support. (#570) (Ilya Bylich)

v2.6.2.1 (2019-04-05)
---------------------

API modifications:
 * Bump 2.4 branch to 2.4.6. (#569) (Ilya Bylich)
 * Lexer should know about current parsing context. (#566) (Ilya Bylich)

v2.6.2.0 (2019-03-21)
---------------------

API modifications:
 * Bump ruby versions to 2.5.5 and 2.6.2. (#563) (Ilya Bylich)
 * Bump Ruby version to 2.6.1. (#554) (Ilya Bylich)

Features implemented:
 * ruby27.y: dsym should be treated as string. (#560) (Ilya Bylich)
 * ruby27.y: Refactored symbol rules. (#557) (Ilya Bylich)
 * ruby27.y: Added method reference operator. (#556) (Ilya Bylich)
 * ruby27.y: branch parser. (#546) (Ilya Bylich)

v2.6.0.0 (2019-01-16)
---------------------

API modifications:
 * 2.6.0 was released, unmark is as -dev. (#538) (Ilya Bylich)

Bugs fixed:
 * Fix parsing of "\\\n" escaped sequences in various literals. (#539) (Ilya Bylich)

v2.5.3.0 (2018-10-29)
---------------------

Bugs fixed:
 * lexer.rl: Fix parsing of 'm :key => m do; m() do end; end'. (#526) (Ilya Bylich)
 * lexer.rl: Fix parsing of ambiguous 1re. (#523) (Ilya Bylich)

v2.5.1.2 (2018-07-10)
---------------------

Bugs fixed:
 * lexer.rl: Partially revert 5ba072d and properly handle 'm = -> *args do end'. (Ilya Bylich)

v2.5.1.1 (2018-07-10)
---------------------

Features implemented:
 * ruby26.y: Endless ranges support. (Ilya Bylich)

Bugs fixed:
 * lexer.rl: Fix parsing of 'm = -> *args do end'. (Ilya Bylich)
 * AST::Processor: Properly recurse into "kwsplat" nodes (Nelson Elhage)
 * ruby24, ruby25, ruby26: Fix cmdargs after command_args followed by tLBRACE_ARG. This commit tracks upstream commit ruby/ruby@f168dbd. (Ilya Bylich)
 * lexer.rl: Fix parsing of `let (:a) { m do; end }`. (Ilya Bylich)

v2.5.1.0 (2018-04-12)
---------------------

API modifications:
 * Parser::Current: bump latest 2.2 branch to 2.2.10. (Ilya Bylich)

Features implemented:
 * ruby26.y: Raise a syntax error on 'else' without 'rescue'. This commit tracks upstream commit ruby/ruby@140512d. (Ilya Bylich)

Bugs fixed:
 * lexer.rl, Dedenter: Treat slash in heredocs as a line continuation. (Ilya Bylich)
 * lexer.rl: Fix parsing of `a ? b + '': nil`. (Ilya Bylich)
 * lexer.rl: Reject `m a: {} {}` and `m [] {}` since 25. (Ilya Bylich)
 * builders/default: allow class/module/dynamic constant definition in the method body if there's a sclass between them. (bug #490) (Ilya Bylich)
 * lexer.rl: Emit :!@ as :!, :~@ as :~. (Ilya Bylich)
 * parse{23,24,25}.y: use only CMDARG/COND _PUSH/POP for cmdarg/cond management. (bug #481) (Ilya Bylich)
 * lexer.rl: emit tSTRING_BEG and tSTRING_DBEG one by one to allow parser to properly manipulate cmdarg stack. (bug #480) (Ilya Bylich)

v2.5.0.4 (2018-03-13)
---------------------

Bugs fixed:
 * AST::Processor: handle on_index, on_indexasgn, on_lambda. (Ilya Bylich)

v2.5.0.3 (2018-03-06)
---------------------

Bugs fixed:
 * Accept `BEGIN` and `END` as correct method name (#463) (Masataka Pocke Kuwabara)
 * Parser::Source::Buffer: Fixed parsing of encoding comment when the file contains only shebang. (Ilya Bylich)

v2.5.0.2 (2018-02-22)
---------------------

Bugs fixed:
 * ruby24.y, ruby25.y: Replicate cmdargs handling from MRI. (#453) (Ilya Bylich)

v2.5.0.1 (2018-02-21)
---------------------

Features implemented:
 * builders/default: __ENCODING__: emit as s(:__ENCODING__) via AST opt-in. (whitequark)
 * ruby25.y: Extract expr_value_do rule. This commit tracks upstream commit ruby/ruby@508533f. (Ilya Bylich)
 * ruby25.y: Extract begin_block rule. This commit tracks upstream commit ruby/ruby@762d23c. (Ilya Bylich)
 * ruby25.y: Allow class and method definition in the while condition. (#432) (Ilya Bylich)
 * ruby25: Allow `-> do rescue; end`. (#431) (Ilya Bylich)

Bugs fixed:
 * parser/current: latest released Ruby series is 2.5.x. (whitequark)
 * builders/default: x[], x[]=1: emit as s(:index), s(:indexasgn) via AST opt-in. (whitequark)
 * lexer.rl: "#{-> foo {}}": fix parsing of interpolated lambda with open args. (Ilya Bylich)

v2.5.0.0 (2018-02-16)
---------------------

API modifications:
 * Parser::Current: bump to 2.2.9 and 2.3.6. (Stan Hu)
 * Deprecate Parser::Rewriter (Marc-Andre Lafortune)
 * Deprecate Parser::Source::Rewriter (Marc-Andre Lafortune)
 * Change relative order of insert_after_multi and insert_before_multi for non-empty ranges (#399). (Marc-Andre Lafortune)

Features implemented:
 * parse.y: Reject brace after literal arg. This commit tracks upstream commits ruby/ruby@9987109 and ruby/ruby@7d6965f. (Ilya Bylich)
 * ruby-parse: add an option for emitting AST as JSON. (Alex Rattray)
 * Add Parser::TreeRewriter (Marc-Andre Lafortune)
 * Add Parser::Rewriter#wrap to ease compatibility (Marc-Andre Lafortune)
 * Add Parser::Source::TreeRewriter (Marc-Andre Lafortune)
 * Add Range#\<=> and include Comparable (Marc-Andre Lafortune)
 * parse.y: disable tLPAREN_ARG state after local variable. (Ilya Bylich)
 * SourceBuffer#source_range (Marc-Andre Lafortune)
 * Range#adjust (Marc-Andre Lafortune)
 * Range#contains?, contained?, crossing? (Marc-Andre Lafortune)
 * Add Range#with. (Marc-André Lafortune)
 * lexer.rl: Relax restriction spaces inside "\u{...}". This commit tracks upstream commit ruby/ruby@7e8b910. (Ilya Bylich)
 * lexer.rl: Allow newlines in heredoc identifiers. This commit tracks upstream commit ruby/ruby@d25faa4. (Ilya Bylich)
 * lexer.rl: allow do after cmdarg in paren. This commit tracks upstream commit ruby/ruby@046c943. (Ilya Bylich)

Bugs fixed:
 * Fixed magic encoding comment parsing when encoding comment is on the first line but not in the beginning. (Ilya Bylich)
 * lexer.rl: Parse '1if' as '1 if', '1rescue' as '1 rescue'. (Ilya Bylich)
 * lexer.rl: Save state before entering a block comment to enter it after =end. (Ilya Bylich)
 * parse.y: Prohibit return in class/module body except for singleton class. Replaced @def_level/in_def? in favor of context.indirectly_in_def?. This commit tracks upstream commit ruby/ruby@8c15f40ac. (Ilya Bylich)
 * lexer.rl: Emit :&& as tSYMBEG + tANDOP, :|| as tSYMBEG + tOROP. (Ilya Bylich)
 * ruby{24,25}.y: preserve cmdarg stack around do/end block [Bug #13073]. (Mateusz Lenik)
 * Parser::Lexer::State: Fixed #lexpop to match MRI behavior. (Ilya Bylich)

v2.4.0.2 (2017-11-13)
---------------------

API modifications:
 * parser/current: update for 2.3.5 release. (whitequark)

v2.4.0.1 (2017-11-13)
---------------------

API modifications:
 * parser/current: update for 2.3.4 release. (whitequark)
 * parser/current: update for Ruby 2.1.10 and 2.2.7. (Koichi ITO)

Features implemented:
 * Allow rescue/else/ensure inside do/end blocks. [Feature #12906] (Ilya Bylich)
 * ruby25.y: branch parser. (Ilya Bylich)

Bugs fixed:
 * Source::Comment::Associator: skip -*- magic comments -*-. (Denis Defreyne)
 * lexer.rl: "- 5": allow whitespace after tUNARY_NUM. (whitequark)
 * *ruby*.y, Builders::Default: "+5": don't lose location of the "+". (whitequark)
 * ruby-rewrite: allow passing paths to --load. (whitequark)
 * builders/default: "def x; else; end": don't crash. (whitequark)

v2.4.0.0 (2017-02-07)
---------------------

API modifications:
 * parser/current: update for the 2.4 release. (whitequark)
 * rubymotion.y: "a&.b": implement safe navigation operator in RubyMotion. (Mark Villacampa)

Bugs fixed:
 * lexer.rl: "a &. b": accept &. in EXPR_ARG also. (whitequark)

v2.3.3.1 (2016-12-02)
---------------------

API modifications:
 * parser/current: update 2.2 warning to 2.2.6 (Jordan Moncharmont)

v2.3.3.0 (2016-11-28)
---------------------

API modifications:
 * parser/current: update 2.3 branch to 2.3.3. (Philip Arndt)

Bugs fixed:
 * ruby24.y: "a += b += raise :x": fix errors with chained op-assignments. (whitequark)
 * ruby24.y: "p p{p(p);p p}, tap do end": preserve cmdarg stack. (whitequark)
 * ruby24.y: "a b{c d}, :e do end": go to EXPR_ENDARG after literal. (whitequark)

v2.3.2.0 (2016-11-20)
---------------------

API modifications:
 * parser/current: update 2.3 branch to 2.3.2. (whitequark)
 * Introduce (procarg0) node for a single required block argument. (Ilya Bylich)

Bugs fixed:
 * {macruby,ruby{19,20,21,22,23,24}}.y: "x::A += m x": treat as constant assignment. (whitequark)
 * ruby24.y: "x += raise y rescue nil": bind rescue tighter than tOP_ASGN. (whitequark)
 * ruby24.y: "x = raise y rescue nil": bind rescue tighter than =. (whitequark)
 * Builders::Default: "begin; else; 1; end": fix a crash. (whitequark)

v2.3.1.3 (2016-09-17)
---------------------

API modifications:
 * parser/current: latest 2.3 release is 2.3.2. (Chris Riddoch)

Features implemented:
 * ruby24.y: "f (g rescue nil)": allow stmt after tLPAREN_ARG. (whitequark)

Bugs fixed:
 * ruby{18,19,20,21,22,23,24}.y: parse trailing commas as mlhs for block args "a.b{ |c,| d }" (fixes #312) (John Backus)
 * Builders::Default: "begin; 1; else; 2; end": do not drop else. (whitequark)
 * Builders::Default: "a&.b &&= c": fix safe navigation in lhs of op-assignment. (Ilya Bylich)
 * AST::Processor: handle "csend" as "send". (#301) (Ilya Bylich)
 * Parser::AST::Processor: do not spuriously modify ASTs. (Ilya Bylich)
 * lexer.rl: "%w\a b\": lex backslash-delimited words literals. (Masataka Kuwabara)

v2.3.1.2 (2016-06-02)
---------------------

API modifications:
 * parser/current: update 2.2 warning to 2.2.5 (#295) (Kohei Suzuki)

Bugs fixed:
 * AST_FORMAT: Fix `kwarg` example (#294) (Magnus Holm)

v2.3.1.1 (2016-06-01)
---------------------

Bugs fixed:
 * ruby{^18}.y: "lambda{|;a|a}": treat shadowarg as local inside block. (Ilya Bylich)
 * Builders::Default: "foo&.bar{}": emit csend in block properly. (whitequark)
 * runner.rb: re-add --23 (cremno)
 * runner.rb: make --24 actually use the 2.4 parser (cremno)

v2.3.1.0 (2016-04-27)
---------------------

Features implemented:
 * Parser::Current: update for Ruby 2.3.1. (whitequark)
 * Builders::Default: allow masgn in conditional context on >=Ruby 2.4. (whitequark)
 * ruby24.y: branch parser. (whitequark)

Bugs fixed:
 * lexer.rl: "def x y; y A::B, ''; end": reject X:: in EXPR_ENDFN (fixes #285). (whitequark)

v2.3.0.7 (2016-03-25)
---------------------

API modifications:
 * Source::Diagnostic: handle ranges pointing to newlines (#273). (whitequark)

Features implemented:
 * Parser::Base#tokenize: allow recovery from syntax errors. (whitequark)
 * lexer.rl: "a=1; a b: 1": allow label after command clashing with local. (whitequark)
 * lexer.rl: "undef %s(x)": emit %s literals in expr_fname in 2.3 mode. (whitequark)

Bugs fixed:
 * Builders::Default: reject non-UTF-8 compatible literals. (whitequark)

v2.3.0.6 (2016-02-14)
---------------------

Bugs fixed:
 * lexer.rl: fix EOF location (closes #273). (whitequark)

v2.3.0.5 (2016-02-12)
---------------------

Bugs fixed:
 * lexer.rl: "%Q{\あ}": fix encoding of UTF-8 noop escapes. (whitequark)

v2.3.0.3 (2016-02-06)
---------------------

API modifications:
 * lexer.rl: "a?=b": lex via tCHARACTER (closes #255). (whitequark)

v2.3.0.2 (2016-01-24)
---------------------

Bugs fixed:
 * Add :csend to Parser::Meta::NODE_TYPES (Markus Schirp)
 * lexer/dedenter: "\<\<x\n  y\\n  z\nx": don't dedent after escaped newline. (whitequark)

v2.3.0.1 (2016-01-14)
---------------------

Features implemented:
 * ruby23.y: implement optional superclass (cremno)

v2.3.0.0 (2016-01-14)
---------------------

Features implemented:
 * parser/current: update for released 2.3. (whitequark)
 * parse.y: "\<\<~HEREDOC": implement dedenting heredocs (fixes #228). (whitequark)

v2.3.0.pre.6 (2015-12-20)
-------------------------

API modifications:
 * parser/current: update 2.2 warning to 2.2.4. (whitequark)
 * ruby{22,23}.y: "1 ? p do end : 0". (whitequark)
 * lexer.rl: "{%'a':1}": %-string cannot be a label. (whitequark)
 * parser/current: update 2.1 warning to 2.1.8. (whitequark)

Features implemented:
 * ruby-parse: add --emit-ruby option. (whitequark)

Bugs fixed:
 * lexer.rl: "f(a ? 'a':1)": disallow quoted label at expr_value. (whitequark)

v2.3.0.pre.5 (2015-12-16)
-------------------------

API modifications:
 * Source::Diagnostic: output ^^^^^ instead of ^~~~~ (like clang). (whitequark)

v2.3.0.pre.4 (2015-11-26)
-------------------------

Bugs fixed:
 * ruby23.y: add generated grammar to gemspec. (whitequark)

v2.3.0.pre.3 (2015-11-25)
-------------------------

API modifications:
 * builders/default: introduce a (lambda) node (fixes #212). (whitequark)
 * lexer.rl: do not override argument variable. (Keiji, Yoshimi)
 * lexer.rl: rename variable names from lit to current_literal. (Keiji, Yoshimi)
 * lexer.rl: use Regexp to match string. (Keiji, Yoshimi)
 * lib/parser/source/buffer: reduce respond_to?(:bsearch) (Keiji, Yoshimi)
 * lexer.rl: reduce String literal allocations (Keiji, Yoshimi)
 * lexer.rl: reduce respond_to?(:encode) method call on #advance (Keiji, Yoshimi)
 * lexer.rl: reduce Stirng.length method call on #advance (Keiji, Yoshimi)
 * lexer.rl: reduce .class method call on #advance (Keiji, Yoshimi)

Features implemented:
 * lexer.rl, ruby23.y: "a&.b": implement "safe navigation operator" (fixes #209). (whitequark)
 * ruby23.y: fork grammar. (whitequark)

Bugs fixed:
 * lexer.rl: never let EOF token location point past EOF. (whitequark)

v2.2.3.0 (2015-10-08)
---------------------

Bugs fixed:
 * lexer.rl: "-> a: {}": state after -> is ENDFN, not END (fixes #203). (whitequark)
 * ruby{21,22}.y: "p -> { :hello }, a: 1 do end": lexpop cmdarg. (whitequark)

v2.2.2.6 (2015-06-30)
---------------------

API modifications:
 * parser/current: link to README from syntax deviation warning. (whitequark)

v2.3.0.pre.2 (2015-06-15)
-------------------------

Bugs fixed:
 * {macruby,rubymotion}.rb: add to gemspec. (whitequark)

v2.3.0.pre.1 (2015-06-13)
-------------------------

API modifications:
 * ruby20.y: revert 7f7f2a45. (whitequark)

Features implemented:
 * Add RubyMotion support. (whitequark)
 * Add MacRuby support. (whitequark)

Bugs fixed:
 * lexer.rl: "[/()\\1/, ?#]": fixes #198. (whitequark)

v2.2.2.5 (2015-05-25)
---------------------

API modifications:
 * Source::Comment::Associator: rework entirely; fixes #194 (Oleg Zubchenko)

Features implemented:
 * Source::Map: add last_line, last_column delegation (Oleg Zubchenko)
 * Source::Range: add last_line, last_column methods (Oleg Zubchenko)

Bugs fixed:
 * AST::Processor: add missing on_block_pass (fixes #196) (whitequark)

v2.2.2.3 (2015-05-17)
---------------------

API modifications:
 * lexer.rl: "a?? 1 : 0": squelch "invalid character syntax" warning. (whitequark)
 * parser/current: bump warnings to 2.0.1, 2.1.7, 2.2.3. (whitequark)

Bugs fixed:
 * Source::Map: do not include :node in to_hash. (whitequark)
 * ruby{20,21,22}.y: "p ->() do a() do end end": save cmdarg. (whitequark)

v2.2.2.2 (2015-04-28)
---------------------

Bugs fixed:
 * lexer.rl: "%r.\..", "%r'\''": leave regexp metacharacters escaped (fixes #192). (whitequark)

v2.2.2.1 (2015-04-18)
---------------------

Bugs fixed:
 * builders/default: don't falsely diagnose multiline regexps (fixes #190). (whitequark)

v2.2.0.4 (2015-04-15)
---------------------

Features implemented:
 * Add Parser::Source::Map#node. (whitequark)
 * Add Parser::Source::Comment.associate_locations. (kubicle)

v2.2.0.1 (2014-12-27)
---------------------

Bugs fixed:
 * lexer.rl, lexer/literal: "{'a'::": don't parse as quoted label. (Peter Zotov)
 * Update syntax deviation warning to reflect 2.2 release. (Peter Zotov)

v2.2.0 (2014-12-25)
-------------------

Bugs fixed:
 * lexer.rl: "{'x':1,'y':{}}": fix lex_state after tLABEL_END. (Peter Zotov)

v2.2.0.pre.8 (2014-11-19)
-------------------------

API modifications:
 * parser/current: update 2.1 to 2.1.5 (fixes #174). (Peter Zotov)

v2.2.0.pre.7 (2014-11-03)
-------------------------

Bugs fixed:
 * parser/meta: add missing nodes (fixes #171). (Peter Zotov)

v2.2.0.pre.6 (2014-10-28)
-------------------------

API modifications:
 * parser/current: latest stable 2.1.x is 2.1.4, update warning. (hirocaster)

v2.2.0.pre.5 (2014-10-03)
-------------------------

Features implemented:
 * parser/current: add syntax deviation warning for 2.1.2. (Peter Zotov)
 * lexer.rl, ruby22.y: "{'x':1}": add tLABEL_END. (Peter Zotov)

Bugs fixed:
 * lexer.rl, ruby{21,22}.y: "def a b:\nreturn": fix #164. (Peter Zotov)
 * Fix for `ruby-rewrite` not rewriting files if any rewriter was loaded, due to it getting confused about the filename. (Jon Frisby)

v2.2.0.pre.4 (2014-08-09)
-------------------------

Bugs fixed:
 * builders/default: "not(x)": fix source map (fixes #158). (Peter Zotov)

v2.2.0.pre.3 (2014-07-02)
-------------------------

Features implemented:
 * Raise EncodingError when source includes invalid byte sequence (Yuji Nakayama)

Bugs fixed:
 * ruby{19,20,21}.y: "x def y; z do end end": save cmdarg stack to isolate command argument state from outer scope. (Peter Zotov)
 * ruby{19,20,21}.y: "tap (proc do end)": allow parenthesed do-block in cmdarg. (Peter Zotov)

v2.2.0.pre.2 (2014-06-14)
-------------------------

Bugs fixed:
 * ruby22.rb: include in gemspec. (Peter Zotov)

v2.2.0.pre.1 (2014-06-12)
-------------------------

Features implemented:
 * Add Source::Rewriter#transaction for atomic rewrite actions (Yuji Nakayama)
 * Raise Parser::ClobberingError for clobbering rewrite error (Yuji Nakayama)

Bugs fixed:
 * parser/current: fix the fallback case (refs #146). (Peter Zotov)
 * ruby22.y: "tap (proc do end)": allow parenthesed do-block in cmdarg. (Peter Zotov)

v2.1.9 (2014-04-21)
-------------------

API modifications:
 * Extend ast dependency to >= 1.1 \< 3.0. (Peter Zotov)
 * parser/current: fallback to latest released Ruby instead of raising (fixes #140). (Peter Zotov)

Features implemented:
 * ruby-rewrite: add a --modify switch for rewriters that modify AST (fixes #143). (Peter Zotov)

Bugs fixed:
 * lexer.rl: don't fail to parse string literals in huge files (fixes #142). (Peter Zotov)

v2.1.7 (2014-03-05)
-------------------

Bugs fixed:
 * lexer.rl: make sure all invalid escapes lead to fatal errors (fixes #136). (Peter Zotov)

v2.1.6 (2014-03-04)
-------------------

Features implemented:
 * Add the list of all node types within Parser::Meta. (Markus Schirp)

v2.1.5 (2014-02-24)
-------------------

Bugs fixed:
 * Parser::Base, ruby18.y: don't try to lookup Encoding on 1.8 (fixes #133). (Peter Zotov)

v2.1.4 (2014-01-11)
-------------------

Features implemented:
 * ruby22.y: "x def y; z do end end": save cmdarg stack to isolate command argument state from outer scope. (Peter Zotov)
 * Add Ruby 2.2 syntax. (Peter Zotov)

Bugs fixed:
 * Builders::Default: "super do end": super and zsuper are like send (fixes #131). (Peter Zotov)

v2.1.3 (2014-01-10)
-------------------

Bugs fixed:
 * lexer.rl: "/\//": don't include escaped delimiter in AST in its escaped form (fixes #125). (Peter Zotov)
 * Builders::Default: "return x y do end": correctly build AST for keywords followed by command (closes #129). (Peter Zotov)
 * Fix a bug where "ambiguous first argument" diagnostic was not emitted (Yuji Nakayama)
 * Source::Comment::Associator: don't die while associating with "__ENCODING__". (Peter Zotov)
 * ruby-parse: don't die when invoked with -L -e "__ENCODING__". (Peter Zotov)
 * Add missing source map for match-current-line (Yuji Nakayama)

v2.1.2 (2014-01-05)
-------------------

Bugs fixed:
 * lexer.rl: in "foo!= x", foo is tIDENTIFIER, not tFID (closes #126). (Peter Zotov)

v2.1.1 (2013-12-25)
-------------------

API modifications:
 * ruby21.y: Ruby 2.1 is released already. (Peter Zotov)

v2.1.0 (2013-12-25)
-------------------

API modifications:
 * Parser::Diagnostic: expose reason symbolically (closes #115, #116). (Ian MacLeod)
 * lexer.rl: coerce literals to UTF-8 in ASCII-encoded files if they contain \uXXXX (Peter Zotov)

Bugs fixed:
 * builders/default: represent heredocs with dedicated map (fixes #100). (Peter Zotov)

v2.1.0.pre1 (2013-11-12)
------------------------

API modifications:
 * lexer.rl: correctly handle __END__ with non-whitespace after it (Peter Zotov)
 * lexer.rl: handle \r in middle of a line as mere whitespace (Peter Zotov)
 * ruby{18,19,20,21}.y, builders/default: precisely point to tUMINUS_NUM. (Peter Zotov)

Features implemented:
 * lexer.rl, ruby21.y, builders/default: rational/complex literals. (Peter Zotov)

v2.0.0 (2013-10-06)
-------------------

API modifications:
 * Source::Rewriter: raise an exception if updates clobber each other. (Peter Zotov)
 * Source::Range#inspect: use full class name. (Peter Zotov)
 * lexer.rl: make EOF tokens actually pointing at EOF and zero-length. (Peter Zotov)
 * Source::Range#column_range: raise RangeError if range spans >1 line. (Peter Zotov)
 * Source::Comment::Associator: fix argument order. (Peter Zotov)

Features implemented:
 * Source::Comment: implement #inspect. (Peter Zotov)
 * Backport Array#bsearch from Ruby 2.0. (Peter Zotov)

v2.0.0.pre8 (2013-09-15)
------------------------

API modifications:
 * lexer.rl: make lexing faster and improve parsing speed by ~60%. (Peter Zotov)

v2.0.0.pre7 (2013-09-10)
------------------------

Features implemented:
 * Parser::Base: add #parse_with_comments, #parse_file_with_comments. (Trent Ogren)
 * lexer.rl (Ruby 2.1): "1end": lex non-exponent `e' separate from number. (Peter Zotov)

Bugs fixed:
 * lexer.rl: "->*{}": tLAMBEG at expr_beg (fixes #103). (Peter Zotov)
 * Source::Rewriter: apply actions in the insertion order. (Josh Cheek)

v2.0.0.pre5 (2013-07-31)
------------------------

Bugs fixed:
 * Remove a forgotten require. (Peter Zotov)

v2.0.0.pre4 (2013-07-31)
------------------------

API modifications:
 * source/comment: make #loc/#location return Source::Map for consistency (fixes #96). (Peter Zotov)

Features implemented:
 * source/comment/associator: skip shebang and encoding line by default (fixes #95). (Peter Zotov)

Bugs fixed:
 * ruby{19,20,21}.y, lexer.rl, builders/default: correct begin for ?a (fixes #92). (Peter Zotov)
 * ruby{18,19,20,21}.y, builders/default: don't add spurious begin/end for string parts (refs #92). (Peter Zotov)
 * Activate `diagnostics.all_errors_are_fatal` on non-MRI Rubies as a workaround (closes #93). (Peter Zotov)

v2.0.0.pre3 (2013-07-26)
------------------------

API modifications:
 * lexer.rl: add simple explicit output encoding for strings. (Peter Zotov)

Features implemented:
 * Source::Buffer: support for -(dos|unix|mac) and utf8-mac encodings. (Peter Zotov)
 * Source::Range#resize. (Peter Zotov)
 * Significantly improve speed for large (>100k) and very large (>1M) files. (Peter Zotov)

Bugs fixed:
 * ruby21.y: fix typos. (Peter Zotov)
 * builders/default: respect regexp encoding. (Peter Zotov)
 * lexer.rl: literal EOF (\0, \x04, \x1a) inside literals and comments. (Peter Zotov)
 * lexer.rl: "meth (lambda do end)" (1.8), "f x: -> do meth do end end": expr_cmdarg. (Peter Zotov)
 * lexer.rl: "\<\<E\nE\r\r\n": extraneous CRs are ignored after heredoc delimiter. (Peter Zotov)
 * lexer.rl: "%\nfoo\n": \n can be used as %-literal delimiter. (Peter Zotov)
 * source/buffer, lexer.rl: convert CRLF to LF prior to lexing. (Peter Zotov)
 * lexer.rl: "\<\<w; "\nfoo\nw\n"": interleaved heredoc and non-heredoc literals. (Peter Zotov)
 * builders/default: 1.8 did not descend into &&/|| in conditional context. (Peter Zotov)
 * lexer.rl: "1+a:a": respect context sensitivity in 1.8 label fallback. (Peter Zotov)
 * lexer.rl: ruby 1.8 is context-sensitive wrt/ locals as well. (Peter Zotov)
 * lexer.rl: "eof??a": expr_arg doesn't need space before character literal. (Peter Zotov)
 * lexer.rl: interleaved heredoc and interpolated double-quoted string. (Peter Zotov)
 * lexer.rl: "#{f:a}": interpolation starts expr_value, not expr_beg. (Peter Zotov)
 * lexer.rl: "\cM" is "\r", not an error. (Peter Zotov)
 * ruby{20,21}.y: constant op-assignment inside a def is not an error. (Peter Zotov)
 * lexer.rl: "when Date:" fix label fallback for 1.8 mode. (Peter Zotov)
 * ruby{19,20,21}.y: "->(scope){}; scope :foo": lambda identifier leakage. (Peter Zotov)
 * lexer.rl: "eh ?\r\n": don't eat tEH if followed by CRLF. (Peter Zotov)
 * lexer.rl: "f \<\<-TABLE\ndo |a,b|\nTABLE\nend": leave FSM after lexing heredoc. (Peter Zotov)
 * lexer.rl: "foo %\n bar": don't % at expr_arg as tSTRING_BEG. (Peter Zotov)
 * lexer.rl, lexer/literal: use lexer encoding for literal buffer. (Peter Zotov)
 * lexer.rl: "\u{9}": one-digit braced unicode escapes. (Peter Zotov)
 * Source::Buffer: don't chew \r from source lines. (Peter Zotov)
 * builders/default: don't die in eh_keyword_map if else branch is empty. (Peter Zotov)
 * lexer.rl: "0777_333": octal literals with internal underscores. (Peter Zotov)
 * lexer.rl: "let [] {}": goto tLBRACE_ARG after any closing braces. (Peter Zotov)
 * lexer.rl: "while not (1) do end": emit proper kDO* when in cond/cmdarg state. (Peter Zotov)
 * lexer.rl: "rescue=>": correctly handle rescue+assoc at expr_beg. (Peter Zotov)
 * lexer.rl: "puts 123do end": only trailing `_' and `e' in number are errors. (Peter Zotov)
 * lexer.rl: "begin; rescue rescue1; end": accept barewords at expr_mid. (Peter Zotov)
 * lexer.rl: "f.x!if 1": correct modifier handling in expr_arg. (Peter Zotov)
 * lexer.rl: "=begin\n#=end\n=end": only recognize =end at bol. (Peter Zotov)
 * builders/default: don't check for duplicate arguments in 1.8 mode. (Peter Zotov)
 * Don't attempt to parse magic encoding comment in 1.8 mode. (Peter Zotov)
 * lexer.rl: "\777": octal literals overflow. (Peter Zotov)
 * lexer.rl: "foo;\n__END__", "\na:b": whitespace in expr_value. (Peter Zotov)
 * lexer.rl: "\xE2\x80\x99": concatenation of byte escape sequences. (Peter Zotov)
 * lexer.rl: "E10", "E4U": don't conflate floats and identifiers. (Peter Zotov)
 * lexer.rl: "foo.bar= {1=>2}": return fid, = as separate tokens in expr_dot. (Peter Zotov)
 * lexer.rl: "def defined?": properly return defined? in expr_fname. (Peter Zotov)
 * lexer.rl: "Rainbows! do end", "foo.S?": allow bareword fid in expr_beg/dot. (Peter Zotov)

v2.0.0.pre2 (2013-07-11)
------------------------

Features implemented:
 * Allow to differentiate between __FILE__/__LINE__ and literals (closes #89). (Peter Zotov)
 * Add attribute `diagnostic' to Parser::SyntaxError (closes #88). (Peter Zotov)

Bugs fixed:
 * Don't treat byte order mark as an identifier (closes #91). (Peter Zotov)

v2.0.0.beta10 (2013-07-02)
--------------------------

Bugs fixed:
 * ruby-parse, ruby-rewrite: fix require of removed compatibility shim. (Peter Zotov)
 * lexer.rl: "def !@; end" unary bang. (Peter Zotov)

v2.0.0.beta9 (2013-06-28)
-------------------------

API modifications:
 * ruby{18,19,20,21}.y: removed obsolete warnings and linting. (Peter Zotov)

Features implemented:
 * builders/default: add keyword source range for BEGIN/END (fixes #85). (Peter Zotov)

Bugs fixed:
 * lexer.rl: "t=1;(a)?t:T" context sensitivity in expr_value (fixes #87). (Peter Zotov)
 * lexer.rl: keywords as labels, e.g. "unless:" (fixes #83, #84). (Peter Zotov)
 * lexer.rl: rectify usage of c_space/c_space_nl (fixes #81). (Peter Zotov)
 * ruby{18,19,20,21}.y: fix warnings for class/module in method body. (Peter Zotov)
 * lexer.rl: fix warning for ?\s. (Peter Zotov)
 * lexer.rl: expr_fname emits expr_beg-like keywords (fixes #82). (Peter Zotov)
 * lexer.rl: get rid of harmful nondeterminism in w_space (fixes #80). (Peter Zotov)
 * lexer/explanation: 1.8, 1.9 compatibility (fixes #76). (Peter Zotov)

v2.0.0.beta8 (2013-06-24)
-------------------------

Bugs fixed:
 * ast/processor: add missing node handlers (Yuji Nakayama)
 * ast/processor: rename some obsolete node handlers (Yuji Nakayama)

v2.0.0.beta7 (2013-06-22)
-------------------------

API modifications:
 * Implement a much more sane encoding model (closes #60). (Peter Zotov)

Features implemented:
 * builders/default: (while-post) and (until-post); (kwbegin) (fixes #70). (Peter Zotov)

Bugs fixed:
 * builders/default: don't swallow (begin) in "if (foo); end" (fixes #75). (Peter Zotov)

v2.0.0.beta6 (2013-06-17)
-------------------------

API modifications:
 * Get rid of "synthesized (nil)". If it's not in source, it's not in AST (fixes #71). (Peter Zotov)
 * lexer.rl, ruby{18,19,20,21}.y: source maps for interpolation (fixes #27). (Peter Zotov)

Features implemented:
 * ruby{18,19,20,21}.y, builders/default: lvar-injecting match (closes #69). (Peter Zotov)
 * builders/default: implicit matches (refs #69). (Peter Zotov)
 * builders/default: flip-flops (refs #69). (Peter Zotov)

Bugs fixed:
 * lexer.rl: fix an off-by-1 error in heredoc parsing. (Peter Zotov)
 * lexer.rl: don't fail on "alias $a $b\n# comment\nalias $c $d". (Peter Zotov)
 * builders/default: fix treatment of masgn in &&/|| (refs #69). (Peter Zotov)
 * ruby-parse: make -L command line option work again. (Peter Zotov)
 * ruby{18,19,20,21}.y: begin source map for "if foo\nthen bar end" (fixes #68). (Peter Zotov)
 * Source::Comment::Associator: gracefully terminate when out of comments (fixes #67). (Peter Zotov)

v2.0.0.beta5 (2013-06-08)
-------------------------

Bugs fixed:
 * Source::Buffer: better magic encoding comment recognition (fixes #65). (Peter Zotov)
 * lexer.rl: "{success?: true}" (fixes #66). (Peter Zotov)
 * Source::Buffer: if in doubt, treat data as UTF-8 (closes #60). (Peter Zotov)

v2.0.0.beta4 (2013-06-05)
-------------------------

Bugs fixed:
 * lexer.rl: fix heredoc parsing with CRLF line endings (closes #61). (Peter Zotov)
 * lexer.rl: fix premature ending of heredoc "\<\<D\nABCDEF\nD" (fixes #59). (Peter Zotov)

v2.0.0.beta3 (2013-05-29)
-------------------------

Bugs fixed:
 * AST::Processor: traverse "A, B = foo" (fixes #55). (Peter Zotov)
 * lexer.rl: correctly handle CRLF line endings (fixes #56). (Peter Zotov)
 * Fix traversing of "case; when a?; when b?; end" by AST::Processor. (Peter Zotov)
 * Correctly lex "foo a, b # comment\nbar" (fixes #54). (Peter Zotov)

v2.0.0.beta2 (2013-05-27)
-------------------------

Bugs fixed:
 * Actually return comments from Parser::Base#tokenize instead of nil. (Peter Zotov)

v2.0.0.beta1 (2013-05-25)
-------------------------

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

