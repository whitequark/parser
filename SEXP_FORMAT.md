Location and Sexp RFC
=====================

# Open questions:

* Open close markers for delimited literals (regexp, string)?
  The parser would benefit from having them on the longerm.  Especially regexp can be very tricky.

* Format of this document is far from perfect.

## Literal

### Primitive

#### Integer

```
(lit 123)
"123"
 ~~~ expression
```
#### Float
```
(lit 1.0)
"1.0"
 ~~~ expression
```

#### String

```
(lit "foo")
"'foo'"
 ~~~~~ expresion
```

#### Singletons

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

### Regexp options

IMHO it makes sense to have an regexp options node.
Ruby regexp options are complex and under documented.

https://github.com/mbj/to_source/blob/master/lib/to_source/emitter/literal/regexp/options.rb#L5-L28

Also the pure symbols make sense. It helps not to leak regexp internals into the lexer.

```
(regopt :i :m)
"im"
 ~~ expression
```

### Regexp

Format:

```
(regexp (regopt :i :m) "source")
"/source/im"
 ~~~~~~~~~~ expression
```

### Execute-string

Format:

```
(xstr "foo")
"`foo`"
 ~~~~~ expression
```

### Dynamic

#### String

```
(dstr (lit "foo") (lvar bar) (lit "baz"))
'"foo#{bar}baz"'
 ~~~~~~~~~~~~~~ expression
```

#### Execute-string

```
(dxstr (lit "foo") (lvar bar))
"`foo#{bar}`"
 ~~~~~~~~~~ expression
```

#### Regexp

This is very close to RBX, inner nodes are strings rather regexp.
This way we avoid inner options!

```
(dregexp (regopt :i) (lit "source") (lvar bar))
"/foo#{bar}/i"
 ~~~~~~~~~~ expression
```

### Compound

#### Array

##### Plain
```
(array (lit 1) (lit 2))

"[1, 2]"
 ~~~~~~ expression
```

##### With interpolation

```
(array (lit 1) (splat (lvar :foo)) (lit 2))

"[1, *foo, 2]"
 ~~~~~~~~~~~~ expression
```

#### Hash

```
(hash (lit 1) (lit 2) (lit 3) (lit 4))
"{1 => 2, 3 => 4}"
 ~~~~~~~~~~~~~~~~ expression
```

#### Range

##### Inclusive

```
(irange (lit 1) (lit 2))
"(1..2)"
  ~~~~ expression
```

##### Exclusive

```
(erange (lit 1) (lit 2))
"(1...2)"
  ~~~~~ expression
```

## Binary operators (and or && ||)

```
(and (lvar :foo) (lvar :bar))
"foo and bar"
     ~~~ operator
 ~~~~~~~~~~~ expression
```

## Variables

### Local

```
(lvar :foo)
"foo"
 ~~~ expression
```

### Instance

```
(ivar :@foo)
"@foo"
 ~~~~ expression
```

### Global

```
(gvar :$foo)
"$foo"
 ~~~~ expression
```

## Assignment

### To local variable

```
(lvasgn :foo (lvar :bar))
"foo = bar"
     ^ assignment
 ~~~~~~~~~ expression
````

### To instance variable

```
(ivasgn :@foo (lvar :bar))
"@foo = bar"
     ^ assignment
 ~~~~~~~~~~ expression
````

### To class variable

```
(cvasgn :@@foo (lvar :bar))
"@@foo = bar"
       ^ assignment
 ~~~~~~~~~~~ expression
````

### To global variable

```
(gvasgn :$foo (lvar :bar))
"$foo = bar"
      ^ assignment
 ~~~~~~~~~~ expression
````

### Operator assignment

For `||= &&= *= /= += %= -=`

```
(op_asgn :||=  (lvar :foo) (lvar :bar))
"foo ||= bar"
     ~~~ operator
 ~~~~~~~~~~~ expression
```

### Multiple assignment

```
(:masgn [(assgn :foo, (lit, 1)), (assgn :bar, (lit, 1))])
"foo, bar = 1, 2"
          ^ operator
 ~~~~~~~~~~~~~~~ expression
```

## Formal Arguments

Used when defining methods / blocks.

```
(args (arg :foo))
"(foo)"
 ~~~~ expression
```

## argument (within formal arguments)

### Required

```
(arg :foo)
"foo"
 ~~~ expression
 ~~~ name
```

### Optional

```
(optarg :foo (lit 1))
"foo = 1"
 ~~~~~~~ expression
     ~ assignment
 ~~~ name
```

### Named Splat
```
(splatarg :foo)
"*foo"
 ~~~~ expression
  ~~~ name
```
No need to catch "*"?

### Unnamed Splat

```
(splatarg)
"*"
 ^ expression
