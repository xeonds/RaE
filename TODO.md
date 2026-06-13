# RaE TODO

## 序列化
- [ ] **CRC32 / CRC16-CCITT / MD5 / SHA1** — 校验和
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
