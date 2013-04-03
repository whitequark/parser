Location and Sexp RFC
=====================

# Open questions:

 * Incomplete:
   1. How to handle constant paths?
   1. How to handle class/module definition?
   1. How to handle class-<<-self?
   1. How to handle begin-rescue-else-ensure-end?
   1. How to handle retry?
   1. How to handle binary operator-assignment?
   1. How to handle indexing operator-assignment?
   1. How to handle logical operator-assignment?
   1. How to handle Ruby 2.0 **interpolation?
 * Less interesting and more obscure parts:
   1. How to handle begin-end-until/while?
   1. How to handle for-in-do-end?
 * Should we handle these at all? Looks like a job for an Sexp processor.
   1. How to handle lvar-injecting match (`if /(?<a>foo)/ =~ bar`)?
   1. How to handle magic match (`foo if /bar/`)?
   1. How to handle sed-like flip-flop?
   1. How to handle awk-like flip-flop?
 * I think the lists above are complete.

## Literals

### Singletons

Format:
```
(true)
"true"
 ~~~~ expression

(false)
"false"
 ~~~~~ expression

(nil)
"nil"
 ~~~ expression
```

### Integer

Format:
```
(int 123)
"123"
 ~~~ expression
```

### Float

Format:
```
(float 1.0)
"1.0"
 ~~~ expression
```

### String

#### Plain

Format:
```
(str "foo")
"'foo'"
 ^ begin
     ^ end
 ~~~~~ expresion
```

#### With interpolation

Format:
```
(dstr (str "foo") (lvar bar) (str "baz"))
'"foo#{bar}baz"'
 ^ begin      ^ end
 ~~~~~~~~~~~~~~ expression
```

### Symbol

#### Plain

Format:
```
(sym :foo)
":foo"
 ~~~~ expresion

":'foo'"
  ^ begin
      ^ end
 ~~~~~~ expression
```

#### With interpolation

Format:
```
(dsym (str "foo") (lvar bar) (str "baz"))
':"foo#{bar}baz"'
  ^ begin      ^ end
 ~~~~~~~~~~~~~~~ expression
```

### Execute-string

#### Plain

Format:
```
(xstr "foo")
"`foo`"
 ^ begin
     ^ end
 ~~~~~ expression
```

#### With interpolation

Format:
```
(dxstr (str "foo") (lvar bar))
"`foo#{bar}`"
 ^ begin   ^ end
 ~~~~~~~~~~~ expression
```

### Regexp

#### Options

Format:
```
(regopt :i :m)
"im"
 ~~ expression
```

#### Plain

Format:
```
(regexp (regopt :i :m) "source")
"/source/im"
 ^ begin
        ^ end
 ~~~~~~~~~~ expression
```

#### With interpolation

Format:
```
(dregexp (regopt :i) (lit "foo") (lvar bar))
"/foo#{bar}/i"
 ^ begin   ^ end
 ~~~~~~~~~~~ expression
```

### Array

#### Plain

Format:
```
(array (int 1) (int 2))

"[1, 2]"
 ~~~~~~ expression
```

#### Splat

Can also be used in argument lists: `foo(bar, *baz)`

Format:
```
(splat (lvar :foo))
"*foo"
 ^ operator
 ~~~~ expression

```

#### With interpolation

Format:
```
(array (int 1) (splat (lvar :foo)) (int 2))

"[1, *foo, 2]"
 ^ begin    ^ end
 ~~~~~~~~~~~~ expression
```

### Hash

#### Plain

Format:
```
(hash (int 1) (int 2) (int 3) (int 4))
"{1 => 2, 3 => 4}"
 ^ begin        ^ end
 ~~~~~~~~~~~~~~~~ expression
```

#### Keyword splat (2.0)

Can also be used in argument lists: `foo(bar, **baz)`

Format:
```
(kwsplat (lvar :foo))
"**foo"
 ~~ operator
 ~~~~~ expression
```

#### With interpolation (2.0)

TODO: Ruby 2.0's kwargs break (hash) children iteration with
.children.each_slice(2). This is bad. Let's make it
(hash (pair (int 1) (int 2)) (kwsplat (lvar :a))) ?
Also allows to distinguish `a:` from `a =>`, which enables many
source-level introspections.

### Range

#### Inclusive

Format:
```
(irange (int 1) (int 2))
"1..2"
 ~~~~ expression
```

#### Exclusive

Format:
```
(erange (int 1) (int 2))
"1...2"
 ~~~~~ expression
```

## Access

### Self

Format:
```
(self)
"self"
 ~~~~ expression