```

### Keyword argument

```
(kwoptarg :foo (lit 1))
"foo: 1"
 ~~~~~~ expression
 ~~~~ name
```

### Keyword argument splat

```
(kwsplat :foo)
"**foo"
 ~~~~~ expression
   ~~~ name
```

## Actual argument

May be used in argument list.

### Splat argument

Used in argument lists like `foo(bar, *baz)`
Also used in array literals like `[*foo]`

```
(splat (lvar :foo))
"*foo"
 ^ operator
 ~~~~ expression

```

### Block pass

Used when passing expression as block `foo(&bar)`

```
(block-pass (lvar :foo))
"&foo"
 ^ operator
 ~~~~ expression
```

TODO: rename to block-reference and also use as block-capture?

## Send

### To self

#### Without arguments

```
(send nil :foo nil)
`foo`
 ~~~ expression
```

#### With arguments

```
(send nil :foo (lvar :bar))
"foo(bar)"
 ~~~ selector
 ~~~~~~~~ expression
```

### To receiver

#### Without arguments

```
(send (lvar :foo) :bar)
"foo.bar"
     ~~~ selector
 ~~~~~~~ expression
```

#### With arguments

```
(send (lvar :foo) :bar (lit 1))
"foo.bar(1)"
     ~~~ selector
 ~~~~~~~~~~ expression
```

#### Attribute assignment (just a send also)

```
(send (lvar :foo) :bar= (lvar :baz))
"foo.bar = baz"
     ~~~~~ selector
 ~~~~~~~~~~~~~ expression
```

#### Element assignment (also just a plain send)

```
(send (lvar :bar) :[]= (lit 1) (lvar :bar))
"foo[i] = bar"
    ~~~~~ selector (for the ease of implementation no extra ref to "[" and "]")
 ~~~~~~~~~~~~ expression
```

#### Element reference

```
(send (lvar :foo) :[] (lit 1))
"foo[i]"
    ~~~ selector
 ~~~~~~ expression
```

#### Binary "Method"-Operators, just like send to receiver

```
(send (lvar :receiver) :+ (lit 1))
"receiver + 1"
          ^ selector
 ~~~~~~~~~~~~ expression
```

#### Unary "Method"-Operators, just like send

```
(send (lvar :foo) :@-)
"-foo"
 ^ selector
 ~~~~ expression
````

## Blocks

```
(block (send nil :foo) (args (arg :bar)) (begin ...))
"foo do |bar|; end"
     ~~ open
               ~~~ close
 ~~~~~~~~~~~~~~~~~ expression
```


## Control flow

### Ternary operator

```
(if (lvar :cond) (lvar :iftrue) (lvar :iffalse))
"cond ? iftrue : iffalse"
      ^ question
               ^ colon
 ~~~~~~~~~~~~~~~~~~~~~~~ expression
```

### if

#### With else

```
(if (lvar :cond) (lvar :iftrue) (lvar :iffalse))
"if cond; iftrue; else; iffalse; end"
 ~~ keyword
                  ~~~~ else
                                 ~~~ close
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression
```

#### Without else

```
(if (lvar :cond) (lvar :iftrue) nil)
"if cond; iftrue; end"
 ~~ keyword
                  ~~~ close
 ~~~~~~~~~~~~~~~~~~~~ expression
```

### unless

#### with else

```
(unless (lvar :cond) (lvar :iftrue) (lvar :iffalse))
"unless cond; iftrue; else; iffalse; end"
 ~~~~~~ keyword
                      ~~~~ else
                                     ~~~ close
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression
```

#### without else

```
(unless (lvar :cond) (lvar :iftrue) nil)
"unless cond; iftrue; end"
 ~~~~~~ keyword
                      ~~~ close
 ~~~~~~~~~~~~~~~~~~~~~~~~ expression
```

### while

```
(while (lvar :condition) (send nil :foo))
"while condition; do; foo; end"
 ~~~~~ keyword
                  ~~ open
                           ~~~ close
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression
```

### until

```
(until (lvar :condition) (send nil :foo))
"until condition; do; foo; end"
 ~~~~~ keyword
                  ~~ open
                           ~~~ close
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ expression
```

## Define method

### Instance method

```
(def :foo (args) nil)
"def foo; end"
 ~~~ keyword
     ~~~ name
          ~~~ close
 ~~~~~~~~~~~~ expression
```
Do we need to track open and close here. Is there a diagnostics case?

### Singleton method

This includes the define on singleton `def self.foo` case!

```
(defs (self) (args) nil)
"def self.foo; end"
 ~~~
          ~~~ name
               ~~~ close
 ~~~~~~~~~~~~~~~~~ expression
```
