# Filter with @select

Pick out specific records from an array based on a condition.

## Use case

A binary contains a header followed by an array of records. Each record has a `type` byte. You want only the records where `type == 1`.

## Script

```rae
file Log {
  struct Header {
    count: u16 @ 0 [endian = be];
  }

  struct Record {
    type:   u8 @ 0;
    length: u8 @ 1;
    body:   bytes([count = .length]) @ 2;
  }

  header:  Header @ 0;
  records: array<Record> [count = .header.count] @ 2;
}
```

Now filter:

```rae
.records[] | @select(.type == 1) | .body
```

## How it works

- `.records[]` expands the array into individual elements. After this, `_` is one record.
- `@select(.type == 1)` keeps the element only if `type` equals 1.
- `.body` projects to the record's body bytes.

The final value is a `VArray` of `VBytes` values — the bodies of all matching records.

## Trying it

Build a sample binary:

```bash
cat > /tmp/make_log.rae <<'EOF'
file Log {
  struct Header { count: u16 @ 0 [endian = be]; }
  struct Record { type: u8; length: u8; body: bytes(4); }
  header: Header;
  records: array<Record> [count = .header.count];
}

new Log {
  header = new Header { count = 3 },
  records = [
    new Record { type = 1, length = 4, body = "AAA" },
    new Record { type = 2, length = 4, body = "BBB" },
    new Record { type = 1, length = 4, body = "CCC" },
  ]
} | @write("log.bin")
EOF

rae /tmp/make_log.rae /dev/null
```

Now filter it:

```bash
rae "file Log {
  struct Header { count: u16 @ 0 [endian = be]; }
  struct Record { type: u8; length: u8; body: bytes([count = .length]) @ 2; }
  header: Header @ 0;
  records: array<Record> [count = .header.count] @ 2;
}
.records[] | @select(.type == 1) | .body" log.bin
```

The output is the count of bodies (length-only summary):

```
bytes(3)
bytes(3)
```

## Counting matches

Combine `@select` with a manual count:

```rae
@block {
  let matches = .records[] | @select(.type == 1);
  @echo(matches);
  matches
}
```

## More complex conditions

Any expression returning a non-zero integer is truthy:

```rae
.records[] | @select(.type == 1 && .length > 0) | .body
```

```rae
.records[] | @select(.type != 0xFF) | .body
```

## Projecting after filtering

To extract just one field of each match, keep the pipe:

```rae
.records[]
  | @select(.type == 1)
  | .body
```

To extract multiple fields, build a structured result by combining `@echo` and `@write`:

```rae
@block {
  let hits = .records[] | @select(.type == 1);
  @echo("Found", hits);
  hits[0].body    // first match's body
}
```

## Why `@select` over a block?

`@select` is concise and composes naturally with `.records[] | ...`. The block form would require iterating manually:

```rae
@block {
  let hits = [];
  @each(r in .records) {
    @select(r.type == 1);
    hits
  };
  hits
}
```

`@select` removes a layer of nesting and reads like jq.

## Performance note

`@select` is `O(n)` over the array. For very large arrays, the engine still parses every element first (because the count is fixed) and only filters the parsed tree. If you need streaming-style filtering, you must implement it at a lower level — RaE always parses the whole structure before evaluating expressions.