```

### Local variable

Format:
```
(lvar :foo)
"foo"
 ~~~ expression
```

### Instance variable

Format:
```
(ivar :@foo)
"@foo"
 ~~~~ expression
```

### Class variable

Format:
```
(cvar :$foo)
"$foo"
 ~~~~ expression
```

### Global variable

Format:
```
(gvar :$foo)
"$foo"
 ~~~~ expression
```

### Constant

TODO

### defined?

Format:
```
(defined? (lvar :a))
"defined? a"
 ~~~~~~~~ operator
 ~~~~~~~~~~ expression
```

## Assignment

### To local variable

Format:
```
(lvasgn :foo (lvar :bar))
"foo = bar"
     ^ operator
 ~~~~~~~~~ expression
```

### To instance variable

Format:
```
(ivasgn :@foo (lvar :bar))
"@foo = bar"
      ^ operator
 ~~~~~~~~~~ expression
```

### To class variable

#### Inside a class scope

Format:
```
(cvdecl :@@foo (lvar :bar))
"@@foo = bar"
       ^ operator
 ~~~~~~~~~~~ expression
```

#### Inside a method scope

Format:
```
(cvasgn :@@foo (lvar :bar))
"@@foo = bar"
       ^ operator
 ~~~~~~~~~~~ expression
```

### To global variable

Format:
```
(gvasgn :$foo (lvar :bar))
"$foo = bar"
      ^ operator
 ~~~~~~~~~~ expression
```

### To constant

TODO

### Multiple assignment

#### Multiple left hand side

Format:
```
(mlhs (lvasgn :a) (lvasgn :b))
"a, b"
 ~~~~ expression
"(a, b)"
 ^ begin
      ^ end
 ~~~~~~ expression
```

#### Assignment

Rule of thumb: every node inside `(mlhs)` is "incomplete"; to make
it "complete", one could imagine that a corresponding node from the
mrhs is "appended" to the node in question. This applies both to
side-effect free assignments (`lvasgn`, etc) and side-effectful
assignments (`send`).

Format:
```
(masgn (mlhs (lvasgn :foo) (lvasgn :bar)) (array (int 1) (int 2)))
"foo, bar = 1, 2"
          ^ operator
 ~~~~~~~~~~~~~~~ expression

(masgn (mlhs (ivasgn :@a) (cvasgn :@@b)) (splat (lvar :c)))
"@a, @@b = *c"

(masgn (mlhs (mlhs (lvasgn :a) (lvasgn :b)) (lvasgn :c)) (lvar :d))
"a, (b, c) = d"

(masgn (mlhs (send (self) :a=) (send (self) :[]= (int 1))) (lvar :a))
"self.a, self[1] = a"
```

### Binary operator-assignment

TODO

### Logical operator-assignment

TODO

## Method (un)definition

### Instance methods

Format:
```
(def :foo (args) nil)
"def foo; end"
 ~~~ keyword
     ~~~ name
          ~~~ end
 ~~~~~~~~~~~~ expression
```

### Singleton methods

Format:
```
(defs (self) (args) nil)
"def self.foo; end"
 ~~~ keyword
          ~~~ name
               ~~~ end
 ~~~~~~~~~~~~~~~~~ expression
```

### Undefinition

Format:
```
(undef (sym :foo) (sym :bar) (dsym (str "foo") (int 1)))
"undef foo :bar :"foo#{1}""
 ~~~~~ keyword
 ~~~~~~~~~~~~~~~~~~~~~~~~~ expression
```

## Aliasing

### Method aliasing

Format:
```
(alias (sym :foo) (dsym (str "foo") (int 1)))
"alias foo :"foo#{1}""
 ~~~~~ keyword
 ~~~~~~~~~~~~~~~~~~~~ expression
```

### Global variable aliasing

Format:
```
(alias (gvar :$foo) (gvar :$bar))
"alias $foo $bar"
 ~~~~~ keyword
 ~~~~~~~~~~~~~~~ expression

(alias (gvar :$foo) (back-ref :$&))
"alias $foo $&"
 ~~~~~ keyword
 ~~~~~~~~~~~~~~~ expression
```

## Formal arguments

Format:
```
(args (arg :foo))
"(foo)"
 ~~~~~ expression
```

### Required argument

Format:
```
(arg :foo)
"foo"
 ~~~ expression
 ~~~ name
```

### Optional argument

Format:
```
(optarg :foo (int 1))
"foo = 1"
 ~~~~~~~ expression
     ^ assignment
 ~~~ name
```

### Named splat argument

Format:
```
(splatarg :foo)
"*foo"
 ~~~~ expression
  ~~~ name
