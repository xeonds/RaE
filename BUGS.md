# RaE — Code Quality Findings

构建：`dune build` 通过。

| ID | 等级 | 模块 | 问题 | 状态 |
|----|------|------|------|------|
| Q1 | 🔴 | `lib/binlib.ml` | `parse_data`/`write_data` 用 `int_of_string` / `Int32.of_string` 处理 raw bytes，整条 I/O 路径与 `engine.ml` 重复且语义错误；死代码 | 待修 |
| Q2 | 🔴 | `lib/ast.ml` `lib/engine.ml` | `VInt`/`VInt32`/`VInt64` 三套并存，eval/equal/format 全部 3×3 矩阵，赋值靠 fallback 类型适配 | 待修 |
| Q3 | 🔴 | `lib/engine.ml` | `parse_field` 和 `size_of_field` 重复展开 struct/数组，嵌套 struct 数组 O(n²) 调用 | 待修 |
| Q4 | 🟠 | `lib/engine.ml` | `construct_defs` 是全局 `ref`，`main.ml` 在 LSP/测试并发场景下会污染 | 待修 |
| Q5 | 🟠 | `lib/engine.ml` | `eval_actions` 对 actions 调 `List.rev` 两次 | 待修 |
| Q6 | 🟠 | `lib/engine.ml` | `lookup_struct` / `lookup_template` 每次线性扫描 defs | 待修 |
| Q7 | 🟠 | `lib/ast.ml` | `VObj` 用关联列表，`List.assoc`/`remove_assoc` O(n)，重复字段无保护 | 待修 |
| Q8 | 🟠 | `lib/parser.mly` `lib/engine.ml` | `Ident "_"` 隐式约定 current，散在 parser/engine 两处 | 待修 |
| Q9 | 🟡 | `bin/main.ml` `lib/engine.ml` `lib/binlib.ml` | 值的格式化在 4 个文件里重复手写 | 待修 |
| Q10 | 🟡 | `lib/engine.ml` | `construct_binary` 对 `Dynamic`/`After` offset 静默 fallback 到 0 | 待修 |
| Q11 | 🟡 | `lib/dune` | 声明依赖 `unix` 但未使用 | 待修 |
| Q12 | 🟡 | `lib/lexer.mll` | 关键字大小写两套，标识符/关键字冲突靠 case-insensitive 兜底 | 待修 |
| Q13 | 🟡 | `lib/engine.ml` | `dispatch_variants` 无匹配 case 静默返回原 env | 待修 |
| Q14 | 🟡 | `lib/ast.ml` `lib/parser.mly` `lib/engine.ml` | `BitFieldDef` / `EnumDef` parser 有但 engine 不完整 | 待修 |
| Q15 | 🟡 | `lib/engine.ml` | `process_imports` 用正则匹配 `import '...'`，会误命中字符串字面量 | 待修 |
| Q16 | 🟡 | `lib/ast.ml` `lib/parser.mly` `lib/engine.ml` | `StructDef.params` 多参能力声明但实现只支持 1 | 待修 |
| Q17 | 🟡 | `lib/parser.mly` | `attr_key` 用字符串比较 + `failwith` 抛非位置错误 | 待修 |
