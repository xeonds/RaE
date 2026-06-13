# RaE TODO

## P0 — 差异化护城河（决定 RaE 是否成立）

不实现这些，RaE 就是 "Construct in OCaml"。

- [ ] **写回时自动重算校验和** — `@checksum(field)` 标记后，构造/变更时引擎自动更新。当前 `@checksum` 只是求值，不是声明。
- [ ] **变更后偏移自动重排** — 改字段大小后，后续字段 offset 跟着移；当前需用户手写 `after(field)`。
- [ ] **构造模式真实可用** — `new X { ... } | @write(...)` 走完整流程，含嵌套、对齐、校验和写入。当前只 demo 过最简两层。
- [ ] **ELF 完整 schema 案例** — header + sections + program headers + symbol table 跑通读 + 改 + 写，验证差异化是否兑现。

## 序列化

- [ ] **CRC32 / CRC16-CCITT / MD5 / SHA1** — 校验和算法
- [ ] **@bswap16 / @bswap32** — 字节序交换 helper

## 模块化

- [ ] **import 命名空间** — 当前纯文本拼接
- [ ] **多形参模板** `template<T, U>`
- [ ] **枚举值查表** — `enum` 值在 expression 中按名引用

## 数组

- [ ] **变长元素数组** — `array<bytes>` / `array<string>` stride 由 `[size = expr]` 给出

## CLI

- [ ] **stdin 支持** — `cat file.bin | rae script.rae`
- [ ] **`-o` 输出参数**