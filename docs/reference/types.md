# Types

Every field has a type. RaE supports primitive integers and floats, strings, raw bytes, fixed-size arrays, named structs, and parameterized templates.

## Primitive integers

| Type | Size (bytes) | Notes                                  |
|------|--------------|----------------------------------------|
| `u8` | 1            | Unsigned 8-bit                         |
| `u16`| 2            | Unsigned 16-bit                        |
| `u32`| 4            | Unsigned 32-bit                        |
| `u64`| 8            | Unsigned 64-bit (may display negative) |
| `i8` | 1            | Signed 8-bit                           |
| `i16`| 2            | Signed 16-bit                          |
| `i32`| 4            | Signed 32-bit                          |
| `i64`| 8            | Signed 64-bit                          |

`u64` values larger than `2^63 - 1` print as negative integers because OCaml's `Int64` is signed. The bit pattern is correct.

## Floats

| Type | Size (bytes) |
|------|--------------|
| `f32`| 4            |
| `f64`| 8            |

Stored and loaded as IEEE 754. The `[endian = ...]` attribute applies.

## Strings

```rae
name: string;             // variable length, reads until end of buffer
name: string(16);         // exactly 16 bytes, null-padded if shorter
```

The encoding is UTF-8 by default. Fixed-size strings are zero-padded when serialized.

## Raw bytes

```rae
data: bytes(64);          // exactly 64 bytes
payload: bytes;           // variable length, reads until end of buffer
```

`bytes(n)` is a fixed-size byte array. Bare `bytes` reads to the end of the input — useful at the top level.

## Arrays

```rae
items: array<u8>;         // count is read from [count = N]
items: array<u32> [count = 4];
names: array<string(8)> [count = 8];
```

The element type is any other type. The `[count = expr]` attribute is mandatory — it controls how many elements the engine reads and how much space to allocate when constructing.

`array<T>` reads exactly `count` elements of type `T` in sequence.

## Structs

```rae
struct Header {
  magic: u32 [endian = be];
  version: u8;
}

header: Header @ 0;
```

A struct is a named group of fields. Refer to it by name as a type. Nested structs are parsed recursively.

See **[Structs & variants](/reference/structs)** for variants and conditions.

## Templates

```rae
template<T, U> Pair {
  first: T;
  second: U;
}

p: Pair<u32, string(8)>;
```

Templates parameterize a struct over one or more type variables. On instantiation the type variables are substituted throughout the body. Templates work for primitive types too — `Pair<u32, u8>` is a valid use.

## Type resolution

When a field's type is an `IDENT`, the engine looks up a matching struct, enum, or template. The lowercase primitive type names (`u8`, `u16`, ...) are resolved as their primitive types, not struct lookups.