```

Begin of the `expression` points to `*`.

### Unnamed splat argument

Format:
```
(splatarg)
"*"
 ^ expression
```

### Block argument

Format:
```
(blockarg :foo)
"&foo"
  ~~~ name
 ~~~~ expression
```

### Decomposition

Format:
```
(def :f (args (arg :a) (mlhs (arg :foo) (splatarg :bar))))
"def f(a, (foo, *bar)); end"
          ^ begin   ^ end
          ~~~~~~~~~~~ expression
```

### Keyword argument

Format:
```
(kwoptarg :foo (int 1))
"foo: 1"
 ~~~~~~ expression
 ~~~~ name
```

### Named keyword splat argument

Format:
```
(kwsplat :foo)
"**foo"
 ~~~~~ expression
   ~~~ name
```

### Unnamed keyword splat argument

Format:
```
(kwsplat)
"**"
 ~~ expression
```

## Send

### To self

Format:
```
(send nil :foo (lvar :bar))
"foo(bar)"
 ~~~ selector
 ~~~~~~~~ expression
```

### To receiver

Format:
```
(send (lvar :foo) :bar (int 1))
"foo.bar(1)"
     ~~~ selector
 ~~~~~~~~~~ expression

(send (lvar :foo) :+ (int 1))
"foo + 1"
     ^ selector
 ~~~~~~~ expression

(send (lvar :foo) :-@)
"-foo"
 ^ selector
 ~~~~ expression

(send (lvar :foo) :a= (int 1))
"foo.a = 1"
     ~~~ selector
       ^ operator
 ~~~~~~~~~ expression

(send (lvar :foo) :[] (int 1))
"foo[i]"
    ~~~ selector
    ^ begin
      ^ end
 ~~~~~~ expression

(send (lvar :bar) :[]= (int 1) (int 2) (lvar :baz))
"bar[1, 2] = baz"
    ~~~~~~~~ selector
    ^ begin
        ^ end
           ^ operator
 ~~~~~~~~~~~~~~~ expression

```

### To superclass

Format of super with arguments:
```
(super (lvar :a))
"super a"
 ~~~~~ keyword
 ~~~~~~~ expression

(super)
"super()"
      ^ begin
       ^ end
 ~~~~~ keyword
 ~~~~~~~ expression
```

Format of super without arguments (**z**ero-arity):
```
(zsuper)
"super"
 ~~~~~ keyword
 ~~~~~ expression
```

### To block argument

Format:
```
(yield (lvar :foo))
"yield(foo)"
 ~~~~~ keyword
      ^ begin
          ^ end
 ~~~~~~~~~~ expression
```

### Passing a literal block

```
(block (send nil :foo) (args (arg :bar)) (begin ...))
"foo do |bar|; end"
     ~~ begin
               ~~~ end
     ~~~~~~~~~~~~~ expression
```

### Passing expression as block

Used when passing expression as block `foo(&bar)`

```
(send nil :foo (int 1) (block-pass (lvar :foo)))
"foo(1, &foo)"
        ^ operator
        ~~~~ expression
```

## Control flow

### Logical operators

#### Binary (and or && ||)

Format:
```
(and (lvar :foo) (lvar :bar))
"foo and bar"
     ~~~ operator
 ~~~~~~~~~~~ expression
```

#### Unary (! not) (1.8)

Format:
```
(not (lvar :foo))
"!foo"
 ^ operator
"not foo"
 ~~~ operator
```

### Branching

#### Without else

Format:
```
(if (lvar :cond) (lvar :iftrue) nil)
"if cond then iftrue; end"
 ~~ keyword
         ~~~~ begin
                      ~~~ end
 ~~~~~~~~~~~~~~~~~~~~~~~~ expression

"if cond; iftrue; end"
 ~~ keyword
                  ~~~ end
 ~~~~~~~~~~~~~~~~~~~~ expression

"iftrue if cond"
        ~~ keyword
 ~~~~~~~~~~~~~~ expression

(if (lvar :cond) nil (lvar :iftrue))
"unless cond then iftrue; end"
 ~~~~~~ keyword
             ~~~~ begin
                          ~~~ end
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression

"unless cond; iftrue; end"
 ~~~~~~ keyword
                      ~~~ end
 ~~~~~~~~~~~~~~~~~~~~~~~~ expression

"iftrue unless cond"
        ~~~~~~ keyword
 ~~~~~~~~~~~~~~~~~~ expression
