# Templates

Templates parameterize a struct over one or more type variables. They let you write a struct once and instantiate it with different element types.

## Defining a template

```rae
template<T, U> Pair {
  first: T;
  second: U;
}
```

The type parameters (`T`, `U`) are used in field declarations. Any field type is allowed — primitives, strings, structs, even other templates.

## Instantiating

```rae
p_int_str: Pair<u32, string(8)>;
p_str_str: Pair<string(16), string(16)>;
p_ints:   Pair<array<u8>, array<u16>>;
```

The angle brackets contain the actual types to substitute. The parser does the substitution at parse time and the engine lays out the resulting fields.

## Constraints

- The number of type parameters in the instantiation must match the template's declaration.
- Primitive type names are resolved before substitution, so `Pair<u32, u8>` substitutes `u32` for `T` and `u8` for `U`.
- Templates don't recurse — you can't reference a template inside its own body.

## Example: a generic header

```rae
template<T> Hdr {
  magic: u32 @ 0 [endian = be] == 0xDEADBEEF;
  payload: T;
}

file F {
  hdr_u8:  Hdr<u8>;
  hdr_str: Hdr<string(8)>;
}
```

The template's magic is the same across both instantiations; only the payload type changes.

## Templates vs structs

Use a struct when the shape is fixed. Use a template when you have a recurring shape that varies only by element type — for example, a fixed-length header followed by a variable-type body, a tagged pointer, or a generic record.

Templates are expanded inline. There's no runtime overhead or indirection.