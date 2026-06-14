# Operators

RaE's operator precedence, top to bottom (highest first):

| Level | Operators                              | Associativity |
|-------|----------------------------------------|---------------|
| 1     | `.` `[]` `()`                          | left          |
| 2     | unary `-` `!` `~`                      | right         |
| 3     | `*` `/`                                | left          |
| 4     | `+` `-`                                | left          |
| 5     | `<<` `>>`                              | left          |
| 6     | `&` `^` (also `land` `lxor`)           | left          |
| 7     | `\|` (also `lor`) — bitwise or         | left          |
| 8     | `<` `<=` `>` `>=`                      | left          |
| 9     | `==` `!=`                              | left          |
| 10    | `&&`                                   | left          |
| 11    | `\|\|`                                 | left          |
| 12    | `=` (assignment)                       | right         |
| 13    | `\|` (pipe)                            | left          |

## Arithmetic

```rae
.a + .b
.a - .b
.a * .b
.a / .b
-a
```

Integer division truncates toward zero. Mixing `VInt` and `VInt32` widens to `VInt32`; with `VInt64`, to `VInt64`.

## Bitwise

```rae
.a & .b                  // AND (symbol &) — but note: bare `|` is the pipe
.a ^ .b                  // XOR
.a land .b               // AND (keyword form, always safe)
.a lor .b                // OR (keyword form — `|` alone is the pipe)
.a lxor .b               // XOR (keyword form)
.a << 2
.a >> 1
~.a                      // bitwise NOT
```

::: warning
`|` is the **pipe operator**, not bitwise OR. Use `lor` for bitwise OR.
:::

## Comparison

```rae
.a == .b
.a != .b
.a < .b
.a <= .b
.a > .b
.a >= .b
```

Returns 1 (true) or 0 (false). Strings compare lexicographically.

## Logical

```rae
.a && .b       // AND
.a || .b       // OR
!.a            // NOT — returns 1 if .a is 0, else 0
```

These short-circuit: in `a && b`, `b` is not evaluated when `a` is 0.

## Pipe vs bitwise OR

Because `|` is the pipe operator, the only way to spell bitwise OR is `lor`. This is a known ambiguity in jq-style grammars and RaE chose pipes.

```rae
.flags | .mode            // pipe
.flags lor 0x80           // bitwise OR
```

## Assignment

```rae
.a = 1
.b.c = 2
.arr[0] = 3
```

Returns the new current value. Use `=` only on the rightmost stage of a pipeline unless you intend to overwrite the whole current value.

## Grouping

Parentheses override precedence:

```rae
(.a + .b) * .c
```

Use them whenever the precedence is non-obvious, especially around `&&`, `||`, and bitwise operators.