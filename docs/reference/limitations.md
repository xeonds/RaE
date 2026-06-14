# Known limitations

RaE is at v1.0 and has a handful of known limitations. Most have workarounds; all are documented.

## Display of large u64

**Symptom:** `u64` values larger than `2^63 - 1` print as negative integers.

**Cause:** OCaml's `Int64` is a signed 64-bit integer. The bit pattern is read correctly, but the pretty-printer treats the high bit as a sign.

**Workaround:** Use hex literals in expressions, or compare against hex values:

```rae
.value == 0xFFFFFFFFFFFFFFFF      // works
.value                             // prints negative for large u64
```

This is an OCaml limitation, not a RaE bug — fixing it would require an `Int64`-as-unsigned type throughout the engine.

## No `|` as bitwise OR

**Symptom:** `a | b` is parsed as a pipe, not a bitwise OR.

**Cause:** `|` is the pipe operator throughout RaE's grammar.

**Workaround:** Use the keyword form `a lor b`. For non-carry cases, `a + b` may also work.

## `after(X)` is field end, not field value

**Symptom:** `@ after(.pointer)` does not give you the offset pointed to by `.pointer`.

**Cause:** `after(X)` resolves to X's end position (offset + size) in the schema, not X's runtime value.

**Workaround:** Use an explicit dynamic offset: `@ (.pointer + 4)`. This evaluates the expression at parse time.

## Imports are flat text concatenation

**Symptom:** Two `import` files with the same struct name collide silently.

**Cause:** The import processor concatenates files with no namespace.

**Workaround:** Rename types and fields manually, or write a single file. There's no module system.

## No module / namespace system

RaE scripts share one global identifier space per `file` block. Use distinct prefixes for similar concepts in large schemas.

## Variant patterns are not exhaustive

**Symptom:** If the tag's runtime value matches no `case`, no case fields are added.

**Workaround:** Add a default case (`_ => { ... }`) at the end of the `variant` block to ensure some payload is always parsed.

## Array count must be known at parse time

`[count = expr]` is evaluated at parse time and must return a non-negative integer. If you need to parse a variable-length structure based on a sentinel or terminator, you'll need a different approach (e.g., a wrapper struct with explicit lengths).

## Variants don't have conditions on cases

Each case is selected purely by tag value. There's no `if`-style guard per case. If you need conditional cases, encode the condition in the tag value.

## Bitfield bit ordering

Bitfields pack bits least-significant-first by declaration order. Big-endian bitfields (MSB-first, common in some hardware specs) are not yet supported.

## No `if`/`else` expression

RaE has no ternary `if`/`else`. Use `@select` and explicit comparisons:

```rae
// jq-style
.a | if . > 0 then . else -. end

// RaE-style
.a | @select(. > 0) | .a        // doesn't quite work
```

In practice, multi-branch logic is expressed with `@block { let ... ; ... }` and explicit comparisons. See the [Block & @each](/reference/block) page for patterns.