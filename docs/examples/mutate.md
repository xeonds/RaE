# Mutate + write

Modify fields in an existing binary and save the result.

## Use case

You have a binary with a known structure and want to patch a few bytes — for example, bumping a version number, flipping a flag, or zeroing a region.

## Script

```rae
// patch.rae
file F {
  a: u8 @ 0;
  b: u8 @ 1;
  c: u16 @ 2;
}

.a = 0xCA;
.b = 0xFE;
.c = 0xBABE;
@write("out.bin")
```

This reads a 4-byte input, overwrites all four fields with new values, and writes `out.bin`.

## Run

```bash
printf '\x00\x00\x00\x00' > /tmp/in.bin
rae patch.rae /tmp/in.bin

xxd out.bin
# 00000000: cafe beba                            ....
```

## Without `@write`

If you prefer, use the `-o` flag to write the final expression's value:

```rae
file F {
  a: u8;
  b: u8;
}

.a = 1; .b = 2
```

```bash
rae patch.rae /tmp/in.bin -o out.bin
```

The trailing expression's value (`{ a = 1, b = 2 }`) is serialized against the top-level schema and written to `out.bin`. The `@write` built-in is just an in-script alternative that lets you write to arbitrary paths or write multiple times.

## Multiple patches with one script

```rae
file F {
  flags: u8 @ 0;
  reserved: bytes(3) @ 1;
  payload: bytes(8) @ 4;
}

@block {
  // set bit 0 of flags
  .flags = .flags | 0x01;
  // zero the reserved region
  .reserved = bytes(3, 0);
  // tag payload with a marker
  .payload[0] = 0xAA;
  @write("patched.bin");
}
```

This script:
1. Sets the low bit of `flags` using bitwise OR (keyword form `|` is the pipe, so we use a different mechanism — here `.flags` is `u8`, and `| 0x01` is `flags OR 1`).
2. Replaces `reserved` with three zero bytes.
3. Tags the first byte of `payload`.

> **Note:** As of v1.0, bitwise OR is not directly available as `|`. Use the assignment form `.flags = .flags | 0x01` and let the engine handle the conversion, or use `+` if no carry is possible.

## Mutating nested structs

```rae
file F {
  struct Inner {
    x: u8;
    y: u8;
  }

  inner: Inner @ 0;
}

.inner.x = 99
```

Path-based assignment works at any depth.

## Common pitfalls

- **Final expression must produce `VBytes` (or be the top-level object).** If your last expression is `0` or `null`, `-o` has nothing to write.
- **`-o` is silent on failure.** If the final value isn't a `VObj` or `VBytes`, nothing is written — check stderr for engine errors.
- **`@write` returns a count, not the bytes.** Don't rely on it as the final expression if you want the mutated tree in the output.

## Combining with checksums

If your struct has a `[checksum = ...]` field, the engine recomputes it on write:

```rae
file F {
  body: bytes(8);
  crc: u32 [checksum = .body];
}
```

Just construct the file and let RaE handle the checksum.