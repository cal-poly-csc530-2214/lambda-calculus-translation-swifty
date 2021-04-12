#  Assignment 2: Simple translation

So, I decided to base my work on my DXUQ interpretor from CSC 430. Note that I didn't use the Racket version, but a version I'd translated into Swift. This made sense to me, since I was translating to Swift. Plus, while I'd gotten functional programming down pretty good, it's still not my preferred style for all programming. Rather, I like it as an option / style when I need it.

## Syntax

To that end, I'm using a slightly different syntax, albeit more complex syntax:

```
LC = num
   | id
   | (fn id (args ...) LC)
   | (LC LC)
   | (+ LC LC)
   | (* LC LC)
   | (/ LC LC)
   | (- LC LC)
   | (and LC LC)
   | (or LC LC)
   | (xor LC LC)
   | (== LC LC)
   | (!= LC LC)
   | (<= LC LC)
   | (>= LC LC)
   | (< LC LC)
   | (> LC LC)
   | (begin LC*)
   | (if LC LC LC)
   | (let (id = LC) in LC)
   | (id := LC)
   | (print LC*)
```

Sorry if the syntax isn't 100% correct. There's the main points of difference:

1. The interesting things here are that I support generic `if` rather than just `ifleq0` and I therefore also support a number of equality operators.
2. I support assignment and `let`, which allows me to implement basic recursion.
3. Originally, `let` was defined via syntactic sugar, I promoted it to the AST with it's own expression type. This makes language translation much easier.
4. My langauge also supports strings and reals, but for assignment purposes, I only tested with integers.
5. Also note that I support using either braces or parentheses to denote expressions, which is why the example below uses braces.

## Example

The nice thing about this is that I was able to use my DXUQ unit tests to also test my translator, after a few modifications. Here's an example input, from one of our more complicated tests:

```Racket
{let
  {fact = {fn {n} 0}}
in
{begin
  {fact := {fn {n} {if {<= n 0} 1 {* n {fact {- n 1}}}}}}
  {print "12! =" {fact 12}}
  {fact 12}}}
```

Which generates the following code:

```Swift
func main() -> Any {
    var fact = { (n: Any) -> Any in 0 }

    return { () -> Any in
        _ = fact = { (n: Any) -> Any in {() -> Any in
            if (n <= 0) {
                return 1
            } else {
                return (n * fact((n - 1)))
            }
        }() }
        _ = print("12! =", fact(12))
        return fact(12)
    }()
}
```

Some notes here:

1. I somewhat arbitrarily name the top level "lambda" main(), since Swift doesn't like a lambda at the top leve.
2. There's some odd looking code, like `_ = LC`. This is because all of our expression return a value, even though we ignore some values. For example, our assignment returns a value, but it's meaningless. The does, in some cases, produce a warning, like the `_ = print..)` line, because print in Swift returns `Void`, and so assigning it produces a warning, even though the assignment to _ basicaly indicates that the return value should be ignore.
3. The code is slightly more complicated than Swift code would normally be, again do to things always return values in our base language. A good example of this is the `if` block. In Swift, we wind up wrapping this is a lambda, even though that's not strictly necessary.
4. You can see from the code, where if we had typechecking, the outputted code could be a lot nicer.
5. This code does run, and produces the output: `12! = 479001600`, which is correct.
6. The lack of typing requires a little bit of "help" by the use. For example, in the original code, the let statement defined `fact = "bogus"`, which that means that Swift would define `fact` to be a string, which means Swift would then not allow the assignment of the lambda further down.
7. Don't try too hard, I'm sure something could easily be found that'll break the translation. For example, using reals.
8. The actual code generation is done in a manner similar to unparse, except that it unparses to Swift.
    a. This required adding an "indent" parameter to Environment.
    b. Likewise, this requires then passing Environment to the code generation.
9. Another interesting point is that Swift declares variables as either `let` or `var`. `let` is basically a constant, while `var` can be assigned to, or otherwise mutated. This required that I examine subexpressions to see if the assignment operator was used. If it was, I had to declare with `var`.

## Type Checking

