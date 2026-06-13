# RaE — Code Quality Findings

构建：`dune build` 通过。

| ID | 等级 | 模块 | 问题 | 状态 |
|----|------|------|------|------|
| Q1 | 🔴 | `lib/binlib.ml` | 死代码，已精简 | ✅ |
| Q2 | 🔴 | `lib/ast.ml` `lib/engine.ml` | VInt/VInt32/VInt64 三套共存 | 待修 |
| Q3 | 🔴 | `lib/engine.ml` | parse_field/size_of_field 重复展开 struct/数组 | 待修 |
| Q4 | 🟠 | `lib/engine.ml` | construct_defs 全局 ref | 待修 |
| Q5 | 🟠 | `lib/engine.ml` | eval_actions List.rev 两次 | ✅ |
| Q6 | 🟠 | `lib/engine.ml` | lookup_struct 线性扫描 | 待修 |
| Q7 | 🟠 | `lib/ast.ml` | VObj 关联列表 O(n) | 待修 |
| Q8 | 🟠 | `lib/parser.mly` `lib/engine.ml` | Ident "_" 隐式约定 | 待修 |
| Q9 | 🟡 | 多文件 | 值格式化重复 | 待修 |
| Q10 | 🟡 | `lib/engine.ml` | construct_binary offset fallback | ✅ |
| Q11 | 🟡 | `lib/dune` | 声明 unix 未使用 (LSP 在用) | 免修 |
| Q12 | 🟡 | `lib/lexer.mll` | 关键字大小写两套 | 待修 |
| Q13 | 🟡 | `lib/engine.ml` | dispatch_variants 无匹配静默 | 设计 |
| Q14 | 🟡 | 多文件 | BitFieldDef/EnumDef engine 不完整 | 待修 |
| Q15 | 🟡 | `lib/engine.ml` | process_imports 正则边缘情况 | 免修 |
| Q16 | 🟡 | `lib/ast.ml` | StructDef.params 多参已实现 | ✅ |
| Q17 | 🟡 | `lib/parser.mly` | attr_key failwith | 免修 |
