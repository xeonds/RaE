# Expressions

Expressions are how you read, mutate, and produce data. The grammar is pipeline-first — most scripts are written as a chain of `.field` accesses joined by `|`.

## The current value: `_` and `.`

Every expression runs against a *current value* (`_`), initially the parsed file. Inside an expression, `.foo` is shorthand for `_.foo`. The current value changes as you pipe forward:

```rae
.header | .type        // same as _ | _.type, but _.type is .type
```

After a pipe, the next expression's `_` is the previous expression's value. Use `.` for short accessors and `_` when you need to pass the whole value.

## Field access

```rae
.a                // top-level field `a`
.a.b              // nested
.a[0]             // array index
.a[]              // expand array — produces VArray
```

`.a[]` is sugar for `@expand(.a)`. It yields each element of the array as a separate value when piped:

```rae
.records[] | select(.valid) | .value
```

Each element of `records` becomes the current value, then `select` filters, then `.value` projects.

## Assignment

```rae
.a = 99
.header.version = 2
.arr[0] = 42
```

Assignment mutates the current value in place. The expression returns the new current value, so it composes in pipelines:

```rae
.header.version = 2 | @write("out.bin")
```

See [Mutation mode](/guide/modes#2-mutate) for details on writing the result.

## Construction

```rae
new Schema { a = 1, b = "hi", c = 0xCAFE }
```

Build a value from scratch. The schema name must be a struct or template defined in the file. Field expressions are evaluated and laid out according to the schema's offsets and attributes.

```rae
new Pkt { type = 1, body = [0xAA, 0xBB, 0xCC] }
```

## Literals

| Kind      | Examples                                  |
|-----------|-------------------------------------------|
| Integer   | `42`, `0xCAFE`, `-7`                      |
| Float     | `3.14`, `-0.5`                            |
| String    | `"hello"`, `"line\nbreak"`                |
| Identifier| `a_field` (resolved against the current value or env) |

## Identifiers and the environment

A bare identifier is looked up first in the current value's fields, then in the enclosing environment. The environment holds:

- Top-level file fields.
- Block-local `let` bindings.

```rae
@block {
  let x = .header.size;
  x + 1
}
```

If a name is not found, the expression evaluates to `VNull`.

## Comments

```rae
// single-line
/* multi-line */
```

Comments are ignored by the parser. Use them liberally in schemas.