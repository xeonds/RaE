# Pipeline vs block

RaE has two ways to chain expressions:

| Style    | Syntax                       | Use for                                  |
|----------|------------------------------|------------------------------------------|
| Pipeline | `_ \| expr \| expr`          | 80% of cases — linear data flow          |
| Block    | `@block { let x = ...; ... }` | Imperative logic, multi-statement bodies |

## Pipeline — the default

A pipe `|` passes the value of the left expression into the right one. The right side sees the piped value as `_` (the current value).

```rae
.header.sections[] | select(.type == 1) | { .name, .size }
```

Read this as: *for each section, keep it if `type == 1`, then build an object with name and size*.

Pipes compose left-to-right and don't need parentheses.

## Block — when you need statements

Sometimes a single expression isn't enough — you want to bind a name, run side effects, then return a final value. Use `@block { ... }`:

```rae
@block {
  let total = .arr[0] + .arr[1];
  let doubled = total * 2;
  doubled
}
```

A block contains zero or more `let` bindings followed by expressions. The **last expression's value** is the block's return value. Earlier expressions' values are discarded.

Blocks can appear anywhere an expression is expected — including inside pipes:

```rae
.payload | @block {
  let n = @crc32(_);
  @write("crc.bin");
  n
}
```

Here `_` (or `.`) refers to the current value fed in by the pipe.

## `@each` — map over arrays

`@each` is a block-style built-in that iterates over an array:

```rae
@each(x in .arr) { x + 1 }
```

For each element `x`, evaluate the body and collect results into a new array. Use this when `@select` isn't enough — for example, when you need to transform each element rather than filter.

## When to use which

- **Pipeline** when the operation is naturally a chain of transformations on one value.
- **Block** when you need intermediate names, side effects (`@write`, `@echo`), or multiple statements that don't compose into a single expression.
- **`@each`** when you need to transform every element of an array; pair it with `@select` for filtering.

```rae
// Pure pipeline: filter + project
.records[] | select(.valid) | .value

// Block with intermediate binding
@block {
  let sum = .records[0].a + .records[1].a;
  let avg = sum / 2;
  avg
}

// @each + @select combo
.records[] | @select(.active) | @each(x in .tags) { x }
```

There are no top-level `for`, `if`, or `while` — traversal happens through `.[]` and `select()`, mutation through `=`, and side effects through built-ins.