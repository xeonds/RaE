# RaE TODO

## 序列化
- [ ] **`@write` 按 schema 重新编码 VObj** — 当前 `value_to_bytes` 做文本拼接，需基于 struct schema 二进制布局
- [ ] **VFloat 写出用 IEEE 754**（`write_value` 目前缺 Float 分支）

## 字段定位
- [ ] **动态偏移能引用同 struct 字段** — `compute_offset` 的 env 应为当前 struct 累积 env
- [ ] **`[count = expr]` 的 expr 能引用同 struct 字段**

## 数组
- [ ] **变长元素数组** — `array<bytes>` / `array<string>` stride 由 `[size = expr]` 给出

## 校验和
- [ ] **CRC32** / **CRC16-CCITT** / **MD5** / **SHA1**
- [ ] **@bswap16 / @bswap32** 字节序交换

## 模块化
- [ ] **import 命名空间**
- [ ] **多形参模板** `template<T, U>`
- [ ] **枚举值查表** — `enum` 值在 expression 中按名引用

## CLI
- [ ] **stdin 支持**
- [ ] **`-o` 输出参数**
