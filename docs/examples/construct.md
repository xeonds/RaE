# Construct from scratch

Build a binary entirely from RaE, with no input file.

## Use case

You're generating a binary — a config blob, a network packet, a firmware image. Writing it by hand means juggling offsets and endianness. With RaE, you describe the structure and the engine assembles the bytes.

## Script

```rae
file F {
  struct Pkt {
    type:    u8;
    length:  u8;
    payload: array<u8> [count = .length];
    crc:     u32 [checksum = .payload];
  }
}

new Pkt { type = 1, length = 4, payload = [0xAA, 0xBB, 0xCC, 0xDD] }
  | @write("pkt.bin")
```

This declares a packet with a type byte, length byte, payload, and a CRC32 over the payload. The `[checksum = ...]` attribute tells the engine to compute the CRC32 automatically and write it into `crc` on construction.

## Run

```bash
rae "file F { struct Pkt { type: u8; length: u8; payload: array<u8> [count = .length]; crc: u32 [checksum = .payload]; } } new Pkt { type = 1, length = 4, payload = [0xAA, 0xBB, 0xCC, 0xDD] } | @write(\"pkt.bin\")" /dev/null

xxd pkt.bin
# 00000000: 0104 aabb cccd ........
```

The four trailing bytes (after the payload) are the CRC32 of `[AA BB CC DD]`.

## Constructing arrays

`array<u8> [count = .length]` reads or writes `length` bytes. The count expression can reference earlier fields:

```rae
struct Pkt {
  count:   u8;
  values:  array<u32> [count = .count];
}

new Pkt { count = 3, values = [100, 200, 300] }
```

The engine allocates `3 * 4 = 12` bytes for `values`.

## Constructing nested structs

```rae
struct Inner {
  x: u8;
  y: u8;
}

struct Outer {
  magic: u32 [endian = be];
  inner: Inner;
}

new Outer { magic = 0xDEADBEEF, inner = new Inner { x = 1, y = 2 } }
```

Nesting works recursively. Each struct's fields are laid out in declaration order, packing them after one another.

## Constructing with templates

```rae
template<T> Box {
  tag:    u8;
  value:  T;
}

new Box<u32>    { tag = 1, value = 0xCAFEBABE }
new Box<string(8)> { tag = 2, value = "hello" }
```

Template substitution happens at parse time — there's no runtime cost.

## Reading stdin

When constructing, the input file is required by the CLI but not read. Use `/dev/null` for clarity:

```bash
rae construct.rae /dev/null
```

Or omit the input and let RaE read empty stdin:

```bash
echo -n "" | rae construct.rae
```

Both work identically.

## Checksum fields

The `[checksum = ...]` attribute fires only on **construction**, not on parsing. After parsing an existing binary, the field contains whatever was in the file. After constructing, the field contains the engine-computed CRC32.

Supported checksum functions:

| Function | Output                |
|----------|-----------------------|
| `crc32`  | 32-bit IEEE 802.3 CRC |

A 16-bit byte-sum checksum is available as `@checksum` for manual use, but no automatic attribute for it yet.