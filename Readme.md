# led

led is a **library** for adding scripting functionality to a program written in **D**.
The scripting language resembles bash, lua or ruby with `end` as the block terminator.

## Syntax

```ruby
age = 21;

message = (if (age > 18) "Adult" else "Minor" end);

# message => "Adult"
```

## Status

This library is still in pre-pre-pre alpha state.

### Right now
 + simple expression : some operations are not implemented, function calls are done, but no method calls.
 + conditionals : `if .. else .. end` is done with returning value.
 + loops : `while .. end` is done but no support for control structures yet like `return`, `break` or `continue`.
 + functions : native functions and scripting funtions are done without control structures.
 + classes and objects : native classes can be added by just implementing the `Type` interface, and no led classes **yet**
 + imports : not yet...

## Example

```d
import ledengine;
import ledtypes;
import std.stdio;

void main() {
    Scope ns = new Scope();
    
    writeln(ns.Eval("2+3"));
}
```

Compiling and running the above D program should print `5`.

## Usage
In your dub project add the dependency like this :

```json
"dependencies": {
    "led": "~master"
}
```
The version can be the one of the many found in the dlang package indexing website.
