# RaE — Code Quality Findings

构建：`dune build` 通过。

| ID | 等级 | 模块 | 问题 | 状态 |
|----|------|------|------|------|
| Q1 | 🔴 | `lib/binlib.ml` | 死代码 | ✅ |
| Q2 | 🔴 | `lib/ast.ml` `lib/engine.ml` | VInt/VInt32/VInt64 三套 | 待修 |
| Q3 | 🔴 | `lib/engine.ml` | parse_field/size_of_field 双重 | ✅ |
| Q4 | 🟠 | `lib/engine.ml` | construct_defs 全局 ref | 待修 |
| Q5 | 🟠 | `lib/engine.ml` | eval_actions 双重 List.rev | ✅ |
| Q6 | 🟠 | `lib/engine.ml` | lookup_struct 线性 | 免修 |
| Q7 | 🟠 | `lib/ast.ml` | VObj 关联列表 | 免修 |
| Q8 | 🟠 | 多文件 | Ident "_" 隐式约定 | ✅ |
| Q9 | 🟡 | 多文件 | 值格式化重复 | ✅ |
| Q10 | 🟡 | `lib/engine.ml` | construct_binary fallback | ✅ |
| Q11 | 🟡 | `lib/dune` | unix 未使用 | 免修 |
| Q12 | 🟡 | `lib/lexer.mll` | 关键字两套 | 免修 |
| Q13 | 🟡 | `lib/engine.ml` | dispatch_variants 静默 | 设计 |
| Q14 | 🟡 | 多文件 | BitFieldDef/EnumDef runtime | 待修 |
| Q15 | 🟡 | `lib/engine.ml` | process_imports 正则 | 免修 |
| Q16 | 🟡 | `lib/ast.ml` | StructDef.params | ✅ |
| Q17 | 🟡 | `lib/parser.mly` | attr_key failwith | 免修 |
