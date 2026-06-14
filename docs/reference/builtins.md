# Built-in functions

Built-ins start with `@`. They're invoked like ordinary function calls but receive the **current value** implicitly.

## `@echo(expr)`

Print a value to stdout. Returns the current value unchanged.

```rae
@echo(.header.magic)
```

Useful for debugging intermediate values without breaking the pipeline.

## `@write(path)`

Serialize the current value to a file and return the byte count.

```rae
@write("out.bin")
```

The current value must be a `VBytes`, `VObj` (against the top-level schema), or anything with a sensible byte representation. After `@write`, you can continue the pipeline.

If you pass `-o out.bin` on the CLI, the engine also writes the **final expression's value** to `out.bin`. Use `@write` for in-script writes; use `-o` for the conventional final write.

## `@checksum(expr)` / `@checksum()`

16-bit byte-sum checksum. Lower 16 bits of the sum of all bytes.

```rae
@checksum(.payload)
@checksum()             // checksum the current value
```

Use this to write a checksum field manually:

```rae
.checksum = @checksum(.body)
```

## `@crc32(expr)`

IEEE 802.3 CRC32. Returns a `VInt32`.

```rae
@crc32(.payload)
```

Used in many network protocols (Ethernet, PNG, ZIP, ...).

## `@align(value, N)`

Round `value` up to the next multiple of `N`.

```rae
@align(.offset, 4)
```

`@align(7, 4) == 8`. `N` must be positive.

## `@bswap16(expr)` / `@bswap32(expr)`

Swap byte order of a 16- or 32-bit integer.

```rae
@bswap16(.u16_field)
@bswap32(.u32_field)
```

Useful for inline endian conversions when a per-field `[endian = ...]` doesn't fit (for example, mixed-endian data inside a single field).

## `@select(condition)`

Filter elements of an array. When the current value is an array, keep elements where the condition is non-zero.

```rae
.records[] | @select(.valid) | .value
```

Inside the condition, `_` (or `.`) refers to the current array element.

## `@expand(expr)`

Force an expression to expand to its elements. Useful when a pipe would otherwise treat an array as a single value.

```rae
.arr | @expand | .field
```

Equivalent to `.arr[] | .field`.

## `@each(var in arr) { body }`

Map over an array. Binds `var` to each element and evaluates `body`. Returns a new array of the results.

```rae
@each(x in .arr) { x + 1 }
```

## `@block { ... }`

A multi-statement block. See [Block & @each](/reference/block) for full details.

```rae
@block {
  let total = .a + .b;
  let doubled = total * 2;
  doubled
}
```

## `@object`

Create an empty object. Mainly for internal use; consider using field syntax in expressions instead.