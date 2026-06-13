# Bug Report — RaE

构建：`dune build` 通过，menhir 警告 2 个 shift/reduce conflict（预期内）。

## 状态总览

| ID | 问题 | 状态 |
|----|------|------|
| B1 | 多顶层 expr current 污染 | ✅ 分号分隔，各 action 独立 |
| B2 | `@echo` 对 VBytes/数组 | ✅ 打印 VBytes 内容、VArray `[a,b]` |
| B3 | `parse_binary` 不处理 definitions 里的 struct | ✅ 实例化字段可用；纯 definition 不解析是设计行为 |
| B4 | menhir conflict | ✅ 8→2 |
| B5 | 字符串变长字段 | ✅ 根因 B11 已修复 |
| B6 | `@write` 只能写原始 bytes | ❌ mutation 未实现 |
| B7 | `@checksum` | ✅ VObj 序列化后计算 |
| B8 | `field_decl` 分号 | ✅ 分号改为可选 |
| B9 | `eval_binary_op` 缺类型提升 | ✅ VInt32+VInt, VInt64+VInt 等跨类型 |
| B10 | `@select` filter | ✅ |
| B11 | `string`/`bytes` 读 0 字节 | ✅ size_of_type 处理 BytesType(Some n) |
| B12 | F32/F64 解析为整数 | ✅ IEEE 754 float 读取 |
| B13 | `i8`/`i16` 符号扩展 | ✅ I8 sign bit 检查, I16/I32/I64 用 read_sint |
| B14 | `variant` 成员被丢弃 | 🟡 filter_map 保留 Field，Variant 待实现 |
| B15 | `template<T>` 未实现 | ❌ parser 不支持 |
| B16 | u64 lsl 56 溢出 | ✅ read_uint 用 Int64 运算 |
| B17 | `Bytes.sub` 越界 | ✅ parse_field_bytes 边界检查抛 Engine_error |
| B18 | `string(n)` 语法 | ✅ STRING() 接受 expr |

## 剩余待实现

| ID | 问题 |
|----|------|
| B6 | `@write` mutation 路径 — Assign 返回 VNull |
| B14 | `variant` dispatch — parse_field 按 tag 路由 |
| B15 | `template<T>` 泛型 — parser 拒 |
