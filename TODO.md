# RaE TODO

## LSP
- [x] **关键字补全** — 41 个 token: 关键词(11) + 类型(13) + 属性(7) + builtin(10)
- [ ] **上下文补全** — `@` 后只补全 builtins, `[...` 内只补全属性键
- [ ] **诊断位置优化** — Syntax_error 使用 AST loc 而非 lexbuf 位置
