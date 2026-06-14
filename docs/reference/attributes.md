# Attributes

Square-bracket attributes modify a field's parsing or serialization. They appear after the offset and before the optional `==` assertion.

## Syntax

```rae
name: type @ offset [key = value, key2 = value2] == expected;
```

Attributes are comma-separated key/value pairs inside `[...]`. Values are expressions evaluated in the field's environment.

## `count`

How many elements an `array<T>` has. Mandatory for arrays.

```rae
items: array<u32> [count = 8];
payload: array<u8> [count = .header.len];
```

`count` is read as an integer. For primitives, `array<u8> [count = 4]` reads 4 bytes.

## `if`

Skip the field if the condition is false. When `if` is false, the field is absent from the parsed tree and writes as zero bytes.

```rae
opt_field: u32 [if = .flags & 0x01];
```

This is useful for optional fields in a packed structure.

## `validate`

Run an assertion at parse time. Unlike `==`, the value is an arbitrary expression evaluated in the field's environment. The field fails to parse if the expression returns 0 (false).

```rae
version: u8 [validate = .version >= 1 && .version <= 4];
```

## `endian`

Per-field endianness. Default is little-endian (LE).

```rae
magic: u32 @ 0 [endian = be] == 0x7F454C46;
```

Accepted values are `le` and `be`. The keyword can be uppercase: `[endian = BE]`.

## `checksum`

Mark this field as a checksum to be filled automatically during **construction**.

```rae
struct Pkt {
  type: u8;
  len: u8;
  body: bytes([count = .len]);
  crc: u32 [checksum = .body];
}
```

When you build the packet with `new Pkt { ... }`, the engine computes a CRC32 over the prior fields and writes it into `crc`. The expression after `=` is stored but not used at parse time — it's a label that documents what gets checksummed.

## Combining attributes

Multiple attributes are comma-separated. Order doesn't matter:

```rae
items: array<u8> [count = .n, endian = be];
```

All attributes are independent — there's no conflict resolution. If you set both `if` and `count`, an absent field consumes no bytes regardless of `count`.