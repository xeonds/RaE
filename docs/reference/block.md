# Block & @each

A block is a sequence of statements wrapped in `@block { ... }`. The last expression's value is the block's return value.

## Block syntax

```rae
@block {
  let x = .header.size;
  let y = x * 2;
  y + 1            // block returns y + 1
}
```

A block contains:

- Zero or more `let` bindings.
- One or more expressions (separated by `;`).

Earlier expressions' values are discarded. The **last expression** is the block's value.

## Why use a block?

- **Intermediate names** — bind a partial result with `let`.
- **Side effects** — call `@echo` or `@write` between steps.
- **Multi-step computation** — when one expression can't do everything.

```rae
@block {
  let bytes = .body;
  let sum = @checksum(bytes);
  let crc = @crc32(bytes);
  @echo(sum);
  crc
}
```

This pattern prints the checksum and returns the CRC32.

## Block scope

`let` bindings are scoped to the enclosing block. Inner blocks see outer bindings but not siblings':

```rae
@block {
  let x = 1;
  @block {
    let y = x + 1;    // OK — sees outer `x`
    y
  }
  // `y` is not visible here
}
```

## `@each(var in expr) { body }`

`@each` maps a block over an array:

```rae
@each(item in .records) { item.value + 1 }
```

- `var` is the iteration variable name.
- `expr` is evaluated against the current value and must return an array.
- `body` runs once per element with `var` bound to the element and `_` set to the element.

The result is a new array of the bodies' values.

### Use `@each` with `@select`

`@select` filters, `@each` transforms. Combine them in a pipeline:

```rae
.records[]
  | @select(.valid)
  | @each(r) { r.value * 2 }
```

## `@each` vs `@select`

| Built-in   | Returns           | Use for                       |
|------------|-------------------|-------------------------------|
| `@select`  | subset of array   | Filtering                     |
| `@each`    | transformed array | Per-element transformation    |

For simple `.field` projection, you don't need `@each` — `.records[] | .value` already iterates.

## Examples

```rae
// Sum an array
@block {
  let arr = .data;
  @each(x in arr) { x } | @crc32(_)
}
```

```rae
// Find the max value
@block {
  let best = 0;
  @each(x in .values) {
    best = if x > best then x else best;
    best
  };
  best
}
```

Note: the example above uses bare `if`/`else` which is not a RaE primitive — you'd typically use `@select` and `>` chains instead. The cleaner version:

```rae
.values[] | @select(. > .best_so_far)   // doesn't quite work; use @block
```

In practice, fold-style operations over arrays are best expressed with `@each` returning a single value and accumulating via `let` mutation in a parent block.