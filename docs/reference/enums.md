# Enums & bitfields

Enums name integer constants. Bitfields describe packed bit-level fields inside a single byte or word.

## Enums

```rae
enum Color : u8 {
  RED = 0;
  GREEN = 1;
  BLUE = 2;
}
```

The base type (`u8`, `u16`, `u32`, ...) determines the enum's storage size. Members are name/value pairs.

Enum values are just integers at parse time — they don't auto-decode into their names. Use the value directly:

```rae
file F {
  color: Color @ 0;
}

.color             // raw integer (e.g., 1 for GREEN)
```

If you want a symbolic name, write a pipeline expression:

```rae
.color | if . == 0 then "RED" elif . == 1 then "GREEN" else "BLUE" end
```

(Or, in RaE, use a sequence of `@select` calls or just check `.color == Color.GREEN` if you expose enum members as constants — currently the parser does not export enum members, so the integer literal is the only form.)

## Bitfields

Bitfields describe packed bits within a single byte:

```rae
bitfield Flags {
  READ    : 1;
  WRITE   : 1;
  EXEC    : 1;
  RESERVED: 5;
}
```

The numbers are bit widths. Members are packed in declaration order, least-significant bit first, into the smallest unit that fits (typically a byte).

A bitfield used as a field's type:

```rae
flags: Flags @ 4;
```

The engine reads or writes the packed bits as a single integer when constructing or destructuring.

## Use cases

- **Enums**: tag bytes, type fields, mode selectors.
- **Bitfields**: register-style flags, packed status words, hardware register layouts.

Both are pure schema features — they don't change how expressions work, only how fields are encoded into bytes.