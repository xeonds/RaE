---
layout: home

hero:
  name: RaE
  text: awk/jq for binary files
  tagline: Declarative schema + pipeline expressions to parse, inspect, mutate, and construct binary data.
  actions:
    - theme: brand
      text: Get started
      link: /guide/getting-started
    - theme: alt
      text: View on GitHub
      link: https://github.com/xeonds/RaE

features:
  - title: Declarative schema
    details: Define your binary structure once with struct, enum, variant, template. The engine handles offsets, alignment, and endianness automatically.
  - title: Pipeline expressions
    details: jq-style field access, pipes, and select() cover 80% of inspection tasks. Drop into @block when you need imperative logic.
  - title: Mutate and write
    details: Assign to .field paths to mutate the parsed tree, then @write to serialize. Checksums auto-update on construction.
  - title: Construct from scratch
    details: Build a binary from zero with the new keyword. No input file required — pipe /dev/null or omit the binary arg.
---