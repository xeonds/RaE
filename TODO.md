# RaE TODO

## 模块化
- [ ] **import 命名空间** — 当前纯文本拼接，flat 命名
- [ ] **枚举值查表** — `enum` 值在 expression 中按名引用

## 数组
- [ ] **变长元素数组** — `array<bytes>` / `array<string>` stride 由 `[size = expr]` 给出

## 已知设计决定
- 三套整数类型 (VInt/VInt32/VInt64) 对应字段宽度，不统一到 Int64 — 保留类型安全
- 线性 lookup (O(n)) 对 schema (<100 字段) 无瓶颈
- `construct_defs` 全局 ref 在单线程 CLI 下安全
