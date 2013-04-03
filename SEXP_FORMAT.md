Location and Sexp RFC
=====================

# Open questions:

 * None?

## Literals

### Self

Format:
```
(self)
"self"
 ~~~~ expression
```

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
 ~~~~~~~~~~ expression
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

## Variables

### Local

Format:
```
(lvar :foo)
"foo"
 ~~~ expression
```

### Instance

Format:
```
(ivar :@foo)
"@foo"
 ~~~~ expression
```

### Global

Format:
```
(gvar :$foo)
"$foo"
 ~~~~ expression
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

## Method definition

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

### Formal arguments

Format:
```
(args (arg :foo))
"(foo)"
 ~~~~~ expression
```

#### Required argument

Format:
```
(arg :foo)
"foo"
 ~~~ expression
 ~~~ name
```

#### Optional argument

Format:
```
(optarg :foo (int 1))
"foo = 1"
 ~~~~~~~ expression
     ^ assignment
 ~~~ name
```

#### Named splat argument

Format:
```
(splatarg :foo)
"*foo"
 ~~~~ expression
  ~~~ name
```

Begin of the `expression` points to `*`.

#### Unnamed splat argument

Format:
```
(splatarg)
"*"
 ^ expression
```

#### Decomposition

Format:
```
(def :f (args (arg :a) (mlhs (arg :foo) (splatarg :bar))))
"def f(a, (foo, *bar)); end"
          ^ begin   ^ end
          ~~~~~~~~~~~ expression
```

#### Keyword argument

Format:
```
(kwoptarg :foo (int 1))
"foo: 1"
 ~~~~~~ expression
 ~~~~ name
```

#### Named keyword splat argument

Format:
```
(kwsplat :foo)
"**foo"
 ~~~~~ expression
   ~~~ name
```

#### Unnamed keyword splat argument

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
