# Bug Report — RaE

构建：`dune build` 通过。

## 状态

| ID | 问题 | 状态 |
|----|------|------|
| B1 | 多顶层 expr current 污染 | ✅ |
| B2 | `@echo` VBytes/数组 | ✅ |
| B3 | `parse_binary` definitions | ✅ |
| B4 | menhir conflict 8→2 | ✅ |
| B5 | 字符串变长字段 | ✅ |
| B6 | `@write` mutation 写出 | ✅ Assign + value_to_bytes 序列化 |
| B7 | `@checksum` | ✅ |
| B8 | `field_decl` 分号 | ✅ |
| B9 | 混合类型算术 | ✅ |
| B10 | `@select` filter | ✅ |
| B11 | `string`/`bytes` 0 字节 | ✅ |
| B12 | F32/F64 浮点 | ✅ |
| B13 | `i8`/`i16` 符号 | ✅ |
| B14 | `variant` dispatch | ✅ |
| B15 | `template<T>` | ✅ 参数替换展开 |
| B16 | u64 溢出 | ✅ |
| B17 | 越界 crash | ✅ |
| B18 | `string(n)` 语法 | ✅ |

全部解决。
