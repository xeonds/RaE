# Offsets

The `@ offset` part of a field declaration tells the engine where to read the field. Four forms are supported.

## `@ N` — fixed offset

```rae
header: u32 @ 0;
body: bytes(16) @ 16;
```

The offset is in bytes from the start of the containing struct or file. Hex literals are accepted: `@ 0x10`.

## `@ after(field)` — place after another field

```rae
header: u32 @ 0;
body: bytes(16) @ after(header);
```

The engine looks up `field`'s end position and places the current field there. Useful when offsets depend on preceding variable-size fields without writing arithmetic.

> ⚠️ `after(X)` resolves to **X's end position**, not X's value. If you want to use X's value as an offset (e.g., a pointer-style field), use `@ (expr)` instead.

## `@ align(N)` — align to N bytes

```rae
data: u32 @ align(4);
```

Rounds up the current offset to the next multiple of `N`. The argument is an expression and can reference fields:

```rae
data: u32 @ align(.header.alignment);
```

## `@ (expr)` — dynamic expression

```rae
pointer: u32 @ (.offset_table[.idx]);
payload: bytes(8) @ (.pointer + 4);
```

The expression runs in the current environment, so it can read previously-parsed fields. It must evaluate to a non-negative integer.

## Omitting the offset

```rae
a: u8;
b: u16;
c: u32;
```

When `@` is absent, the engine auto-lays fields in declaration order, packing each immediately after the previous one. This is the cleanest form for header-style structs with fixed-size fields.

## Mixed layouts

You can mix explicit and implicit offsets in the same struct. The engine tracks the running "previous end" position as it scans fields left-to-right:

```rae
struct Pkt {
  magic: u32 @ 0;          // fixed
  version: u8;             // implicit: after(magic) = 4
  body: bytes(8);          // implicit: after(version) = 5
  trailer: u16 @ 0;        // explicit: back to start (overlap is allowed)
}
```

Overlapping fields are allowed — RaE doesn't enforce uniqueness of byte ranges.

## Offsets in nested structs

Each nested struct has its own offset 0. The `@ N` is relative to the parent's start, not the file's start:

```rae
struct Inner {
  x: u8 @ 0;
  y: u8 @ 1;
}

file F {
  inner: Inner @ 8;       // Inner starts at byte 8 of the file
  inner.x                  // byte 8
  inner.y                  // byte 9
}
```