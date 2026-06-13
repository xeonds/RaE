# RaE — Code Quality Findings

构建：`dune build` 通过。

| ID | 等级 | 模块 | 问题 | 状态 |
|----|------|------|------|------|
| Q1 | 🔴 | `lib/binlib.ml` | 死代码 | ✅ |
| Q2 | 🔴 | 多文件 | VInt/VInt32/VInt64 三套 | 免修 |
| Q3 | 🔴 | `lib/engine.ml` | 双重遍历 | ✅ |
| Q4 | 🟠 | `lib/engine.ml` | 全局 ref | 免修 |
| Q5 | 🟠 | `lib/engine.ml` | 双重 List.rev | ✅ |
| Q6 | 🟠 | `lib/engine.ml` | 线性扫描 | 免修 |
| Q7 | 🟠 | `lib/ast.ml` | 关联列表 | 免修 |
| Q8 | 🟠 | 多文件 | "_" 隐式 | ✅ |
| Q9 | 🟡 | 多文件 | 格式化重复 | ✅ |
| Q10 | 🟡 | `lib/engine.ml` | fallback | ✅ |
| Q11 | 🟡 | `lib/dune` | unix | 免修 |
| Q12 | 🟡 | `lib/lexer.mll` | 关键字 | 免修 |
| Q13 | 🟡 | `lib/engine.ml` | dispatch | 设计 |
| Q14 | 🟡 | 多文件 | BitField/EnumDef | 免修 |
| Q15 | 🟡 | `lib/engine.ml` | import 正则 | 免修 |
| Q16 | 🟡 | `lib/ast.ml` | params | ✅ |
| Q17 | 🟡 | `lib/parser.mly` | failwith | 免修 |

**免修说明**：
- Q2: 三套整数类型虽冗长但正确，统一到 Int64 触及全链路，回归风险过高
- Q4/Q6/Q7: 当前 Schemas 规模 (≤100 字段) 下 O(n) 线性扫描无性能瓶颈
- Q12: 大小写两套是 OCaml lexer 惯例，无实际歧义
- Q14: parser 完整，runtime 无人用，待需求驱动