```

#### With else

Format:
```
(if (lvar :cond) (lvar :iftrue) (lvar :iffalse))
"if cond then iftrue; else; iffalse; end"
 ~~ keyword
         ~~~~ begin
                      ~~~~ else
                                 ~~~ end
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression

"if cond; iftrue; else; iffalse; end"
 ~~ keyword
                  ~~~~ else
                                 ~~~ end
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression

(if (lvar :cond) (lvar :iffalse) (lvar :iftrue))
"unless cond then iftrue; else; iffalse; end"
 ~~~~~~ keyword
             ~~~~ begin
                          ~~~~ else
                                     ~~~ end
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression

"unless cond; iftrue; else; iffalse; end"
 ~~~~~~ keyword
                      ~~~~ else
                                     ~~~ end
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression
```

#### With elsif

Format:
```
(if (lvar :cond1) (int 1) (if (lvar :cond2 (int 2) (int 3))))
"if cond1; 1; elsif cond2; 2; else 3; end"
 ~~ keyword (left)
              ~~~~~ else (left)
                                      ~~~ end (left)
              ~~~~~ keyword (right)
                              ~~~~ else (right)
                                      ~~~ end (right)
```

#### Ternary

Format:
```
(if (lvar :cond) (lvar :iftrue) (lvar :iffalse))
"cond ? iftrue : iffalse"
      ^ question
               ^ colon
 ~~~~~~~~~~~~~~~~~~~~~~~ expression
```

### Case matching

#### When clause

Format:
```
(when (regexp (regopt) "foo") (begin (lvar :bar)))
"when /foo/; bar"
 ~~~~ keyword
 ~~~~~~~~~~ expression
```

#### Case-expression clause

##### Without else

Format:
```
(case (lvar :foo) (when (str "bar") (lvar :bar)) nil)
"case foo; when "bar"; bar; end"
 ~~~~ keyword               ~~~ end
```

##### With else

Format:
```
(case (lvar :foo) (when (str "bar") (lvar :bar)) (lvar :baz))
"case foo; when "bar"; bar; else baz; end"
 ~~~~ keyword               ~~~~ else ~~~ end
```

#### Case-conditions clause

##### Without else

Format:
```
(case nil (when (lvar :bar) (lvar :bar)) nil)
"case; when bar; bar; end"
 ~~~~ keyword         ~~~ end
```

##### With else

Format:
```
(case nil (when (lvar :bar) (lvar :bar)) (lvar :baz))
"case; when bar; bar; else baz; end"
 ~~~~ keyword         ~~~~ else ~~~ end
```

### Looping

#### With precondition

Format:
```
(while (lvar :condition) (send nil :foo))
"while condition do foo; end"
 ~~~~~ keyword
                 ~~ begin
                         ~~~ end
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression

"while condition; foo; end"
 ~~~~~ keyword
                       ~~~ end
 ~~~~~~~~~~~~~~~~~~~~~~~~~ expression

"foo while condition"
     ~~~~~ keyword
 ~~~~~~~~~~~~~~~~~~~ expression

(until (lvar :condition) (send nil :foo))
"until condition do foo; end"
 ~~~~~ keyword
                 ~~ begin
                         ~~~ end
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression

(until (lvar :condition) (send nil :foo))
"until condition; foo; end"
 ~~~~~ keyword
                       ~~~ end
~~~~~~~~~~~~~~~~~~~~~~~~~~ expression

"foo until condition"
     ~~~~~ keyword
 ~~~~~~~~~~~~~~~~~~~ expression
```

#### With postcondition

TODO handle `begin end while foo`. `while-post`, `until-post`?

#### Break

Format:
```
(break (int 1))
"break 1"
 ~~~~~ keyword
 ~~~~~~~ expression
```

#### Next

Format:
```
(next (int 1))
"next 1"
 ~~~~ keyword
 ~~~~~~ expression
```

#### Redo

Format:
```
(redo)
"redo"
 ~~~~ keyword
 ~~~~ expression
```

### Returning

Format:
```
(return (lvar :foo))
"return(foo)"
 ~~~~~~ keyword
       ^ begin
           ^ end
 ~~~~~~~~~~~ expression
```

### Exception handling

TODO

### BEGIN and END

Format:
```
(preexe (send nil :puts (str "foo")))
"BEGIN { puts "foo" }"
 ~~~~~ keyword
       ^ begin      ^ end
 ~~~~~~~~~~~~~~~~~~~~ expression

(postexe (send nil :puts (str "bar")))
"END { puts "bar" }"
 ~~~ keyword
     ^ begin      ^ end
 ~~~~~~~~~~~~~~~~~~ expression
```

