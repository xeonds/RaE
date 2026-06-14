# ELF header

A complete walkthrough of parsing an ELF executable's header with RaE.

## Background

The ELF (Executable and Linkable Format) header is a 52- or 64-byte structure at the start of every ELF file. The first four bytes are the magic number `\x7F E L F`. The next byte describes the class (32-bit or 64-bit), followed by endianness, version, and a long list of offsets and counts.

This example parses just the first 24 bytes of a 64-bit ELF and prints its version.

## Script

Save as `elf.rae`:

```rae
file ELF {
  struct H {
    magic:    u32 @ 0  [endian = be] == 0x7F454C46;
    class:    u8  @ 4;
    data:     u8  @ 5;
    version:  u8  @ 6;
    osabi:    u8  @ 7;
    pad:      u8  @ 8;
    pad2:     u16 @ 9;
    pad3:     bytes(7) @ 11;
    type:     u16 @ 18 [endian = be];
    machine:  u16 @ 20 [endian = be];
    eversion: u32 @ 22 [endian = be];
  }

  header: H @ 0;
}

.header.version
```

The schema declares a struct `H` with all 24 bytes as named fields. The `== 0x7F454C46` assertion verifies the magic at parse time — a typo or non-ELF file fails loudly.

## Run

```bash
rae elf.rae /bin/ls
# → 1
```

`/bin/ls` on most Linux distributions starts with `\x7FELF\x02\x01\x01`, so `version` is `1`.

## Trying other fields

```bash
# Print the architecture
rae elf.rae /bin/ls    # → 1
```

Edit the last line of the script:

```rae
.header.machine        # → 62 (x86_64)
.header.type           # → 2 (ET_EXEC)
```

## Why this works

- The `==` assertion on `magic` ensures the file is actually an ELF. If you point RaE at a JPEG, parsing aborts with an engine error.
- `[endian = be]` is correct because the ELF header is always stored in the file's endianness; the magic is `\x7FELF` regardless, but the byte order of subsequent fields depends on the byte at offset 5.
- All field offsets are explicit (`@ N`) to make the structure obvious. You could omit them and let the engine auto-pack, since each field's size is known.

## Extending

To parse more of the ELF header (program headers, section headers), add nested structs:

```rae
struct Phdr {
  ptype:   u32 @ 0  [endian = be];
  pflags:  u32 @ 4  [endian = be];
  poffset: u64 @ 8  [endian = be];
  pvaddr:  u64 @ 16 [endian = be];
  pfilesz: u64 @ 24 [endian = be];
  pmemsz:  u64 @ 32 [endian = be];
  palign:  u64 @ 40 [endian = be];
}

struct H {
  // ... existing fields ...
  phoff:   u64 @ 24 [endian = be];   // offset of program headers
  shoff:   u64 @ 32 [endian = be];
  phentsize: u16 @ 54 [endian = be];
  phnum:   u16 @ 56 [endian = be];
}

header: H @ 0;
phdrs: array<Phdr> [count = .header.phnum] @ (.header.phoff);
```

This pattern — fixed header then array of variable-size structures — is the bread and butter of binary parsing in RaE.