That being said, I dont' support the full DXUQ syntax. The big thing not support is that I based my work on the version of DXUQ just prior to supporting typing. The problem this caused is that Swift is actually a strongly typed langauge. This leads to the problem when generating Swift code, in that Swift wants me to declare the argument and return type of everything. To get around this issue, I made everything in Swift return `Any`, which is the way the program can tell Swift that the type can be, well, anything. This creates further problems in that basic Swift operators don't work on `Any`, like `+` or `*`. To get around that, I added a bunch of "glue" code to make this work. **This is a horribly bad thing to do, and should never be done in production code!** But, for the purposes of our exercise, it works pretty well. 

## Glue Code

Here's the "glue" code. Note that this code is probably not complete, but works for my test cases. I didn't go for 100% code coverage.

```Swift
func integer(from value: Any) -> Int64? {
    if let value = value as? Int { return Int64(value) }
    if let value = value as? Int8 { return Int64(value) }
    if let value = value as? Int16 { return Int64(value) }
    if let value = value as? Int32 { return Int64(value) }
    if let value = value as? Int64 { return value }
    if let value = value as? UInt { return Int64(value) }
    if let value = value as? UInt8 { return Int64(value) }
    if let value = value as? UInt16 { return Int64(value) }
    if let value = value as? UInt32 { return Int64(value) }
    if let value = value as? UInt64 { return Int64(value) }
    if let value = value as? String { return Int64(value) }
    if let value = value as? Bool { return value ? 1 : 0 }
    return nil
}

func boolean(from value: Any) -> Bool? {
    if let value = value as? Int { return value != 0 }
    if let value = value as? Int8 { return value != 0 }
    if let value = value as? Int16 { return value != 0 }
    if let value = value as? Int32 { return value != 0 }
    if let value = value as? Int64 { return value != 0 }
    if let value = value as? UInt { return value != 0 }
    if let value = value as? UInt8 { return value != 0 }
    if let value = value as? UInt16 { return value != 0 }
    if let value = value as? UInt32 { return value != 0 }
    if let value = value as? UInt64 { return value != 0 }
    if let value = value as? String { return value != 0 }
    if let value = value as? Bool { return value }
    return nil
}

func string(from value: Any) -> String {
    return String(describing: value)
}

func + (left: Any, right: Any) -> Any {
    if let left = integer(from: left), let right = integer(from: right) {
        return left + right
    }
    return 0
}

func - (left: Any, right: Any) -> Any {
    if let left = integer(from: left), let right = integer(from: right) {
        return left - right
    }
    return 0
}

func * (left: Any, right: Any) -> Any {
    if let left = integer(from: left), let right = integer(from: right) {
        return left * right
    }
    return 0
}

func / (left: Any, right: Any) -> Any {
    if let left = integer(from: left), let right = integer(from: right) {
        return left / right
    }
    return 0
}

func < (left: Any, right: Any) -> Bool {
    if let left = integer(from: left), let right = integer(from: right) {
        return left < right
    }
    return false
}

func <= (left: Any, right: Any) -> Bool {
    if let left = integer(from: left), let right = integer(from: right) {
        return left <= right
    }
    return false
}

func > (left: Any, right: Any) -> Bool {
    if let left = integer(from: left), let right = integer(from: right) {
        return left > right
    }
    return false
}

func >= (left: Any, right: Any) -> Bool {
    if let left = integer(from: left), let right = integer(from: right) {
        return left >= right
    }
    return false
}

func == (left: Any, right: Any) -> Bool {
    if let left = integer(from: left), let right = integer(from: right) {
        return left == right
    }
    return false
}

func != (left: Any, right: Any) -> Bool {
    if let left = integer(from: left), let right = integer(from: right) {
        return left != right
    }
    return false
}

func && (left: Any, right: Any) -> Bool {
    if let left = boolean(from: left), let right = boolean(from: right) {
        return left && right
    }
    return false
}

func || (left: Any, right: Any) -> Bool {
    if let left = boolean(from: left), let right = boolean(from: right) {
        return left && right
    }
    return false
}

infix operator ^^

func ^^ (left: Any, right: Any) -> Bool {
    if let left = boolean(from: left), let right = boolean(from: right) {
        return (left && !right) || (!left && right)
    }
    return false
}
```
