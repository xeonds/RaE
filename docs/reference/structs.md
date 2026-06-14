# Structs & variants

Structs group named fields. Variants add tagged-union dispatch — useful for protocols with a type byte followed by type-specific payload.

## Basic struct

```rae
struct Header {
  magic: u32 @ 0 [endian = be];
  version: u8;
  flags: u8;
}
```

A struct is a record with named fields. You can nest them by referring to one struct as another field's type:

```rae
file F {
  struct A { x: u8; }
  struct B { y: u8; }

  a: A @ 0;
  b: B @ 2;
}
```

## Conditions

A struct can carry an optional `if` condition that gates parsing:

```rae
struct OptHeader(version >= 2) {
  extended_flags: u16;
}
```

When the condition is false, the struct is skipped — none of its fields are read.

## Variants — tagged unions

A `variant` member dispatches to one of several `case`s based on a tag field's value:

```rae
struct Packet {
  type: u8 @ 0;
  variant(type) {
    0x01 => { data: u32 @ 1; }
    0x02 => { count: u16 @ 1; }
  }
}
```

The syntax is `variant(<tag-field-name>) { <pattern> => { <fields> }, ... }`. The pattern is an expression compared against the tag's value at parse time.

Only the matched case's fields are added to the parsed tree. Other cases contribute zero bytes.

### Patterns

Patterns are expressions. Common forms:

```rae
variant(type) {
  1 => { ... }
  2 => { ... }
  0x10 => { ... }
}
```

A pattern returns any integer value. Comparisons with the tag's runtime value use `values_equal`, so patterns and tag values must compare equal under that function.

## Nested variants

A case body can itself contain a variant:

```rae
struct Frame {
  kind: u8;
  variant(kind) {
    1 => {
      sub_kind: u8;
      variant(sub_kind) {
        0xAA => { aa_payload: u16; }
        0xBB => { bb_payload: u32; }
      }
    }
    2 => { simple_payload: u8; }
  }
}
```

Each `variant` looks up its tag in the current environment, which includes outer variants' fields.

## Construction

When constructing with `new Struct { ... }`, you must provide values for the **non-variant** fields. Variant case fields are not required because they're filled by the dispatcher at parse time.

```rae
new Packet { type = 1, data = 0xCAFEBABE }
```

The engine lays out the fixed fields, then lays out the case fields at the offsets they declare. The case is selected implicitly by `type`'s value.