# RaE — Quality & Bugs

构建：`dune build` 通过，2 个 menhir shift/reduce conflict（预期内）。

## Quality (全关)

17 项，11 修 6 免修。

## Bug Report (全关)

| ID | 问题 | 状态 |
|----|------|------|
| B7 | `@checksum` VInt32/VInt64 字符串化 | ✅ |
| B9 | 位运算 keyword 形式 (`land`/`lor`/`lsl`) | ✅ |
| B15 | `template<T>` + 基本类型参数 | ✅ |
| B16 | u64 越界 | OCaml Int64 限制 |

**本轮修复**：B7 value_to_bytes 对 VInt32/VInt64 用 write_uint；B9 lexer 加 land/lor/lxor/lsl/lsr keywords + parser BOR token；B15 resolve_type 将 StructType "u8" → U8 等基本类型映射。

## 设计注释

- B3 (`parse_binary` definitions) 不是 bug：struct 必须实例化为 field 才能解析
- N1 (`after(field)` 语义) 不是 bug：`after(X)` 明确是字段结束位置
